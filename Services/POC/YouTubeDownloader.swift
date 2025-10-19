//
//  YouTubeDownloader.swift
//  SahilStats
//
//  YouTube video downloader for PoC processing
//

import Foundation

class YouTubeDownloader {
    static let shared = YouTubeDownloader()

    private init() {}

    enum DownloadError: Error {
        case invalidURL
        case downloadFailed(String)
        case saveFailed(String)
    }

    /// Download YouTube video for processing
    /// Note: For PoC, we'll use a simplified approach with yt-dlp if available,
    /// or provide instructions to manually download the video
    func downloadVideo(youtubeURL: String, progress: @escaping (Double) -> Void) async throws -> URL {
        print("📥 Starting YouTube video download...")
        print("   URL: \(youtubeURL)")

        // For PoC, we'll use a manual download approach
        // The user should download the video using a browser or yt-dlp

        // Check if yt-dlp is available
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: ytDlpPath) {
            // Use yt-dlp to download
            return try await downloadWithYtDlp(youtubeURL: youtubeURL, ytDlpPath: ytDlpPath, progress: progress)
        } else {
            // Fallback: Check if video is already downloaded manually
            return try await checkForManualDownload(youtubeURL: youtubeURL)
        }
    }

    /// Download using yt-dlp command line tool
    /// Note: Process is only available on macOS, not iOS
    private func downloadWithYtDlp(youtubeURL: String, ytDlpPath: String, progress: @escaping (Double) -> Void) async throws -> URL {
        #if os(macOS)
        print("📦 Using yt-dlp to download video...")

        // Create temporary download directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("POC_Videos", isDirectory: true)

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Output file path
        let outputPath = tempDir.appendingPathComponent("video.mp4")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputPath)

        // yt-dlp command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = [
            "-f", "best[ext=mp4][height<=720]", // Download 720p MP4
            "-o", outputPath.path,
            youtubeURL
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        // Monitor progress
        Task {
            let handle = pipe.fileHandleForReading
            while process.isRunning {
                if let data = try? handle.availableData, !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        print(output, terminator: "")

                        // Parse progress if possible
                        if output.contains("%") {
                            // Simple progress parsing
                            await MainActor.run {
                                progress(0.5) // Rough estimate
                            }
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }

        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("✅ Video downloaded successfully")
            print("   Path: \(outputPath.path)")
            await MainActor.run {
                progress(1.0)
            }
            return outputPath
        } else {
            throw DownloadError.downloadFailed("yt-dlp failed with status \(process.terminationStatus)")
        }
        #else
        // iOS doesn't support Process - fallback to manual download
        print("⚠️ yt-dlp not supported on iOS - use manual download")
        return try await checkForManualDownload(youtubeURL: youtubeURL)
        #endif
    }

    /// Check if video was manually downloaded
    private func checkForManualDownload(youtubeURL: String) async throws -> URL {
        print("⚠️ yt-dlp not found - checking for manual download...")

        // Check common download locations
        let downloadsPaths = [
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            FileManager.default.temporaryDirectory.appendingPathComponent("POC_Videos", isDirectory: true)
        ]

        for downloadsDir in downloadsPaths {
            guard let downloadsDir = downloadsDir else { continue }

            // Look for video files
            if let files = try? FileManager.default.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil) {
                let videoFiles = files.filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "mp4" || ext == "mov" || ext == "m4v"
                }

                if let firstVideo = videoFiles.first {
                    print("✅ Found manually downloaded video: \(firstVideo.lastPathComponent)")
                    return firstVideo
                }
            }
        }

        // If not found, throw error with instructions
        let instructions = """

        ⚠️ Video not found. Please download manually:

        Option 1: Install yt-dlp (recommended)
        ─────────────────────────────────────────
        brew install yt-dlp

        Option 2: Download manually
        ─────────────────────────────────────────
        1. Visit: \(youtubeURL)
        2. Download the video (use browser extension or online downloader)
        3. Save to: ~/Downloads/
        4. Retry processing

        """

        print(instructions)
        throw DownloadError.downloadFailed("Manual download required. See console for instructions.")
    }

    /// Get video information without downloading
    func getVideoInfo(youtubeURL: String) async throws -> VideoInfo {
        // For now, return basic info
        // In production, could use yt-dlp to get metadata

        let videoId = extractVideoId(from: youtubeURL)

        return VideoInfo(
            videoId: videoId,
            title: "YouTube Video",
            duration: 0, // Unknown until downloaded
            thumbnailURL: "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
        )
    }

    private func extractVideoId(from url: String) -> String {
        // Extract video ID from various YouTube URL formats
        if let urlObj = URL(string: url),
           let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false) {

            // youtube.com/watch?v=VIDEO_ID
            if let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoId
            }

            // youtu.be/VIDEO_ID
            if urlObj.host == "youtu.be" {
                return urlObj.lastPathComponent
            }
        }

        return "unknown"
    }
}

// MARK: - Supporting Types

struct VideoInfo {
    let videoId: String
    let title: String
    let duration: TimeInterval
    let thumbnailURL: String
}
