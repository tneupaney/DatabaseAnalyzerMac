import SwiftUI

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
        guard !selectedShard.isEmpty else { return [] }
        return Array(schema.shards[selectedShard]?.tables.keys ?? []).sorted()
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
        guard !selectedShard.isEmpty, !selectedTable.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Build query with pagination, search, and sorting
                var query = "SELECT * FROM \"\(selectedTable)\""
                
                // Add search filter
                if !searchText.isEmpty {
                    let searchConditions = tableColumns.compactMap { column in
                        if column.type.uppercased().contains("TEXT") || column.type.uppercased().contains("VARCHAR") {
                            return "\"\(column.name)\" LIKE '%\(searchText)%'"
                        }
                        return nil
                    }
                    
                    if !searchConditions.isEmpty {
                        query += " WHERE " + searchConditions.joined(separator: " OR ")
                    }
                }
                
                // Add sorting
                if !sortColumn.isEmpty {
                    query += " ORDER BY \"\(sortColumn)\" \(sortAscending ? "ASC" : "DESC")"
                }
                
                // Add pagination
                let offset = currentPage * rowsPerPage
                query += " LIMIT \(rowsPerPage) OFFSET \(offset)"
                
                let results = try await analyzer.executeQuery(query, onShard: selectedShard)
                
                // Get total count
                var countQuery = "SELECT COUNT(*) as total FROM \"\(selectedTable)\""
                if !searchText.isEmpty {
                    let searchConditions = tableColumns.compactMap { column in
                        if column.type.uppercased().contains("TEXT") || column.type.uppercased().contains("VARCHAR") {
                            return "\"\(column.name)\" LIKE '%\(searchText)%'"
                        }
                        return nil
                    }
                    
                    if !searchConditions.isEmpty {
                        countQuery += " WHERE " + searchConditions.joined(separator: " OR ")
                    }
                }
                
                let countResults = try await analyzer.executeQuery(countQuery, onShard: selectedShard)
                let total = Int(countResults.first?.columns["total"] ?? "0") ?? 0
                
                DispatchQueue.main.async {
                    self.tableData = results
                    self.totalRows = total
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func performSearch() {
        currentPage = 0
        loadTableData()
    }
    
    private func exportTableData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(selectedTable)_data.csv"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    do {
                        // Export all data, not just current page
                        var exportQuery = "SELECT * FROM \"\(selectedTable)\""
                        
                        if !searchText.isEmpty {
                            let searchConditions = tableColumns.compactMap { column in
                                if column.type.uppercased().contains("TEXT") || column.type.uppercased().contains("VARCHAR") {
                                    return "\"\(column.name)\" LIKE '%\(searchText)%'"
                                }
                                return nil
                            }
                            
                            if !searchConditions.isEmpty {
                                exportQuery += " WHERE " + searchConditions.joined(separator: " OR ")
                            }
                        }
                        
                        let allData = try await analyzer.executeQuery(exportQuery, onShard: selectedShard)
                        let csvContent = generateCSV(from: allData)
                        
                        try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = "Export failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
    
    private func generateCSV(from results: [QueryResult]) -> String {
        guard !results.isEmpty else { return "" }
        
        let headers = tableColumns.map { $0.name }
        var csvContent = headers.joined(separator: ",") + "\n"
        
        for result in results {
            let row = headers.map { key in
                let value = result.columns[key] ?? ""
                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\"\"))\""
            }.joined(separator: ",")
            csvContent += row + "\n"
        }
        
        return csvContent
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
            LazyVGrid(columns: gridColumns, spacing: 1) {
                // Headers
                ForEach(columns, id: \.name) { column in
                    Button {
                        onSort(column.name)
                    } label: {
                        HStack {
                            Text(column.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if sortColumn == column.name {
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.controlBackgroundColor))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Data rows
                ForEach(Array(data.enumerated()), id: \.offset) { index, result in
                    ForEach(columns, id: \.name) { column in
                        Text(result.columns[column.name] ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(index % 2 == 0 ? Color(.controlBackgroundColor).opacity(0.3) : Color.clear)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .background(Color(.textBackgroundColor))
    }
    
    private var gridColumns: [GridItem] {
        columns.map { _ in
            GridItem(.flexible(minimum: 120), spacing: 1)
        }
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