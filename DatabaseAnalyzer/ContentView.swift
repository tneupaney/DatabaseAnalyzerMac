import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    // State variables for UI inputs
    @State private var dbType: String = "SQLite"
    @State private var sqlitePaths: [String] = []
    
    // State for analysis process
    @State private var analysisStatus: String = "Ready to analyze."
    @State private var isAnalyzing: Bool = false
    @State private var analysisResults: AnalysisResults? = nil
    @State private var currentAnalyzer: SQLiteAnalyzer? = nil // Store the analyzer
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // UserDefaults keys for persistence
    private let recentDatabasesKey = "RecentDatabases"
    private let lastSelectedPathsKey = "LastSelectedPaths"
    
    var body: some View {
        Group {
            if let results = analysisResults, let analyzer = currentAnalyzer {
                // Full screen analysis view
                AnalysisResultsView(results: results, analyzer: analyzer)
                    .navigationTitle("Database Analysis Results")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("New Analysis") {
                                withAnimation {
                                    analysisResults = nil
                                    currentAnalyzer = nil
                                    analysisStatus = "Ready to analyze."
                                }
                            }
                            .keyboardShortcut("n", modifiers: .command)
                        }
                    }
            } else {
                // Database selection view
                DatabaseSelectionView(
                    dbType: $dbType,
                    sqlitePaths: $sqlitePaths,
                    analysisStatus: $analysisStatus,
                    isAnalyzing: $isAnalyzing,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage,
                    onAnalysisComplete: { results in
                        withAnimation {
                            self.analysisResults = results
                        }
                        saveRecentDatabases()
                    },
                    onStartAnalysis: startAnalysis
                )
                .navigationTitle("Database Analyzer")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadRecentDatabases()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func loadRecentDatabases() {
        if let savedPaths = UserDefaults.standard.array(forKey: lastSelectedPathsKey) as? [String] {
            // Filter out paths that no longer exist
            let existingPaths = savedPaths.filter { FileManager.default.fileExists(atPath: $0) }
            sqlitePaths = existingPaths
        }
    }
    
    private func saveRecentDatabases() {
        UserDefaults.standard.set(sqlitePaths, forKey: lastSelectedPathsKey)
        
        // Also save to recent databases list
        var recentDatabases = UserDefaults.standard.array(forKey: recentDatabasesKey) as? [String] ?? []
        
        // Add new paths and remove duplicates
        for path in sqlitePaths {
            if let index = recentDatabases.firstIndex(of: path) {
                recentDatabases.remove(at: index)
            }
            recentDatabases.insert(path, at: 0)
        }
        
        // Keep only the last 10 recent databases
        if recentDatabases.count > 10 {
            recentDatabases = Array(recentDatabases.prefix(10))
        }
        
        UserDefaults.standard.set(recentDatabases, forKey: recentDatabasesKey)
    }

    func startAnalysis() {
        isAnalyzing = true
        analysisStatus = "Starting analysis..."
        alertMessage = ""
        showAlert = false

        guard !sqlitePaths.isEmpty else {
            alertMessage = "Please select at least one SQLite database file."
            showAlert = true
            isAnalyzing = false
            return
        }

        Task {
            do {
                let analyzer = SQLiteAnalyzer(dbPaths: sqlitePaths)
                
                DispatchQueue.main.async { self.analysisStatus = "Discovering schema..." }
                let schema = try analyzer.discoverSchema()

                DispatchQueue.main.async { self.analysisStatus = "Analyzing queries..." }
                let queryPerf = try analyzer.analyzeQueries(schema: schema)

                DispatchQueue.main.async { self.analysisStatus = "Checking indexes..." }
                let (indexIssues, indexSuggestions) = try analyzer.checkIndexes(schema: schema)

                DispatchQueue.main.async { self.analysisStatus = "Checking data integrity..." }
                let integrityIssues = try analyzer.checkDataIntegrity(schema: schema)

                DispatchQueue.main.async { self.analysisStatus = "Checking security..." }
                let securityFindings = try analyzer.checkSecurity(schema: schema)

                DispatchQueue.main.async { self.analysisStatus = "Analyzing triggers..." }
                let triggerPerf = try analyzer.analyzeTriggers(schema: schema)

                DispatchQueue.main.async { self.analysisStatus = "Analyzing relationships..." }
                let relationshipPerf = try analyzer.analyzeRelationships(schema: schema)

                let results = AnalysisResults(
                    queryPerformanceData: queryPerf,
                    indexIssues: indexIssues,
                    indexSuggestions: indexSuggestions,
                    integrityIssues: integrityIssues,
                    securityFindings: securityFindings,
                    triggerPerformanceResults: triggerPerf,
                    relationshipPerfResults: relationshipPerf,
                    discoveredSchema: schema,
                    htmlReportContent: nil
                )

                DispatchQueue.main.async {
                    self.analysisStatus = "Analysis complete!"
                    self.analysisResults = results
                    self.currentAnalyzer = analyzer // Store the analyzer
                    self.isAnalyzing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.analysisStatus = "Analysis failed."
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    self.isAnalyzing = false
                }
            }
        }
    }
}

