import SwiftUI

struct TriggerPerformanceView: View {
    let results: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trigger Performance Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Performance analysis of database triggers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary
                    StatCard(title: "Performance Tests", value: "\(results.count)", icon: "bolt.fill", color: .orange)
                    
                    // Results or empty state
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Performance Results")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(results, id: \.self) { result in
                                    TriggerResultRowView(result: result)
                                }
                            }
                        }
                    } else {
                        NoIssuesView(title: "No Trigger Performance Data", description: "No triggers were found or tested for performance analysis.")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Trigger Performance")
    }
}

struct TriggerResultRowView: View {
    let result: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            Text(result)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}