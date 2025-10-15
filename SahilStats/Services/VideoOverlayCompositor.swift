//
//  VideoOverlayCompositor.swift
//  SahilStats
//
//  Composites score overlay onto recorded video with time-based animations
//

import AVFoundation
import UIKit
import CoreGraphics

class VideoOverlayCompositor {

    /// Adds time-based overlay to video that changes as scores update
    static func addTimeBasedOverlayToVideo(
        videoURL: URL,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        print("🎨 VideoOverlayCompositor: Starting time-based overlay composition")
        print("   Input: \(videoURL.lastPathComponent)")
        print("   Timeline snapshots: \(scoreTimeline.count)")

        let asset = AVURLAsset(url: videoURL)

        // Use Task for async track loading
        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = tracks.first else {
                    print("❌ No video track found")
                    completion(.failure(NSError(domain: "VideoOverlayCompositor", code: 1,
                                               userInfo: [NSLocalizedDescriptionKey: "No video track found"])))
                    return
                }

                await processVideo(asset: asset, videoTrack: videoTrack, scoreTimeline: scoreTimeline, videoURL: videoURL, completion: completion)
            } catch {
                print("❌ Error loading video track: \(error)")
                completion(.failure(error))
            }
        }
    }

    private static func processVideo(
        asset: AVURLAsset,
        videoTrack: AVAssetTrack,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        let composition = AVMutableComposition()

        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("❌ Could not create video track")
            completion(.failure(NSError(domain: "VideoOverlayCompositor", code: 2,
                                       userInfo: [NSLocalizedDescriptionKey: "Could not create video track"])))
            return
        }

        // Add audio track if exists
        var compositionAudioTrack: AVMutableCompositionTrack?

        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if audioTracks.first != nil {
                compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
            }

            let duration = try await asset.load(.duration)
            _ = try await videoTrack.load(.timeRange)
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: videoTrack,
                at: .zero
            )

            if let audioTrack = audioTracks.first,
               let compAudioTrack = compositionAudioTrack {
                try await audioTrack.load(.timeRange)
                try compAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: audioTrack,
                    at: .zero
                )
            }

            print("✅ Tracks added to composition")

        } catch {
            print("❌ Error adding tracks: \(error)")
            completion(.failure(error))
            return
        }

        // Create animated overlay layer
        let videoSize: CGSize
        let duration: CMTime
        do {
            videoSize = try await videoTrack.load(.naturalSize)
            duration = try await asset.load(.duration)
        } catch {
            print("❌ Error loading video properties: \(error)")
            completion(.failure(error))
            return
        }

        let videoDuration = CMTimeGetSeconds(duration)
        let overlayLayer = createAnimatedOverlayLayer(
            for: videoSize,
            scoreTimeline: scoreTimeline,
            videoDuration: videoDuration
        )

        // Create parent layer
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)

        // Create video layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)

        // Add layers
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        // Create layer instruction using modern configuration API
        let layerInstructionConfig = AVVideoCompositionLayerInstruction.Configuration(trackID: compositionVideoTrack.trackID)
        let layerInstruction = AVVideoCompositionLayerInstruction(configuration: layerInstructionConfig)

        // Create instruction using modern configuration API
        var instructionConfig = AVVideoCompositionInstruction.Configuration()
        instructionConfig.timeRange = CMTimeRange(start: .zero, duration: duration)
        instructionConfig.layerInstructions = [layerInstruction]
        let instruction = AVVideoCompositionInstruction(configuration: instructionConfig)

        // Create video composition using modern configuration API
        var compositionConfig = AVVideoComposition.Configuration()
        compositionConfig.renderSize = videoSize
        compositionConfig.frameDuration = CMTime(value: 1, timescale: 30)
        compositionConfig.instructions = [instruction]
        compositionConfig.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        let videoComposition = AVVideoComposition(configuration: compositionConfig)

        // Export using modern iOS 18+ async API
        let outputURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent("overlay_\(Date().timeIntervalSince1970).mov")

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("❌ Could not create export session")
            completion(.failure(NSError(domain: "VideoOverlayCompositor", code: 3,
                                       userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])))
            return
        }

        exporter.outputFileType = .mov
        exporter.videoComposition = videoComposition

        print("📤 Exporting video with animated overlay to: \(outputURL.lastPathComponent)")

        do {
            try await exporter.export(to: outputURL, as: .mov)

            print("✅ Video export completed successfully")

            // Delete original video to save space
            try? FileManager.default.removeItem(at: videoURL)
            print("🗑️ Deleted original video (without overlay)")

            DispatchQueue.main.async {
                completion(.success(outputURL))
            }
        } catch {
            print("❌ Export failed: \(String(describing: error))")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Animated Overlay Creation

    private static func createAnimatedOverlayLayer(
        for videoSize: CGSize,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDuration: TimeInterval
    ) -> CALayer {
        print("🎨 Creating animated overlay layer for video size: \(videoSize)")
        print("   Video duration: \(String(format: "%.1f", videoDuration))s")

        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: videoSize)

        // Determine if landscape based on video size
        let isLandscape = videoSize.width > videoSize.height

        guard isLandscape else {
            print("⚠️ Portrait video - no overlay added")
            return overlayLayer
        }

        // Scale factor for text size based on video resolution
        let scaleFactor = min(videoSize.width, videoSize.height) / 375.0

        // Compact scoreboard (matching SwiftUI SimpleScoreOverlay design)
        let scoreboardWidth: CGFloat = 246 * scaleFactor  // HStack spacing + content
        let scoreboardHeight: CGFloat = 56 * scaleFactor

        // Position at bottom center (matching SwiftUI .padding(.bottom, 40))
        let scoreboardContainer = CALayer()
        scoreboardContainer.frame = CGRect(
            x: (videoSize.width - scoreboardWidth) / 2,
            y: videoSize.height - scoreboardHeight - (40 * scaleFactor),
            width: scoreboardWidth,
            height: scoreboardHeight
        )

        // Semi-transparent background with blur effect (matching .ultraThinMaterial)
        let backgroundLayer = CALayer()
        backgroundLayer.frame = scoreboardContainer.bounds
        backgroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        backgroundLayer.cornerRadius = 14 * scaleFactor
        backgroundLayer.borderWidth = 1
        backgroundLayer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        scoreboardContainer.addSublayer(backgroundLayer)

        // Shadow (matching SwiftUI shadow)
        scoreboardContainer.shadowColor = UIColor.black.cgColor
        scoreboardContainer.shadowOpacity = 0.3
        scoreboardContainer.shadowRadius = 10 * scaleFactor
        scoreboardContainer.shadowOffset = CGSize(width: 0, height: 2 * scaleFactor)

        // Create text layers for each component that will be animated
        // Layout: [HomeTeam | Separator | Clock/Period | Separator | AwayTeam]

        let columnWidth: CGFloat = 50 * scaleFactor
        let centerWidth: CGFloat = 70 * scaleFactor
        let separatorWidth: CGFloat = 1
        let spacing: CGFloat = 12 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor

        var xOffset = padding

        // Home team section
        let homeTeamNameLayer = createTextLayer(
            text: "",  // Will be set by animation
            fontSize: 10 * scaleFactor,
            color: UIColor.white.withAlphaComponent(0.9),
            weight: .semibold
        )
        homeTeamNameLayer.frame = CGRect(
            x: xOffset,
            y: 8 * scaleFactor,
            width: columnWidth,
            height: 12 * scaleFactor
        )
        homeTeamNameLayer.alignmentMode = .center
        scoreboardContainer.addSublayer(homeTeamNameLayer)

        let homeScoreLayer = createTextLayer(
            text: "",  // Will be set by animation
            fontSize: 20 * scaleFactor,
            color: .white,
            weight: .bold
        )
        homeScoreLayer.frame = CGRect(
            x: xOffset,
            y: 22 * scaleFactor,
            width: columnWidth,
            height: 24 * scaleFactor
        )
        homeScoreLayer.alignmentMode = .center
        scoreboardContainer.addSublayer(homeScoreLayer)

        xOffset += columnWidth + spacing

        // First separator
        let separator1 = CALayer()
        separator1.frame = CGRect(
            x: xOffset - spacing / 2,
            y: 13 * scaleFactor,
            width: separatorWidth,
            height: 30 * scaleFactor
        )
        separator1.backgroundColor = UIColor.white.withAlphaComponent(0.2).cgColor
        scoreboardContainer.addSublayer(separator1)

        // Center section (clock & period)
        let periodLayer = createTextLayer(
            text: "",  // Will be set by animation
            fontSize: 9 * scaleFactor,
            color: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95),  // Orange
            weight: .semibold
        )
        periodLayer.frame = CGRect(
            x: xOffset,
            y: 8 * scaleFactor,
            width: centerWidth,
            height: 11 * scaleFactor
        )
        periodLayer.alignmentMode = .center
        scoreboardContainer.addSublayer(periodLayer)

        let clockLayer = createTextLayer(
            text: "",  // Will be set by animation
            fontSize: 16 * scaleFactor,
            color: .white,
            weight: .bold
        )
        clockLayer.frame = CGRect(
            x: xOffset,
            y: 22 * scaleFactor,
            width: centerWidth,
            height: 20 * scaleFactor
        )
        clockLayer.alignmentMode = .center
        scoreboardContainer.addSublayer(clockLayer)

        xOffset += centerWidth + spacing

        // Second separator
        let separator2 = CALayer()
        separator2.frame = CGRect(
            x: xOffset - spacing / 2,
            y: 13 * scaleFactor,
            width: separatorWidth,
            height: 30 * scaleFactor
        )
        separator2.backgroundColor = UIColor.white.withAlphaComponent(0.2).cgColor
        scoreboardContainer.addSublayer(separator2)

        // Away team section
        let awayTeamNameLayer = createTextLayer(
            text: "",  // Will be set by animation
            fontSize: 10 * scaleFactor,
            color: UIColor.white.withAlphaComponent(0.9),
            weight: .semibold
        )
        awayTeamNameLayer.frame = CGRect(
            x: xOffset,
            y: 8 * scaleFactor,
            width: columnWidth,
            height: 12 * scaleFactor
        )
        awayTeamNameLayer.alignmentMode = .center
        scoreboardContainer.addSublayer(awayTeamNameLayer)

        let awayScoreLayer = createTextLayer(
            text: "",  // Will be set by animation
            fontSize: 20 * scaleFactor,
            color: .white,
            weight: .bold
        )
        awayScoreLayer.frame = CGRect(
            x: xOffset,
            y: 22 * scaleFactor,
            width: columnWidth,
            height: 24 * scaleFactor
        )
        awayScoreLayer.alignmentMode = .center
        scoreboardContainer.addSublayer(awayScoreLayer)

        // Add animations for score changes
        addScoreAnimations(
            homeTeamNameLayer: homeTeamNameLayer,
            homeScoreLayer: homeScoreLayer,
            awayTeamNameLayer: awayTeamNameLayer,
            awayScoreLayer: awayScoreLayer,
            periodLayer: periodLayer,
            clockLayer: clockLayer,
            scoreTimeline: scoreTimeline,
            videoDuration: videoDuration
        )

        overlayLayer.addSublayer(scoreboardContainer)

        print("✅ Animated overlay layer created successfully")
        return overlayLayer
    }

    // MARK: - Score Animations

    private static func addScoreAnimations(
        homeTeamNameLayer: CATextLayer,
        homeScoreLayer: CATextLayer,
        awayTeamNameLayer: CATextLayer,
        awayScoreLayer: CATextLayer,
        periodLayer: CATextLayer,
        clockLayer: CATextLayer,
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDuration: TimeInterval
    ) {
        guard !scoreTimeline.isEmpty else {
            print("❌ ERROR: No score timeline - overlay will be BLANK!")
            print("   This means ScoreTimelineTracker didn't capture any data during recording")
            return
        }

        print("🎬 Adding score animations for \(scoreTimeline.count) snapshots")
        print("   First snapshot: \(scoreTimeline[0].homeTeam) \(scoreTimeline[0].homeScore) - \(scoreTimeline[0].awayScore) \(scoreTimeline[0].awayTeam)")
        if scoreTimeline.count > 1 {
            print("   Last snapshot: \(scoreTimeline.last!.homeTeam) \(scoreTimeline.last!.homeScore) - \(scoreTimeline.last!.awayScore) \(scoreTimeline.last!.awayTeam)")
        }

        // INTERPOLATION: Create smooth clock countdown
        let interpolatedTimeline = interpolateClockValues(scoreTimeline: scoreTimeline, videoDuration: videoDuration)
        print("   📈 Interpolated to \(interpolatedTimeline.count) snapshots for smooth clock")

        // Use interpolated timeline for smoother clock updates
        let timelineToUse = interpolatedTimeline

        // Use keyframe animation for smoother, more reliable animations
        addKeyframeAnimations(
            homeTeamNameLayer: homeTeamNameLayer,
            homeScoreLayer: homeScoreLayer,
            awayTeamNameLayer: awayTeamNameLayer,
            awayScoreLayer: awayScoreLayer,
            periodLayer: periodLayer,
            clockLayer: clockLayer,
            timeline: timelineToUse,
            videoDuration: videoDuration
        )
    }

    private static func addKeyframeAnimations(
        homeTeamNameLayer: CATextLayer,
        homeScoreLayer: CATextLayer,
        awayTeamNameLayer: CATextLayer,
        awayScoreLayer: CATextLayer,
        periodLayer: CATextLayer,
        clockLayer: CATextLayer,
        timeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDuration: TimeInterval
    ) {
        guard !timeline.isEmpty else { return }

        // Prepare arrays for keyframe animation
        var homeTeamNames: [String] = []
        var homeScores: [String] = []
        var awayTeamNames: [String] = []
        var awayScores: [String] = []
        var periodTexts: [String] = []
        var clockTimes: [String] = []
        var keyTimes: [NSNumber] = []

        for snapshot in timeline {
            let homeTeamName = formatTeamName(snapshot.homeTeam, maxLength: 4)
            let awayTeamName = formatTeamName(snapshot.awayTeam, maxLength: 4)
            let periodText = formatPeriod(quarter: snapshot.quarter, gameFormat: snapshot.gameFormat)

            homeTeamNames.append(homeTeamName)
            homeScores.append("\(snapshot.homeScore)")
            awayTeamNames.append(awayTeamName)
            awayScores.append("\(snapshot.awayScore)")
            periodTexts.append(periodText)
            clockTimes.append(snapshot.clockTime)

            // Normalize timestamp to 0-1 range
            let normalizedTime = videoDuration > 0 ? snapshot.timestamp / videoDuration : 0
            keyTimes.append(NSNumber(value: normalizedTime))
        }

        // Set initial values
        homeTeamNameLayer.string = homeTeamNames[0]
        homeScoreLayer.string = homeScores[0]
        awayTeamNameLayer.string = awayTeamNames[0]
        awayScoreLayer.string = awayScores[0]
        periodLayer.string = periodTexts[0]
        clockLayer.string = clockTimes[0]

        // Create keyframe animations
        createKeyframeAnimation(for: homeTeamNameLayer, values: homeTeamNames, keyTimes: keyTimes, duration: videoDuration)
        createKeyframeAnimation(for: homeScoreLayer, values: homeScores, keyTimes: keyTimes, duration: videoDuration)
        createKeyframeAnimation(for: awayTeamNameLayer, values: awayTeamNames, keyTimes: keyTimes, duration: videoDuration)
        createKeyframeAnimation(for: awayScoreLayer, values: awayScores, keyTimes: keyTimes, duration: videoDuration)
        createKeyframeAnimation(for: periodLayer, values: periodTexts, keyTimes: keyTimes, duration: videoDuration)
        createKeyframeAnimation(for: clockLayer, values: clockTimes, keyTimes: keyTimes, duration: videoDuration)

        print("   ✅ Created keyframe animations with \(keyTimes.count) keyframes")
    }

    private static func createKeyframeAnimation(
        for layer: CATextLayer,
        values: [String],
        keyTimes: [NSNumber],
        duration: TimeInterval
    ) {
        let animation = CAKeyframeAnimation(keyPath: "string")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.duration = duration
        animation.calculationMode = .discrete // Discrete (not interpolated) values
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        layer.add(animation, forKey: "stringAnimation")
    }

    // MARK: - Helper Methods

    private static func createTextLayer(
        text: String,
        fontSize: CGFloat,
        color: UIColor,
        weight: UIFont.Weight
    ) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = color.cgColor
        textLayer.alignmentMode = .natural
        textLayer.contentsScale = 3.0  // Fixed scale for high-quality video rendering

        // Use system font with weight
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        textLayer.font = font

        return textLayer
    }

    private static func formatTeamName(_ teamName: String, maxLength: Int) -> String {
        if teamName.count <= maxLength {
            return teamName.uppercased()
        }
        let words = teamName.components(separatedBy: " ")
        if words.count > 1 {
            let firstWord = words[0]
            if firstWord.count <= maxLength {
                return firstWord.uppercased()
            }
        }
        return String(teamName.prefix(maxLength)).uppercased()
    }

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

    // MARK: - Clock Interpolation

    private static func interpolateClockValues(
        scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot],
        videoDuration: TimeInterval
    ) -> [ScoreTimelineTracker.ScoreSnapshot] {
        guard scoreTimeline.count > 0 else { return [] }

        var result: [ScoreTimelineTracker.ScoreSnapshot] = []
        let frameInterval: TimeInterval = 0.1 // Update clock every 0.1 seconds for smooth countdown

        // Process each segment between snapshots
        for i in 0..<scoreTimeline.count {
            let currentSnapshot = scoreTimeline[i]
            let currentTime = currentSnapshot.timestamp

            // Add the current snapshot
            result.append(currentSnapshot)

            // If there's a next snapshot, interpolate between them
            if i < scoreTimeline.count - 1 {
                let nextSnapshot = scoreTimeline[i + 1]
                let nextTime = nextSnapshot.timestamp
                let duration = nextTime - currentTime

                // Parse clock values
                guard let startClockSeconds = parseClockToSeconds(currentSnapshot.clockTime),
                      let endClockSeconds = parseClockToSeconds(nextSnapshot.clockTime) else {
                    continue
                }

                // Create intermediate frames
                var t = currentTime + frameInterval
                while t < nextTime {
                    // Calculate how far we are between current and next
                    let progress = (t - currentTime) / duration

                    // Interpolate clock (linear countdown)
                    let interpolatedClockSeconds = startClockSeconds - (startClockSeconds - endClockSeconds) * progress
                    let interpolatedClockString = formatSecondsToClockString(interpolatedClockSeconds)

                    // Create interpolated snapshot (keep scores the same, only update clock)
                    let interpolatedSnapshot = ScoreTimelineTracker.ScoreSnapshot(
                        timestamp: t,
                        homeScore: currentSnapshot.homeScore,
                        awayScore: currentSnapshot.awayScore,
                        quarter: currentSnapshot.quarter,
                        clockTime: interpolatedClockString,
                        homeTeam: currentSnapshot.homeTeam,
                        awayTeam: currentSnapshot.awayTeam,
                        gameFormat: currentSnapshot.gameFormat,
                        zoomLevel: currentSnapshot.zoomLevel
                    )

                    result.append(interpolatedSnapshot)
                    t += frameInterval
                }
            } else {
                // For the last snapshot, extend to end of video with countdown
                guard let clockSeconds = parseClockToSeconds(currentSnapshot.clockTime) else {
                    continue
                }

                var t = currentTime + frameInterval
                while t <= videoDuration {
                    let elapsed = t - currentTime
                    let interpolatedClockSeconds = max(0, clockSeconds - elapsed)
                    let interpolatedClockString = formatSecondsToClockString(interpolatedClockSeconds)

                    let interpolatedSnapshot = ScoreTimelineTracker.ScoreSnapshot(
                        timestamp: t,
                        homeScore: currentSnapshot.homeScore,
                        awayScore: currentSnapshot.awayScore,
                        quarter: currentSnapshot.quarter,
                        clockTime: interpolatedClockString,
                        homeTeam: currentSnapshot.homeTeam,
                        awayTeam: currentSnapshot.awayTeam,
                        gameFormat: currentSnapshot.gameFormat,
                        zoomLevel: currentSnapshot.zoomLevel
                    )

                    result.append(interpolatedSnapshot)
                    t += frameInterval
                }
            }
        }

        return result
    }

    private static func parseClockToSeconds(_ clockString: String) -> Double? {
        // Parse formats like "19:58", "9:45", "0:03"
        let components = clockString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        let minutes = components[0]
        let seconds = components[1]
        return Double(minutes * 60 + seconds)
    }

    private static func formatSecondsToClockString(_ totalSeconds: Double) -> String {
        let seconds = max(0, Int(totalSeconds.rounded()))
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
