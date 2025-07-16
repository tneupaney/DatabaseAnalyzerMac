//
//  RelationshipPerformanceView.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import SwiftUI

struct RelationshipPerformanceView: View {
    let results: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationship Performance Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("JOIN performance and relationship optimization")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary
                    StatCard(title: "JOIN Tests", value: "\(results.count)", icon: "link", color: .purple)
                    
                    // Results or empty state
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Performance Results")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(results, id: \.self) { result in
                                    RelationshipResultRowView(result: result)
                                }
                            }
                        }
                    } else {
                        NoIssuesView(title: "No Relationship Performance Data", description: "No foreign key relationships were found or tested for performance analysis.")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Relationship Performance")
    }
}

struct RelationshipResultRowView: View {
    let result: String
    
    var resultType: RelationshipResultType {
        let lowercased = result.lowercased()
        if lowercased.contains("warning") || lowercased.contains("missing") {
            return .warning
        } else if lowercased.contains("suggestion") {
            return .suggestion
        } else if lowercased.contains("analyzing") {
            return .info
        } else {
            return .info
        }
    }
    
    enum RelationshipResultType {
        case warning, suggestion, info
        
        var color: Color {
            switch self {
            case .warning: return .orange
            case .suggestion: return .blue
            case .info: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .suggestion: return "lightbulb.fill"
            case .info: return "link"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: resultType.icon)
                .foregroundColor(resultType.color)
                .font(.title3)
            
            Text(result)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(resultType.color.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(resultType.color.opacity(0.3), lineWidth: 1)
        )
    }
}