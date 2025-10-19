//
//  RealTimeOverlayRecorder.swift
//  SahilStats
//
//  Real-time video recording with live score overlay composition
//  Uses AVAssetWriter to burn overlays directly during recording
//

import AVFoundation
import UIKit
import CoreImage
import CoreGraphics
import Combine

class RealTimeOverlayRecorder: NSObject {

    // MARK: - Properties

    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?

    private let videoQueue = DispatchQueue(label: "com.sahilstats.videoQueue", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "com.sahilstats.audioQueue", qos: .userInitiated)

    private var isRecording = false
    private var recordingStartTime: CMTime?
    private var lastVideoTimestamp: CMTime = .zero
    private var frameCount: Int = 0 // Track number of frames written

    // Overlay state
    private var currentOverlayImage: UIImage?
    private var cachedOverlayCGImage: CGImage? // Cache the CGImage for faster composition
    private var overlayUpdateTimer: Timer?
    private var currentLiveGame: LiveGame?
    private var overlayUpdateCount: Int = 0

    // Lock for overlay image access (ensures memory visibility across threads)
    private let overlayLock = NSLock()

    // Clock interpolation for smooth countdown
    private var lastClockTime: TimeInterval = 0
    private var lastClockUpdateTime: Date = Date()
    private var isClockRunning: Bool = false

    // Frame composition tracking
    private var lastFrameHash: Int = 0
    private var duplicateFrameCount: Int = 0

    // End game banner state
    private var isShowingEndGameBanner: Bool = false
    private var endGameBannerData: (winner: String, homeScore: Int, awayScore: Int, homeTeam: String, awayTeam: String)?

    // Output
    private var outputURL: URL?

    // Reusable CI context for frame composition (creating this is expensive!)
    private lazy var ciContext: CIContext = {
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    // Video resolution (detected from camera)
    private var outputWidth: Int = 1920  // Default to 1080p
    private var outputHeight: Int = 1080

    // MARK: - Public API

    func setupOutputs(for session: AVCaptureSession) -> Bool {
        debugPrint("🎥 RealTimeOverlayRecorder: Setting up outputs")

        // Detect output resolution from session preset
        switch session.sessionPreset {
        case .hd4K3840x2160:
            outputWidth = 3840
            outputHeight = 2160
            debugPrint("📹 Using 4K resolution (3840x2160)")
        case .hd1920x1080:
            outputWidth = 1920
            outputHeight = 1080
            debugPrint("📹 Using 1080p resolution (1920x1080)")
        case .hd1280x720:
            outputWidth = 1280
            outputHeight = 720
            debugPrint("📹 Using 720p resolution (1280x720)")
        case .high, .medium:
            outputWidth = 1280
            outputHeight = 720
            debugPrint("📹 Using 720p resolution (high/medium preset)")
        default:
            outputWidth = 1280
            outputHeight = 720
            debugPrint("📹 Using 720p resolution (default)")
        }

        // Remove existing movie file output if present
        for output in session.outputs {
            if output is AVCaptureMovieFileOutput {
                session.removeOutput(output)
                debugPrint("🗑️ Removed AVCaptureMovieFileOutput")
            }
        }

        // Add video data output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoDataOutput = videoOutput
            debugPrint("✅ Added AVCaptureVideoDataOutput")

            // CRITICAL FIX: Set video orientation on the connection
            if let connection = videoOutput.connection(with: .video) {
                let deviceOrientation = UIDevice.current.orientation
                let rotationAngle: CGFloat

                switch deviceOrientation {
                case .portrait:
                    rotationAngle = 90
                case .portraitUpsideDown:
                    rotationAngle = 270
                case .landscapeLeft:
                    rotationAngle = 0    // Home button on left - swapped back
                case .landscapeRight:
                    rotationAngle = 180  // Home button on right - swapped back
                default:
                    rotationAngle = 180  // Default to landscape
                }

                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                    debugPrint("🎥 Set initial video rotation to \(rotationAngle)° for device orientation: \(deviceOrientation.rawValue)")
                } else {
                    debugPrint("⚠️ Rotation angle \(rotationAngle)° not supported")
                    let supportedAngles = [0.0, 90.0, 180.0, 270.0].filter { connection.isVideoRotationAngleSupported($0) }
                    debugPrint("   Supported angles: \(supportedAngles)")
                }
            } else {
                debugPrint("⚠️ No video connection available to set rotation")
            }
        } else {
            forcePrint("❌ Cannot add video data output")
            return false
        }

