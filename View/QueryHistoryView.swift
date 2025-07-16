import SwiftUI

// MARK: - Query History View

struct QueryHistoryView: View {
    let history: [HistoryItem]
    let onSelect: (HistoryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if history.isEmpty {
                    EmptyHistoryView()
                } else {
                    List(history) { item in
                        HistoryRowView(item: item) {
                            onSelect(item)
                        }
                    }
                }
            }
            .navigationTitle("Query History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct HistoryRowView: View {
    let item: HistoryItem
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.sql.prefix(100) + (item.sql.count > 100 ? "..." : ""))
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack {
                        Label(item.shard, systemImage: "server.rack")
                        Label("\(item.rowCount) rows", systemImage: "tablecells")
                        Label(String(format: "%.3fs", item.executionTime), systemImage: "clock")
                        Label(formatDate(item.timestamp), systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Use Query") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Query History")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Execute some queries to build up your history")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Saved Queries View

struct SavedQueriesView: View {
    let savedQueries: [SavedQuery]
    let onSelect: (SavedQuery) -> Void
    let onDelete: (SavedQuery) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if savedQueries.isEmpty {
                    EmptySavedQueriesView()
                } else {
                    List(savedQueries) { query in
                        SavedQueryRowView(query: query, onSelect: {
                            onSelect(query)
                        }, onDelete: {
                            onDelete(query)
                        })
                    }
                }
            }
            .navigationTitle("Saved Queries")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct SavedQueryRowView: View {
    let query: SavedQuery
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(query.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(query.sql.prefix(150) + (query.sql.count > 150 ? "..." : ""))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    Text("Saved \(formatDate(query.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Use Query") {
                        onSelect()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptySavedQueriesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Saved Queries")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Save frequently used queries for quick access")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}