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
import FirebaseAuth

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
        
        Task {
            do {
                // Get fresh access token (auto-refreshes if expired)
                let accessToken = try await getFreshAccessToken()
                
                // Upload to YouTube
                let videoId = try await uploadToYouTube(
                    videoURL: upload.videoURL,
                    title: upload.title,
                    description: upload.description,
                    accessToken: accessToken
                )
                
                print("Upload successful, video ID: \(videoId)")
                
                // Save video ID to game
                try await saveVideoIdToGame(videoId: videoId, gameId: upload.gameId)
                
                await MainActor.run {
                    completeUpload(upload, success: true)
                }
            } catch {
                print("Upload failed: \(error.localizedDescription)")
                // Handle retry logic
            }
        }
    }

    private func getFreshAccessToken() async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw YouTubeAuthError.notSignedIn
        }

        let docRef = Firestore.firestore().collection("users").document(userId)

        do {
            let document = try await docRef.getDocument()
            guard let data = document.data(),
                  let accessToken = data["youtubeAccessToken"] as? String,
                  let timestamp = data["youtubeAuthTimestamp"] as? Timestamp else {
                // If we don't have the necessary data, we have to re-authorize.
                throw UploadError.uploadFailed(statusCode: 401, message: "YouTube token information is missing. Please re-authorize.")
            }

            let tokenDate = timestamp.dateValue()
            let fiftyMinutesInSeconds: TimeInterval = 50 * 60

            // If the token is less than 50 minutes old, use it.
            if Date().timeIntervalSince(tokenDate) < fiftyMinutesInSeconds {
                print("✅ Using existing, valid YouTube access token.")
                return accessToken
            } else {
                // Otherwise, refresh the token.
                print("⌛️ YouTube access token is old, attempting to refresh.")
                return try await FirebaseYouTubeAuthManager.shared.refreshAccessToken()
            }
        } catch {
            print("Token refresh failed: \(error)")
            throw UploadError.uploadFailed(statusCode: 401, message: "Unable to refresh YouTube token. Please re-authorize.")
        }
    }
    
    private func uploadToYouTube(
        videoURL: URL,
        title: String,
        description: String,
        accessToken: String
    ) async throws -> String {
        
        // Metadata
        let metadata: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description,
                "categoryId": "17"
            ],
            "status": [
                "privacyStatus": "unlisted"
            ]
        ]
        
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
        
        // Use resumable upload for large files
        let url = URL(string: "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as! Int)", forHTTPHeaderField: "X-Upload-Content-Length")
        request.setValue("video/*", forHTTPHeaderField: "X-Upload-Content-Type")
        request.httpBody = metadataJSON
        
        // Get upload URL
        let (_, initResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = initResponse as? HTTPURLResponse,
              let uploadURL = httpResponse.value(forHTTPHeaderField: "Location") else {
            throw UploadError.invalidResponse
        }
        
        // Upload video file
        var uploadRequest = URLRequest(url: URL(string: uploadURL)!)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("video/*", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.upload(for: uploadRequest, fromFile: videoURL)
        
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw UploadError.uploadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Upload failed")
        }
        
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
