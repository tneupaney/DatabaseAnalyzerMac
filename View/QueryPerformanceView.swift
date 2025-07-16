import SwiftUI

struct QueryPerformanceView: View {
    let results: [QueryPerformanceResult]
    @State private var searchText = ""
    @State private var showOptimizedOnly = false
    
    var filteredResults: [QueryPerformanceResult] {
        let filtered = showOptimizedOnly ? results.filter { !$0.optimized } : results
        return searchText.isEmpty ? filtered : filtered.filter { $0.query.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header with controls
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Query Performance Analysis")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("\(results.count) queries analyzed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("Show Issues Only", isOn: $showOptimizedOnly)
                            .toggleStyle(SwitchToggleStyle())
                    }
                    
                    // Performance Summary
                    HStack(spacing: 20) {
                        PerformanceMetric(title: "Total Queries", value: "\(results.count)", color: .blue)
                        PerformanceMetric(title: "Optimized", value: "\(results.filter { $0.optimized }.count)", color: .green)
                        PerformanceMetric(title: "Need Attention", value: "\(results.filter { !$0.optimized }.count)", color: .red)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                
                // Query List
                List(filteredResults, id: \.query) { result in
                    QueryPerformanceRowView(result: result)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
                .searchable(text: $searchText, prompt: "Search queries...")
            }
        }
        .navigationTitle("Query Performance")
    }
}

struct QueryPerformanceRowView: View {
    let result: QueryPerformanceResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.query)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            Text(result.executionTime)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.primary.opacity(0.1))
                                        .background(Color(.controlBackgroundColor))
                                )
                                .cornerRadius(4)
                            
                            Text(result.optimized ? "Optimized" : "Needs Attention")
                                .font(.caption)
                                .foregroundColor(result.optimized ? .white : .white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(result.optimized ? Color.green : Color.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                        .background(Color(.controlBackgroundColor))
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Optimization suggestion
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Suggested Optimization")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(result.suggestedOptimization)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Query plan
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Query Plan")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            Text(result.queryPlan)
                                .font(.caption)
                                .monospaced()
                                .textSelection(.enabled)
                                .foregroundColor(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                        .background(Color(.textBackgroundColor))
                                )
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 150)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.03))
                        .background(Color(.controlBackgroundColor))
                )
                .cornerRadius(10)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.vertical, 4)
    }
}
