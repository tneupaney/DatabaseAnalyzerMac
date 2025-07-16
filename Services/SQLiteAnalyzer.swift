import Foundation
import GRDB // Import GRDB for SQLite interaction

// Define a custom error type for analysis failures
enum AnalysisError: Error, LocalizedError {
    case databaseConnectionFailed(String)
    case schemaDiscoveryFailed(String)
    case queryExecutionFailed(String)
    case invalidQueryPlanFormat(String)
    case missingTableForTrigger(String)
    case genericError(String)

    var errorDescription: String? {
        switch self {
        case .databaseConnectionFailed(let message): return "Database connection failed: \(message)"
        case .schemaDiscoveryFailed(let message): return "Schema discovery failed: \(message)"
        case .queryExecutionFailed(let message): return "Query execution failed: \(message)"
        case .invalidQueryPlanFormat(let message): return "Invalid query plan format: \(message)"
        case .missingTableForTrigger(let message): return "Missing table for trigger: \(message)"
        case .genericError(let message): return "An error occurred: \(message)"
        }
    }
}

class SQLiteAnalyzer {
    private var dbPaths: [String]
    private(set) var dbQueues: [String: DatabaseQueue] = [:] // Store database queues by shard name

    init(dbPaths: [String]) {
        self.dbPaths = dbPaths
    }

    /// Establishes connections to all SQLite database files.
    private func connectToDatabases() throws {
        dbQueues.removeAll()
        for (index, path) in dbPaths.enumerated() {
            let shardName = "shard_\(index + 1)"
            do {
                let dbQueue = try DatabaseQueue(path: path)
                dbQueues[shardName] = dbQueue
                print("Connected to SQLite database: \(path) as \(shardName)")
            } catch {
                throw AnalysisError.databaseConnectionFailed("Could not open database at \(path): \(error.localizedDescription)")
            }
        }
    }

    /// Discovers the schema of all connected databases.
    func discoverSchema() throws -> DiscoveredSchema {
        try connectToDatabases() // Ensure connections are open

        var discoveredSchema = DiscoveredSchema(shards: [:], relationships: [], allTriggers: [])

        for (shardName, dbQueue) in dbQueues {
            var shardInfo = ShardInfo(tables: [:], triggers: [])
            try dbQueue.read { db in
                // Get table names
                let tableNames = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")

                for tableName in tableNames {
                    var tableInfo = TableInfo(columns: [], primaryKey: [], uniqueConstraints: [], foreignKeys: [], indexes: [])

                    // Columns
                    let columnInfoRows = try Row.fetchAll(db, sql: "PRAGMA table_info(\"\(tableName)\");")
                    for row in columnInfoRows {
                        let name: String = row["name"] ?? "UNKNOWN"
                        let type: String = row["type"] ?? "UNKNOWN"
                        let notNull: Bool = (row["notnull"] as? Int) == 1
                        tableInfo.columns.append(ColumnInfo(name: name, type: type, nullable: !notNull))
                    }

                    // Primary Key
                    tableInfo.primaryKey = columnInfoRows.filter { ($0["pk"] as? Int) == 1 }.map { $0["name"] ?? "" }

                    // Foreign Keys
                    let fkInfoRows = try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(\"\(tableName)\");")
                    for row in fkInfoRows {
                        let fromCol: String = row["from"] ?? "UNKNOWN"
                        let toTable: String = row["table"] ?? "UNKNOWN"
                        let toCol: String = row["to"] ?? "UNKNOWN"
                        tableInfo.foreignKeys.append(ForeignKeyConstraint(constrainedColumns: [fromCol], referredTable: toTable, referredColumns: [toCol]))
                        
                        discoveredSchema.relationships.append(ForeignKeyRelationship(
                            shard: shardName,
                            fromTable: tableName,
                            fromColumns: [fromCol],
                            toTable: toTable,
                            toColumns: [toCol]
                        ))
                    }

                    // Indexes
                    let indexListRows = try Row.fetchAll(db, sql: "PRAGMA index_list(\"\(tableName)\");")
                    for indexRow in indexListRows {
                        let indexName: String = indexRow["name"] ?? "UNKNOWN"
                        let isUnique: Bool = (indexRow["unique"] as? Int) == 1
                        
                        let indexInfoRows = try Row.fetchAll(db, sql: "PRAGMA index_info(\"\(indexName)\");")
                        let columnNames = indexInfoRows.map { (row: Row) -> String in row["name"] ?? "" }
                        
                        tableInfo.indexes.append(IndexInfo(name: indexName, columns: columnNames, unique: isUnique))
                        if isUnique && columnNames.count > 0 {
                            tableInfo.uniqueConstraints.append(columnNames)
                        }
                    }
                    
                    shardInfo.tables[tableName] = tableInfo
                }
                
                // Triggers
                let triggerRows = try Row.fetchAll(db, sql: "SELECT name, tbl_name, sql FROM sqlite_master WHERE type='trigger';")
                for row in triggerRows {
                    let name: String = row["name"] ?? "UNKNOWN"
                    let tableName: String = row["tbl_name"] ?? "UNKNOWN"
                    let sql: String = row["sql"] ?? "UNKNOWN"
                    let triggerInfo = TriggerInfo(name: name, table: tableName, sql: sql, shard: shardName)
                    shardInfo.triggers.append(triggerInfo)
                    discoveredSchema.allTriggers.append(triggerInfo)
                }
            }
            discoveredSchema.shards[shardName] = shardInfo
        }
        return discoveredSchema
    }

