import SwiftUI

struct SchemaView: View {
    let schema: DiscoveredSchema
    @State private var searchText = ""
    @State private var selectedShard: String?
    
    var body: some View {
        NavigationSplitView {
            // Shard List
            List(selection: $selectedShard) {
                ForEach(schema.shards.keys.sorted(), id: \.self) { shardName in
                    NavigationLink(value: shardName) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shardName)
                                    .font(.headline)
                                Text("\(schema.shards[shardName]?.tables.count ?? 0) tables")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Database Shards")
            .searchable(text: $searchText, prompt: "Search shards...")
        } detail: {
            if let selectedShard = selectedShard,
               let shardInfo = schema.shards[selectedShard] {
                ShardDetailView(shardName: selectedShard, shardInfo: shardInfo)
            } else {
                ContentUnavailableView("Select a Database Shard", systemImage: "server.rack", description: Text("Choose a shard from the sidebar to view its tables and structure"))
            }
        }
        .onAppear {
            if selectedShard == nil {
                selectedShard = schema.shards.keys.sorted().first
            }
        }
    }
}

struct ShardDetailView: View {
    let shardName: String
    let shardInfo: ShardInfo
    @State private var selectedTable: String?
    
    var body: some View {
        NavigationSplitView {
            // Table List
            List(selection: $selectedTable) {
                Section("Tables") {
                    ForEach(shardInfo.tables.keys.sorted(), id: \.self) { tableName in
                        NavigationLink(value: tableName) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tableName)
                                        .font(.headline)
                                    Text("\(shardInfo.tables[tableName]?.columns.count ?? 0) columns")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "tablecells")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                if !shardInfo.triggers.isEmpty {
                    Section("Triggers") {
                        ForEach(shardInfo.triggers, id: \.name) { trigger in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trigger.name)
                                        .font(.headline)
                                    Text("on \(trigger.table)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle(shardName)
        } detail: {
            if let selectedTable = selectedTable,
               let tableInfo = shardInfo.tables[selectedTable] {
                TableDetailView(tableName: selectedTable, tableInfo: tableInfo)
            } else {
                ContentUnavailableView("Select a Table", systemImage: "tablecells", description: Text("Choose a table from the sidebar to view its structure"))
            }
        }
        .onAppear {
            if selectedTable == nil {
                selectedTable = shardInfo.tables.keys.sorted().first
            }
        }
    }
}

struct TableDetailView: View {
    let tableName: String
    let tableInfo: TableInfo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(tableName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Table structure and constraints")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Columns
                VStack(alignment: .leading, spacing: 12) {
                    Text("Columns")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(tableInfo.columns, id: \.name) { column in
                            ColumnRowView(column: column, isPrimaryKey: tableInfo.primaryKey.contains(column.name))
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Primary Key
                if !tableInfo.primaryKey.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Primary Key")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(tableInfo.primaryKey.joined(separator: ", "))
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Foreign Keys
                if !tableInfo.foreignKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foreign Keys")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(tableInfo.foreignKeys, id: \.constrainedColumns.joined()) { fk in
                                ForeignKeyRowView(foreignKey: fk)
                            }
                        }
                    }
                }
                
                // Indexes
                if !tableInfo.indexes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Indexes")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(tableInfo.indexes, id: \.name) { index in
                                IndexRowView(index: index)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(tableName)
    }
}

struct ColumnRowView: View {
    let column: ColumnInfo
    let isPrimaryKey: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(column.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if isPrimaryKey {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text(column.type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    if !column.nullable {
                        Text("NOT NULL")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ForeignKeyRowView: View {
    let foreignKey: ForeignKeyConstraint
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(foreignKey.constrainedColumns.joined(separator: ", "))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("→ \(foreignKey.referredTable).\(foreignKey.referredColumns.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct IndexRowView: View {
    let index: IndexInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(index.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if index.unique {
                        Text("UNIQUE")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(index.columns.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}