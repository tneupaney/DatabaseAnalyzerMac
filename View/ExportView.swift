//
//  ExportView.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import SwiftUI

struct ExportView: View {
    let results: AnalysisResults
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportManager.ExportFormat = .pdf
    @State private var isExporting: Bool = false
    @State private var includeSchema: Bool = true
    @State private var includePerformance: Bool = true
    @State private var includeIssues: Bool = true
    @State private var includeSecurity: Bool = true
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Analysis Report")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Choose export format and content to include")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Format selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ExportManager.ExportFormat.allCases, id: \.self) { format in
                            FormatCard(
                                format: format,
                                isSelected: selectedFormat == format
                            ) {
                                selectedFormat = format
                            }
                        }
                    }
                }
                
                // Content selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Include Content")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ContentToggle(
                            title: "Database Schema",
                            description: "Tables, columns, relationships",
                            isOn: $includeSchema,
                            icon: "doc.text.magnifyingglass"
                        )
                        
                        ContentToggle(
                            title: "Query Performance",
                            description: "Performance analysis and optimizations",
                            isOn: $includePerformance,
                            icon: "speedometer"
                        )
                        
                        ContentToggle(
                            title: "Issues & Suggestions",
                            description: "Index issues and recommendations",
                            isOn: $includeIssues,
                            icon: "exclamationmark.triangle"
                        )
                        
                        ContentToggle(
                            title: "Security Findings",
                            description: "Security analysis and findings",
                            isOn: $includeSecurity,
                            icon: "lock.shield"
                        )
                    }
                }
                
                Spacer()
                
                // Export button
                VStack(spacing: 12) {
                    if isExporting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Exporting \(selectedFormat.rawValue)...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        exportReport()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export \(selectedFormat.rawValue)")
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isExporting ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isExporting)
                }
            }
            .padding()
            .navigationTitle("Export Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isExporting)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func exportReport() {
        isExporting = true
        
        // Create filtered results based on user selection
        var filteredResults = results
        
        if !includeSchema {
            filteredResults = AnalysisResults(
                queryPerformanceData: includePerformance ? results.queryPerformanceData : [],
                indexIssues: includeIssues ? results.indexIssues : [],
                indexSuggestions: includeIssues ? results.indexSuggestions : [],
                integrityIssues: includeIssues ? results.integrityIssues : [],
                securityFindings: includeSecurity ? results.securityFindings : [],
                triggerPerformanceResults: includePerformance ? results.triggerPerformanceResults : [],
                relationshipPerfResults: includePerformance ? results.relationshipPerfResults : [],
                discoveredSchema: DiscoveredSchema(shards: [:], relationships: [], allTriggers: []),
                htmlReportContent: results.htmlReportContent
            )
        } else {
            filteredResults = AnalysisResults(
                queryPerformanceData: includePerformance ? results.queryPerformanceData : [],
                indexIssues: includeIssues ? results.indexIssues : [],
                indexSuggestions: includeIssues ? results.indexSuggestions : [],
                integrityIssues: includeIssues ? results.integrityIssues : [],
                securityFindings: includeSecurity ? results.securityFindings : [],
                triggerPerformanceResults: includePerformance ? results.triggerPerformanceResults : [],
                relationshipPerfResults: includePerformance ? results.relationshipPerfResults : [],
                discoveredSchema: results.discoveredSchema,
                htmlReportContent: results.htmlReportContent
            )
        }
        
        ExportManager.exportAnalysisResults(filteredResults, format: selectedFormat) { result in
            isExporting = false
            
            switch result {
            case .success(let url):
                onComplete("Report exported successfully to \(url.lastPathComponent)")
                dismiss()
            case .failure(let error):
                onComplete("Export failed: \(error.localizedDescription)")
            }
        }
    }
}

struct FormatCard: View {
    let format: ExportManager.ExportFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(format.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(isSelected ? Color.blue : Color(.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch format {
        case .pdf: return "doc.text.fill"
        case .excel: return "tablecells.fill"
        case .json: return "doc.plaintext.fill"
        case .markdown: return "text.alignleft"
        }
    }
    
    private var description: String {
        switch format {
        case .pdf: return "Formatted document\nwith charts and tables"
        case .excel: return "Spreadsheet with\ndata and analysis"
        case .json: return "Raw data in\nJSON format"
        case .markdown: return "Text document with\nmarkdown formatting"
        }
    }
}

struct ContentToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isOn ? .blue : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.vertical, 4)
    }
}