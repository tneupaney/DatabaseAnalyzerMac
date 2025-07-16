import SwiftUI

struct AnalysisResultsView: View {
    let results: AnalysisResults
    let analyzer: SQLiteAnalyzer
    @State private var selectedTab: String = "Overview"
    @State private var showExportSheet: Bool = false
    @State private var exportMessage: String = ""
    @State private var showExportAlert: Bool = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                NavigationLink(value: "Overview") {
                    Label("Overview", systemImage: "info.circle.fill")
                }
                
                NavigationLink(value: "Schema") {
                    Label("Database Schema", systemImage: "doc.text.magnifyingglass")
                }
                
                NavigationLink(value: "DataBrowser") {
                    Label("Data Browser", systemImage: "tablecells.fill")
                }
                
                NavigationLink(value: "SQLEditor") {
                    Label("SQL Editor", systemImage: "terminal.fill")
                }
                
                NavigationLink(value: "Performance") {
                    Label("Query Performance", systemImage: "speedometer")
                }
                
                NavigationLink(value: "Indexes") {
                    Label("Index Analysis", systemImage: "magnifyingglass.circle.fill")
                }
                
                NavigationLink(value: "Integrity") {
                    Label("Data Integrity", systemImage: "checkmark.shield.fill")
                }
                
                NavigationLink(value: "Security") {
                    Label("Security Findings", systemImage: "lock.shield.fill")
                }
                
                NavigationLink(value: "Triggers") {
                    Label("Trigger Performance", systemImage: "bolt.fill")
                }
                
                NavigationLink(value: "Relationships") {
                    Label("Relationship Performance", systemImage: "link")
                }
            }
            .navigationTitle("Analysis Results")
            .frame(minWidth: 200)
        } detail: {
            // Main Content
            Group {
                switch selectedTab {
                case "Overview":
                    OverviewView(results: results)
                case "Schema":
                    SchemaView(schema: results.discoveredSchema)
                case "DataBrowser":
                    DataBrowserView(analyzer: analyzer, schema: results.discoveredSchema)
                case "SQLEditor":
                    SQLEditorView(analyzer: analyzer)
                case "Performance":
                    QueryPerformanceView(results: results.queryPerformanceData)
                case "Indexes":
                    IndexAnalysisView(issues: results.indexIssues, suggestions: results.indexSuggestions)
                case "Integrity":
                    DataIntegrityView(issues: results.integrityIssues)
                case "Security":
                    SecurityFindingsView(findings: results.securityFindings)
                case "Triggers":
                    TriggerPerformanceView(results: results.triggerPerformanceResults)
                case "Relationships":
                    RelationshipPerformanceView(results: results.relationshipPerfResults)
                default:
                    OverviewView(results: results)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Export Report") {
                    showExportSheet = true
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView(results: results) { message in
                exportMessage = message
                showExportAlert = true
            }
        }
        .alert("Export Status", isPresented: $showExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
    }
}
