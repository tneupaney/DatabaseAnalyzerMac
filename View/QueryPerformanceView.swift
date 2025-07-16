import SwiftUI

// MARK: - Query Performance View
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
                .background(Color.gray.opacity(0.05))
                
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

struct PerformanceMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
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
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text(result.optimized ? "Optimized" : "Needs Attention")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(result.optimized ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
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
                        
                        Text(result.suggestedOptimization)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Query plan
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Query Plan")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            Text(result.queryPlan)
                                .font(.caption)
                                .monospaced()
                                .textSelection(.enabled)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 150)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Index Analysis View
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

struct IssueRowView: View {
    let issue: String
    let type: IssueType
    
    enum IssueType {
        case error, warning, info
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .font(.title3)
            
            Text(issue)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(type.color.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SuggestionRowView: View {
    let suggestion: String
    @State private var copied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("SQL Suggestion")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(suggestion)
                    .font(.caption)
                    .monospaced()
                    .textSelection(.enabled)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(suggestion, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copied ? .green : .blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct NoIssuesView: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Data Integrity View
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

// MARK: - Security Findings View
struct SecurityFindingsView: View {
    let findings: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Security Analysis")
                            .font(.largeTitle)
                            .