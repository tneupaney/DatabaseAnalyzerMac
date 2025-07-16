import Foundation

// MARK: - Analysis Result Models

struct QueryPerformanceResult: Codable {
    var query: String
    var executionTime: String // Stored as string to handle "Error" cases or formatted time
    var optimized: Bool
    var suggestedOptimization: String
    var queryPlan: String
}

// These are simplified to String for now as per the native UI display
// If you need more structured data for specific UI elements, these can be expanded.
struct IndexIssue: Codable {
    var issue: String
    var suggestion: String
}

struct IntegrityIssue: Codable {
    var issue: String
}

struct SecurityFinding: Codable {
    var finding: String
}

struct TriggerPerformanceResult: Codable {
    var result: String // Simplified to a single string for now
}

struct RelationshipPerformanceResult: Codable {
    var result: String // Simplified to a single string for now
}

// Consolidated Analysis Results - HTML removed for native UI
struct AnalysisResults: Codable {
    var queryPerformanceData: [QueryPerformanceResult]
    var indexIssues: [String] // List of issue strings
    var indexSuggestions: [String] // List of suggestion SQL strings
    var integrityIssues: [String] // List of issue strings
    var securityFindings: [String] // List of finding strings
    var triggerPerformanceResults: [String] // List of result strings
    var relationshipPerfResults: [String] // List of result strings
    var discoveredSchema: DiscoveredSchema // The full discovered schema
    
    // Optional: Keep minimal HTML for export functionality if needed
    var htmlReportContent: String? // Optional HTML report string
}
