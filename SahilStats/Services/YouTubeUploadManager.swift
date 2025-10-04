//
//  YouTubeUploadManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/3/25.
//
// File: SahilStats/Services/YouTubeUploadManager.swift
// Manages YouTube uploads with WiFi detection

import Foundation
import Photos
import Combine
//import WifiNetworkMonitor

class YouTubeUploadManager: ObservableObject {
    static let shared = YouTubeUploadManager()
    
    @Published var pendingUploads: [PendingUpload] = []
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var currentUpload: PendingUpload?
    
    private var wifinetworkMonitor = WifiNetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadPendingUploads()
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        // Monitor WiFi connection changes
        wifinetworkMonitor.$isWiFi
            .dropFirst() // Skip initial value
            .sink { [weak self] isWiFi in
                if isWiFi {
                    print("📡 WiFi detected - checking for pending uploads")
                    self?.processPendingUploads()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Add Video to Upload Queue
    
    func queueVideoForUpload(
        videoURL: URL,
        title: String,
        description: String,
        gameId: String
    ) {
        let upload = PendingUpload(
            id: UUID().uuidString,
            videoURL: videoURL,
            title: title,
            description: description,
            gameId: gameId,
            dateAdded: Date()
        )
        
        pendingUploads.append(upload)
        savePendingUploads()
        
        print("📹 Video queued for upload: \(title)")
        
        // If on WiFi, start uploading immediately
        if wifinetworkMonitor.isWiFi {
            processPendingUploads()
        }
    }
    
    // MARK: - Process Uploads
    
    func processPendingUploads() {
        guard wifinetworkMonitor.isWiFi else {
            print("⚠️ Not on WiFi - uploads paused")
            return
        }
        
        guard !isUploading else {
            print("⚠️ Already uploading")
            return
        }
        
        guard let nextUpload = pendingUploads.first else {
            print("✅ No pending uploads")
            return
        }
        
        uploadVideo(nextUpload)
    }
    
    private func uploadVideo(_ upload: PendingUpload) {
        isUploading = true
        currentUpload = upload
        uploadProgress = 0
        
        print("🚀 Starting upload: \(upload.title)")
        
        // TODO: Implement actual YouTube API upload
        // For now, simulate upload
        simulateUpload(upload)
    }
    
    private func simulateUpload(_ upload: PendingUpload) {
        // Simulate upload progress
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.uploadProgress += 0.1
            
            if self.uploadProgress >= 1.0 {
                timer.invalidate()
                self.completeUpload(upload, success: true)
            }
        }
    }
    
    private func completeUpload(_ upload: PendingUpload, success: Bool) {
        if success {
            print("✅ Upload completed: \(upload.title)")
            
            // Remove from pending uploads
            if let index = pendingUploads.firstIndex(where: { $0.id == upload.id }) {
                pendingUploads.remove(at: index)
            }
            
            // Optionally delete local file
            deleteLocalVideo(upload.videoURL)
        } else {
            print("❌ Upload failed: \(upload.title)")
        }
        
        isUploading = false
        currentUpload = nil
        uploadProgress = 0
        
        savePendingUploads()
        
        // Process next upload if available
        if !pendingUploads.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.processPendingUploads()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func savePendingUploads() {
        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: "pendingUploads")
        }
    }
    
    private func loadPendingUploads() {
        if let data = UserDefaults.standard.data(forKey: "pendingUploads"),
           let decoded = try? JSONDecoder().decode([PendingUpload].self, from: data) {
            pendingUploads = decoded
        }
    }
    
    // MARK: - File Management
    
    private func deleteLocalVideo(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ Deleted local video: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete local video: \(error)")
        }
    }
    
    // MARK: - Manual Controls
    
    func pauseUploads() {
        isUploading = false
        print("⏸️ Uploads paused")
    }
    
    func resumeUploads() {
        if wifinetworkMonitor.isWiFi {
            processPendingUploads()
        }
    }
    
    func cancelUpload(_ uploadId: String) {
        if let index = pendingUploads.firstIndex(where: { $0.id == uploadId }) {
            let upload = pendingUploads[index]
            pendingUploads.remove(at: index)
            savePendingUploads()
            print("❌ Cancelled upload: \(upload.title)")
        }
    }
    
    func retryFailedUpload(_ uploadId: String) {
        // Move failed upload back to pending
        processPendingUploads()
    }
}

// MARK: - Pending Upload Model

struct PendingUpload: Codable, Identifiable {
    let id: String
    let videoURL: URL
    let title: String
    let description: String
    let gameId: String
    let dateAdded: Date
    var uploadAttempts: Int = 0
    var lastError: String?
    
    enum CodingKeys: String, CodingKey {
        case id, videoURL, title, description, gameId, dateAdded, uploadAttempts, lastError
    }
}
