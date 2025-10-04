//
//  UploadStatusView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/3/25.
//// File: SahilStats/Views/UploadStatusView.swift
// Shows upload status and pending uploads

import SwiftUI

struct UploadStatusView: View {
    @StateObject private var uploadManager = YouTubeUploadManager.shared
    @StateObject private var wifinetworkMonitor = WifiNetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Network Status Section
                Section("Network Status") {
                    HStack {
                        Image(systemName: wifinetworkMonitor.isConnected ? "wifi" : "wifi.slash")
                            .foregroundColor(wifinetworkMonitor.isWiFi ? .green : .gray)
                        
                        Text(wifinetworkMonitor.connectionType.displayName)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if wifinetworkMonitor.isWiFi {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !wifinetworkMonitor.isWiFi {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Uploads require WiFi connection")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Current Upload Section
                if let current = uploadManager.currentUpload {
                    Section("Currently Uploading") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text(current.title)
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: uploadManager.uploadProgress)
                                .progressViewStyle(.linear)
                            
                            Text("\(Int(uploadManager.uploadProgress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Pending Uploads Section
                if !uploadManager.pendingUploads.isEmpty {
                    Section("Pending Uploads (\(uploadManager.pendingUploads.count))") {
                        ForEach(uploadManager.pendingUploads) { upload in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(upload.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("Added: \(upload.dateAdded, style: .relative) ago")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                if upload.uploadAttempts > 0 {
                                    Text("Attempts: \(upload.uploadAttempts)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                
                                if let error = upload.lastError {
                                    Text("Error: \(error)")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .lineLimit(2)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    uploadManager.cancelUpload(upload.id)
                                } label: {
                                    Label("Cancel", systemImage: "trash")
                                }
                            }
                        }
                    }
                } else if !uploadManager.isUploading {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            
                            Text("No Pending Uploads")
                                .font(.headline)
                            
                            Text("All videos have been uploaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                
                // Controls Section
                Section("Upload Controls") {
                    if uploadManager.isUploading {
                        Button("Pause Uploads") {
                            uploadManager.pauseUploads()
                        }
                        .foregroundColor(.orange)
                    } else if !uploadManager.pendingUploads.isEmpty {
                        Button("Resume Uploads") {
                            uploadManager.resumeUploads()
                        }
                        .foregroundColor(.green)
                        .disabled(!wifinetworkMonitor.isWiFi)
                    }
                }
            }
            .navigationTitle("Upload Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Upload Status Badge

struct UploadStatusBadge: View {
    @StateObject private var uploadManager = YouTubeUploadManager.shared
    @StateObject private var wifinetworkMonitor = WifiNetworkMonitor.shared
    
    var body: some View {
        if uploadManager.isUploading || !uploadManager.pendingUploads.isEmpty {
            Button(action: {}) {
                HStack(spacing: 6) {
                    if uploadManager.isUploading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                    }
                    
                    Text("\(uploadManager.pendingUploads.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    UploadStatusView()
}

