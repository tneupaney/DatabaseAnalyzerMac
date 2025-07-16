import SwiftUI
import GRDB
#if canImport(AppKit)
import AppKit
#endif

struct DataBrowserView: View {
    let analyzer: SQLiteAnalyzer
    let schema: DiscoveredSchema
    
    @State private var selectedShard: String = ""
    @State private var selectedTable: String = ""
    @State private var tableData: [QueryResult] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var currentPage: Int = 0
    @State private var rowsPerPage: Int = 50
    @State private var totalRows: Int = 0
    @State private var searchText: String = ""
    @State private var sortColumn: String = ""
    @State private var sortAscending: Bool = true
    
    var availableShards: [String] {
        Array(schema.shards.keys).sorted()
    }
    
    var availableTables: [String] {
        guard !selectedShard.isEmpty,
              let shardInfo = schema.shards[selectedShard] else { return [] }
        return Array(shardInfo.tables.keys).sorted()
    }
    
    var tableColumns: [ColumnInfo] {
        guard !selectedShard.isEmpty, !selectedTable.isEmpty else { return [] }
        return schema.shards[selectedShard]?.tables[selectedTable]?.columns ?? []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    // Database and table selection
                    HStack {
                        Text("Database:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Shard", selection: $selectedShard) {
                            Text("Select Database").tag("")
                            ForEach(availableShards, id: \.self) { shard in
                                Text(shard).tag(shard)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                        .onChange(of: selectedShard) { _, _ in
                            selectedTable = ""
                            tableData = []
                        }
                        
                        Text("Table:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Table", selection: $selectedTable) {
                            Text("Select Table").tag("")
                            ForEach(availableTables, id: \.self) { table in
                                Text(table).tag(table)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                        .disabled(selectedShard.isEmpty)
                        .onChange(of: selectedTable) { _, _ in
                            if !selectedTable.isEmpty {
                                loadTableData()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    HStack {
                        if !selectedTable.isEmpty {
                            Text("Rows per page:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Rows", selection: $rowsPerPage) {
                                Text("25").tag(25)
                                Text("50").tag(50)
                                Text("100").tag(100)
                                Text("500").tag(500)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 80)
                            .onChange(of: rowsPerPage) { _, _ in
                                currentPage = 0
                                loadTableData()
                            }
                        }
                        
                        Button("Refresh") {
                            loadTableData()
                        }
                        .disabled(selectedTable.isEmpty || isLoading)
                        
                        Button("Export CSV") {
                            exportTableData()
                        }
                        .disabled(tableData.isEmpty)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .border(Color(.separatorColor), width: 1)
                
                // Search bar
                if !selectedTable.isEmpty {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search in table data...", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                loadTableData()
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Button("Search") {
                            performSearch()
                        }
                        .disabled(searchText.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                // Table info and pagination
                if !selectedTable.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Table: \(selectedTable)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("Total rows: \(totalRows)")
                                Text("•")
                                Text("Columns: \(tableColumns.count)")
                                Text("•")
                                Text("Page: \(currentPage + 1)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Pagination controls
                        HStack {
                            Button("Previous") {
                                if currentPage > 0 {
                                    currentPage -= 1
                                    loadTableData()
                                }
                            }
                            .disabled(currentPage <= 0 || isLoading)
                            
                            Button("Next") {
                                currentPage += 1
                                loadTableData()
                            }
                            .disabled(tableData.count < rowsPerPage || isLoading)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                }
                
                // Data display
                if isLoading {
                    ProgressView("Loading table data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        loadTableData()
                    }
                } else if selectedTable.isEmpty {
                    EmptySelectionView()
                } else if tableData.isEmpty {
                    EmptyDataView(tableName: selectedTable)
                } else {
                    TableDataView(
                        data: tableData,
                        columns: tableColumns,
                        sortColumn: $sortColumn,
                        sortAscending: $sortAscending,
                        onSort: { column in
                            if sortColumn == column {
                                sortAscending.toggle()
                            } else {
                                sortColumn = column
                                sortAscending = true
                            }
                            loadTableData()
                        }
                    )
                }
            }
        }
        .navigationTitle("Data Browser")
        .onAppear {
            if selectedShard.isEmpty && !availableShards.isEmpty {
                selectedShard = availableShards.first!
            }
        }
    }
    
    private func loadTableData() {
        guard !selectedShard.isEmpty, !selectedTable.isEmpty else {
            print("DEBUG: Cannot load data - missing shard or table")
            return
        }
        
        print("DEBUG: Loading data for table '\(selectedTable)' in shard '\(selectedShard)'")
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Build query with pagination, search, and sorting
                var queryParts: [String] = []
                queryParts.append("SELECT * FROM \"\(selectedTable)\"")
                
                // Add search filter
                if !searchText.isEmpty {
                    let searchConditions = tableColumns.compactMap { column in
                        if column.type.uppercased().contains("TEXT") || column.type.uppercased().contains("VARCHAR") {
                            return "\"\(column.name)\" LIKE '%\(searchText)%'"
                        }
                        return nil
                    }
                    
                    if !searchConditions.isEmpty {
                        let whereClause = " WHERE "
                        let conditions = searchConditions.joined(separator: " OR ")
                        queryParts.append(whereClause)
                        queryParts.append(conditions)
                    }
                }
                
                // Add sorting
                if !sortColumn.isEmpty {
                    let orderClause = " ORDER BY \"\(sortColumn)\" \(sortAscending ? "ASC" : "DESC")"
                    queryParts.append(orderClause)
                }
                
                // Add pagination
                let offset = currentPage * rowsPerPage
                let limitClause = " LIMIT \(rowsPerPage) OFFSET \(offset)"
                queryParts.append(limitClause)
                
                let query = queryParts.joined()
                print("DEBUG: Executing query: \(query)")
                
                let results = try await executeQuerySafely(query, onShard: selectedShard)
                print("DEBUG: Query returned \(results.count) rows")
                
                // Get total count
                var countQueryParts: [String] = []
                countQueryParts.append("SELECT COUNT(*) as total FROM \"\(selectedTable)\"")
                
                if !searchText.isEmpty {
                    let searchConditions = tableColumns.compactMap { column in
                        if column.type.uppercased().contains("TEXT") || column.type.uppercased().contains("VARCHAR") {
                            return "\"\(column.name)\" LIKE '%\(searchText)%'"
                        }
                        return nil
                    }
                    
                    if !searchConditions.isEmpty {
                        let whereClause = " WHERE "
                        let conditions = searchConditions.joined(separator: " OR ")
                        countQueryParts.append(whereClause)
                        countQueryParts.append(conditions)
                    }
                }
                
                let countQuery = countQueryParts.joined()
                print("DEBUG: Executing count query: \(countQuery)")
                
                let countResults = try await executeQuerySafely(countQuery, onShard: selectedShard)
                print("DEBUG: Count query returned \(countResults.count) results")
                if let firstCountResult = countResults.first {
                    print("DEBUG: Count result columns: \(firstCountResult.columns)")
                }
                
                let totalString = countResults.first?.columns["total"] ?? "0"
                let total = Int(totalString) ?? 0
                print("DEBUG: Parsed total as: \(total) from string: '\(totalString)'")
                
                await MainActor.run {
                    self.tableData = results
                    self.totalRows = total
                    self.isLoading = false
                    print("DEBUG: UI updated with \(results.count) rows, total: \(total)")
                }
            } catch {
                print("DEBUG: Error loading table data: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func executeQuerySafely(_ query: String, onShard shard: String) async throws -> [QueryResult] {
        guard let dbQueue = analyzer.dbQueues[shard] else {
            throw NSError(domain: "DataBrowser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Shard '\(shard)' not found"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try dbQueue.read { db in
                    let rows = try Row.fetchAll(db, sql: query)
                    let results = rows.map { row in
                        var columns: [String: String] = [:]
                        for columnName in row.columnNames {
                            let value = row[columnName]
                            
                            // Handle different data types properly
                            if let stringValue = value as? String {
                                columns[columnName] = stringValue
                            } else if let intValue = value as? Int64 {
                                columns[columnName] = String(intValue)
                            } else if let intValue = value as? Int {
                                columns[columnName] = String(intValue)
                            } else if let doubleValue = value as? Double {
                                columns[columnName] = String(format: "%.2f", doubleValue)
                            } else if let boolValue = value as? Bool {
                                columns[columnName] = boolValue ? "true" : "false"
                            } else if value == nil {
                                columns[columnName] = "NULL"
                            } else {
                                // For any other type, convert to string without Optional wrapper
                                let stringValue = String(describing: value)
                                // Remove Optional() wrapper if present
                                if stringValue.hasPrefix("Optional(") && stringValue.hasSuffix(")") {
                                    let startIndex = stringValue.index(stringValue.startIndex, offsetBy: 9)
                                    let endIndex = stringValue.index(stringValue.endIndex, offsetBy: -1)
                                    columns[columnName] = String(stringValue[startIndex..<endIndex])
                                } else {
                                    columns[columnName] = stringValue
                                }
                            }
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
    
    private func performSearch() {
        currentPage = 0
        loadTableData()
    }
    
    private func exportTableData() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(selectedTable)_data.csv"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    do {
                        // Export all data, not just current page
                        var exportQueryParts: [String] = []
                        exportQueryParts.append("SELECT * FROM \"\(selectedTable)\"")
                        
                        if !searchText.isEmpty {
                            let escapedSearchText = searchText.replacingOccurrences(of: "'", with: "''")
                            let searchConditions = tableColumns.compactMap { column in
                                if column.type.uppercased().contains("TEXT") || column.type.uppercased().contains("VARCHAR") {
                                    return "\"\(column.name)\" LIKE '%\(escapedSearchText)%'"
                                }
                                return nil
                            }
                            
                            if !searchConditions.isEmpty {
                                let whereClause = " WHERE "
                                let conditions = searchConditions.joined(separator: " OR ")
                                exportQueryParts.append(whereClause)
                                exportQueryParts.append(conditions)
                            }
                        }
                        
                        let exportQuery = exportQueryParts.joined()
                        let allData = try await executeQuerySafely(exportQuery, onShard: selectedShard)
                        let csvContent = generateCSV(from: allData)
                        
                        try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Export failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        #endif
    }
    
    private func generateCSV(from results: [QueryResult]) -> String {
        guard !results.isEmpty else { return "" }
        
        let headers = tableColumns.map { $0.name }
        var csvLines: [String] = []
        csvLines.append(headers.joined(separator: ","))
        
        for result in results {
            let rowValues = headers.map { key -> String in
                let value = result.columns[key] ?? ""
                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            let row = rowValues.joined(separator: ",")
            csvLines.append(row)
        }
        
        return csvLines.joined(separator: "\n")
    }
}

// MARK: - Supporting Views

struct TableDataView: View {
    let data: [QueryResult]
    let columns: [ColumnInfo]
    @Binding var sortColumn: String
    @Binding var sortAscending: Bool
    let onSort: (String) -> Void
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                // Headers
                HStack(spacing: 0) {
                    ForEach(columns, id: \.name) { column in
                        Button {
                            onSort(column.name)
                        } label: {
                            HStack {
                                Text(column.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if sortColumn == column.name {
                                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .frame(minWidth: 320, maxWidth: .infinity, alignment: .leading)
                            .background(Color(.controlBackgroundColor))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Column separator
                        if column.name != columns.last?.name {
                            Rectangle()
                                .fill(Color(.separatorColor))
                                .frame(width: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Data rows
                ForEach(Array(data.enumerated()), id: \.offset) { index, result in
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.name) { column in
                            Text(result.columns[column.name] ?? "NULL")
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(8)
                                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                                .background(index % 2 == 0 ? Color(.controlBackgroundColor).opacity(0.2) : Color.clear)
                                .lineLimit(1)
                            
                            // Column separator
                            if column.name != columns.last?.name {
                                Rectangle()
                                    .fill(Color(.separatorColor))
                                    .frame(width: 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Row separator
                    if index < data.count - 1 {
                        Rectangle()
                            .fill(Color(.separatorColor).opacity(0.3))
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
}

struct EmptySelectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Select a Table")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Choose a database and table to browse data")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDataView: View {
    let tableName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Table '\(tableName)' contains no data")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error Loading Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
