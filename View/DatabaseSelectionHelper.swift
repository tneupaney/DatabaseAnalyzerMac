//
//  DatabaseSelectionArea.swift
//  DatabaseAnalyzer
//
//  Created by Tushar Neupaney on 16/7/2025.
//


import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Database Selection Helper Components

struct DatabaseSelectionArea: View {
    @Binding var sqlitePaths: [String]
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @State private var isDragOver = false
    
    var body: some View {
        Button {
            selectDatabaseFiles()
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(spacing: 4) {
                    Text("Select Database Files")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Click to browse or drag & drop SQLite files")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(isDragOver ? 0.8 : 0.3), lineWidth: 2)
                            .animation(.easeInOut(duration: 0.2), value: isDragOver)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func selectDatabaseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "sqlite")!,
            UTType(filenameExtension: "db")!,
            UTType(filenameExtension: "sqlite3")!
        ]
        
        if panel.runModal() == .OK {
            sqlitePaths = panel.urls.map { $0.path }
        } else {
            alertMessage = "File selection cancelled."
            showAlert = true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var newPaths: [String] = []
        
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.isFileURL {
                    let path = url.path
                    if path.hasSuffix(".sqlite") || path.hasSuffix(".db") || path.hasSuffix(".sqlite3") {
                        newPaths.append(path)
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            if !newPaths.isEmpty {
                sqlitePaths.append(contentsOf: newPaths)
                sqlitePaths = Array(Set(sqlitePaths)) // Remove duplicates
            }
        }
        
        return !newPaths.isEmpty
    }
}

struct SelectedDatabasesView: View {
    @Binding var paths: [String]
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(paths, id: \.self) { path in
                HStack {
                    Image(systemName: "cylinder")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        paths.removeAll { $0 == path }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("Add More Files") {
                selectMoreFiles()
            }
            .foregroundColor(.blue)
        }
    }
    
    private func selectMoreFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "sqlite")!,
            UTType(filenameExtension: "db")!,
            UTType(filenameExtension: "sqlite3")!
        ]
        
        if panel.runModal() == .OK {
            let newPaths = panel.urls.map { $0.path }
            paths.append(contentsOf: newPaths)
            paths = Array(Set(paths)) // Remove duplicates
        } else {
            alertMessage = "File selection cancelled."
            showAlert = true
        }
    }
}

struct RecentDatabasesView: View {
    let recentDatabases: [String]
    let onSelect: ([String]) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Databases")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(recentDatabases.prefix(5), id: \.self) { path in
                Button {
                    onSelect([path])
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}