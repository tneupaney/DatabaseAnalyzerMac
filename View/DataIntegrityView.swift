import SwiftUI

struct DataIntegrityView: View {
    let issues: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Integrity Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Foreign key violations and constraint issues")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary
                    StatCard(title: "Issues Found", value: "\(issues.count)", icon: "checkmark.shield.fill", color: issues.isEmpty ? .green : .red)
                    
                    // Issues or success message
                    if !issues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Integrity Issues")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(issues, id: \.self) { issue in
                                    IssueRowView(issue: issue, type: .error)
                                }
                            }
                        }
                    } else {
                        NoIssuesView(title: "No Data Integrity Issues", description: "All foreign key constraints and data integrity rules are properly maintained.")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Data Integrity")
    }
}