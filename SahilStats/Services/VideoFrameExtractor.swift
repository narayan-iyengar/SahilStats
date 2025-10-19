//
//  VideoFrameExtractor.swift
//  SahilStats
//
//  Extract frames from video for AI processing
//

import Foundation
import AVFoundation
import UIKit
import CoreImage

class VideoFrameExtractor {
    static let shared = VideoFrameExtractor()

    private init() {}

    enum ExtractionError: Error {
        case invalidVideoURL
        case trackNotFound
        case extractionFailed(String)
    }

    /// Extract frames from video at specified FPS
    func extractFrames(
        from videoURL: URL,
        fps: Double = 1.0, // Default: 1 frame per second
        progress: @escaping (Double, Int, Int) -> Void // (progress, currentFrame, totalFrames)
    ) async throws -> [VideoFrame] {
        debugPrint("🎬 Extracting frames from video...")
        debugPrint("   URL: \(videoURL.path)")
        debugPrint("   FPS: \(fps)")

        // Load video asset
        let asset = AVURLAsset(url: videoURL)

        // Get video duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        debugPrint("   Duration: \(String(format: "%.1f", durationSeconds))s")

        // Calculate frame interval
        let frameInterval = 1.0 / fps
        let totalFrames = Int(durationSeconds * fps)

        // Safety check: limit frames for PoC (prevent memory issues)
        let maxFrames = 2700 // ~45 minutes at 1fps (full game)
        if totalFrames > maxFrames {
            debugPrint("   ⚠️ WARNING: Video reports \(totalFrames) frames (\(String(format: "%.1f", durationSeconds))s)")
            debugPrint("   ⚠️ This seems incorrect. Limiting to \(maxFrames) frames for safety.")
            debugPrint("   ⚠️ Video metadata may be corrupted. Please check video duration.")
        }

        debugPrint("   Extracting ~\(min(totalFrames, maxFrames)) frames (1 every \(String(format: "%.1f", frameInterval))s)")

        // Create image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        var frames: [VideoFrame] = []
        var extractedCount = 0

        // Generate time points
        var currentTime: Double = 0
        var timePoints: [CMTime] = []

        let effectiveDuration = min(durationSeconds, Double(maxFrames) * frameInterval)

        while currentTime < effectiveDuration {
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            timePoints.append(cmTime)
            currentTime += frameInterval
        }

        debugPrint("   Time points generated: \(timePoints.count)")

        // Extract frames
        for (index, time) in timePoints.enumerated() {
            do {
                // Use modern async API (iOS 18+)
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)

                let frame = VideoFrame(
                    image: uiImage,
                    timestamp: CMTimeGetSeconds(time),
                    frameNumber: index
                )

                frames.append(frame)
                extractedCount += 1

                // Report progress
                let progressValue = Double(index + 1) / Double(timePoints.count)
                await MainActor.run {
                    progress(progressValue, extractedCount, totalFrames)
                }

                if index % 10 == 0 {
                    debugPrint("   Extracted \(extractedCount)/\(totalFrames) frames...")
                }

            } catch {
                debugPrint("   ⚠️ Failed to extract frame at \(String(format: "%.1f", CMTimeGetSeconds(time)))s: \(error)")
                // Continue with next frame
            }
        }

        debugPrint("✅ Frame extraction complete: \(frames.count) frames extracted")

        return frames
    }

    /// Extract a single frame at specific timestamp
    func extractFrame(from videoURL: URL, at timestamp: Double) async throws -> VideoFrame {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        let cgImage = try await imageGenerator.image(at: time).image
        let uiImage = UIImage(cgImage: cgImage)

        return VideoFrame(
            image: uiImage,
            timestamp: timestamp,
            frameNumber: 0
        )
    }

    /// Get video metadata
    func getVideoMetadata(from videoURL: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: videoURL)

        // Load required properties
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw ExtractionError.trackNotFound
        }

        let size = try await videoTrack.load(.naturalSize)
        let frameRate = try await videoTrack.load(.nominalFrameRate)

        let durationSeconds = CMTimeGetSeconds(duration)

        debugPrint("""
        📊 Video Metadata:
           Duration: \(String(format: "%.1f", durationSeconds))s
           Resolution: \(Int(size.width))x\(Int(size.height))
           Frame Rate: \(String(format: "%.1f", frameRate)) fps
        """)

        let fileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: videoURL.path),
           let fileSizeValue = attrs[.size] as? Int64 {
            fileSize = fileSizeValue
        } else {
            fileSize = 0
        }

        return VideoMetadata(
            duration: durationSeconds,
            resolution: size,
            frameRate: Double(frameRate),
            fileSize: fileSize
        )
    }

    /// Save frames to disk for debugging
    func saveFramesToDisk(frames: [VideoFrame], directory: URL) throws {
        let fileManager = FileManager.default

        // Create directory if needed
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        debugPrint("💾 Saving \(frames.count) frames to disk...")
        debugPrint("   Directory: \(directory.path)")

        for (index, frame) in frames.enumerated() {
            let filename = String(format: "frame_%04d_%.1fs.jpg", frame.frameNumber, frame.timestamp)
            let fileURL = directory.appendingPathComponent(filename)

            if let jpegData = frame.image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: fileURL)

                if index % 20 == 0 {
                    debugPrint("   Saved \(index + 1)/\(frames.count) frames...")
                }
            }
        }

        forcePrint("✅ All frames saved to disk")
    }
}

// MARK: - Supporting Types

struct VideoFrame {
    let image: UIImage
    let timestamp: Double // Time in seconds
    let frameNumber: Int

    var timestampFormatted: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        let milliseconds = Int((timestamp.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

struct VideoMetadata {
    let duration: TimeInterval
    let resolution: CGSize
    let frameRate: Double
    let fileSize: Int64

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var fileSizeFormatted: String {
        let mb = Double(fileSize) / 1_000_000.0
        return String(format: "%.1f MB", mb)
    }
}
