import Foundation

class HTMLReportGenerator {
    // Since we're going fully native, this can be simplified or removed entirely
    // For now, we'll keep a minimal implementation in case HTML export is needed later
    
    func generateReport(
        queryPerformanceData: [QueryPerformanceResult],
        indexIssues: [String],
        integrityIssues: [String],
        securityFindings: [String],
        indexSuggestions: [String],
        triggerPerformanceResults: [String],
        relationshipPerfResults: [String],
        discoveredSchema: DiscoveredSchema
    ) -> String {
        // Return a minimal HTML report or empty string since we're using native UI
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Database Analysis Report</title>
            <style>
                body { font-family: system-ui, -apple-system, sans-serif; margin: 40px; }
                .summary { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
                .metric { display: inline-block; margin-right: 20px; }
                .metric-value { font-size: 24px; font-weight: bold; color: #007AFF; }
                .metric-label { font-size: 14px; color: #666; }
            </style>
        </head>
        <body>
            <h1>Database Analysis Report</h1>
            
            <div class="summary">
                <h2>Summary</h2>
                <div class="metric">
                    <div class="metric-value">\(discoveredSchema.shards.count)</div>
                    <div class="metric-label">Databases</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(discoveredSchema.shards.values.map { $0.tables.count }.reduce(0, +))</div>
                    <div class="metric-label">Tables</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(queryPerformanceData.count)</div>
                    <div class="metric-label">Queries Tested</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(indexIssues.count)</div>
                    <div class="metric-label">Index Issues</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(integrityIssues.count)</div>
                    <div class="metric-label">Integrity Issues</div>
                </div>
                <div class="metric">
                    <div class="metric-value">\(securityFindings.count)</div>
                    <div class="metric-label">Security Findings</div>
                </div>
            </div>
            
            <p><em>For detailed analysis, please use the native application interface.</em></p>
        </body>
        </html>
        """
    }
}

// Helper extension can be removed since we're not using HTML escaping in native UI
extension String {
    var htmlEscaped: String {
        return self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#039;")
    }
}