struct DatabaseSelectionView: View {
    @Binding var dbType: String
    @Binding var sqlitePaths: [String]
    @Binding var analysisStatus: String
    @Binding var isAnalyzing: Bool
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    let onAnalysisComplete: (AnalysisResults) -> Void
    let onStartAnalysis: () -> Void
    
    // UserDefaults key for recent databases
    private let recentDatabasesKey = "RecentDatabases"
    @State private var recentDatabases: [String] = []
    
    var body: some View {
        HStack(spacing: 0) {
            // Left section - Blue background with app info
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Database Analyzer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Comprehensive database health and performance analysis tool")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "speedometer", text: "Query Performance Analysis")
                    FeatureRow(icon: "magnifyingglass.circle", text: "Index Optimization")
                    FeatureRow(icon: "checkmark.shield", text: "Data Integrity Checks")
                    FeatureRow(icon: "lock.shield", text: "Security Scanning")
                    FeatureRow(icon: "bolt", text: "Trigger Performance")
                    FeatureRow(icon: "link", text: "Relationship Analysis")
                }
                
                Spacer()
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Right section - Database selection
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Connect to Database")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Database Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Database Type")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Database Type", selection: $dbType) {
                            Text("SQLite").tag("SQLite")
                        }
                        .pickerStyle(.segmented)
                        .disabled(true)
                    }
                    
                    // Database Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Database Files")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !sqlitePaths.isEmpty {
                                Button("Clear") {
                                    sqlitePaths = []
                                }
                                .foregroundColor(.red)
                            }
                        }
                        
                        if sqlitePaths.isEmpty {
                            DatabaseSelectionArea(
                                sqlitePaths: $sqlitePaths,
                                showAlert: $showAlert,
                                alertMessage: $alertMessage
                            )
                        } else {
                            SelectedDatabasesView(
                                paths: $sqlitePaths,
                                showAlert: $showAlert,
                                alertMessage: $alertMessage
                            )
                        }
                        
                        // Recent databases
                        if !recentDatabases.isEmpty && sqlitePaths.isEmpty {
                            RecentDatabasesView(
                                recentDatabases: recentDatabases,
                                onSelect: { paths in
                                    sqlitePaths = paths
                                }
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Analysis Status and Connect Button
                VStack(spacing: 16) {
                    if isAnalyzing {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(analysisStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: onStartAnalysis) {
                        Text(isAnalyzing ? "Analyzing..." : "Connect & Analyze")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isAnalyzing || sqlitePaths.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isAnalyzing || sqlitePaths.isEmpty)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.controlBackgroundColor))
        }
        .onAppear {
            loadRecentDatabases()
        }
    }
    
    private func loadRecentDatabases() {
        recentDatabases = UserDefaults.standard.array(forKey: recentDatabasesKey) as? [String] ?? []
        // Filter out non-existent files
        recentDatabases = recentDatabases.filter { FileManager.default.fileExists(atPath: $0) }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
