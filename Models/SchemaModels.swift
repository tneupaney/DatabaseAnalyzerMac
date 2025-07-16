import Foundation

// MARK: - Schema Discovery Models

struct DiscoveredSchema: Codable {
    var shards: [String: ShardInfo]
    var relationships: [ForeignKeyRelationship]
    var allTriggers: [TriggerInfo]
}

struct ShardInfo: Codable {
    var tables: [String: TableInfo]
    var triggers: [TriggerInfo] // Triggers specific to this shard
}

struct TableInfo: Codable {
    var columns: [ColumnInfo]
    var primaryKey: [String] // Column names forming the primary key
    var uniqueConstraints: [[String]] // Arrays of column names for unique constraints
    var foreignKeys: [ForeignKeyConstraint]
    var indexes: [IndexInfo]
}

struct ColumnInfo: Codable, Hashable {
    var name: String
    var type: String // e.g., "INTEGER", "TEXT", "VARCHAR(255)"
    var nullable: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(nullable)
    }
}

struct ForeignKeyConstraint: Codable, Hashable {
    var constrainedColumns: [String]
    var referredTable: String
    var referredColumns: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(constrainedColumns)
        hasher.combine(referredTable)
        hasher.combine(referredColumns)
    }
}

struct ForeignKeyRelationship: Codable, Hashable {
    var shard: String
    var fromTable: String
    var fromColumns: [String]
    var toTable: String
    var toColumns: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(shard)
        hasher.combine(fromTable)
        hasher.combine(fromColumns)
        hasher.combine(toTable)
        hasher.combine(toColumns)
    }
}

struct IndexInfo: Codable, Hashable {
    var name: String
    var columns: [String]
    var unique: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(columns)
        hasher.combine(unique)
    }
}

struct TriggerInfo: Codable, Hashable {
    var name: String
    var table: String // The table this trigger is on
    var sql: String // The SQL definition of the trigger
    var shard: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(table)
        hasher.combine(sql)
        hasher.combine(shard)
    }
}
