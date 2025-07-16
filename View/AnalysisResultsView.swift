import SwiftUI
import WebKit // For WKWebView to display HTML

struct AnalysisResultsView: View {
    let results: AnalysisResults

    // State to control which tab is selected by sidebar
    @State private var selectedTab: String = "Overview"

    var body: some View {
        HStack {
            // Sidebar
            List {
                Group {
                    SidebarItem(title: "Overview", selectedTab: $selectedTab)
                    SidebarItem(title: "Discovered Schema", selectedTab: $selectedTab)
                    SidebarItem(title: "Query Performance", selectedTab: $selectedTab)
                    SidebarItem(title: "Index Analysis", selectedTab: $selectedTab)
                    SidebarItem(title: "Data Integrity", selectedTab: $selectedTab)
                    SidebarItem(title: "Security Findings", selectedTab: $selectedTab)
                    SidebarItem(title: "Trigger Performance", selectedTab: $selectedTab)
                    SidebarItem(title: "Relationship Performance", selectedTab: $selectedTab)
                    SidebarItem(title: "Full HTML Report", selectedTab: $selectedTab)
                }
                .listRowSeparator(.hidden) // Hide separators for cleaner look
            }
            .listStyle(.sidebar)
            .frame(width: 200)
            .padding(.vertical)

            // Main Content Area (Tabbed)
            TabView(selection: $selectedTab) {
                OverviewTab(results: results)
                    .tag("Overview")
                
                SchemaTab(schema: results.discoveredSchema)
                    .tag("Discovered Schema")
                
                QueryPerformanceTab(results: results.queryPerformanceData)
                    .tag("Query Performance")
                
                IndexAnalysisTab(issues: results.indexIssues, suggestions: results.indexSuggestions)
                    .tag("Index Analysis")
                
                DataIntegrityTab(issues: results.integrityIssues)
                    .tag("Data Integrity")
                
                SecurityFindingsTab(findings: results.securityFindings)
                    .tag("Security Findings")
                
                TriggerPerformanceTab(results: results.triggerPerformanceResults)
                    .tag("Trigger Performance")
                
                RelationshipPerformanceTab(results: results.relationshipPerfResults)
                    .tag("Relationship Performance")

                FullHTMLReportTab(htmlContent: results.htmlReportContent)
                    .tag("Full HTML Report")
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Hide native tab bar, controlled by sidebar
            .animation(.default, value: selectedTab) // Smooth transition between tabs
        }
    }
}

// MARK: - Sidebar Item Helper
struct SidebarItem: View {
    let title: String
    @Binding var selectedTab: String