        // Add audio data output
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)

        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioDataOutput = audioOutput
            debugPrint("✅ Added AVCaptureAudioDataOutput")
        } else {
            forcePrint("❌ Cannot add audio data output")
            return false
        }

        return true
    }

    func startRecording(liveGame: LiveGame) -> URL? {
        debugPrint("🎥 RealTimeOverlayRecorder: Starting recording")
        debugPrint("   Game: \(liveGame.teamName) vs \(liveGame.opponent)")
        debugPrint("   Score: \(liveGame.homeScore)-\(liveGame.awayScore)")
        debugPrint("   Clock: \(liveGame.currentClockDisplay)")

        guard !isRecording else {
            forcePrint("❌ Already recording")
            return nil
        }

        // Store game for overlay updates (on videoQueue for thread safety)
        videoQueue.sync {
            self.currentLiveGame = liveGame
        }
        debugPrint("✅ Current game stored for overlay updates (thread-safe)")

        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent("realtime_\(Date().timeIntervalSince1970).mov")
        self.outputURL = url
        debugPrint("📁 Output URL: \(url.path)")

        // Initialize asset writer
        debugPrint("🎬 Setting up asset writer...")
        guard setupAssetWriter(outputURL: url) else {
            forcePrint("❌ Failed to setup asset writer")
            return nil
        }
        debugPrint("✅ Asset writer setup complete")

        // Start overlay update timer
        debugPrint("🎨 Starting overlay updates...")
        startOverlayUpdates()

        isRecording = true
        recordingStartTime = nil // Will be set on first frame
        frameCount = 0 // Reset frame counter
        overlayUpdateCount = 0 // Reset overlay counter

        debugPrint("✅ Recording started successfully")
        debugPrint("   Output URL: \(url.lastPathComponent)")
        debugPrint("   isRecording: \(isRecording)")
        return url
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        debugPrint("🎥 RealTimeOverlayRecorder: Stopping recording")
        debugPrint("   Total frames written: \(frameCount)")
        debugPrint("   Total overlay updates: \(overlayUpdateCount)")
        debugPrint("   isRecording: \(isRecording)")

        guard isRecording else {
            forcePrint("❌ Not currently recording")
            completion(nil)
            return
        }

        isRecording = false
        debugPrint("✅ Set isRecording = false")

        stopOverlayUpdates()
        debugPrint("✅ Stopped overlay updates")

        // Finish writing
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        debugPrint("✅ Marked inputs as finished")

        guard let writer = assetWriter else {
            forcePrint("❌ No asset writer")
            completion(nil)
            return
        }

        let outputURL = self.outputURL
        debugPrint("📁 Output URL: \(outputURL?.path ?? "nil")")

        debugPrint("🎬 Calling writer.finishWriting()...")
        writer.finishWriting {
            DispatchQueue.main.async {
                if writer.status == .completed {
                    debugPrint("✅ Recording completed successfully")
                    debugPrint("   Final frame count: \(self.frameCount)")
                    if let url = outputURL {
                        let fileExists = FileManager.default.fileExists(atPath: url.path)
                        debugPrint("   File exists: \(fileExists)")
                        if fileExists {
                            do {
                                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                                let fileSize = attrs[.size] as? Int64 ?? 0
                                debugPrint("   File size: \(fileSize) bytes (\(Double(fileSize) / 1_000_000) MB)")
                            } catch {
                                debugPrint("   Could not get file size: \(error)")
                            }
                        }
                    }
                    completion(outputURL)
                } else if let error = writer.error {
                    forcePrint("❌ Recording failed: \(error)")
                    completion(nil)
                } else {
                    forcePrint("❌ Recording failed with unknown error")
                    debugPrint("   Writer status: \(writer.status.rawValue)")
                    completion(nil)
                }
            }
        }
    }

    func updateGame(_ liveGame: LiveGame) {
        debugPrint("📊 RealTimeOverlayRecorder.updateGame() called:")
        debugPrint("   Score: \(liveGame.homeScore)-\(liveGame.awayScore)")
        debugPrint("   Clock: \(liveGame.currentClockDisplay)")
        debugPrint("   Period: Q\(liveGame.quarter)")
        debugPrint("   Teams: \(liveGame.teamName) vs \(liveGame.opponent)")
        debugPrint("   Is Running: \(liveGame.isRunning)")

        // CRITICAL FIX: Update game data on videoQueue to ensure thread safety
        // This ensures overlay rendering always has consistent game data
        videoQueue.sync {
            self.currentLiveGame = liveGame
        }

        // Update clock interpolation tracking
        let newClockTime = parseClockToSeconds(liveGame.currentClockDisplay)
        let gameIsRunning = liveGame.isRunning

        // CRITICAL FIX: Use actual game running state, not clock value
        // This fixes the issue where clock would continue after period changes
        if newClockTime != lastClockTime || gameIsRunning != isClockRunning {
            debugPrint("   ⏱️ Clock changed from \(formatSecondsToClockDisplay(lastClockTime)) to \(liveGame.currentClockDisplay)")
            debugPrint("   ⏱️ isRunning changed from \(isClockRunning) to \(gameIsRunning)")
            lastClockTime = newClockTime
            lastClockUpdateTime = Date()
            isClockRunning = gameIsRunning  // Use actual game state!
        }

        // Immediately trigger overlay update with new game data
        updateOverlay()
    }

    func showEndGameBanner(game: LiveGame) {
        debugPrint("🏆 RealTimeOverlayRecorder: Showing end game banner")
        debugPrint("   Final Score: \(game.homeScore)-\(game.awayScore)")
        debugPrint("   Teams: \(game.teamName) vs \(game.opponent)")

        // Determine winner
        let winner: String
        if game.homeScore > game.awayScore {
            winner = "\(game.teamName) WINS!"
        } else if game.awayScore > game.homeScore {
            winner = "\(game.opponent) WINS!"
        } else {
            winner = "TIE GAME!"
        }

        // Store banner data
        videoQueue.sync {
            self.isShowingEndGameBanner = true
            self.endGameBannerData = (
                winner: winner,
                homeScore: game.homeScore,
                awayScore: game.awayScore,
                homeTeam: game.teamName,
                awayTeam: game.opponent
            )
        }

        // Force overlay update
        DispatchQueue.main.async {
            self.updateOverlay()
            forcePrint("✅ End game banner overlay updated")
        }
    }

    // MARK: - Asset Writer Setup

    private func setupAssetWriter(outputURL: URL) -> Bool {
        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

            // Video input settings - use detected resolution
            // Bitrate: 20Mbps for 4K, 8Mbps for 1080p, 4Mbps for 720p
            let bitRate: Int
            if outputWidth >= 3840 {
                bitRate = 20_000_000  // 20 Mbps for 4K
            } else if outputWidth >= 1920 {
                bitRate = 8_000_000   // 8 Mbps for 1080p
            } else {
                bitRate = 4_000_000   // 4 Mbps for 720p
            }
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: outputWidth,
                AVVideoHeightKey: outputHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitRate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]
            debugPrint("📹 Asset writer configured for \(outputWidth)x\(outputHeight) @ \(bitRate/1_000_000)Mbps")

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            // No transform needed - we're compositing to 1280x720 (landscape) directly
            // The camera frames and overlay are both drawn into the same landscape buffer

            if writer.canAdd(videoInput) {
                writer.add(videoInput)
                self.videoWriterInput = videoInput
                debugPrint("✅ Added video input to asset writer")
            } else {
                forcePrint("❌ Cannot add video input")
                return false
            }

            // Pixel buffer adaptor - use detected resolution
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: outputWidth,
                kCVPixelBufferHeightKey as String: outputHeight
            ]

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
            self.pixelBufferAdaptor = adaptor

            // Audio input settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ]

            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true

            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                self.audioWriterInput = audioInput
                debugPrint("✅ Added audio input to asset writer")
            } else {
                forcePrint("❌ Cannot add audio input")
            }

            self.assetWriter = writer
            return true

        } catch {
            forcePrint("❌ Failed to create asset writer: \(error)")
            return false
        }
    }

    // MARK: - Overlay Management

    private func startOverlayUpdates() {
        debugPrint("🎨 RealTimeOverlayRecorder: Starting overlay update timer")
        debugPrint("   Current game: \(currentLiveGame?.teamName ?? "nil") vs \(currentLiveGame?.opponent ?? "nil")")

        // Update overlay 4 times per second (reduced from 10Hz to save memory)
        // Still smooth enough for clock countdown, but uses 60% less memory
        DispatchQueue.main.async { [weak self] in
            self?.overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.updateOverlay()
            }
            if let timer = self?.overlayUpdateTimer {
                RunLoop.main.add(timer, forMode: .common)
                debugPrint("✅ Overlay update timer scheduled and added to run loop")
            } else {
                forcePrint("❌ Failed to create overlay update timer")
            }
        }

        // Generate initial overlay on main thread (UIGraphicsImageRenderer requires main thread!)
        debugPrint("🎨 Generating initial overlay...")
        DispatchQueue.main.async {
            self.updateOverlay()
            debugPrint("✅ Initial overlay generated")
        }
    }

    private func stopOverlayUpdates() {
        overlayUpdateTimer?.invalidate()
        overlayUpdateTimer = nil
    }

    private func updateOverlay() {
        autoreleasepool {
            overlayUpdateCount += 1

            // CRITICAL FIX: Read currentLiveGame with proper synchronization!
            // Even though we're on main thread, we must use videoQueue.sync to read
            // the value that was written with videoQueue.sync
            let game: LiveGame? = videoQueue.sync {
                return self.currentLiveGame
            }

            let showingBanner = videoQueue.sync {
                return self.isShowingEndGameBanner
            }

            // ALWAYS log every 100 calls to verify timer is firing
            if overlayUpdateCount % 100 == 0 || showingBanner {
                debugPrint("⏱️ updateOverlay() called \(overlayUpdateCount) times")
                debugPrint("   currentLiveGame: \(game != nil ? "EXISTS" : "NIL!")")
                debugPrint("   showingEndGameBanner: \(showingBanner)")
            }

            guard let game = game else {
                if overlayUpdateCount % 100 == 0 {
                    forcePrint("❌ ERROR: currentLiveGame is NIL - overlay cannot be rendered!")
                }
                return
            }

            // Generate overlay image (banner or normal scoreboard)
            let overlayImage = showingBanner ? renderEndGameBannerImage() : renderOverlayImage(for: game)

            // Log every 12 overlay updates (roughly every 3 seconds at 4Hz) - reduced for memory
            let shouldLog = overlayUpdateCount % 12 == 0
            if shouldLog {
                let interpolatedClock = getInterpolatedClockDisplay()
                debugPrint("🎨 Overlay updated (\(overlayUpdateCount) updates): \(game.teamName) \(game.homeScore)-\(game.awayScore) \(game.opponent) | Clock: \(interpolatedClock)")
                debugPrint("   Raw clock from game: \(game.currentClockDisplay)")
                debugPrint("   Interpolated clock: \(interpolatedClock)")
                debugPrint("   Overlay image generated: \(overlayImage != nil ? "YES" : "NO")")
                if let img = overlayImage {
                    debugPrint("   Overlay image size: \(img.size.width)x\(img.size.height)")
                }
            }

            // CRITICAL FIX: Store overlay with explicit lock to ensure memory visibility
            // This ensures the video queue can see the updated overlay image
            // PERFORMANCE: Also cache the CGImage to avoid repeated UIImage->CGImage conversions
            overlayLock.lock()
            self.currentOverlayImage = overlayImage
            self.cachedOverlayCGImage = overlayImage?.cgImage // Cache CGImage for fast access
            overlayLock.unlock()

            if shouldLog && overlayImage != nil {
                let pointer = Unmanaged.passUnretained(overlayImage!).toOpaque()
                debugPrint("   ✅ Stored overlay - pointer: \(String(describing: pointer))")
                debugPrint("   ✅ Cached CGImage for performance")
            }
        }
    }

    private func renderOverlayImage(for game: LiveGame) -> UIImage? {
        // Wrap in autoreleasepool to immediately release temporary objects
        return autoreleasepool {
            // CRITICAL FIX: Render overlay at EXACT output resolution to avoid scaling artifacts
            // This ensures pixel-perfect overlay composition without interpolation
            let size = CGSize(width: outputWidth, height: outputHeight)

            // IMPORTANT: Use transparent format, not opaque (prevents black box artifact)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false  // This is critical!
            format.scale = 1  // Use 1x scale for exact pixel control

            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let tempImage = renderer.image { context in
                let cgContext = context.cgContext

                // Clear background (transparent) - now this actually works!
                cgContext.clear(CGRect(origin: .zero, size: size))

                // Draw scoreboard overlay
                drawScoreboardOverlay(in: cgContext, size: size, game: game)
            }

            // CRITICAL FIX: iOS reuses UIImage object wrappers even when CGImage changes
            // Extract CGImage and create NEW UIImage to force unique object identity
            // This prevents video queue from reading stale CGImage reference
            guard let cgImage = tempImage.cgImage else {
                return tempImage
            }

            // Create a fresh UIImage from the CGImage - this ensures unique object identity
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        }
    }

    private func renderEndGameBannerImage() -> UIImage? {
        return autoreleasepool {
            // Get banner data with proper synchronization
            guard let bannerData = videoQueue.sync(execute: { return self.endGameBannerData }) else {
                forcePrint("❌ No banner data available")
                return nil
            }

            let size = CGSize(width: outputWidth, height: outputHeight)

            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = 1

            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let tempImage = renderer.image { context in
                let cgContext = context.cgContext

                // Clear background
                cgContext.clear(CGRect(origin: .zero, size: size))

                // Draw end game banner
                drawEndGameBanner(in: cgContext, size: size, bannerData: bannerData)
            }

            guard let cgImage = tempImage.cgImage else {
                return tempImage
            }

            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        }
    }

    private func drawEndGameBanner(in context: CGContext, size: CGSize, bannerData: (winner: String, homeScore: Int, awayScore: Int, homeTeam: String, awayTeam: String)) {
        let scaleFactor = size.height / 375.0

        // Large banner in center of screen
        let bannerWidth: CGFloat = 500 * scaleFactor
        let bannerHeight: CGFloat = 200 * scaleFactor

        let bannerRect = CGRect(
            x: (size.width - bannerWidth) / 2,
            y: (size.height - bannerHeight) / 2,
            width: bannerWidth,
            height: bannerHeight
        )

        // Draw banner background
        let cornerRadius = 20 * scaleFactor
        let path = UIBezierPath(roundedRect: bannerRect, cornerRadius: cornerRadius)

        // Fill with semi-transparent black
        context.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        // Add border
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(2)
        context.addPath(path.cgPath)
        context.strokePath()

        // Draw "FINAL SCORE" text
        drawText(
            "FINAL SCORE",
            at: CGPoint(x: bannerRect.midX, y: bannerRect.minY + 20 * scaleFactor),
            fontSize: 16 * scaleFactor,
            color: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95),
            weight: .bold,
            centered: true,
            in: context
        )

        // Draw score
        let scoreText = "\(formatTeamName(bannerData.homeTeam, maxLength: 6)) \(bannerData.homeScore) - \(bannerData.awayScore) \(formatTeamName(bannerData.awayTeam, maxLength: 6))"
        drawText(
            scoreText,
            at: CGPoint(x: bannerRect.midX, y: bannerRect.minY + 60 * scaleFactor),
            fontSize: 32 * scaleFactor,
            color: .white,
            weight: .bold,
            centered: true,
            in: context
        )

        // Draw winner text
        drawText(
            bannerData.winner,
            at: CGPoint(x: bannerRect.midX, y: bannerRect.minY + 120 * scaleFactor),
            fontSize: 40 * scaleFactor,
            color: UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0), // Green
            weight: .black,
            centered: true,
            in: context
        )
    }

    private func drawScoreboardOverlay(in context: CGContext, size: CGSize, game: LiveGame) {
        // Match SwiftUI SimpleScoreOverlay design
        let scaleFactor = size.height / 375.0 // Scale based on video height

        // Scoreboard width
        let scoreboardWidth: CGFloat = 246 * scaleFactor
        let scoreboardHeight: CGFloat = 56 * scaleFactor

        // Position at bottom center
        let scoreboardRect = CGRect(
            x: (size.width - scoreboardWidth) / 2,
            y: size.height - scoreboardHeight - (40 * scaleFactor),
            width: scoreboardWidth,
            height: scoreboardHeight
        )

        // Draw rounded rectangle background (single draw, no artifacts)
        let cornerRadius = 14 * scaleFactor
        let path = UIBezierPath(roundedRect: scoreboardRect, cornerRadius: cornerRadius)

        // Fill with semi-transparent black
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        // Add border
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1)
        context.addPath(path.cgPath)
        context.strokePath()

        // Text attributes
        let homeTeamName = formatTeamName(game.teamName, maxLength: 4)
        let awayTeamName = formatTeamName(game.opponent, maxLength: 4)
        let periodText = formatPeriod(quarter: game.quarter, gameFormat: game.gameFormat)
        // Use interpolated clock for smooth countdown
        let clockText = getInterpolatedClockDisplay()

        let columnWidth: CGFloat = 50 * scaleFactor
        let centerWidth: CGFloat = 70 * scaleFactor
        let spacing: CGFloat = 12 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor

        var xOffset = scoreboardRect.minX + padding

        // Home team section
        drawText(
            homeTeamName,
            at: CGPoint(x: xOffset + columnWidth / 2, y: scoreboardRect.minY + 8 * scaleFactor),
            fontSize: 10 * scaleFactor,
            color: .white.withAlphaComponent(0.9),
            weight: .semibold,
            centered: true,
            in: context
        )

        drawText(
            "\(game.homeScore)",
            at: CGPoint(x: xOffset + columnWidth / 2, y: scoreboardRect.minY + 22 * scaleFactor),
            fontSize: 20 * scaleFactor,
            color: .white,
            weight: .bold,
            centered: true,
            in: context
        )

        xOffset += columnWidth + spacing

        // First separator
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + 13 * scaleFactor))
        context.addLine(to: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + 43 * scaleFactor))
        context.strokePath()

        // Center section
        drawText(
            periodText,
            at: CGPoint(x: xOffset + centerWidth / 2, y: scoreboardRect.minY + 8 * scaleFactor),
            fontSize: 9 * scaleFactor,
            color: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95), // Orange
            weight: .semibold,
            centered: true,
            in: context
        )

        drawText(
            clockText,
            at: CGPoint(x: xOffset + centerWidth / 2, y: scoreboardRect.minY + 22 * scaleFactor),
            fontSize: 16 * scaleFactor,
            color: .white,
            weight: .bold,
            centered: true,
            in: context
        )

        xOffset += centerWidth + spacing

        // Second separator
        context.move(to: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + 13 * scaleFactor))
        context.addLine(to: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + 43 * scaleFactor))
        context.strokePath()

        // Away team section
        drawText(
            awayTeamName,
            at: CGPoint(x: xOffset + columnWidth / 2, y: scoreboardRect.minY + 8 * scaleFactor),
            fontSize: 10 * scaleFactor,
            color: .white.withAlphaComponent(0.9),
            weight: .semibold,
            centered: true,
            in: context
        )

        drawText(
            "\(game.awayScore)",
            at: CGPoint(x: xOffset + columnWidth / 2, y: scoreboardRect.minY + 22 * scaleFactor),
            fontSize: 20 * scaleFactor,
            color: .white,
            weight: .bold,
            centered: true,
            in: context
        )

        // Status dots removed - clean overlay for final video
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        fontSize: CGFloat,
        color: UIColor,
        weight: UIFont.Weight,
        centered: Bool,
        in context: CGContext
    ) {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        let drawPoint: CGPoint
        if centered {
            drawPoint = CGPoint(x: point.x - size.width / 2, y: point.y)
        } else {
            drawPoint = point
        }

        attributedString.draw(at: drawPoint)
    }

    // MARK: - Frame Composition

    private func composeFrame(from sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) -> CVPixelBuffer? {
        // PERFORMANCE OPTIMIZED: Reduced expensive operations
        return autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                if frameCount % 100 == 0 {
                    forcePrint("❌ composeFrame: No image buffer in sample buffer!")
                }
                return nil
            }

            // Create output pixel buffer first
            guard let pixelBufferPool = pixelBufferAdaptor?.pixelBufferPool else {
                return nil
            }

            var outputPixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &outputPixelBuffer)

            guard status == kCVReturnSuccess, let outputBuffer = outputPixelBuffer else {
                return nil
            }

            // Lock buffers
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            CVPixelBufferLockBaseAddress(outputBuffer, [])
            defer {
                CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                CVPixelBufferUnlockBaseAddress(outputBuffer, [])
            }

            // Get dimensions
            let outputWidth = CVPixelBufferGetWidth(outputBuffer)
            let outputHeight = CVPixelBufferGetHeight(outputBuffer)

            // Create graphics context once
            guard let context = CGContext(
                data: CVPixelBufferGetBaseAddress(outputBuffer),
                width: outputWidth,
                height: outputHeight,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(outputBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                return nil
            }

            // PERFORMANCE OPTIMIZATION: Create CGImage once, draw efficiently
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let rotationAngle = connection.videoRotationAngle

            // Log rotation angle for debugging (only every 120 frames)
            if frameCount % 120 == 0 {
                debugPrint("📹 Rotation: \(rotationAngle)° | Frame: \(frameCount)")
            }

            // Create CGImage from camera frame
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }

            // Apply rotation using CGContext
            context.saveGState()

            switch rotationAngle {
            case 90:
                // Portrait: rotate 90° clockwise
                context.translateBy(x: CGFloat(outputWidth), y: 0)
                context.rotate(by: .pi / 2)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputHeight, height: outputWidth))

            case 180:
                // Landscape Left: rotate 180°
                context.translateBy(x: CGFloat(outputWidth), y: CGFloat(outputHeight))
                context.rotate(by: .pi)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

            case 270:
                // Portrait Upside Down: rotate 270° clockwise
                context.translateBy(x: 0, y: CGFloat(outputHeight))
                context.rotate(by: -.pi / 2)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputHeight, height: outputWidth))

            default:
                // Landscape Right - rotate 180°
                context.translateBy(x: CGFloat(outputWidth), y: CGFloat(outputHeight))
                context.rotate(by: .pi)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
            }

            context.restoreGState()

            // Draw overlay (use cached CGImage for performance)
            overlayLock.lock()
            let overlayCGImage = cachedOverlayCGImage
            overlayLock.unlock()

            if let overlayImage = overlayCGImage {
                let overlayRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
                context.setBlendMode(.normal)
                context.draw(overlayImage, in: overlayRect)

                // Log every 120 frames
                if frameCount % 120 == 0 {
                    debugPrint("🎨 Drawing overlay on frame \(frameCount)")
                }
            } else if frameCount % 60 == 0 {
                debugPrint("⚠️ NO OVERLAY IMAGE to draw on frame \(frameCount)")
            }

            return outputBuffer
        }
    }

    // MARK: - Clock Interpolation

    private func parseClockToSeconds(_ clockDisplay: String) -> TimeInterval {
        // Parse "5:23" -> 323 seconds, "0:45" -> 45 seconds
        let components = clockDisplay.split(separator: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return 0
        }
        return (minutes * 60) + seconds
    }

    private func getInterpolatedClockDisplay() -> String {
        guard isClockRunning, lastClockTime > 0 else {
            return formatSecondsToClockDisplay(lastClockTime)
        }

        // Calculate how much time has elapsed since last update
        let elapsedSinceUpdate = Date().timeIntervalSince(lastClockUpdateTime)

        // Subtract elapsed time from last clock value (clock counts down)
        let interpolatedTime = max(0, lastClockTime - elapsedSinceUpdate)

        return formatSecondsToClockDisplay(interpolatedTime)
    }

    private func formatSecondsToClockDisplay(_ totalSeconds: TimeInterval) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Helper Methods

    private func formatTeamName(_ teamName: String, maxLength: Int) -> String {
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

    private func formatPeriod(quarter: Int, gameFormat: GameFormat) -> String {
        let periodName = gameFormat == .halves ? "HALF" : "QTR"
        let ordinal = getOrdinalSuffix(quarter)
        return "\(quarter)\(ordinal) \(periodName)"
    }

    private func getOrdinalSuffix(_ number: Int) -> String {
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
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension RealTimeOverlayRecorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    // Track delegate calls
    private static var delegateCallCount: Int = 0

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else {
            // Only log first few times to avoid spam
            if Self.delegateCallCount < 3 {
                Self.delegateCallCount += 1
                debugPrint("⚠️ captureOutput called but isRecording=false")
            }
            return
        }

        // Log first few delegate callbacks
        if frameCount < 3 {
            if output == videoDataOutput {
                debugPrint("📹 captureOutput: VIDEO frame received (frameCount: \(frameCount))")
            } else if output == audioDataOutput {
                debugPrint("🔊 captureOutput: AUDIO sample received")
            }
        }

        if output == videoDataOutput {
            handleVideoFrame(sampleBuffer, connection: connection)
        } else if output == audioDataOutput {
            handleAudioSample(sampleBuffer)
        }
    }

    private func handleVideoFrame(_ sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) {
        // Autoreleasepool to prevent memory accumulation during tight loop processing
        autoreleasepool {
            guard let writer = assetWriter,
                  let videoInput = videoWriterInput,
                  let adaptor = pixelBufferAdaptor else {
                debugPrint("⚠️ handleVideoFrame: Missing writer/input/adaptor")
                return
            }

            // Start writing on first frame
            if recordingStartTime == nil {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                recordingStartTime = timestamp
                lastVideoTimestamp = timestamp

                debugPrint("🎬 First video frame received!")
                debugPrint("   Timestamp: \(CMTimeGetSeconds(timestamp))s")
                debugPrint("   Writer status: \(writer.status.rawValue)")

                if writer.status == .unknown {
                    writer.startWriting()
                    writer.startSession(atSourceTime: timestamp)
                    debugPrint("✅ Started asset writer session at time: \(CMTimeGetSeconds(timestamp))")
                } else {
                    debugPrint("⚠️ Writer status not .unknown, it's: \(writer.status.rawValue)")
                }
            }

            guard writer.status == .writing else {
                if writer.status == .failed {
                    forcePrint("❌ Asset writer failed: \(String(describing: writer.error))")
                } else if frameCount < 5 {
                    // Log status issues for first few frames
                    debugPrint("⚠️ Writer status not .writing: \(writer.status.rawValue)")
                }
                return
            }

            // Write frame if input is ready
            if videoInput.isReadyForMoreMediaData {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                // Adjust timestamp relative to recording start
                let adjustedTimestamp = CMTimeSubtract(timestamp, recordingStartTime ?? .zero)

                // Compose frame with overlay (pass connection for orientation)
                if let composedPixelBuffer = composeFrame(from: sampleBuffer, connection: connection) {
                    adaptor.append(composedPixelBuffer, withPresentationTime: adjustedTimestamp)

                    // Check for duplicate timestamps
                    if frameCount > 0 && CMTimeCompare(adjustedTimestamp, lastVideoTimestamp) == 0 {
                        debugPrint("⚠️ DUPLICATE TIMESTAMP! Frame #\(frameCount) has same timestamp as previous frame: \(CMTimeGetSeconds(adjustedTimestamp))s")
                    }

                    lastVideoTimestamp = adjustedTimestamp
                    frameCount += 1

                    // Log first 5 frames, then every 30 frames
                    if frameCount <= 5 || frameCount % 30 == 0 {
                        debugPrint("📹 Written frame #\(frameCount) at \(String(format: "%.3f", CMTimeGetSeconds(adjustedTimestamp)))s")
                    }
                } else {
                    forcePrint("❌ Failed to compose frame at \(CMTimeGetSeconds(adjustedTimestamp))s")
                }
            } else {
                // Frame dropped because input not ready
                if frameCount < 5 {
                    debugPrint("⚠️ Video input not ready for frame (frameCount: \(frameCount))")
                }
            }
        }
    }

    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter,
              let audioInput = audioWriterInput,
              recordingStartTime != nil else {
            return
        }

        guard writer.status == .writing else { return }

        if audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }
}