    /// Analyzes query performance by generating synthetic queries.
    func analyzeQueries(schema: DiscoveredSchema) throws -> [QueryPerformanceResult] {
        var results: [QueryPerformanceResult] = []
        for (shardName, shardInfo) in schema.shards {
            guard let dbQueue = dbQueues[shardName] else { continue }
            for (tableName, tableInfo) in shardInfo.tables {
                // SELECT * LIMIT 10
                let simpleSelectSQL = "SELECT * FROM \"\(tableName)\" LIMIT 10"
                let simpleSelectResult = try executeAndAnalyzeQuery(dbQueue: dbQueue, query: simpleSelectSQL, queryName: "Select Top 10 from \(tableName) (\(shardName))", suggestedOptimization: "Basic select, usually optimized by default.")
                results.append(simpleSelectResult)

                // COUNT(*)
                let countSQL = "SELECT COUNT(*) FROM \"\(tableName)\""
                let countResult = try executeAndAnalyzeQuery(dbQueue: dbQueue, query: countSQL, queryName: "Count Rows in \(tableName) (\(shardName))", suggestedOptimization: "Consider index on primary key for faster counts on large tables.")
                results.append(countResult)

                // Filter by text column (LIKE)
                if let textCol = tableInfo.columns.first(where: { $0.type.uppercased().contains("TEXT") || $0.type.uppercased().contains("VARCHAR") }) {
                    let filterTextSQL = "SELECT * FROM \"\(tableName)\" WHERE \"\(textCol.name)\" LIKE '%test%' LIMIT 5"
                    let filterTextResult = try executeAndAnalyzeQuery(dbQueue: dbQueue, query: filterTextSQL, queryName: "Filter \(tableName) by \(textCol.name) (LIKE) (\(shardName))", suggestedOptimization: "Consider full-text search or leading wildcard optimization for LIKE queries.")
                    results.append(filterTextResult)
                }

                // Filter by numeric column (Range)
                if let numericCol = tableInfo.columns.first(where: { $0.type.uppercased().contains("INT") || $0.type.uppercased().contains("REAL") || $0.type.uppercased().contains("DECIMAL") }) {
                    let filterNumericSQL = "SELECT * FROM \"\(tableName)\" WHERE \"\(numericCol.name)\" > 100 LIMIT 5"
                    let filterNumericResult = try executeAndAnalyzeQuery(dbQueue: dbQueue, query: filterNumericSQL, queryName: "Filter \(tableName) by \(numericCol.name) (Range) (\(shardName))", suggestedOptimization: "Ensure index on \(tableName).\(numericCol.name) for range queries.")
                    results.append(filterNumericResult)
                }
            }
        }
        return results
    }

