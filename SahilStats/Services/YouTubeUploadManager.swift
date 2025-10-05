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
import FirebaseFirestore

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
        
        print("Starting upload: \(upload.title)")
        
        Task {
            do {
                // Get fresh access token
                let (accessToken, _) = try await FirebaseYouTubeAuthManager.shared.getYouTubeTokens()
                
                // Upload to YouTube
                let videoId = try await uploadToYouTube(
                    videoURL: upload.videoURL,
                    title: upload.title,
                    description: upload.description,
                    accessToken: accessToken
                )
                
                print("Upload successful, video ID: \(videoId)")
                
                // Save video ID to game in Firestore
                try await saveVideoIdToGame(videoId: videoId, gameId: upload.gameId)
                
                await MainActor.run {
                    completeUpload(upload, success: true)
                }
            } catch {
                print("Upload failed: \(error.localizedDescription)")
                
                var updatedUpload = upload
                updatedUpload.uploadAttempts += 1
                updatedUpload.lastError = error.localizedDescription
                
                // Retry up to 3 times
                if updatedUpload.uploadAttempts < 3 {
                    print("Will retry upload (attempt \(updatedUpload.uploadAttempts + 1))")
                    await MainActor.run {
                        if let index = self.pendingUploads.firstIndex(where: { $0.id == upload.id }) {
                            self.pendingUploads[index] = updatedUpload
                        }
                        self.isUploading = false
                        self.currentUpload = nil
                        
                        // Retry after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.processPendingUploads()
                        }
                    }
                } else {
                    await MainActor.run {
                        completeUpload(upload, success: false)
                    }
                }
            }
        }
    }
    
    private func uploadToYouTube(
        videoURL: URL,
        title: String,
        description: String,
        accessToken: String
    ) async throws -> String {
        
        // Step 1: Create video metadata
        let metadata: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description,
                "categoryId": "17" // Sports category
            ],
            "status": [
                "privacyStatus": "unlisted" // Change to "private" or "public" as needed
            ]
        ]
        
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
        
        // Step 2: Create multipart request
        let boundary = UUID().uuidString
        let url = URL(string: "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Step 3: Build multipart body
        var body = Data()
        
        // Add metadata part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataJSON)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add video file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        
        let videoData = try Data(contentsOf: videoURL)
        body.append(videoData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Step 4: Upload with progress tracking
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("YouTube API error: \(errorBody)")
            throw UploadError.uploadFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Step 5: Parse response to get video ID
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let videoId = json?["id"] as? String else {
            throw UploadError.noVideoId
        }
        
        return videoId
    }

    private func saveVideoIdToGame(videoId: String, gameId: String) async throws {
        let db = Firestore.firestore()
        
        try await db.collection("games").document(gameId).updateData([
            "youtubeVideoId": videoId,
            "videoUploadedAt": Timestamp()
        ])
        
        print("Saved video ID to game: \(gameId)")
    }

    enum UploadError: LocalizedError {
        case invalidResponse
        case uploadFailed(statusCode: Int, message: String)
        case noVideoId
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response"
            case .uploadFailed(let code, let message):
                return "Upload failed (HTTP \(code)): \(message)"
            case .noVideoId:
                return "No video ID in response"
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
