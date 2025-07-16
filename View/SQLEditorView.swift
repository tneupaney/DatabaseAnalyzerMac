import SwiftUI
import GRDB

struct SQLEditorView: View {
    let analyzer: SQLiteAnalyzer
    
    @State private var sqlQuery: String = "SELECT * FROM sqlite_master WHERE type='table';"
    @State private var queryResults: [QueryResult] = []
    @State private var isExecuting: Bool = false
    @State private var executionError: String? = nil
    @State private var executionTime: TimeInterval = 0
    @State private var selectedShard: String = ""
    @State private var queryHistory: [HistoryItem] = []
    @State private var showHistory: Bool = false
    @State private var showSavedQueries: Bool = false
    @State private var savedQueries: [SavedQuery] = []
    @State private var showSaveDialog: Bool = false
    @State private var saveQueryName: String = ""
    
    var availableShards: [String] {
        analyzer.dbQueues.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    // Shard selection
                    HStack {
                        Text("Database:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Shard", selection: $selectedShard) {
                            ForEach(availableShards, id: \.self) { shard in
                                Text(shard).tag(shard)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            showHistory.toggle()
                        } label: {
                            Image(systemName: "clock")
                            Text("History")
                        }
                        .foregroundColor(.blue)
                        
                        Button {
                            showSavedQueries.toggle()
                        } label: {
                            Image(systemName: "bookmark")
                            Text("Saved")
                        }
                        .foregroundColor(.blue)
                        
                        Button {
                            showSaveDialog = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                        .foregroundColor(.blue)
                        .disabled(sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button {
                            executeQuery()
                        } label: {
                            HStack {
                                if isExecuting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text("Execute")
                            }
                        }
                        .disabled(isExecuting || sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedShard.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .border(Color(.separatorColor), width: 1)
                
                // SQL Editor
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("SQL Query")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if executionTime > 0 {
                            Text("Executed in \(String(format: "%.3f", executionTime))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    SQLCodeEditor(text: $sqlQuery)
                        .frame(minHeight: 200)
                        .background(Color(.textBackgroundColor))
                        .border(Color(.separatorColor), width: 1)
                }
                
                // Results section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Results")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !queryResults.isEmpty {
                            Text("(\(queryResults.count) rows)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !queryResults.isEmpty {
                            Button("Export CSV") {
                                exportResults()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if let error = executionError {
                        ErrorResultView(error: error)
                    } else if queryResults.isEmpty && !isExecuting {
                        EmptyResultView()
                    } else {
                        QueryResultsView(results: queryResults)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("SQL Editor")
        .onAppear {
            if selectedShard.isEmpty && !availableShards.isEmpty {
                selectedShard = availableShards.first!
            }
            loadSavedQueries()
            loadQueryHistory()
        }
        .sheet(isPresented: $showHistory) {
            QueryHistoryView(history: queryHistory, onSelect: { query in
                sqlQuery = query.sql
                showHistory = false
            })
        }
        .sheet(isPresented: $showSavedQueries) {
            SavedQueriesView(savedQueries: savedQueries, onSelect: { query in
                sqlQuery = query.sql
                showSavedQueries = false
            }, onDelete: { query in
                deleteSavedQuery(query)
            })
        }
        .alert("Save Query", isPresented: $showSaveDialog) {
            TextField("Query Name", text: $saveQueryName)
            Button("Save") {
                saveQuery()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func executeQuery() {
        guard !selectedShard.isEmpty, !sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isExecuting = true
        executionError = nil
        queryResults = []
        
        let startTime = Date()
        
        Task {
            do {
                let results = try await analyzer.executeQuery(sqlQuery, onShard: selectedShard)
                
                DispatchQueue.main.async {
                    self.executionTime = Date().timeIntervalSince(startTime)
                    self.queryResults = results
                    self.isExecuting = false
                    
                    // Add to history
                    let historyItem = HistoryItem(
                        sql: self.sqlQuery,
                        timestamp: Date(),
                        shard: self.selectedShard,
                        executionTime: self.executionTime,
                        rowCount: results.count
                    )
                    self.queryHistory.insert(historyItem, at: 0)
                    if self.queryHistory.count > 50 {
                        self.queryHistory.removeLast()
                    }
                    self.saveQueryHistory()
                }
            } catch {
                DispatchQueue.main.async {
                    self.executionError = error.localizedDescription
                    self.isExecuting = false
                }
            }
        }
    }
    
    private func saveQuery() {
        let query = SavedQuery(
            id: UUID(),
            name: saveQueryName,
            sql: sqlQuery,
            createdAt: Date()
        )
        savedQueries.append(query)
        saveSavedQueries()
        saveQueryName = ""
    }
    
    private func deleteSavedQuery(_ query: SavedQuery) {
        savedQueries.removeAll { $0.id == query.id }
        saveSavedQueries()
    }
    
    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "query_results.csv"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    let csvContent = generateCSV(from: queryResults)
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error saving CSV: \(error)")
                }
            }
        }
    }
    
    private func generateCSV(from results: [QueryResult]) -> String {
        guard !results.isEmpty else { return "" }
        
        // Headers
        let headers = results.first?.columns.keys.sorted() ?? []
        var csvContent = headers.joined(separator: ",") + "\n"
        
        // Data rows
        for result in results {
            let row = headers.map { key in
                let value = result.columns[key] ?? ""
                return "\"\(value)\""
            }.joined(separator: ",")
            csvContent += row + "\n"
        }
        
        return csvContent
    }
    
    private func loadSavedQueries() {
        if let data = UserDefaults.standard.data(forKey: "SavedQueries"),
           let queries = try? JSONDecoder().decode([SavedQuery].self, from: data) {
            savedQueries = queries
        }
    }
    
    private func saveSavedQueries() {
        if let data = try? JSONEncoder().encode(savedQueries) {
            UserDefaults.standard.set(data, forKey: "SavedQueries")
        }
    }
    
    private func loadQueryHistory() {
        if let data = UserDefaults.standard.data(forKey: "QueryHistory"),
           let history = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            queryHistory = history
        }
    }
    
    private func saveQueryHistory() {
        if let data = try? JSONEncoder().encode(queryHistory) {
            UserDefaults.standard.set(data, forKey: "QueryHistory")
        }
    }
}

// MARK: - Supporting Views

struct SQLCodeEditor: View {
    @Binding var text: String
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color(.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
    }
}

struct QueryResultsView: View {
    let results: [QueryResult]
    
    var body: some View {
        if results.isEmpty {
            EmptyResultView()
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVGrid(columns: gridColumns, spacing: 1) {
                    // Headers
                    ForEach(columnHeaders, id: \.self) { header in
                        Text(header)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Data rows
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        ForEach(columnHeaders, id: \.self) { header in
                            Text(result.columns[header] ?? "")
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(index % 2 == 0 ? Color(.controlBackgroundColor).opacity(0.5) : Color.clear)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .background(Color(.textBackgroundColor))
        }
    }
    
    private var columnHeaders: [String] {
        results.first?.columns.keys.sorted() ?? []
    }
    
    private var gridColumns: [GridItem] {
        columnHeaders.map { _ in
            GridItem(.flexible(minimum: 100), spacing: 1)
        }
    }
}

struct EmptyResultView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Execute a query to see results here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
}

struct ErrorResultView: View {
    let error: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Query Error")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(error)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.textBackgroundColor))
    }
}

// MARK: - Data Models

struct QueryResult {
    let columns: [String: String]
}

struct HistoryItem: Codable, Identifiable {
    let id = UUID()
    let sql: String
    let timestamp: Date
    let shard: String
    let executionTime: TimeInterval
    let rowCount: Int
}

struct SavedQuery: Codable, Identifiable {
    let id: UUID
    let name: String
    let sql: String
    let createdAt: Date
}