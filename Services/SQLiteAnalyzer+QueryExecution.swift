//
//  DatabaseStats.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import Foundation
import GRDB

// Extension to SQLiteAnalyzer for query execution support
extension SQLiteAnalyzer {
    
    /// Access to database queues for SQL Editor
    var dbQueues: [String: DatabaseQueue] {
        return self.dbQueues
    }
    
    /// Execute a custom SQL query on a specific shard
    func executeQuery(_ sql: String, onShard shardName: String) async throws -> [QueryResult] {
        guard let dbQueue = dbQueues[shardName] else {
            throw AnalysisError.genericError("Shard '\(shardName)' not found")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try dbQueue.read { db in
                    let rows = try Row.fetchAll(db, sql: sql)
                    let results = rows.map { row -> QueryResult in
                        var columns: [String: String] = [:]
                        for columnName in row.columnNames {
                            let value = row[columnName]
                            columns[columnName] = formatValue(value)
                        }
                        return QueryResult(columns: columns)
                    }
                    continuation.resume(returning: results)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Get table names for a specific shard
    func getTableNames(forShard shardName: String) throws -> [String] {
        guard let dbQueue = dbQueues[shardName] else {
            throw AnalysisError.genericError("Shard '\(shardName)' not found")
        }
        
        return try dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
        }
    }
    
    /// Get column information for a specific table
    func getTableColumns(tableName: String, inShard shardName: String) throws -> [ColumnInfo] {
        guard let dbQueue = dbQueues[shardName] else {
            throw AnalysisError.genericError("Shard '\(shardName)' not found")
        }
        
        return try dbQueue.read { db in
            let columnInfoRows = try Row.fetchAll(db, sql: "PRAGMA table_info(\"\(tableName)\");")
            return columnInfoRows.map { row in
                let name: String = row["name"] ?? "UNKNOWN"
                let type: String = row["type"] ?? "UNKNOWN"
                let notNull: Bool = (row["notnull"] as? Int) == 1
                return ColumnInfo(name: name, type: type, nullable: !notNull)
            }
        }
    }
    
    /// Format database values for display
    private func formatValue(_ value: DatabaseValue) -> String {
        switch value.storage {
        case .null:
            return "NULL"
        case .int64(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .string(let string):
            return string
        case .blob(let data):
            return "<BLOB \(data.count) bytes>"
        }
    }
    
    /// Get sample data from a table
    func getSampleData(fromTable tableName: String, inShard shardName: String, limit: Int = 100) throws -> [QueryResult] {
        let sql = "SELECT * FROM \"\(tableName)\" LIMIT \(limit);"
        return try executeQuerySync(sql, onShard: shardName)
    }
    
    /// Synchronous version of executeQuery for simpler cases
    private func executeQuerySync(_ sql: String, onShard shardName: String) throws -> [QueryResult] {
        guard let dbQueue = dbQueues[shardName] else {
            throw AnalysisError.genericError("Shard '\(shardName)' not found")
        }
        
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: sql)
            return rows.map { row -> QueryResult in
                var columns: [String: String] = [:]
                for columnName in row.columnNames {
                    let value = row[columnName]
                    columns[columnName] = formatValue(value)
                }
                return QueryResult(columns: columns)
            }
        }
    }
    
    /// Validate SQL query syntax without executing
    func validateQuery(_ sql: String, onShard shardName: String) throws -> Bool {
        guard let dbQueue = dbQueues[shardName] else {
            throw AnalysisError.genericError("Shard '\(shardName)' not found")
        }
        
        return try dbQueue.read { db in
            // Use EXPLAIN to validate syntax without executing
            let explainSQL = "EXPLAIN \(sql)"
            _ = try Row.fetchAll(db, sql: explainSQL)
            return true
        }
    }
    
    /// Get database statistics
    func getDatabaseStats(forShard shardName: String) throws -> DatabaseStats {
        guard let dbQueue = dbQueues[shardName] else {
            throw AnalysisError.genericError("Shard '\(shardName)' not found")
        }
        
        return try dbQueue.read { db in
            let tableCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';") ?? 0
            let indexCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%';") ?? 0
            let triggerCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';") ?? 0
            let viewCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='view';") ?? 0
            
            // Get database size (page count * page size)
            let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count;") ?? 0
            let pageSize = try Int.fetchOne(db, sql: "PRAGMA page_size;") ?? 0
            let databaseSize = pageCount * pageSize
            
            return DatabaseStats(
                tableCount: tableCount,
                indexCount: indexCount,
                triggerCount: triggerCount,
                viewCount: viewCount,
                databaseSize: databaseSize,
                pageCount: pageCount,
                pageSize: pageSize
            )
        }
    }
}

// MARK: - Supporting Data Models

struct DatabaseStats {
    let tableCount: Int
    let indexCount: Int
    let triggerCount: Int
    let viewCount: Int
    let databaseSize: Int
    let pageCount: Int
    let pageSize: Int
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(databaseSize))
    }
}