    var body: some View {
        Button(action: {
            selectedTab = title
        }) {
            HStack {
                Image(systemName: iconName(for: title))
                Text(title)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(.plain) // Remove default button styling
        .background(selectedTab == title ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(5)
    }

    func iconName(for title: String) -> String {
        switch title {
        case "Overview": return "info.circle.fill"
        case "Discovered Schema": return "doc.text.magnifyingglass"
        case "Query Performance": return "speedometer"
        case "Index Analysis": return "magnifyingglass.circle.fill"
        case "Data Integrity": return "checkmark.shield.fill"
        case "Security Findings": return "lock.shield.fill"
        case "Trigger Performance": return "bolt.fill"
        case "Relationship Performance": return "link"
        case "Full HTML Report": return "doc.richtext.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Tab Views (Placeholder Implementations)

struct OverviewTab: View {
    let results: AnalysisResults

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Analysis Overview</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                Text("Total Shards/Databases Analyzed: \(results.discoveredSchema.shards.count)")
                Text("Total Tables Discovered: \(results.discoveredSchema.shards.values.map { $0.tables.count }.reduce(0, +))")
                Text("Query Performance Entries: \(results.queryPerformanceData.count)")
                Text("Index Issues Found: \(results.indexIssues.count)")
                Text("Data Integrity Issues Found: \(results.integrityIssues.count)")
                Text("Security Findings: \(results.securityFindings.count)")
                Text("Trigger Performance Results: \(results.triggerPerformanceResults.count)")
                Text("Relationship Performance Results: \(results.relationshipPerfResults.count)")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SchemaTab: View {
    let schema: DiscoveredSchema

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Discovered Database Schema</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                ForEach(schema.shards.sorted(by: { $0.key < $1.key }), id: \.key) { shardName, shardInfo in
                    Text("<h3>Shard: \(shardName)</h3>")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    ForEach(shardInfo.tables.sorted(by: { $0.key < $1.key }), id: \.key) { tableName, tableInfo in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("**Columns:**")
                                ForEach(tableInfo.columns, id: \.name) { col in
                                    Text("- \(col.name) (\(col.type)\(col.nullable ? "" : ", NOT NULL"))")
                                        .font(.footnote)
                                }
                                if !tableInfo.primaryKey.isEmpty {
                                    Text("**Primary Key:** \(tableInfo.primaryKey.joined(separator: ", "))")
                                        .font(.footnote)
                                }
                                if !tableInfo.foreignKeys.isEmpty {
                                    Text("**Foreign Keys:**")
                                    ForEach(tableInfo.foreignKeys, id: \.constrainedColumns.joined()) { fk in
                                        Text("- \(fk.constrainedColumns.joined(separator: ", ")) -> \(fk.referredTable).\(fk.referredColumns.joined(separator: ", "))")
                                            .font(.footnote)
                                    }
                                }
                                if !tableInfo.indexes.isEmpty {
                                    Text("**Indexes:**")
                                    ForEach(tableInfo.indexes, id: \.name) { idx in
                                        Text("- \(idx.name) (\(idx.columns.joined(separator: ", ")))\(idx.unique ? " (Unique)" : "")")
                                            .font(.footnote)
                                    }
                                }
                                if !tableInfo.uniqueConstraints.isEmpty {
                                    Text("**Unique Constraints:**")
                                    ForEach(tableInfo.uniqueConstraints, id: \.joined()) { uc in
                                        Text("- \(uc.joined(separator: ", "))")
                                            .font(.footnote)
                                    }
                                }
                            }
                            .padding(.leading)
                        } label: {
                            Text("<h4>Table: \(tableName)</h4>")
                                .font(.subheadline)
                        }
                    }
                }
                
                if !schema.allTriggers.isEmpty {
                    Text("<h3>All Triggers:</h3>")
                        .font(.headline)
                        .padding(.top, 5)
                    ForEach(schema.allTriggers, id: \.name) { trigger in
                        DisclosureGroup {
                            Text(trigger.sql)
                                .font(.footnote)
                                .monospaced()
                                .padding(.leading)
                        } label: {
                            Text("- \(trigger.name) on \(trigger.table)")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct QueryPerformanceTab: View {
    let results: [QueryPerformanceResult]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Query Performance Analysis</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                ForEach(results, id: \.query) { result in
                    DisclosureGroup {
                        VStack(alignment: .leading) {
                            Text("**Execution Time:** \(result.executionTime)s")
                            Text("**Optimized:** \(result.optimized ? "Yes" : "No")")
                            Text("**Suggested Optimization:** \(result.suggestedOptimization)")
                            Text("**Query Plan:**")
                                .padding(.top, 5)
                            Text(result.queryPlan)
                                .font(.footnote)
                                .monospaced()
                                .textSelection(.enabled) // Allow text selection
                                .padding(.all, 5)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(5)
                        }
                        .padding(.leading)
                    } label: {
                        Text("<h4>Query: \(result.query)</h4>")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct IndexAnalysisTab: View {
    let issues: [String]
    let suggestions: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Index Analysis</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                if !issues.isEmpty {
                    Text("<h3>Issues:</h3>")
                        .font(.headline)
                    ForEach(issues, id: \.self) { issue in
                        Text("- \(issue)")
                            .font(.body)
                    }
                } else {
                    Text("No index issues found.")
                        .foregroundColor(.secondary)
                }

                if !suggestions.isEmpty {
                    Text("<h3>Suggestions (SQL):</h3>")
                        .font(.headline)
                        .padding(.top, 10)
                    ForEach(suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                            .font(.footnote)
                            .monospaced()
                            .textSelection(.enabled)
                            .padding(.all, 5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DataIntegrityTab: View {
    let issues: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Data Integrity Checks</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                if !issues.isEmpty {
                    ForEach(issues, id: \.self) { issue in
                        Text("- \(issue)")
                            .font(.body)
                    }
                } else {
                    Text("No data integrity issues found.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SecurityFindingsTab: View {
    let findings: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Security Findings</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                if !findings.isEmpty {
                    ForEach(findings, id: \.self) { finding in
                        Text("- \(finding)")
                            .font(.body)
                    }
                } else {
                    Text("No security findings.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TriggerPerformanceTab: View {
    let results: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Trigger Performance Analysis</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                if !results.isEmpty {
                    ForEach(results, id: \.self) { result in
                        Text("- \(result)")
                            .font(.body)
                    }
                } else {
                    Text("No trigger performance results.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RelationshipPerformanceTab: View {
    let results: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("<h2>Relationship Performance Analysis (JOINs)</h2>")
                    .font(.title)
                    .padding(.bottom, 5)
                
                if !results.isEmpty {
                    ForEach(results, id: \.self) { result in
                        Text("- \(result)")
                            .font(.body)
                    }
                } else {
                    Text("No relationship performance results.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - WKWebView for Full HTML Report
struct FullHTMLReportTab: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
