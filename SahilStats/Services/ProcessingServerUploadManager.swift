//
//  ProcessingServerUploadManager.swift
//  SahilStats
//
//  Manages uploads to processing server for video processing
//

import Foundation
import Combine

class ProcessingServerUploadManager: ObservableObject {
    static let shared = ProcessingServerUploadManager()

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var lastError: String?

    private init() {}

    struct UploadResponse: Codable {
        let success: Bool
        let video_id: String
        let job_id: String
        let message: String
    }

    /// Upload video and timeline to processing server
    func uploadToServer(videoURL: URL, gameId: String) async throws -> UploadResponse {
        guard !SettingsManager.shared.processingServerURL.isEmpty else {
            throw NSError(domain: "Processing server URL not configured", code: -1)
        }

        guard let serverURL = URL(string: "\(SettingsManager.shared.processingServerURL)/upload") else {
            throw NSError(domain: "Invalid server URL", code: -1)
        }

        // Load timeline JSON
        guard let timeline = loadTimeline(forGameId: gameId) else {
            throw NSError(domain: "Timeline not found for game \(gameId)", code: -1)
        }

        await MainActor.run {
            isUploading = true
            uploadProgress = 0
            lastError = nil
        }

        debugPrint("📤 Uploading to processing server: \(serverURL.absoluteString)")
        debugPrint("   Video: \(videoURL.lastPathComponent)")
        debugPrint("   Game: \(gameId)")
        debugPrint("   Timeline snapshots: \(timeline.count)")

        do {
            // Create multipart request
            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"

            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)",
                           forHTTPHeaderField: "Content-Type")

            var body = Data()

            // Add video file
            let videoData = try Data(contentsOf: videoURL)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(videoURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)

            // Add game ID
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"game_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(gameId)\r\n".data(using: .utf8)!)

            // Add timeline JSON - convert array to JSON string
            let timelineJSON = try JSONSerialization.data(
                withJSONObject: [
                    "game_id": gameId,
                    "snapshots": timeline
                ],
                options: []
            )
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"timeline_json\"\r\n\r\n".data(using: .utf8)!)
            body.append(timelineJSON)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            // Upload with progress tracking
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "Invalid response", code: -1)
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "Upload failed: \(errorMessage)", code: httpResponse.statusCode)
            }

            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)

            await MainActor.run {
                isUploading = false
                uploadProgress = 1.0
            }

            forcePrint("✅ Server upload successful!")
            forcePrint("   Video ID: \(uploadResponse.video_id)")
            forcePrint("   Job ID: \(uploadResponse.job_id)")

            return uploadResponse

        } catch {
            await MainActor.run {
                isUploading = false
                uploadProgress = 0
                lastError = error.localizedDescription
            }
            forcePrint("❌ Server upload failed: \(error)")
            throw error
        }
    }

    private func loadTimeline(forGameId gameId: String) -> [[String: Any]]? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timelineURL = documentsPath.appendingPathComponent("timeline_\(gameId).json")

        do {
            let data = try Data(contentsOf: timelineURL)
            let decoder = JSONDecoder()
            let snapshots = try decoder.decode([ScoreTimelineTracker.ScoreSnapshot].self, from: data)

            // Convert to dictionary format for upload
            return snapshots.map { snapshot in
                [
                    "timestamp": snapshot.timestamp,
                    "homeScore": snapshot.homeScore,
                    "awayScore": snapshot.awayScore,
                    "quarter": snapshot.quarter,
                    "clockTime": snapshot.clockTime,
                    "homeTeam": snapshot.homeTeam,
                    "awayTeam": snapshot.awayTeam,
                    "gameFormat": snapshot.gameFormat.rawValue,
                    "zoomLevel": snapshot.zoomLevel as Any
                ]
            }
        } catch {
            forcePrint("❌ Failed to load timeline: \(error)")
            return nil
        }
    }
}