    private func executeAndAnalyzeQuery(dbQueue: DatabaseQueue, query: String, queryName: String, suggestedOptimization: String) throws -> QueryPerformanceResult {
        var queryPlan = "N/A"
        var executionTime: TimeInterval = -1
        var status = "Error"
        var isOptimized = false

        do {
            try dbQueue.read { db in
                // Get Query Plan
                let explainRows = try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN \(query)")
                queryPlan = explainRows.map { row in
                    row.columnNames.map { colName in "\(colName): \(row[colName] ?? "NULL")" }.joined(separator: ", ")
                }.joined(separator: "\n")
                
                // Heuristic for optimization: check for SCAN TABLE and USING INDEX
                let planDetailsUpper = queryPlan.uppercased()
                isOptimized = !planDetailsUpper.contains("SCAN TABLE") || planDetailsUpper.contains("USING INDEX")

                // Execute Query and Measure Time
                let startTime = Date()
                _ = try Row.fetchAll(db, sql: query)
                executionTime = Date().timeIntervalSince(startTime)
                status = String(format: "%.4f", executionTime)
            }
        } catch {
            status = "Error: \(error.localizedDescription)"
            isOptimized = false
        }
        return QueryPerformanceResult(query: queryName, executionTime: status, optimized: isOptimized, suggestedOptimization: suggestedOptimization, queryPlan: queryPlan)
    }

    /// Checks for missing and potentially redundant indexes.
    func checkIndexes(schema: DiscoveredSchema) throws -> ([String], [String]) {
        var issues: [String] = []
        var suggestions: [String] = []

        for (shardName, shardInfo) in schema.shards {
            for (tableName, tableInfo) in shardInfo.tables {
                let existingIndexesForTable = tableInfo.indexes

                // Check for missing indexes on Foreign Keys
                for fk in tableInfo.foreignKeys {
                    let fkColumns = fk.constrainedColumns
                    let hasFkIndex = existingIndexesForTable.contains { idx in
                        Set(fkColumns).isSubset(of: Set(idx.columns))
                    }
                    if !hasFkIndex {
                        let issue = "[\(shardName)] Missing index on foreign key column(s) \(fkColumns.joined(separator: ", ")) in table '\(tableName)'."
                        let suggestion = "CREATE INDEX idx_\(tableName)_\(fkColumns.joined(separator: "_"))_fk ON \"\(tableName)\"(\(fkColumns.joined(separator: ", "))); -- In \(shardName)"
                        if !issues.contains(issue) {
                            issues.append(issue)
                            suggestions.append(suggestion)
                        }
                    }
                }

                // Heuristic check for common columns that should be indexed
                for col in tableInfo.columns {
                    let colName = col.name
                    let colType = col.type.uppercased()
                    
                    let isIndexed = existingIndexesForTable.contains { idx in idx.columns.contains(colName) }
                    let isPK = tableInfo.primaryKey.contains(colName)

                    if !isIndexed && !isPK {
                        if colName.uppercased().contains("ID") && !isPK {
                            let issue = "[\(shardName)] Missing index on potential ID column '\(colName)' in table '\(tableName)'."
                            let suggestion = "CREATE INDEX idx_\(tableName)_\(colName)_id ON \"\(tableName)\"(\(colName)); -- In \(shardName)"
                            if !issues.contains(issue) {
                                issues.append(issue)
                                suggestions.append(suggestion)
                            }
                        } else if colType.contains("DATE") || colType.contains("TIME") || colName.uppercased().contains("DATE") || colType.contains("DATETIME") {
                            let issue = "[\(shardName)] Missing index on date/time column '\(colName)' in table '\(tableName)' (often used for filtering/sorting)."
                            let suggestion = "CREATE INDEX idx_\(tableName)_\(colName)_date ON \"\(tableName)\"(\(colName)); -- In \(shardName)"
                            if !issues.contains(issue) {
                                issues.append(issue)
                                suggestions.append(suggestion)
                            }
                        } else if colName.uppercased().contains("NAME") || colName.uppercased().contains("EMAIL") || colName.uppercased().contains("USERNAME") {
                            let issue = "[\(shardName)] Missing index on text column '\(colName)' in table '\(tableName)' (often used for filtering/joining)."
                            let suggestion = "CREATE INDEX idx_\(tableName)_\(colName)_text ON \"\(tableName)\"(\(colName)); -- In \(shardName)"
                            if !issues.contains(issue) {
                                issues.append(issue)
                                suggestions.append(suggestion)
                            }
                        }
                    }
                }

                // Check for redundant indexes (simple case: index (A) and index (A, B))
                for i in 0..<existingIndexesForTable.count {
                    for j in 0..<existingIndexesForTable.count {
                        if i != j {
                            let idx1 = existingIndexesForTable[i]
                            let idx2 = existingIndexesForTable[j]
                            if Set(idx1.columns).isSubset(of: Set(idx2.columns)) && idx1.columns.count < idx2.columns.count {
                                let issue = "[\(shardName)] Potentially redundant index '\(idx1.name)' on columns \(idx1.columns.joined(separator: ", ")) in table '\(tableName)'. It's covered by '\(idx2.name)' on \(idx2.columns.joined(separator: ", "))."
                                let suggestion = "DROP INDEX \"\(idx1.name)\" ON \"\(tableName)\"; -- In \(shardName)"
                                if !issues.contains(issue) {
                                    issues.append(issue)
                                    suggestions.append(suggestion)
                                }
                            }
                        }
                    }
                }
            }
        }
        return (issues, suggestions)
    }

