//
//  StorageSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//
import SwiftUI

struct StorageSettingsView: View {
    @State private var cacheSize: String = "Calculating..."
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Video Cache")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Storage")
            }
            
            Section {
                Button("Clear Recording Cache") {
                    clearRecordingCache()
                }
                .foregroundColor(.orange)
            } footer: {
                Text("This will delete all locally stored video recordings. Uploaded videos will not be affected.")
            }
        }
        .navigationTitle("Storage")
        .onAppear {
            calculateCacheSize()
        }
    }
    
    private func calculateCacheSize() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        guard let videoFiles = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey]) else {
            cacheSize = "Unknown"
            return
        }
        
        let totalSize = videoFiles
            .filter { $0.pathExtension == "mov" }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0, +)
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: Int64(totalSize))
    }
    
    private func clearRecordingCache() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoFiles = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
        
        videoFiles?.forEach { url in
            if url.pathExtension == "mov" {
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        calculateCacheSize()
    }
}
