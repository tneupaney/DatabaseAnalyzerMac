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