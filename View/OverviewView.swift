import SwiftUI

struct OverviewView: View {
    let results: AnalysisResults
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database Analysis Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Complete analysis results for your database")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Statistics Cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    StatCard(title: "Databases", value: "\(results.discoveredSchema.shards.count)", icon: "server.rack", color: .blue)
                    StatCard(title: "Tables", value: "\(results.discoveredSchema.shards.values.map { $0.tables.count }.reduce(0, +))", icon: "tablecells", color: .green)
                    StatCard(title: "Query Tests", value: "\(results.queryPerformanceData.count)", icon: "speedometer", color: .orange)
                    StatCard(title: "Index Issues", value: "\(results.indexIssues.count)", icon: "exclamationmark.triangle", color: .red)
                    StatCard(title: "Integrity Issues", value: "\(results.integrityIssues.count)", icon: "checkmark.shield", color: .purple)
                    StatCard(title: "Security Findings", value: "\(results.securityFindings.count)", icon: "lock.shield", color: .yellow)
                }
                
                // Quick Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SummaryRow(label: "Trigger Performance Results", value: "\(results.triggerPerformanceResults.count)")
                        SummaryRow(label: "Relationship Performance Results", value: "\(results.relationshipPerfResults.count)")
                        SummaryRow(label: "Total Triggers", value: "\(results.discoveredSchema.allTriggers.count)")
                        SummaryRow(label: "Total Relationships", value: "\(results.discoveredSchema.relationships.count)")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Overview")
    }
}
