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
    @Published var isYouTubeUploadEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isYouTubeUploadEnabled, forKey: "isYouTubeUploadEnabled")
            print("📺 YouTube upload \(isYouTubeUploadEnabled ? "enabled" : "disabled")")
        }
    }

    private var wifinetworkMonitor = WifiNetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()


    private init() {
        // Load YouTube upload preference (default: true for existing users)
        self.isYouTubeUploadEnabled = UserDefaults.standard.object(forKey: "isYouTubeUploadEnabled") as? Bool ?? true

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
        print("🎥 queueVideoForUpload called")
        print("   Video URL: \(videoURL)")
        print("   Title: \(title)")
        print("   Game ID: \(gameId)")
        print("   YouTube upload enabled: \(isYouTubeUploadEnabled)")

        // Check if YouTube uploads are disabled
        if !isYouTubeUploadEnabled {
            print("⏸️ YouTube uploads are disabled - skipping queue")
            print("   Local video saved at: \(videoURL.path)")
            return
        }

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: videoURL.path)
        print("   File exists: \(fileExists)")

        if !fileExists {
            print("❌ Video file does not exist at path: \(videoURL.path)")
            return
        }

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

        print("✅ Video queued for upload: \(title)")
        print("   Total pending uploads: \(pendingUploads.count)")

        // If on WiFi, start uploading immediately
        if wifinetworkMonitor.isWiFi {
            print("📡 WiFi detected - starting upload process")
            processPendingUploads()
        } else {
            print("⚠️ Not on WiFi - upload will start when connected")
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

        // Find first upload that hasn't exceeded max attempts
        guard let nextUpload = pendingUploads.first(where: { $0.uploadAttempts < 5 }) else {
            if !pendingUploads.isEmpty {
                print("⚠️ All pending uploads have exceeded maximum attempts")
            } else {
                print("✅ No pending uploads")
            }
            return
        }

        uploadVideo(nextUpload)
    }
    
    private func uploadVideo(_ upload: PendingUpload) {
        isUploading = true
        currentUpload = upload
        uploadProgress = 0

        Task {
            // First, try to save local video URL to game (in case it wasn't saved before)
            // This will fail silently if game doesn't exist yet, but will succeed on retries
            await saveLocalVideoURLToGame(videoURL: upload.videoURL, gameId: upload.gameId)

            do {
                // Update progress: Getting token
                await MainActor.run { self.uploadProgress = 0.1 }

                // Get fresh access token (auto-refreshes if expired)
                let accessToken = try await getFreshAccessToken()

                // Update progress: Starting upload
                await MainActor.run { self.uploadProgress = 0.2 }

                // Upload to YouTube (progress updates happen inside this method)
                let videoId = try await uploadToYouTube(
                    videoURL: upload.videoURL,
                    title: upload.title,
                    description: upload.description,
                    accessToken: accessToken
                )

                print("✅ Upload successful, video ID: \(videoId)")

                // Update progress: Saving metadata
                await MainActor.run { self.uploadProgress = 0.95 }

                // Save video ID to game
                try await saveVideoIdToGame(videoId: videoId, gameId: upload.gameId)

                // Update progress: Complete
                await MainActor.run {
                    self.uploadProgress = 1.0
                    self.completeUpload(upload, success: true)
                }
            } catch {
                print("❌ Upload failed: \(error.localizedDescription)")

                await MainActor.run {
                    var shouldStopRetrying = false

                    // Check if it's an auth error (401 or 403)
                    if let uploadError = error as? UploadError {
                        switch uploadError {
                        case .uploadFailed(let statusCode, _) where statusCode == 401 || statusCode == 403:
                            print("🔒 Authentication error detected - clearing stored tokens")
                            // Clear tokens so user is forced to re-authorize
                            Task {
                                try? await FirebaseYouTubeAuthManager.shared.revokeYouTubeAccess()
                            }
                            shouldStopRetrying = true
                        case .quotaExceeded:
                            print("⚠️ YouTube quota exceeded - stopping retry until quota resets")
                            shouldStopRetrying = true

                            // Store local video URL so users can watch locally while waiting for quota
                            Task {
                                await self.saveLocalVideoURLToGame(videoURL: upload.videoURL, gameId: upload.gameId)
                            }
                        default:
                            break
                        }
                    }

                    // Store error message
                    if let index = self.pendingUploads.firstIndex(where: { $0.id == upload.id }) {
                        self.pendingUploads[index].lastError = error.localizedDescription
                        self.pendingUploads[index].uploadAttempts += 1

                        // Stop retrying for quota/auth errors
                        if shouldStopRetrying {
                            self.pendingUploads[index].uploadAttempts = 999 // Mark as should not retry
                        }

                        // If too many attempts, mark for manual intervention
                        if self.pendingUploads[index].uploadAttempts >= 5 {
                            print("⚠️ Upload failed after \(self.pendingUploads[index].uploadAttempts) attempts - stopping auto-retry")
                        }
                    }

                    // Complete with failure - this will reset state and allow retries
                    self.completeUpload(upload, success: false)
                }
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
                throw UploadError.uploadFailed(statusCode: 401, message: "YouTube token information is missing. Please re-authorize in Settings.")
            }

            let tokenDate = timestamp.dateValue()
            let fortyFiveMinutesInSeconds: TimeInterval = 45 * 60

            // If the token is less than 45 minutes old, use it (more conservative)
            if Date().timeIntervalSince(tokenDate) < fortyFiveMinutesInSeconds {
                print("✅ Using existing YouTube access token (age: \(Int(Date().timeIntervalSince(tokenDate) / 60)) minutes)")
                return accessToken
            } else {
                // Otherwise, refresh the token.
                print("⌛️ YouTube access token is old (\(Int(Date().timeIntervalSince(tokenDate) / 60)) minutes), refreshing...")
                let newToken = try await FirebaseYouTubeAuthManager.shared.refreshAccessToken()
                print("✅ Successfully refreshed YouTube access token")
                return newToken
            }
        } catch {
            print("❌ Token fetch/refresh failed: \(error.localizedDescription)")
            throw UploadError.uploadFailed(statusCode: 401, message: "Unable to get valid YouTube token. Please re-authorize in Settings > YouTube.")
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

        // Update progress: Initializing upload
        await MainActor.run { self.uploadProgress = 0.25 }

        // Use resumable upload for large files
        let url = URL(string: "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status")!

        // Get file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as! Int
        print("📹 Video file size: \(fileSize) bytes (\(fileSize / 1_000_000) MB)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
        request.setValue("video/*", forHTTPHeaderField: "X-Upload-Content-Type")
        request.httpBody = metadataJSON

        print("📤 YouTube Upload Request:")
        print("   URL: \(url)")
        print("   Method: POST")
        print("   Content-Length: \(fileSize)")
        if let metadataString = String(data: metadataJSON, encoding: .utf8) {
            print("   Metadata: \(metadataString)")
        }

        // Get upload URL
        print("🌐 Sending resumable upload initialization request to YouTube...")
        let (initData, initResponse) = try await URLSession.shared.data(for: request)

        // Log response details
        if let httpResponse = initResponse as? HTTPURLResponse {
            print("📡 YouTube API Response:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   Headers: \(httpResponse.allHeaderFields)")

            if let responseBody = String(data: initData, encoding: .utf8) {
                print("   Response Body: \(responseBody)")
            }
        } else {
            print("❌ Response is not HTTPURLResponse: \(type(of: initResponse))")
        }

        guard let httpResponse = initResponse as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        // Check for various error responses
        if httpResponse.statusCode == 400 {
            // Parse error response for quota limits
            if let responseBody = String(data: initData, encoding: .utf8) {
                print("❌ YouTube API error 400. Response: \(responseBody)")

                // Check if it's a quota error
                if responseBody.contains("uploadLimitExceeded") {
                    throw UploadError.quotaExceeded
                } else if responseBody.contains("quotaExceeded") {
                    throw UploadError.quotaExceeded
                } else {
                    throw UploadError.uploadFailed(statusCode: 400, message: "YouTube rejected the upload. Error: \(responseBody)")
                }
            }
            throw UploadError.uploadFailed(statusCode: 400, message: "Bad request to YouTube API")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            if let responseBody = String(data: initData, encoding: .utf8) {
                print("❌ YouTube API auth error. Status: \(httpResponse.statusCode)")
                print("   Response body: \(responseBody)")
            }

            // Provide helpful error message
            if httpResponse.statusCode == 401 {
                throw UploadError.uploadFailed(statusCode: 401, message: "YouTube authorization expired. Please re-authorize in Settings > YouTube.")
            } else {
                throw UploadError.uploadFailed(statusCode: 403, message: "YouTube upload permission denied. Please re-authorize with upload permissions in Settings > YouTube.")
            }
        }

        guard let uploadURL = httpResponse.value(forHTTPHeaderField: "Location") else {
            print("❌ No 'Location' header in response. Status: \(httpResponse.statusCode)")
            if let responseBody = String(data: initData, encoding: .utf8) {
                print("   Response body: \(responseBody)")
            }
            throw UploadError.uploadFailed(statusCode: httpResponse.statusCode, message: "YouTube API error (status \(httpResponse.statusCode)). Check logs for details.")
        }

        print("✅ Got upload URL from YouTube: \(uploadURL)")

        // Update progress: Starting file transfer
        await MainActor.run { self.uploadProgress = 0.3 }

        // Upload video file
        var uploadRequest = URLRequest(url: URL(string: uploadURL)!)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("video/*", forHTTPHeaderField: "Content-Type")

        // Update progress during upload
        await MainActor.run { self.uploadProgress = 0.4 }

        let (data, response) = try await URLSession.shared.upload(for: uploadRequest, fromFile: videoURL)

        // Update progress: Upload complete, processing response
        await MainActor.run { self.uploadProgress = 0.9 }

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

        // Also include the local video URL if we can find it in pending uploads
        var updateData: [String: Any] = [
            "youtubeVideoId": videoId,
            "videoUploadedAt": Timestamp()
        ]

        // Find the upload in our pending list to get the local video URL
        if let upload = pendingUploads.first(where: { $0.gameId == gameId }) {
            updateData["videoURL"] = upload.videoURL.path
            print("📹 Storing local video URL: \(upload.videoURL.path)")
        }

        try await db.collection("games").document(gameId).updateData(updateData)

        print("✅ Saved video ID and local URL to game: \(gameId)")
    }

    private func saveLocalVideoURLToGame(videoURL: URL, gameId: String) async {
        // Try to save with retries (game document may not exist immediately)
        await saveLocalVideoURLWithRetry(videoURL: videoURL, gameId: gameId, attempt: 1, maxAttempts: 10)
    }

    private func saveLocalVideoURLWithRetry(videoURL: URL, gameId: String, attempt: Int, maxAttempts: Int) async {
        do {
            let db = Firestore.firestore()

            // Use setData with merge: true to create document if it doesn't exist
            // This way we don't need to wait for the controller to create it
            try await db.collection("games").document(gameId).setData([
                "videoURL": videoURL.path
            ], merge: true)

            print("✅ Successfully saved local video URL to game: \(gameId)")
            print("   📹 Local video: \(videoURL.lastPathComponent)")
            if attempt > 1 {
                print("   ✓ Saved on attempt \(attempt)")
            }
        } catch {
            print("⚠️ Error saving local video URL (attempt \(attempt)/\(maxAttempts)): \(error.localizedDescription)")

            // Retry on error (unless max attempts reached)
            if attempt < maxAttempts {
                let delay = Double(attempt) * 2.0 // 2s, 4s, 6s...
                print("   Retrying in \(Int(delay))s...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await saveLocalVideoURLWithRetry(videoURL: videoURL, gameId: gameId, attempt: attempt + 1, maxAttempts: maxAttempts)
            } else {
                print("❌ Failed to save local video URL after \(maxAttempts) attempts")
            }
        }
    }

    enum UploadError: LocalizedError {
        case invalidResponse
        case uploadFailed(statusCode: Int, message: String)
        case noVideoId
        case quotaExceeded

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response"
            case .uploadFailed(let code, let message):
                return "Upload failed (HTTP \(code)): \(message)"
            case .noVideoId:
                return "No video ID in response"
            case .quotaExceeded:
                return "YouTube daily upload limit reached. Unverified channels can upload ~6 videos per day. Verify your YouTube channel or wait 24 hours."
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

            // If this is the currently uploading video, reset state
            if currentUpload?.id == uploadId {
                isUploading = false
                currentUpload = nil
                uploadProgress = 0
                print("⚠️ Cancelled active upload: \(upload.title)")
            }

            // Delete the video file if it exists
            deleteLocalVideo(upload.videoURL)

            pendingUploads.remove(at: index)
            savePendingUploads()
            print("❌ Removed from queue: \(upload.title)")

            // Process next upload if available and not currently uploading
            if !isUploading && !pendingUploads.isEmpty && wifinetworkMonitor.isWiFi {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.processPendingUploads()
                }
            }
        }
    }

    func clearAllFailedUploads() {
        // Remove all uploads that have exceeded retry limit
        pendingUploads.removeAll(where: { $0.uploadAttempts >= 5 })
        savePendingUploads()
        print("🗑️ Cleared all failed uploads")
    }
    
    func retryFailedUpload(_ uploadId: String) {
        // Move failed upload back to pending
        processPendingUploads()
    }

    // MARK: - YouTube Video Deletion

    func deleteYouTubeVideo(videoId: String) async throws {
        print("🗑️ Attempting to delete YouTube video: \(videoId)")

        // Get fresh access token
        let accessToken = try await getFreshAccessToken()

        // Delete video using YouTube API
        let urlString = "https://www.googleapis.com/youtube/v3/videos?id=\(videoId)"
        guard let url = URL(string: urlString) else {
            throw UploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        // YouTube returns 204 (No Content) on successful deletion
        if httpResponse.statusCode == 204 {
            print("✅ Successfully deleted YouTube video: \(videoId)")
            return
        }

        // Handle errors
        if httpResponse.statusCode == 404 {
            print("⚠️ YouTube video not found (may already be deleted): \(videoId)")
            return // Not an error - video is already gone
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            print("❌ YouTube authorization error when deleting video")
            throw UploadError.uploadFailed(statusCode: httpResponse.statusCode, message: "YouTube authorization error. Please re-authorize in Settings.")
        }

        // Log unexpected errors
        if let responseBody = String(data: data, encoding: .utf8) {
            print("❌ YouTube API error \(httpResponse.statusCode): \(responseBody)")
        }

        throw UploadError.uploadFailed(statusCode: httpResponse.statusCode, message: "Failed to delete YouTube video (status \(httpResponse.statusCode))")
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