    /// Performs data integrity checks.
    func checkDataIntegrity(schema: DiscoveredSchema) throws -> [String] {
        var issues: [String] = []

        for (shardName, dbQueue) in dbQueues {
            try dbQueue.read { db in
                // Ensure foreign keys are enabled for checks
                _ = try db.execute(sql: "PRAGMA foreign_keys = ON;")

                // Check for foreign key violations (orphaned records)
                for fkRel in schema.relationships {
                    if fkRel.shard == shardName {
                        let fromTable = fkRel.fromTable
                        let fromCols = fkRel.fromColumns.joined(separator: ", ")
                        let toTable = fkRel.toTable
                        let toCols = fkRel.toColumns.joined(separator: ", ")

                        // Check if tables exist in the current shard
                        let tableExists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='\(fromTable)');") ?? false
                        let referredTableExists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='\(toTable)');") ?? false

                        guard tableExists && referredTableExists else { continue }

                        do {
                            let orphanedRows = try Row.fetchAll(db, sql: """
                                SELECT \(fromCols)
                                FROM "\(fromTable)"
                                WHERE \(fromCols) NOT IN (SELECT \(toCols) FROM "\(toTable)")
                                """)
                            if !orphanedRows.isEmpty {
                                let recordStrings = orphanedRows.map { row in
                                    row.columnNames.map { colName in "\(colName): \(row[colName] ?? "NULL")" }.joined(separator: ", ")
                                }
                                issues.append("[\(shardName)] Foreign Key Violation: Orphaned records found in '\(fromTable)' (columns: \(fromCols)) referencing non-existent entries in '\(toTable)' (columns: \(toCols)): \(recordStrings.joined(separator: "; "))")
                            }
                        } catch {
                            issues.append("[\(shardName)] Error checking FK between \(fromTable) and \(toTable): \(error.localizedDescription)")
                        }
                    }
                }

                // Check for duplicate unique columns
                for (tableName, tableInfo) in schema.shards[shardName]?.tables ?? [:] {
                    for uniqueCols in tableInfo.uniqueConstraints {
                        let colsStr = uniqueCols.joined(separator: ", ")
                        do {
                            let duplicateRows = try Row.fetchAll(db, sql: """
                                SELECT \(colsStr), COUNT(*) as count
                                FROM "\(tableName)"
                                GROUP BY \(colsStr)
                                HAVING COUNT(*) > 1
                                """)
                            if !duplicateRows.isEmpty {
                                let recordStrings = duplicateRows.map { row in
                                    let count: Int = row["count"] ?? 0
                                    let colValues = uniqueCols.map { colName in "\(colName): \(row[colName] ?? "NULL")" }.joined(separator: ", ")
                                    return "(\(colValues), Count: \(count))"
                                }
                                issues.append("[\(shardName)] Duplicate Unique Constraint: Found duplicate entries for unique column(s) '\(colsStr)' in table '\(tableName)': \(recordStrings.joined(separator: "; "))")
                            }
                        } catch {
                            issues.append("[\(shardName)] Error checking unique constraint on \(tableName).\(colsStr): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        return issues
    }

    /// Scans for sensitive data.
    func checkSecurity(schema: DiscoveredSchema) throws -> [String] {
        var findings: [String] = []
        let emailRegex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
        let ssnRegex = try! NSRegularExpression(pattern: "^\\d{3}-\\d{2}-\\d{4}$")
        let creditCardRegex = try! NSRegularExpression(pattern: "^(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|6(?:011|5[0-9]{2})[0-9]{12}|3[47][0-9]{13}|(?:2131|1800|35\\d{3})\\d{11})$")

        for (shardName, dbQueue) in dbQueues {
            for (tableName, tableInfo) in schema.shards[shardName]?.tables ?? [:] {
                for col in tableInfo.columns {
                    let colNameLower = col.name.lowercased()
                    let colTypeUpper = col.type.uppercased()

                    if colTypeUpper.contains("TEXT") || colTypeUpper.contains("VARCHAR") {
                        if colNameLower.contains("password") {
                            try dbQueue.read { db in
                                if let sampleValue = try String.fetchOne(db, sql: "SELECT \"\(col.name)\" FROM \"\(tableName)\" WHERE \"\(col.name)\" IS NOT NULL LIMIT 1") {
                                    if sampleValue.count == 64 && sampleValue.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil {
                                        findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Appears to be SHA256 hashed (Good practice).")
                                    } else if sampleValue.count < 20 && !sampleValue.contains(" ") && sampleValue.range(of: "\\W", options: .regularExpression) == nil {
                                        findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Might contain plaintext or weakly hashed passwords (CRITICAL: Investigate immediately!). Sample: '\(sampleValue.prefix(10))...'")
                                    } else {
                                        findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Password field has an unknown format. (WARNING: Verify hashing method). Sample: '\(sampleValue.prefix(10))...'")
                                    }
                                } else {
                                    findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Potential password field, but no data to analyze.")
                                }
                            }
                        }
                        
                        if colNameLower.contains("email") {
                            try dbQueue.read { db in
                                if let sampleValue = try String.fetchOne(db, sql: "SELECT \"\(col.name)\" FROM \"\(tableName)\" WHERE \"\(col.name)\" IS NOT NULL LIMIT 1") {
                                    if emailRegex.firstMatch(in: sampleValue, range: NSRange(sampleValue.startIndex..., in: sampleValue)) != nil {
                                        findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Contains email addresses (Sensitive PII).")
                                    }
                                }
                            }
                        }
                        if colNameLower.contains("ssn") || colNameLower.contains("social_security") {
                            try dbQueue.read { db in
                                if let sampleValue = try String.fetchOne(db, sql: "SELECT \"\(col.name)\" FROM \"\(tableName)\" WHERE \"\(col.name)\" IS NOT NULL LIMIT 1") {
                                    if ssnRegex.firstMatch(in: sampleValue, range: NSRange(sampleValue.startIndex..., in: sampleValue)) != nil {
                                        findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Contains Social Security Numbers (Highly Sensitive PII).")
                                    }
                                }
                            }
                        }
                        if colNameLower.contains("credit_card") || colNameLower.contains("card_number") || colNameLower.contains("cc_num") {
                            try dbQueue.read { db in
                                if let sampleValue = try String.fetchOne(db, sql: "SELECT \"\(col.name)\" FROM \"\(tableName)\" WHERE \"\(col.name)\" IS NOT NULL LIMIT 1") {
                                    let cleanedValue = sampleValue.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                                    if creditCardRegex.firstMatch(in: cleanedValue, range: NSRange(cleanedValue.startIndex..., in: cleanedValue)) != nil {
                                        findings.append("[\(shardName)] Table '\(tableName)', Column '\(col.name)': Contains Credit Card Numbers (PCI Sensitive Data). (CRITICAL: Should be encrypted/tokenized).")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return findings
    }

    /// Analyzes trigger performance.
    func analyzeTriggers(schema: DiscoveredSchema) throws -> [String] {
        var results: [String] = []

        for triggerInfo in schema.allTriggers {
            let shardName = triggerInfo.shard
            let triggerName = triggerInfo.name
            let tableName = triggerInfo.table
            let triggerSQL = triggerInfo.sql

            guard let dbQueue = dbQueues[shardName] else {
                results.append("[\(shardName)] Engine not found for trigger '\(triggerName)'. Skipping.")
                continue
            }

            // Only test AFTER INSERT triggers for simplicity
            if triggerSQL.uppercased().contains("AFTER INSERT") {
                results.append("\nAnalyzing performance of trigger '\(triggerName)' on '\(tableName)' in \(shardName)...")
                let numInserts = 100

                // Get column names and types for the target table to construct a valid insert
                guard let tableDetails = schema.shards[shardName]?.tables[tableName] else {
                    results.append("[\(shardName)] Table '\(tableName)' for trigger '\(triggerName)' not found in schema. Skipping performance test.")
                    continue
                }

                var insertStatements: [String] = []
                for i in 0..<numInserts {
                    var columns: [String] = []
                    var values: [String] = []
                    for col in tableDetails.columns {
                        // Skip auto-incrementing PKs (heuristic for SQLite)
                        if tableDetails.primaryKey.contains(col.name) && (col.type.uppercased().contains("INTEGER") && col.name.lowercased().contains("id")) {
                            continue
                        }

                        columns.append("\"\(col.name)\"")
                        switch col.type.uppercased() {
                        case let type where type.contains("INT"):
                            values.append("\(i + 1000000 + (results.count * numInserts))")
                        case let type where type.contains("REAL") || type.contains("DECIMAL"):
                            values.append(String(format: "%.2f", 100.0 + Double(i) * 0.5))
                        case let type where type.contains("TEXT") || type.contains("VARCHAR"):
                            if col.name.uppercased().contains("DATE") || col.name.uppercased().contains("DATETIME") {
                                values.append("'2025-01-\(String(format: "%02d", i % 28 + 1))'")
                            } else if col.name.uppercased().contains("EMAIL") {
                                values.append("'test\(i)@example.com'")
                            } else if col.name.uppercased().contains("NAME") {
                                values.append("'TestName\(i)'")
                            } else {
                                values.append("'dummy_value_\(i)'")
                            }
                        default:
                            values.append("NULL")
                        }
                    }
                    insertStatements.append("INSERT INTO \"\(tableName)\" (\(columns.joined(separator: ", "))) VALUES (\(values.joined(separator: ", ")));")
                }

                let startTime = Date()
                do {
                    try dbQueue.write { db in
                        defer {
                            try? db.execute(sql: "PRAGMA foreign_keys = ON;")
                        }
                        _ = try db.execute(sql: "PRAGMA foreign_keys = OFF;")
                        _ = try db.execute(sql: "BEGIN TRANSACTION;")
                        for sql in insertStatements {
                            _ = try db.execute(sql: sql)
                        }
                        _ = try db.execute(sql: "COMMIT;")
                    }
                    let duration = Date().timeIntervalSince(startTime)
                    results.append("[\(shardName)] Trigger '\(triggerName)' on '\(tableName)': Inserted \(numInserts) records in \(String(format: "%.4f", duration)) seconds.")
                    
                    if schema.shards[shardName]?.tables["audit_log"] != nil {
                        try dbQueue.read { db in
                            if let auditLogCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM audit_log;") {
                                results.append("  - Audit log entries after test: \(auditLogCount).")
                            }
                        }
                    }
                } catch {
                    results.append("[\(shardName)] Error testing trigger '\(triggerName)' on '\(tableName)': \(error.localizedDescription)")
                    try dbQueue.write { db in
                        _ = try db.execute(sql: "ROLLBACK;")
                        _ = try db.execute(sql: "PRAGMA foreign_keys = ON;")
                    }
                }
            } else {
                results.append("[\(shardName)] Trigger '\(triggerName)': Only 'AFTER INSERT' triggers are currently analyzed for performance. Skipping.")
            }
        }
        return results
    }

    /// Analyzes relationship (JOIN) performance.
        func analyzeRelationships(schema: DiscoveredSchema) throws -> [String] {
            var results: [String] = []

            for rel in schema.relationships {
                let shardName = rel.shard
                let fromTable = rel.fromTable
                let toTable = rel.toTable

                guard let dbQueue = dbQueues[shardName] else {
                    results.append("[\(shardName)] Engine not found for relationship between '\(fromTable)' and '\(toTable)'. Skipping.")
                    continue
                }

                // Use the actual column names from the relationship
                let fromColumn = rel.fromColumns.first ?? "id"
                let toColumn = rel.toColumns.first ?? "id"

                let joinSQL = """
                    SELECT T1.*, T2.*
                    FROM "\(fromTable)" AS T1
                    JOIN "\(toTable)" AS T2
                    ON T1."\(fromColumn)" = T2."\(toColumn)"
                    LIMIT 10
                """
                
                results.append("[\(shardName)] Analyzing relationship: '\(fromTable)' (\(fromColumn)) JOIN '\(toTable)' (\(toColumn))")

                do {
                    try dbQueue.read { db in
                        let fromTableDetails = schema.shards[shardName]?.tables[fromTable]
                        let hasFkIndex = fromTableDetails?.indexes.contains { idx in
                            Set(rel.fromColumns).isSubset(of: Set(idx.columns))
                        } ?? false
                        results.append("  - Index on FK source (\(fromTable).\(fromColumn)): \(hasFkIndex ? "Exists" : "MISSING")")

                        let toTableDetails = schema.shards[shardName]?.tables[toTable]
                        let hasPkIndexOnTarget = toTableDetails?.indexes.contains { idx in
                            idx.unique && Set(rel.toColumns).isSubset(of: Set(idx.columns))
                        } ?? false
                        results.append("  - Index on FK target (\(toTable).\(toColumn)): \(hasPkIndexOnTarget ? "Exists" : "MISSING")")

                        let explainRows = try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN \(joinSQL)")
                        let queryPlan = explainRows.map { row in
                            row.columnNames.map { colName in "\(colName): \(row[colName] ?? "NULL")" }.joined(separator: ", ")
                        }.joined(separator: "\n")
                        results.append("  - Query Plan:\n\(queryPlan)")

                        let planDetailsUpper = queryPlan.uppercased()
                        if planDetailsUpper.contains("SCAN TABLE") && !planDetailsUpper.contains("USING INDEX") {
                            results.append("  - WARNING: Join query involves full table scan without index. Consider adding indexes on join columns.")
                        } else if !hasFkIndex {
                            results.append("  - SUGGESTION: Add index on '\(fromTable).\(fromColumn)' to improve join performance.")
                        } else {
                            results.append("  - Performance appears reasonable for this synthetic join.")
                        }
                    }
                } catch {
                    results.append("  - Error analyzing join performance: \(error.localizedDescription)")
                }
            }
            return results
        }
}
