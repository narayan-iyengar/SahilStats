//
//  HardwareAcceleratedOverlayCompositor.swift
//  SahilStats
//
//  GPU-accelerated video overlay using Core Animation
//  This is the iOS-native way to add overlays to video
//

import AVFoundation
import UIKit
import CoreGraphics

class HardwareAcceleratedOverlayCompositor {

    /// Apply animated score overlay to video using Core Animation (GPU-accelerated)
    static func addAnimatedOverlay(
        to videoURL: URL,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        print("🎨 HardwareAcceleratedOverlayCompositor: Starting GPU-accelerated composition")
        print("   Video: \(videoURL.lastPathComponent)")
        print("   Timeline snapshots: \(scoreTimeline.count)")

        guard !scoreTimeline.isEmpty else {
            print("⚠️ Empty score timeline, returning original video")
            completion(.success(videoURL))
            return
        }

        // Load video asset asynchronously
        let asset = AVURLAsset(url: videoURL)

        Task {
            await processVideoAsync(asset: asset, scoreTimeline: scoreTimeline, videoURL: videoURL, completion: completion)
        }
    }

    private static func processVideoAsync(
        asset: AVURLAsset,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        do {
            // Load video tracks asynchronously
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = videoTracks.first else {
                print("❌ No video track found")
                completion(.failure(NSError(domain: "Compositor", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track"])))
                return
            }

            // Get video properties asynchronously
            let videoSize = try await videoTrack.load(.naturalSize)
            let videoDuration = try await asset.load(.duration)
            let transform = try await videoTrack.load(.preferredTransform)

            print("📹 Video properties:")
            print("   Size: \(videoSize.width)x\(videoSize.height)")
            print("   Duration: \(CMTimeGetSeconds(videoDuration))s")
            print("   Transform: \(transform)")

            // Create composition
            let composition = AVMutableComposition()

            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Failed to create composition video track")
                completion(.failure(NSError(domain: "Compositor", code: -2)))
                return
            }

            // Add video track to composition
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoDuration),
                of: videoTrack,
                at: .zero
            )
            print("✅ Video track added to composition")

            // Add audio track if present (using async API)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = audioTracks.first,
               let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                do {
                    try compositionAudioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: videoDuration),
                        of: audioTrack,
                        at: .zero
                    )
                    print("✅ Audio track added to composition")
                } catch {
                    print("⚠️ Failed to add audio: \(error)")
                }
            }

        // Calculate render size (accounting for transform)
        let renderSize = calculateRenderSize(naturalSize: videoSize, transform: transform)
        print("📐 Render size: \(renderSize.width)x\(renderSize.height)")

        // Create video composition with Core Animation layers
        let videoComposition = createVideoComposition(
            for: composition,
            videoTrack: compositionVideoTrack,
            renderSize: renderSize,
            scoreTimeline: scoreTimeline,
            videoDuration: videoDuration,
            transform: transform
        )

        // Export with GPU acceleration using modern iOS 18+ async API
        let outputURL = createOutputURL()

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("❌ Failed to create export session")
            completion(.failure(NSError(domain: "Compositor", code: -3)))
            return
        }

        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        print("🎬 Starting GPU-accelerated export...")
        print("   Output: \(outputURL.lastPathComponent)")

        do {
            try await exportSession.export(to: outputURL, as: .mov)

            print("✅ GPU-accelerated export completed successfully!")
            let fileExists = FileManager.default.fileExists(atPath: outputURL.path)
            print("   File exists: \(fileExists)")

            if fileExists {
                // Get file size
                if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
                   let fileSize = attrs[.size] as? Int64 {
                    print("   File size: \(Double(fileSize) / 1_000_000) MB")
                }
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Compositor", code: -4)))
                }
            }
        } catch {
            print("❌ Export failed: \(String(describing: error))")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }

        } catch {
            print("❌ Error during video processing: \(error)")
            completion(.failure(error))
        }
    }

    // MARK: - Core Animation Layer Creation

    private static func createVideoComposition(
        for composition: AVMutableComposition,
        videoTrack: AVMutableCompositionTrack,
        renderSize: CGSize,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDuration: CMTime,
        transform: CGAffineTransform
    ) -> AVVideoComposition {

        // Calculate correcting transform to fix orientation
        let angle = atan2(transform.b, transform.a)
        let degrees = angle * 180 / .pi
        print("📐 Applying transform correction for \(degrees)° rotation")

        let correctingTransform: CGAffineTransform
        if abs(degrees - 180) < 10 || abs(degrees + 180) < 10 {
            // 180° rotation - need to flip it back
            let tx = renderSize.width
            let ty = renderSize.height
            correctingTransform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: tx, ty: ty)
            print("📐 Applied 180° correcting transform")
        } else if abs(degrees - 90) < 10 {
            // 90° clockwise - correct to landscape
            let tx = renderSize.height
            correctingTransform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: tx)
            print("📐 Applied 90° correcting transform")
        } else if abs(degrees + 90) < 10 || abs(degrees - 270) < 10 {
            // 270° or -90° - correct to landscape
            let ty = renderSize.width
            correctingTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: ty, ty: 0)
            print("📐 Applied 270° correcting transform")
        } else {
            // 0° - no correction needed
            correctingTransform = .identity
            print("📐 No transform correction needed")
        }

        // Create layer instruction using modern configuration API
        var layerInstructionConfig = AVVideoCompositionLayerInstruction.Configuration(trackID: videoTrack.trackID)
        layerInstructionConfig.setTransform(correctingTransform, at: .zero)
        let layerInstruction = AVVideoCompositionLayerInstruction(configuration: layerInstructionConfig)

        // Create instruction using modern configuration API
        var instructionConfig = AVVideoCompositionInstruction.Configuration()
        instructionConfig.timeRange = CMTimeRange(start: .zero, duration: videoDuration)
        instructionConfig.layerInstructions = [layerInstruction]
        let instruction = AVVideoCompositionInstruction(configuration: instructionConfig)

        // Create Core Animation layers
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)

        // CRITICAL: Pass video duration in seconds for animations
        let videoDurationSeconds = CMTimeGetSeconds(videoDuration)
        print("📊 Video duration: \(videoDurationSeconds)s, Timeline duration: \(scoreTimeline.last?.timestamp ?? 0)s")

        // Create animated overlay layer with proper orientation
        let overlayLayer = createAnimatedOverlayLayer(
            size: renderSize,
            scoreTimeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds,
            videoTransform: transform
        )
        parentLayer.addSublayer(overlayLayer)

        // Create video composition using modern configuration API
        var compositionConfig = AVVideoComposition.Configuration()
        compositionConfig.renderSize = renderSize
        compositionConfig.frameDuration = CMTime(value: 1, timescale: 30) // 30fps
        compositionConfig.instructions = [instruction]
        compositionConfig.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        let videoComposition = AVVideoComposition(configuration: compositionConfig)

        print("✅ Core Animation layers created with GPU acceleration")

        return videoComposition
    }

    private static func createAnimatedOverlayLayer(
        size: CGSize,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval,
        videoTransform: CGAffineTransform
    ) -> CALayer {

        // Container for all overlay elements
        let overlayContainer = CALayer()
        overlayContainer.frame = CGRect(origin: .zero, size: size)

        // Since we're correcting the video transform in the layer instruction,
        // the overlay should always use normal (non-flipped) geometry
        overlayContainer.isGeometryFlipped = true  // AVFoundation coordinate system is flipped by default
        print("📐 Using standard AVFoundation geometry (flipped) for overlay")

        // **NEW BITMAP APPROACH**: Pre-render scoreboard images with glassmorphism
        print("🎨 Using bitmap-based overlay with glassmorphism effect")
        let bitmapLayers = createBitmapScoreboardLayers(
            size: size,
            scoreTimeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )

        for layer in bitmapLayers {
            overlayContainer.addSublayer(layer)
        }

        // End splash screen with final score
        let endSplashLayer = createEndSplashScreen(
            size: size,
            timeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )
        overlayContainer.addSublayer(endSplashLayer)

        print("✅ Created bitmap animated overlay with \(scoreTimeline.count) keyframes")

        return overlayContainer
    }

    // MARK: - Bitmap Scoreboard Rendering

    /// Create bitmap-based scoreboard layers with opacity animations
    /// This approach pre-renders each unique scoreboard state as an image
    /// Provides perfect glassmorphism effect matching the preview
    private static func createBitmapScoreboardLayers(
        size: CGSize,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval
    ) -> [CALayer] {

        // Build timeline events within video duration
        struct ScoreboardState: Hashable {
            let homeScore: Int
            let awayScore: Int
            let clockTime: String
            let quarter: Int
            let gameFormat: GameFormat
            let zoomLevel: CGFloat?

            init(snapshot: ScoreTimelineTracker.ScoreSnapshot) {
                self.homeScore = snapshot.homeScore
                self.awayScore = snapshot.awayScore
                self.clockTime = snapshot.clockTime
                self.quarter = snapshot.quarter
                self.gameFormat = snapshot.gameFormat
                self.zoomLevel = snapshot.zoomLevel  // Will add this to ScoreSnapshot
            }
        }

        struct TimelineEvent {
            let timestamp: TimeInterval
            let state: ScoreboardState
        }

        var events: [TimelineEvent] = []
        for snapshot in scoreTimeline {
            guard snapshot.timestamp <= videoDurationSeconds else {
                continue
            }
            events.append(TimelineEvent(
                timestamp: snapshot.timestamp,
                state: ScoreboardState(snapshot: snapshot)
            ))
        }

        guard !events.isEmpty else {
            print("⚠️ No scoreboard events within video duration")
            return []
        }

        // Find all unique states
        var uniqueStates = Set<ScoreboardState>()
        for event in events {
            uniqueStates.insert(event.state)
        }

        print("🎨 Bitmap overlay rendering:")
        print("   Video duration: \(videoDurationSeconds)s")
        print("   Unique scoreboard states: \(uniqueStates.count)")
        print("   Timeline events: \(events.count)")

        // Pre-render an image for each unique state
        var stateImages: [ScoreboardState: CGImage] = [:]

        for state in uniqueStates {
            // Find a snapshot with this state to get team names
            guard let matchingSnapshot = scoreTimeline.first(where: {
                let snapshotState = ScoreboardState(snapshot: $0)
                return snapshotState == state
            }) else { continue }

            let scoreboardData = ScoreboardData(
                homeTeam: matchingSnapshot.homeTeam,
                awayTeam: matchingSnapshot.awayTeam,
                homeScore: state.homeScore,
                awayScore: state.awayScore,
                clockTime: state.clockTime,
                quarter: state.quarter,
                gameFormat: state.gameFormat,
                zoomLevel: state.zoomLevel
            )

            if let image = ScoreboardRenderer.renderScoreboard(
                data: scoreboardData,
                size: size,
                isRecording: false
            )?.cgImage {
                stateImages[state] = image
            }
        }

        print("   ✅ Pre-rendered \(stateImages.count) bitmap images")

        // Create a layer for each unique state with opacity animation
        var layers: [CALayer] = []

        for state in uniqueStates {
            guard let cgImage = stateImages[state] else { continue }

            let imageLayer = CALayer()
            imageLayer.frame = CGRect(origin: .zero, size: size)
            imageLayer.contents = cgImage
            imageLayer.contentsGravity = .center

            // Build opacity animation: 1.0 when this state is active, 0.0 otherwise
            var opacityValues: [CGFloat] = []
            var keyTimes: [NSNumber] = []

            for event in events {
                let normalizedTime = event.timestamp / videoDurationSeconds
                let opacity: CGFloat = (event.state == state) ? 1.0 : 0.0

                opacityValues.append(opacity)
                keyTimes.append(NSNumber(value: normalizedTime))
            }

            // Ensure the final value stays until the end
            if let lastEvent = events.last, let lastTime = keyTimes.last?.doubleValue {
                if lastTime < 0.999 {
                    let finalOpacity: CGFloat = (lastEvent.state == state) ? 1.0 : 0.0
                    opacityValues.append(finalOpacity)
                    keyTimes.append(NSNumber(value: 1.0))
                }
            }

            // Create animation
            if !opacityValues.isEmpty {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = opacityValues
                animation.keyTimes = keyTimes
                animation.duration = videoDurationSeconds
                animation.calculationMode = .discrete
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards
                animation.beginTime = AVCoreAnimationBeginTimeAtZero

                imageLayer.opacity = Float(opacityValues.first ?? 0.0)
                imageLayer.add(animation, forKey: "opacityAnimation")
            }

            layers.append(imageLayer)
        }

        print("   ✅ Created \(layers.count) bitmap layers with opacity animations")

        return layers
    }

    // MARK: - Legacy Text-based Rendering (Keeping for reference, not used)

    private static func createAnimatedOverlayLayer_LEGACY(
        size: CGSize,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval,
        videoTransform: CGAffineTransform
    ) -> CALayer {

        // Container for all overlay elements
        let overlayContainer = CALayer()
        overlayContainer.frame = CGRect(origin: .zero, size: size)
        overlayContainer.isGeometryFlipped = true
        print("📐 Using legacy text-based overlay")

        // Scoreboard background
        let scoreboardLayer = createScoreboardBackground(size: size)
        overlayContainer.addSublayer(scoreboardLayer)

        // Get first snapshot for initial values
        let firstSnapshot = scoreTimeline.first!

        // Team name labels
        let homeTeamNameLayer = createTeamNameLabel(
            teamName: firstSnapshot.homeTeam,
            position: .home,
            size: size
        )
        overlayContainer.addSublayer(homeTeamNameLayer)

        let awayTeamNameLayer = createTeamNameLabel(
            teamName: firstSnapshot.awayTeam,
            position: .away,
            size: size
        )
        overlayContainer.addSublayer(awayTeamNameLayer)

        // Score labels with animations
        let homeScoreLayer = createAnimatedScoreLabel(
            initialValue: firstSnapshot.homeScore,
            position: .home,
            size: size,
            timeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )
        overlayContainer.addSublayer(homeScoreLayer)

        let awayScoreLayer = createAnimatedScoreLabel(
            initialValue: firstSnapshot.awayScore,
            position: .away,
            size: size,
            timeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )
        overlayContainer.addSublayer(awayScoreLayer)

        // Clock label with animation
        let clockLayer = createAnimatedClockLabel(
            size: size,
            timeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )
        overlayContainer.addSublayer(clockLayer)

        // Period label
        let periodLayer = createPeriodLabel(
            size: size,
            timeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )
        overlayContainer.addSublayer(periodLayer)

        // End splash screen with final score
        let endSplashLayer = createEndSplashScreen(
            size: size,
            timeline: scoreTimeline,
            videoDurationSeconds: videoDurationSeconds
        )
        overlayContainer.addSublayer(endSplashLayer)

        print("✅ Created animated overlay with \(scoreTimeline.count) keyframes")

        return overlayContainer
    }

    private static func createScoreboardBackground(size: CGSize) -> CALayer {
        let scaleFactor = size.height / 375.0

        let width: CGFloat = 246 * scaleFactor  // Original width
        let height: CGFloat = 56 * scaleFactor  // Original height
        let x = (size.width - width) / 2
        let y = size.height - height - (40 * scaleFactor)

        let layer = CALayer()
        layer.frame = CGRect(x: x, y: y, width: width, height: height)
        // Darker background for better visibility (increased from 0.75 to 0.85)
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.85).cgColor
        layer.cornerRadius = 14 * scaleFactor
        layer.borderWidth = 1
        // Brighter border for better contrast
        layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor

        return layer
    }

    enum ScorePosition {
        case home, away
    }

    private static func createTeamNameLabel(
        teamName: String,
        position: ScorePosition,
        size: CGSize
    ) -> CATextLayer {

        let scaleFactor = size.height / 375.0
        let scoreboardWidth: CGFloat = 246 * scaleFactor  // ORIGINAL width
        let scoreboardHeight: CGFloat = 56 * scaleFactor  // ORIGINAL height
        let scoreboardX = (size.width - scoreboardWidth) / 2
        let scoreboardY = size.height - scoreboardHeight - (40 * scaleFactor)

        let columnWidth: CGFloat = 50 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor  // ORIGINAL padding

        let x: CGFloat
        if position == .home {
            x = scoreboardX + padding
        } else {
            x = scoreboardX + scoreboardWidth - columnWidth - padding
        }

        let layer = CATextLayer()
        layer.frame = CGRect(
            x: x,
            y: scoreboardY + 4 * scaleFactor,
            width: columnWidth,
            height: 14 * scaleFactor
        )
        layer.string = teamName.uppercased()
        layer.fontSize = 8 * scaleFactor
        layer.font = UIFont.systemFont(ofSize: 8 * scaleFactor, weight: .semibold)
        // Increased opacity from 0.6 to 0.9 for better visibility
        layer.foregroundColor = UIColor.white.withAlphaComponent(0.9).cgColor
        layer.alignmentMode = .center
        layer.contentsScale = 3.0  // Fixed scale for high-quality video rendering

        return layer
    }

    private static func createAnimatedScoreLabel(
        initialValue: Int,
        position: ScorePosition,
        size: CGSize,
        timeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval
    ) -> CALayer {

        let scaleFactor = size.height / 375.0
        let scoreboardWidth: CGFloat = 246 * scaleFactor  // ORIGINAL width
        let scoreboardHeight: CGFloat = 56 * scaleFactor  // ORIGINAL height
        let scoreboardX = (size.width - scoreboardWidth) / 2
        let scoreboardY = size.height - scoreboardHeight - (40 * scaleFactor)

        let columnWidth: CGFloat = 50 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor  // ORIGINAL padding

        let x: CGFloat
        if position == .home {
            x = scoreboardX + padding
        } else {
            x = scoreboardX + scoreboardWidth - columnWidth - padding
        }

        let frame = CGRect(
            x: x,
            y: scoreboardY + 22 * scaleFactor,
            width: columnWidth,
            height: 30 * scaleFactor
        )

        // Container layer for all score layers
        let containerLayer = CALayer()
        containerLayer.frame = frame

        // Build timeline events within video duration
        struct ScoreEvent {
            let timestamp: TimeInterval
            let value: Int
        }

        var events: [ScoreEvent] = []
        for snapshot in timeline {
            guard snapshot.timestamp <= videoDurationSeconds else {
                continue
            }
            let value = position == .home ? snapshot.homeScore : snapshot.awayScore
            events.append(ScoreEvent(timestamp: snapshot.timestamp, value: value))
        }

        guard !events.isEmpty else {
            print("⚠️ No score events within video duration")
            let layer = CATextLayer()
            layer.frame = CGRect(origin: .zero, size: frame.size)
            layer.string = "\(initialValue)"
            layer.fontSize = 20 * scaleFactor
            layer.font = UIFont.boldSystemFont(ofSize: 20 * scaleFactor)
            layer.foregroundColor = UIColor.white.cgColor
            layer.alignmentMode = .center
            layer.contentsScale = 3.0  // Fixed scale for high-quality video rendering
            return layer
        }

        // Create a text layer for each unique score value with opacity animation
        var uniqueScores = Set<Int>()
        for event in events {
            uniqueScores.insert(event.value)
        }

        print("🎬 Score animation for \(position == .home ? "HOME" : "AWAY") (opacity-based):")
        print("   Video duration: \(videoDurationSeconds)s")
        print("   Unique scores: \(uniqueScores.sorted())")
        print("   Timeline events: \(events.count)")

        // For each unique score, create a layer with opacity animation
        for score in uniqueScores.sorted() {
            let textLayer = CATextLayer()
            textLayer.frame = CGRect(origin: .zero, size: frame.size)
            textLayer.string = "\(score)"
            textLayer.fontSize = 20 * scaleFactor
            textLayer.font = UIFont.boldSystemFont(ofSize: 20 * scaleFactor)
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = 3.0  // Fixed scale for high-quality video rendering

            // Build opacity animation: 1.0 when this score is active, 0.0 otherwise
            var opacityValues: [CGFloat] = []
            var keyTimes: [NSNumber] = []

            // Process each event and set opacity based on whether this score matches
            for event in events {
                let normalizedTime = event.timestamp / videoDurationSeconds
                let opacity: CGFloat = (event.value == score) ? 1.0 : 0.0

                opacityValues.append(opacity)
                keyTimes.append(NSNumber(value: normalizedTime))
            }

            // Ensure the final value stays until the end
            if let lastEvent = events.last, let lastTime = keyTimes.last?.doubleValue {
                if lastTime < 0.999 {
                    let finalOpacity: CGFloat = (lastEvent.value == score) ? 1.0 : 0.0
                    opacityValues.append(finalOpacity)
                    keyTimes.append(NSNumber(value: 1.0))
                }
            }

            // Only create animation if we have keyframes
            if !opacityValues.isEmpty {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = opacityValues
                animation.keyTimes = keyTimes
                animation.duration = videoDurationSeconds
                animation.calculationMode = .discrete
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards
                animation.beginTime = AVCoreAnimationBeginTimeAtZero

                // Set initial opacity
                textLayer.opacity = Float(opacityValues.first ?? 0.0)
                textLayer.add(animation, forKey: "opacityAnimation")

                print("   Score \(score): \(keyTimes.count) keyframes")
            } else {
                // No keyframes - should never happen
                textLayer.opacity = 0.0
            }

            containerLayer.addSublayer(textLayer)
        }

        print("   ✅ Created \(uniqueScores.count) layers with opacity animations")

        return containerLayer
    }

    private static func createAnimatedClockLabel(
        size: CGSize,
        timeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval
    ) -> CALayer {

        let scaleFactor = size.height / 375.0
        let scoreboardWidth: CGFloat = 246 * scaleFactor  // Original width
        let scoreboardHeight: CGFloat = 56 * scaleFactor  // Original height
        let scoreboardX = (size.width - scoreboardWidth) / 2
        let scoreboardY = size.height - scoreboardHeight - (40 * scaleFactor)

        let centerWidth: CGFloat = 70 * scaleFactor
        let columnWidth: CGFloat = 50 * scaleFactor
        let spacing: CGFloat = 12 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor

        let x = scoreboardX + padding + columnWidth + spacing

        let frame = CGRect(
            x: x,
            y: scoreboardY + 22 * scaleFactor,
            width: centerWidth,
            height: 24 * scaleFactor
        )

        // Container layer for all clock layers
        let containerLayer = CALayer()
        containerLayer.frame = frame

        // Build timeline events within video duration
        struct ClockEvent {
            let timestamp: TimeInterval
            let clockTime: String
        }

        var events: [ClockEvent] = []
        for snapshot in timeline {
            guard snapshot.timestamp <= videoDurationSeconds else {
                continue
            }
            events.append(ClockEvent(timestamp: snapshot.timestamp, clockTime: snapshot.clockTime))
        }

        guard !events.isEmpty else {
            print("⚠️ No clock events within video duration")
            let layer = CATextLayer()
            layer.frame = CGRect(origin: .zero, size: frame.size)
            layer.string = timeline.first?.clockTime ?? "20:00"
            layer.fontSize = 16 * scaleFactor
            layer.font = UIFont.boldSystemFont(ofSize: 16 * scaleFactor)
            layer.foregroundColor = UIColor.white.cgColor
            layer.alignmentMode = .center
            layer.contentsScale = 3.0  // Fixed scale for high-quality video rendering
            return layer
        }

        // Create a text layer for each unique clock time with opacity animation
        var uniqueTimes = [String]()  // Use array to preserve order
        var timeSet = Set<String>()
        for event in events {
            if !timeSet.contains(event.clockTime) {
                uniqueTimes.append(event.clockTime)
                timeSet.insert(event.clockTime)
            }
        }

        print("🎬 Clock animation (opacity-based):")
        print("   Video duration: \(videoDurationSeconds)s")
        print("   Unique times: \(uniqueTimes.count)")
        print("   Timeline events: \(events.count)")

        // For each unique clock time, create a layer with opacity animation
        for clockTime in uniqueTimes {
            let textLayer = CATextLayer()
            textLayer.frame = CGRect(origin: .zero, size: frame.size)
            textLayer.string = clockTime
            textLayer.fontSize = 16 * scaleFactor
            textLayer.font = UIFont.boldSystemFont(ofSize: 16 * scaleFactor)
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = 3.0  // Fixed scale for high-quality video rendering

            // Build opacity animation: 1.0 when this time is active, 0.0 otherwise
            var opacityValues: [CGFloat] = []
            var keyTimes: [NSNumber] = []

            // Process each event and set opacity based on whether this time matches
            for event in events {
                let normalizedTime = event.timestamp / videoDurationSeconds
                let opacity: CGFloat = (event.clockTime == clockTime) ? 1.0 : 0.0

                opacityValues.append(opacity)
                keyTimes.append(NSNumber(value: normalizedTime))
            }

            // Ensure the final value stays until the end
            if let lastEvent = events.last, let lastTime = keyTimes.last?.doubleValue {
                if lastTime < 0.999 {
                    let finalOpacity: CGFloat = (lastEvent.clockTime == clockTime) ? 1.0 : 0.0
                    opacityValues.append(finalOpacity)
                    keyTimes.append(NSNumber(value: 1.0))
                }
            }

            // Only create animation if we have keyframes
            if !opacityValues.isEmpty {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = opacityValues
                animation.keyTimes = keyTimes
                animation.duration = videoDurationSeconds
                animation.calculationMode = .discrete
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards
                animation.beginTime = AVCoreAnimationBeginTimeAtZero

                // Set initial opacity
                textLayer.opacity = Float(opacityValues.first ?? 0.0)
                textLayer.add(animation, forKey: "opacityAnimation")
            } else {
                // No keyframes - should never happen
                textLayer.opacity = 0.0
            }

            containerLayer.addSublayer(textLayer)
        }

        print("   ✅ Created \(uniqueTimes.count) clock layers with opacity animations")

        return containerLayer
    }

    private static func createPeriodLabel(
        size: CGSize,
        timeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval
    ) -> CALayer {

        let scaleFactor = size.height / 375.0
        let scoreboardWidth: CGFloat = 246 * scaleFactor  // Original width
        let scoreboardHeight: CGFloat = 56 * scaleFactor  // Original height
        let scoreboardX = (size.width - scoreboardWidth) / 2
        let scoreboardY = size.height - scoreboardHeight - (40 * scaleFactor)

        let centerWidth: CGFloat = 70 * scaleFactor
        let columnWidth: CGFloat = 50 * scaleFactor
        let spacing: CGFloat = 12 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor

        let x = scoreboardX + padding + columnWidth + spacing

        let frame = CGRect(
            x: x,
            y: scoreboardY + 8 * scaleFactor,
            width: centerWidth,
            height: 14 * scaleFactor
        )

        // Container layer for all period layers
        let containerLayer = CALayer()
        containerLayer.frame = frame

        // Build timeline events within video duration
        struct PeriodEvent {
            let timestamp: TimeInterval
            let periodText: String
        }

        var events: [PeriodEvent] = []
        for snapshot in timeline {
            guard snapshot.timestamp <= videoDurationSeconds else {
                continue
            }
            let text = formatPeriod(quarter: snapshot.quarter, gameFormat: snapshot.gameFormat)
            events.append(PeriodEvent(timestamp: snapshot.timestamp, periodText: text))
        }

        guard !events.isEmpty else {
            print("⚠️ No period events within video duration")
            let layer = CATextLayer()
            layer.frame = CGRect(origin: .zero, size: frame.size)
            let firstSnapshot = timeline.first!
            let periodText = formatPeriod(quarter: firstSnapshot.quarter, gameFormat: firstSnapshot.gameFormat)
            layer.string = periodText
            layer.fontSize = 9 * scaleFactor
            layer.font = UIFont.systemFont(ofSize: 9 * scaleFactor, weight: .semibold)
            layer.foregroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95).cgColor
            layer.alignmentMode = .center
            layer.contentsScale = 3.0  // Fixed scale for high-quality video rendering
            return layer
        }

        // Create a text layer for each unique period with opacity animation
        var uniquePeriods = [String]()  // Use array to preserve order
        var periodSet = Set<String>()
        for event in events {
            if !periodSet.contains(event.periodText) {
                uniquePeriods.append(event.periodText)
                periodSet.insert(event.periodText)
            }
        }

        print("🎬 Period animation (opacity-based):")
        print("   Video duration: \(videoDurationSeconds)s")
        print("   Unique periods: \(uniquePeriods)")
        print("   Timeline events: \(events.count)")

        // For each unique period, create a layer with opacity animation
        for periodText in uniquePeriods {
            let textLayer = CATextLayer()
            textLayer.frame = CGRect(origin: .zero, size: frame.size)
            textLayer.string = periodText
            textLayer.fontSize = 9 * scaleFactor
            textLayer.font = UIFont.systemFont(ofSize: 9 * scaleFactor, weight: .semibold)
            textLayer.foregroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95).cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = 3.0  // Fixed scale for high-quality video rendering

            // Build opacity animation: 1.0 when this period is active, 0.0 otherwise
            var opacityValues: [CGFloat] = []
            var keyTimes: [NSNumber] = []

            // Process each event and set opacity based on whether this period matches
            for event in events {
                let normalizedTime = event.timestamp / videoDurationSeconds
                let opacity: CGFloat = (event.periodText == periodText) ? 1.0 : 0.0

                opacityValues.append(opacity)
                keyTimes.append(NSNumber(value: normalizedTime))
            }

            // Ensure the final value stays until the end
            if let lastEvent = events.last, let lastTime = keyTimes.last?.doubleValue {
                if lastTime < 0.999 {
                    let finalOpacity: CGFloat = (lastEvent.periodText == periodText) ? 1.0 : 0.0
                    opacityValues.append(finalOpacity)
                    keyTimes.append(NSNumber(value: 1.0))
                }
            }

            // Only create animation if we have keyframes
            if !opacityValues.isEmpty {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = opacityValues
                animation.keyTimes = keyTimes
                animation.duration = videoDurationSeconds
                animation.calculationMode = .discrete
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards
                animation.beginTime = AVCoreAnimationBeginTimeAtZero

                // Set initial opacity
                textLayer.opacity = Float(opacityValues.first ?? 0.0)
                textLayer.add(animation, forKey: "opacityAnimation")
            } else {
                // No keyframes - should never happen
                textLayer.opacity = 0.0
            }

            containerLayer.addSublayer(textLayer)
        }

        print("   ✅ Created \(uniquePeriods.count) period layers with opacity animations")

        return containerLayer
    }

    private static func createEndSplashScreen(
        size: CGSize,
        timeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDurationSeconds: TimeInterval
    ) -> CALayer {

        // Container for the entire splash screen
        let splashContainer = CALayer()
        splashContainer.frame = CGRect(origin: .zero, size: size)

        // Get final score from last snapshot
        guard let finalSnapshot = timeline.last else {
            print("⚠️ No final snapshot for end splash")
            return splashContainer
        }

        // Find when game actually ends (last event within video duration)
        let eventsWithinVideo = timeline.filter { $0.timestamp <= videoDurationSeconds }
        guard let lastEvent = eventsWithinVideo.last else {
            print("⚠️ No events within video duration for end splash")
            return splashContainer
        }

        // Show splash if there's at least 0.5 seconds after the last event
        // This gives enough time for a quick fade-in
        let timeAfterLastEvent = videoDurationSeconds - lastEvent.timestamp
        let minimumSplashTime: TimeInterval = 0.5

        guard timeAfterLastEvent >= minimumSplashTime else {
            print("⏭️ Skipping end splash - not enough time after last event")
            print("   Last event: \(String(format: "%.1f", lastEvent.timestamp))s")
            print("   Video duration: \(String(format: "%.1f", videoDurationSeconds))s")
            print("   Time remaining: \(String(format: "%.1f", timeAfterLastEvent))s (need \(minimumSplashTime)s)")
            return splashContainer
        }

        let scaleFactor = size.height / 375.0

        // Semi-transparent black background
        let backgroundLayer = CALayer()
        backgroundLayer.frame = CGRect(origin: .zero, size: size)
        backgroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.85).cgColor
        splashContainer.addSublayer(backgroundLayer)

        // "FINAL" text at top
        let finalLabel = CATextLayer()
        finalLabel.frame = CGRect(
            x: 0,
            y: size.height * 0.25,
            width: size.width,
            height: 40 * scaleFactor
        )
        finalLabel.string = "FINAL"
        finalLabel.fontSize = 28 * scaleFactor
        finalLabel.font = UIFont.systemFont(ofSize: 28 * scaleFactor, weight: .bold)
        finalLabel.foregroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0).cgColor
        finalLabel.alignmentMode = .center
        finalLabel.contentsScale = 3.0  // Fixed scale for high-quality video rendering
        splashContainer.addSublayer(finalLabel)

        // Home team (left side)
        let homeTeamLabel = CATextLayer()
        homeTeamLabel.frame = CGRect(
            x: size.width * 0.15,
            y: size.height * 0.40,
            width: size.width * 0.30,
            height: 30 * scaleFactor
        )
        homeTeamLabel.string = finalSnapshot.homeTeam.uppercased()
        homeTeamLabel.fontSize = 18 * scaleFactor
        homeTeamLabel.font = UIFont.systemFont(ofSize: 18 * scaleFactor, weight: .semibold)
        homeTeamLabel.foregroundColor = UIColor.white.cgColor
        homeTeamLabel.alignmentMode = .center
        homeTeamLabel.contentsScale = 3.0  // Fixed scale for high-quality video rendering
        splashContainer.addSublayer(homeTeamLabel)

        // Home score
        let homeScoreLabel = CATextLayer()
        homeScoreLabel.frame = CGRect(
            x: size.width * 0.15,
            y: size.height * 0.48,
            width: size.width * 0.30,
            height: 60 * scaleFactor
        )
        homeScoreLabel.string = "\(finalSnapshot.homeScore)"
        homeScoreLabel.fontSize = 48 * scaleFactor
        homeScoreLabel.font = UIFont.boldSystemFont(ofSize: 48 * scaleFactor)
        homeScoreLabel.foregroundColor = UIColor.white.cgColor
        homeScoreLabel.alignmentMode = .center
        homeScoreLabel.contentsScale = 3.0  // Fixed scale for high-quality video rendering
        splashContainer.addSublayer(homeScoreLabel)

        // Hyphen separator
        let separatorLabel = CATextLayer()
        separatorLabel.frame = CGRect(
            x: size.width * 0.45,
            y: size.height * 0.48,
            width: size.width * 0.10,
            height: 60 * scaleFactor
        )
        separatorLabel.string = "-"
        separatorLabel.fontSize = 48 * scaleFactor
        separatorLabel.font = UIFont.boldSystemFont(ofSize: 48 * scaleFactor)
        separatorLabel.foregroundColor = UIColor.white.withAlphaComponent(0.5).cgColor
        separatorLabel.alignmentMode = .center
        separatorLabel.contentsScale = 3.0  // Fixed scale for high-quality video rendering
        splashContainer.addSublayer(separatorLabel)

        // Away team (right side)
        let awayTeamLabel = CATextLayer()
        awayTeamLabel.frame = CGRect(
            x: size.width * 0.55,
            y: size.height * 0.40,
            width: size.width * 0.30,
            height: 30 * scaleFactor
        )
        awayTeamLabel.string = finalSnapshot.awayTeam.uppercased()
        awayTeamLabel.fontSize = 18 * scaleFactor
        awayTeamLabel.font = UIFont.systemFont(ofSize: 18 * scaleFactor, weight: .semibold)
        awayTeamLabel.foregroundColor = UIColor.white.cgColor
        awayTeamLabel.alignmentMode = .center
        awayTeamLabel.contentsScale = 3.0  // Fixed scale for high-quality video rendering
        splashContainer.addSublayer(awayTeamLabel)

        // Away score
        let awayScoreLabel = CATextLayer()
        awayScoreLabel.frame = CGRect(
            x: size.width * 0.55,
            y: size.height * 0.48,
            width: size.width * 0.30,
            height: 60 * scaleFactor
        )
        awayScoreLabel.string = "\(finalSnapshot.awayScore)"
        awayScoreLabel.fontSize = 48 * scaleFactor
        awayScoreLabel.font = UIFont.boldSystemFont(ofSize: 48 * scaleFactor)
        awayScoreLabel.foregroundColor = UIColor.white.cgColor
        awayScoreLabel.alignmentMode = .center
        awayScoreLabel.contentsScale = 3.0  // Fixed scale for high-quality video rendering
        splashContainer.addSublayer(awayScoreLabel)

        // Fade in very quickly after the last game event
        // Start fade 0.1s after last event, fade for 0.3s, stay visible until end
        let fadeDelay: TimeInterval = 0.1
        let fadeDuration: TimeInterval = 0.3
        let fadeStartTime = lastEvent.timestamp + fadeDelay
        let fadeEndTime = min(fadeStartTime + fadeDuration, videoDurationSeconds)

        // Create opacity animation that fades from 0 to 1 after the last event
        let animation = CAKeyframeAnimation(keyPath: "opacity")

        let normalizedFadeStart = fadeStartTime / videoDurationSeconds
        let normalizedFadeEnd = fadeEndTime / videoDurationSeconds

        animation.values = [0.0, 0.0, 1.0, 1.0]  // Hidden, hidden, fade in, stay visible
        animation.keyTimes = [
            0.0,  // Start of video
            NSNumber(value: normalizedFadeStart),  // Stay hidden until after last event
            NSNumber(value: normalizedFadeEnd),    // Fully visible after fade
            1.0   // Stay visible until end
        ]
        animation.duration = videoDurationSeconds
        animation.calculationMode = .linear
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.beginTime = AVCoreAnimationBeginTimeAtZero

        splashContainer.opacity = 0.0
        splashContainer.add(animation, forKey: "splashFadeIn")

        print("🎬 Created end splash screen")
        print("   Last event at: \(String(format: "%.1f", lastEvent.timestamp))s")
        print("   Fade starts at: \(String(format: "%.1f", fadeStartTime))s")
        print("   Fully visible at: \(String(format: "%.1f", fadeEndTime))s")

        return splashContainer
    }

    // MARK: - Helper Methods

    private static func formatPeriod(quarter: Int, gameFormat: GameFormat) -> String {
        let periodName = gameFormat == .halves ? "HALF" : "QTR"
        let ordinal = getOrdinalSuffix(quarter)
        return "\(quarter)\(ordinal) \(periodName)"
    }

    private static func getOrdinalSuffix(_ number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100

        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "th"
        }

        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private static func calculateRenderSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        // Check if video is rotated 90° or 270°
        let angle = atan2(transform.b, transform.a)
        let isRotated = abs(angle - .pi / 2) < 0.1 || abs(angle + .pi / 2) < 0.1

        if isRotated {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            return naturalSize
        }
    }

    private static func createOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "composited_\(Date().timeIntervalSince1970).mov"
        return documentsPath.appendingPathComponent(filename)
    }
}
