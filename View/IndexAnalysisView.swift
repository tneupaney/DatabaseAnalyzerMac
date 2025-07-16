import SwiftUI

struct IndexAnalysisView: View {
    let issues: [String]
    let suggestions: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Index Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Identify missing indexes and optimization opportunities")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary cards
                    HStack(spacing: 16) {
                        StatCard(title: "Issues Found", value: "\(issues.count)", icon: "exclamationmark.triangle.fill", color: .red)
                        StatCard(title: "Suggestions", value: "\(suggestions.count)", icon: "lightbulb.fill", color: .yellow)
                    }
                    
                    // Issues section
                    if !issues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Issues Found")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(issues, id: \.self) { issue in
                                    IssueRowView(issue: issue, type: .error)
                                }
                            }
                        }
                    } else {
                        NoIssuesView(title: "No Index Issues Found", description: "All indexes appear to be properly configured.")
                    }
                    
                    // Suggestions section
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Optimization Suggestions")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    SuggestionRowView(suggestion: suggestion)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Index Analysis")
    }
}
