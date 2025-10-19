//
//  YouTubeDownloader.swift
//  SahilStats
//
//  YouTube video downloader for PoC processing
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

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

        // Debug: Print environment info
        #if targetEnvironment(simulator)
        print("   Running on: iOS Simulator")
        #elseif os(macOS)
        print("   Running on: macOS")
        #else
        print("   Running on: Real iOS device")
        #endif

        // Check if yt-dlp is available
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        let fileManager = FileManager.default

        print("   Checking for yt-dlp at: \(ytDlpPath)")
        let ytDlpExists = fileManager.fileExists(atPath: ytDlpPath)
        print("   yt-dlp exists: \(ytDlpExists)")

        #if os(macOS) || targetEnvironment(simulator)
        if ytDlpExists {
            print("   ✅ Platform supports Process - will use yt-dlp")
            return try await downloadWithYtDlp(youtubeURL: youtubeURL, ytDlpPath: ytDlpPath, progress: progress)
        } else {
            print("   ⚠️ yt-dlp not found at expected path")
            return try await checkForManualDownload(youtubeURL: youtubeURL)
        }
        #else
        print("   ❌ Platform does not support Process - manual download only")
        return try await checkForManualDownload(youtubeURL: youtubeURL)
        #endif
    }

    /// Download using yt-dlp command line tool
    private func downloadWithYtDlp(youtubeURL: String, ytDlpPath: String, progress: @escaping (Double) -> Void) async throws -> URL {
        #if os(macOS) || targetEnvironment(simulator)
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
        print("⚠️ yt-dlp not supported on iOS - checking for manual download")
        return try await checkForManualDownload(youtubeURL: youtubeURL)
        #endif
    }

    /// Check if video was manually downloaded
    private func checkForManualDownload(youtubeURL: String) async throws -> URL {
        print("⚠️ Checking for cached/manually downloaded video...")

        // Check specific cached locations first (highest priority)
        let cachedPaths = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads/POC_Videos/video.mp4"),
            FileManager.default.temporaryDirectory.appendingPathComponent("POC_Videos/video.mp4")
        ]

        for cachedPath in cachedPaths {
            if FileManager.default.fileExists(atPath: cachedPath.path) {
                print("✅ Found cached video: \(cachedPath.path)")
                return cachedPath
            }
        }

        // Then check common download directories for any video files
        let downloadsPaths = [
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.appendingPathComponent("POC_Videos", isDirectory: true),
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
                    print("✅ Found manually downloaded video: \(firstVideo.path)")
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
