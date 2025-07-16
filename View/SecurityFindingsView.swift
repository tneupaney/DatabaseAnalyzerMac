//
//  SecurityFindingsView.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import SwiftUI

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
                            .fontWeight(.bold)
                        
                        Text("Sensitive data detection and security recommendations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary
                    StatCard(title: "Security Findings", value: "\(findings.count)", icon: "lock.shield.fill", color: findings.isEmpty ? .green : .orange)
                    
                    // Findings or success message
                    if !findings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Security Findings")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(findings, id: \.self) { finding in
                                    SecurityFindingRowView(finding: finding)
                                }
                            }
                        }
                    } else {
                        NoIssuesView(title: "No Security Issues Found", description: "No sensitive data patterns or security vulnerabilities detected.")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Security Analysis")
    }
}

struct SecurityFindingRowView: View {
    let finding: String
    
    var findingType: SecurityFindingType {
        let lowercased = finding.lowercased()
        if lowercased.contains("critical") || lowercased.contains("plaintext") || lowercased.contains("weakly hashed") {
            return .critical
        } else if lowercased.contains("warning") || lowercased.contains("verify") {
            return .warning
        } else if lowercased.contains("good practice") || lowercased.contains("appears to be") {
            return .info
        } else {
            return .warning
        }
    }
    
    enum SecurityFindingType {
        case critical, warning, info
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: findingType.icon)
                .foregroundColor(findingType.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(extractTitle(from: finding))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(finding)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(findingType.color.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(findingType.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func extractTitle(from finding: String) -> String {
        if finding.contains("password") {
            return "Password Security"
        } else if finding.contains("email") {
            return "Email Address (PII)"
        } else if finding.contains("ssn") || finding.contains("social_security") {
            return "Social Security Number"
        } else if finding.contains("credit_card") || finding.contains("card_number") {
            return "Credit Card Information"
        } else {
            return "Security Finding"
        }
    }
}