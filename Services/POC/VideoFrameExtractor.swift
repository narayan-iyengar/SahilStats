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
        print("🎬 Extracting frames from video...")
        print("   URL: \(videoURL.path)")
        print("   FPS: \(fps)")

        // Load video asset
        let asset = AVURLAsset(url: videoURL)

        // Get video duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        print("   Duration: \(String(format: "%.1f", durationSeconds))s")

        // Calculate frame interval
        let frameInterval = 1.0 / fps
        let totalFrames = Int(durationSeconds * fps)

        print("   Extracting ~\(totalFrames) frames (1 every \(String(format: "%.1f", frameInterval))s)")

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

        while currentTime < durationSeconds {
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            timePoints.append(cmTime)
            currentTime += frameInterval
        }

        print("   Time points generated: \(timePoints.count)")

        // Extract frames
        for (index, time) in timePoints.enumerated() {
            do {
                // Use async version for iOS 18+
                let cgImage: CGImage
                if #available(iOS 18.0, *) {
                    cgImage = try await imageGenerator.image(at: time).image
                } else {
                    #if compiler(>=6.0)
                    #warning("Using deprecated copyCGImage for iOS 17 compatibility")
                    #endif
                    cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                }
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
                    print("   Extracted \(extractedCount)/\(totalFrames) frames...")
                }

            } catch {
                print("   ⚠️ Failed to extract frame at \(String(format: "%.1f", CMTimeGetSeconds(time)))s: \(error)")
                // Continue with next frame
            }
        }

        print("✅ Frame extraction complete: \(frames.count) frames extracted")

        return frames
    }

    /// Extract a single frame at specific timestamp
    func extractFrame(from videoURL: URL, at timestamp: Double) async throws -> VideoFrame {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        let cgImage: CGImage
        if #available(iOS 18.0, *) {
            cgImage = try await imageGenerator.image(at: time).image
        } else {
            #if compiler(>=6.0)
            #warning("Using deprecated copyCGImage for iOS 17 compatibility")
            #endif
            cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        }
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

        print("""
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

        print("💾 Saving \(frames.count) frames to disk...")
        print("   Directory: \(directory.path)")

        for (index, frame) in frames.enumerated() {
            let filename = String(format: "frame_%04d_%.1fs.jpg", frame.frameNumber, frame.timestamp)
            let fileURL = directory.appendingPathComponent(filename)

            if let jpegData = frame.image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: fileURL)

                if index % 20 == 0 {
                    print("   Saved \(index + 1)/\(frames.count) frames...")
                }
            }
        }

        print("✅ All frames saved to disk")
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
