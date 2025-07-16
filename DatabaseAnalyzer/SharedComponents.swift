//
//  StatCard.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import SwiftUI

// MARK: - Shared Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
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