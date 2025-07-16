//
//  ExportManager.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import Foundation
import AppKit
import UniformTypeIdentifiers

class ExportManager {
    
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF Report"
        case excel = "Excel Spreadsheet"
        case json = "JSON Data"
        case markdown = "Markdown Report"
        
        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .excel: return "xlsx"
            case .json: return "json"
            case .markdown: return "md"
            }
        }
        
        var utType: UTType {
            switch self {
            case .pdf: return .pdf
            case .excel: return UTType(filenameExtension: "xlsx") ?? .data
            case .json: return .json
            case .markdown: return UTType(filenameExtension: "md") ?? .plainText
            }
        }
    }
    
    static func exportAnalysisResults(
        _ results: AnalysisResults,
        format: ExportFormat,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = "database_analysis_report.\(format.fileExtension)"
        panel.title = "Export \(format.rawValue)"
        
        if panel.runModal() == .OK {
            guard let url = panel.url else {
                completion(.failure(ExportError.noFileSelected))
                return
            }
            
            Task {
                do {
                    switch format {
                    case .pdf:
                        try await exportToPDF(results, url: url)
                    case .excel:
                        try await exportToExcel(results, url: url)
                    case .json:
                        try exportToJSON(results, url: url)
                    case .markdown:
                        try exportToMarkdown(results, url: url)
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(url))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            completion(.failure(ExportError.cancelled))
        }
    }
    
    // MARK: - JSON Export
    private static func exportToJSON(_ results: AnalysisResults, url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(results)
        try jsonData.write(to: url)
    }
    
    // MARK: - Markdown Export
    private static func exportToMarkdown(_ results: AnalysisResults, url: URL) throws {
        var markdown = """
        # Database Analysis Report
        
        Generated on: \(DateFormatter.readable.string(from: Date()))
        
        ## Overview
        
        - **Databases Analyzed**: \(results.discoveredSchema.shards.count)
        - **Total Tables**: \(results.discoveredSchema.shards.values.map { $0.tables.count }.reduce(0, +))
        - **Query Performance Tests**: \(results.queryPerformanceData.count)
        - **Index Issues Found**: \(results.indexIssues.count)
        - **Data Integrity Issues**: \(results.integrityIssues.count)
        - **Security Findings**: \(results.securityFindings.count)
        - **Triggers Analyzed**: \(results.triggerPerformanceResults.count)
        - **Relationships Analyzed**: \(results.relationshipPerfResults.count)
        
        """
        
        // Schema Section
        markdown += "\n## Database Schema\n\n"
        for (shardName, shardInfo) in results.discoveredSchema.shards.sorted(by: { $0.key < $1.key }) {
            markdown += "### \(shardName)\n\n"
            for (tableName, tableInfo) in shardInfo.tables.sorted(by: { $0.key < $1.key }) {
                markdown += "#### Table: \(tableName)\n\n"
                markdown += "| Column | Type | Nullable |\n"
                markdown += "|--------|------|----------|\n"
                for column in tableInfo.columns {
                    markdown += "| \(column.name) | \(column.type) | \(column.nullable ? "Yes" : "No") |\n"
                }
                markdown += "\n"
                
                if !tableInfo.primaryKey.isEmpty {
                    markdown += "**Primary Key**: \(tableInfo.primaryKey.joined(separator: ", "))\n\n"
                }
                
                if !tableInfo.foreignKeys.isEmpty {
                    markdown += "**Foreign Keys**:\n"
                    for fk in tableInfo.foreignKeys {
                        markdown += "- \(fk.constrainedColumns.joined(separator: ", ")) → \(fk.referredTable).\(fk.referredColumns.joined(separator: ", "))\n"
                    }
                    markdown += "\n"
                }
            }
        }
        
        // Performance Section
        if !results.queryPerformanceData.isEmpty {
            markdown += "\n## Query Performance Analysis\n\n"
            for query in results.queryPerformanceData {
                markdown += "### \(query.query)\n\n"
                markdown += "- **Execution Time**: \(query.executionTime)\n"
                markdown += "- **Optimized**: \(query.optimized ? "✅ Yes" : "❌ No")\n"
                markdown += "- **Suggestion**: \(query.suggestedOptimization)\n\n"
            }
        }
        
        // Index Issues
        if !results.indexIssues.isEmpty {
            markdown += "\n## Index Issues\n\n"
            for issue in results.indexIssues {
                markdown += "- ⚠️ \(issue)\n"
            }
            markdown += "\n"
        }
        
        // Index Suggestions
        if !results.indexSuggestions.isEmpty {
            markdown += "\n## Index Suggestions\n\n"
            for suggestion in results.indexSuggestions {
                markdown += "```sql\n\(suggestion)\n```\n\n"
            }
        }
        
        // Security Findings
        if !results.securityFindings.isEmpty {
            markdown += "\n## Security Findings\n\n"
            for finding in results.securityFindings {
                markdown += "- 🔒 \(finding)\n"
            }
            markdown += "\n"
        }
        
        // Data Integrity Issues
        if !results.integrityIssues.isEmpty {
            markdown += "\n## Data Integrity Issues\n\n"
            for issue in results.integrityIssues {
                markdown += "- ❌ \(issue)\n"
            }
            markdown += "\n"
        }
        
        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - PDF Export
    private static func exportToPDF(_ results: AnalysisResults, url: URL) async throws {
        // Create HTML content
        let htmlContent = generateHTMLReport(results)
        
        // Convert HTML to PDF using WebKit
        let webView = await(WKWebView())
        await webView.loadHTMLString(htmlContent, baseURL: nil)
        
        // Wait for content to load
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Create PDF
        let pdfData = try await webView.pdf()
        try pdfData.write(to: url)
    }
    
    // MARK: - Excel Export
    private static func exportToExcel(_ results: AnalysisResults, url: URL) async throws {
        var csvContent = ""
        
        // Overview sheet data
        csvContent += "Database Analysis Report\n"
        csvContent += "Generated,\(DateFormatter.readable.string(from: Date()))\n\n"
        
        csvContent += "Overview\n"
        csvContent += "Metric,Value\n"
        csvContent += "Databases Analyzed,\(results.discoveredSchema.shards.count)\n"
        csvContent += "Total Tables,\(results.discoveredSchema.shards.values.map { $0.tables.count }.reduce(0, +))\n"
        csvContent += "Query Tests,\(results.queryPerformanceData.count)\n"
        csvContent += "Index Issues,\(results.indexIssues.count)\n"
        csvContent += "Integrity Issues,\(results.integrityIssues.count)\n"
        csvContent += "Security Findings,\(results.securityFindings.count)\n\n"
        
        // Schema data
        csvContent += "Database Schema\n"
        csvContent += "Shard,Table,Column,Type,Nullable,Primary Key\n"
        for (shardName, shardInfo) in results.discoveredSchema.shards {
            for (tableName, tableInfo) in shardInfo.tables {
                for column in tableInfo.columns {
                    let isPK = tableInfo.primaryKey.contains(column.name)
                    csvContent += "\(shardName),\(tableName),\(column.name),\(column.type),\(column.nullable),\(isPK)\n"
                }
            }
        }
        csvContent += "\n"
        
        // Query performance data
        if !results.queryPerformanceData.isEmpty {
            csvContent += "Query Performance\n"
            csvContent += "Query,Execution Time,Optimized,Suggestion\n"
            for query in results.queryPerformanceData {
                csvContent += "\"\(query.query)\",\(query.executionTime),\(query.optimized),\"\(query.suggestedOptimization)\"\n"
            }
        }
        
        // Save as CSV (Excel can open this)
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func generateHTMLReport(_ results: AnalysisResults) -> String {
        // Use the existing HTMLReportGenerator but with better styling for PDF
        let generator = HTMLReportGenerator()
        return generator.generateReport(
            queryPerformanceData: results.queryPerformanceData,
            indexIssues: results.indexIssues,
            integrityIssues: results.integrityIssues,
            securityFindings: results.securityFindings,
            indexSuggestions: results.indexSuggestions,
            triggerPerformanceResults: results.triggerPerformanceResults,
            relationshipPerfResults: results.relationshipPerfResults,
            discoveredSchema: results.discoveredSchema
        )
    }
}

// MARK: - Supporting Extensions and Types

enum ExportError: LocalizedError {
    case noFileSelected
    case cancelled
    case conversionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noFileSelected:
            return "No file location selected"
        case .cancelled:
            return "Export cancelled by user"
        case .conversionFailed(let message):
            return "Export failed: \(message)"
        }
    }
}

extension DateFormatter {
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
}

import WebKit

extension WKWebView {
    func pdf() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
            
            self.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
