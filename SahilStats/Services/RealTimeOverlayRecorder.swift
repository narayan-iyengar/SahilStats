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
        print("🎥 RealTimeOverlayRecorder: Setting up outputs")

        // Detect output resolution from session preset
        switch session.sessionPreset {
        case .hd1920x1080:
            outputWidth = 1920
            outputHeight = 1080
            print("📹 Using 1080p resolution (1920x1080)")
        case .hd1280x720:
            outputWidth = 1280
            outputHeight = 720
            print("📹 Using 720p resolution (1280x720)")
        case .high, .medium:
            outputWidth = 1280
            outputHeight = 720
            print("📹 Using 720p resolution (high/medium preset)")
        default:
            outputWidth = 1280
            outputHeight = 720
            print("📹 Using 720p resolution (default)")
        }

        // Remove existing movie file output if present
        for output in session.outputs {
            if output is AVCaptureMovieFileOutput {
                session.removeOutput(output)
                print("🗑️ Removed AVCaptureMovieFileOutput")
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
            print("✅ Added AVCaptureVideoDataOutput")
        } else {
            print("❌ Cannot add video data output")
            return false
        }

        // Add audio data output
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)

        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioDataOutput = audioOutput
            print("✅ Added AVCaptureAudioDataOutput")
        } else {
            print("❌ Cannot add audio data output")
            return false
        }

        return true
    }

    func startRecording(liveGame: LiveGame) -> URL? {
        print("🎥 RealTimeOverlayRecorder: Starting recording")
        print("   Game: \(liveGame.teamName) vs \(liveGame.opponent)")
        print("   Score: \(liveGame.homeScore)-\(liveGame.awayScore)")
        print("   Clock: \(liveGame.currentClockDisplay)")

        guard !isRecording else {
            print("❌ Already recording")
            return nil
        }

        // Store game for overlay updates (on videoQueue for thread safety)
        videoQueue.sync {
            self.currentLiveGame = liveGame
        }
        print("✅ Current game stored for overlay updates (thread-safe)")

        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent("realtime_\(Date().timeIntervalSince1970).mov")
        self.outputURL = url
        print("📁 Output URL: \(url.path)")

        // Initialize asset writer
        print("🎬 Setting up asset writer...")
        guard setupAssetWriter(outputURL: url) else {
            print("❌ Failed to setup asset writer")
            return nil
        }
        print("✅ Asset writer setup complete")

        // Start overlay update timer
        print("🎨 Starting overlay updates...")
        startOverlayUpdates()

        isRecording = true
        recordingStartTime = nil // Will be set on first frame
        frameCount = 0 // Reset frame counter
        overlayUpdateCount = 0 // Reset overlay counter

        print("✅ Recording started successfully")
        print("   Output URL: \(url.lastPathComponent)")
        print("   isRecording: \(isRecording)")
        return url
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        print("🎥 RealTimeOverlayRecorder: Stopping recording")
        print("   Total frames written: \(frameCount)")
        print("   Total overlay updates: \(overlayUpdateCount)")
        print("   isRecording: \(isRecording)")

        guard isRecording else {
            print("❌ Not currently recording")
            completion(nil)
            return
        }

        isRecording = false
        print("✅ Set isRecording = false")

        stopOverlayUpdates()
        print("✅ Stopped overlay updates")

        // Finish writing
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        print("✅ Marked inputs as finished")

        guard let writer = assetWriter else {
            print("❌ No asset writer")
            completion(nil)
            return
        }

        let outputURL = self.outputURL
        print("📁 Output URL: \(outputURL?.path ?? "nil")")

        print("🎬 Calling writer.finishWriting()...")
        writer.finishWriting {
            DispatchQueue.main.async {
                if writer.status == .completed {
                    print("✅ Recording completed successfully")
                    print("   Final frame count: \(self.frameCount)")
                    if let url = outputURL {
                        let fileExists = FileManager.default.fileExists(atPath: url.path)
                        print("   File exists: \(fileExists)")
                        if fileExists {
                            do {
                                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                                let fileSize = attrs[.size] as? Int64 ?? 0
                                print("   File size: \(fileSize) bytes (\(Double(fileSize) / 1_000_000) MB)")
                            } catch {
                                print("   Could not get file size: \(error)")
                            }
                        }
                    }
                    completion(outputURL)
                } else if let error = writer.error {
                    print("❌ Recording failed: \(error)")
                    completion(nil)
                } else {
                    print("❌ Recording failed with unknown error")
                    print("   Writer status: \(writer.status.rawValue)")
                    completion(nil)
                }
            }
        }
    }

    func updateGame(_ liveGame: LiveGame) {
        print("📊 RealTimeOverlayRecorder.updateGame() called:")
        print("   Score: \(liveGame.homeScore)-\(liveGame.awayScore)")
        print("   Clock: \(liveGame.currentClockDisplay)")
        print("   Period: Q\(liveGame.quarter)")
        print("   Teams: \(liveGame.teamName) vs \(liveGame.opponent)")

        // CRITICAL FIX: Update game data on videoQueue to ensure thread safety
        // This ensures overlay rendering always has consistent game data
        videoQueue.sync {
            self.currentLiveGame = liveGame
        }

        // Update clock interpolation tracking
        let newClockTime = parseClockToSeconds(liveGame.currentClockDisplay)
        if newClockTime != lastClockTime {
            print("   ⏱️ Clock changed from \(formatSecondsToClockDisplay(lastClockTime)) to \(liveGame.currentClockDisplay)")
            lastClockTime = newClockTime
            lastClockUpdateTime = Date()
            // Clock is running if it's greater than 0
            isClockRunning = newClockTime > 0
        }

        // Immediately trigger overlay update with new game data
        updateOverlay()
    }

    // MARK: - Asset Writer Setup

    private func setupAssetWriter(outputURL: URL) -> Bool {
        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

            // Video input settings - use detected resolution
            // Use more conservative bitrate (8Mbps for 1080p, 4Mbps for 720p)
            let bitRate = outputWidth >= 1920 ? 8_000_000 : 4_000_000
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
            print("📹 Asset writer configured for \(outputWidth)x\(outputHeight) @ \(bitRate/1_000_000)Mbps")

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            // No transform needed - we're compositing to 1280x720 (landscape) directly
            // The camera frames and overlay are both drawn into the same landscape buffer

            if writer.canAdd(videoInput) {
                writer.add(videoInput)
                self.videoWriterInput = videoInput
                print("✅ Added video input to asset writer")
            } else {
                print("❌ Cannot add video input")
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
                print("✅ Added audio input to asset writer")
            } else {
                print("❌ Cannot add audio input")
            }

            self.assetWriter = writer
            return true

        } catch {
            print("❌ Failed to create asset writer: \(error)")
            return false
        }
    }

    // MARK: - Overlay Management

    private func startOverlayUpdates() {
        print("🎨 RealTimeOverlayRecorder: Starting overlay update timer")
        print("   Current game: \(currentLiveGame?.teamName ?? "nil") vs \(currentLiveGame?.opponent ?? "nil")")

        // Update overlay 4 times per second (reduced from 10Hz to save memory)
        // Still smooth enough for clock countdown, but uses 60% less memory
        DispatchQueue.main.async { [weak self] in
            self?.overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.updateOverlay()
            }
            if let timer = self?.overlayUpdateTimer {
                RunLoop.main.add(timer, forMode: .common)
                print("✅ Overlay update timer scheduled and added to run loop")
            } else {
                print("❌ Failed to create overlay update timer")
            }
        }

        // Generate initial overlay on main thread (UIGraphicsImageRenderer requires main thread!)
        print("🎨 Generating initial overlay...")
        DispatchQueue.main.async {
            self.updateOverlay()
            print("✅ Initial overlay generated")
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

            // ALWAYS log every 100 calls to verify timer is firing
            if overlayUpdateCount % 100 == 0 {
                print("⏱️ updateOverlay() called \(overlayUpdateCount) times")
                print("   currentLiveGame: \(game != nil ? "EXISTS" : "NIL!")")
            }

            guard let game = game else {
                if overlayUpdateCount % 100 == 0 {
                    print("❌ ERROR: currentLiveGame is NIL - overlay cannot be rendered!")
                }
                return
            }

            // Generate overlay image
            let overlayImage = renderOverlayImage(for: game)

            // Log every 12 overlay updates (roughly every 3 seconds at 4Hz) - reduced for memory
            let shouldLog = overlayUpdateCount % 12 == 0
            if shouldLog {
                let interpolatedClock = getInterpolatedClockDisplay()
                print("🎨 Overlay updated (\(overlayUpdateCount) updates): \(game.teamName) \(game.homeScore)-\(game.awayScore) \(game.opponent) | Clock: \(interpolatedClock)")
                print("   Raw clock from game: \(game.currentClockDisplay)")
                print("   Interpolated clock: \(interpolatedClock)")
                print("   Overlay image generated: \(overlayImage != nil ? "YES" : "NO")")
                if let img = overlayImage {
                    print("   Overlay image size: \(img.size.width)x\(img.size.height)")
                }
            }

            // CRITICAL FIX: Store overlay with explicit lock to ensure memory visibility
            // This ensures the video queue can see the updated overlay image
            overlayLock.lock()
            self.currentOverlayImage = overlayImage
            overlayLock.unlock()

            if shouldLog && overlayImage != nil {
                let pointer = Unmanaged.passUnretained(overlayImage!).toOpaque()
                print("   ✅ Stored overlay - pointer: \(String(describing: pointer))")
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

    private func drawScoreboardOverlay(in context: CGContext, size: CGSize, game: LiveGame) {
        // Match SwiftUI SimpleScoreOverlay design
        let scaleFactor = size.height / 375.0 // Scale based on video height

        // Make scoreboard wider to accommodate status dots
        let scoreboardWidth: CGFloat = 280 * scaleFactor  // Increased from 246
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

        // Add subtle status dots on the right side
        let dotSize: CGFloat = 6 * scaleFactor
        let dotSpacing: CGFloat = 4 * scaleFactor
        let dotsStartX = scoreboardRect.maxX - padding - dotSize
        let dotY = scoreboardRect.midY - dotSize / 2

        // Connection dot (green - we're connected if we're recording)
        let connectionDotRect = CGRect(x: dotsStartX - dotSize - dotSpacing, y: dotY, width: dotSize, height: dotSize)
        context.setFillColor(UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.7).cgColor)  // Subtle green
        context.fillEllipse(in: connectionDotRect)

        // Recording dot (red when recording)
        if isRecording {
            let recordingDotRect = CGRect(x: dotsStartX, y: dotY, width: dotSize, height: dotSize)
            context.setFillColor(UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.8).cgColor)  // Subtle red
            context.fillEllipse(in: recordingDotRect)
        }
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
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            if frameCount % 100 == 0 {
                print("❌ composeFrame: No image buffer in sample buffer!")
            }
            return nil
        }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        // Check if camera frames are changing by sampling pixel data (every 120 frames = 4 seconds)
        if frameCount % 120 == 0 {
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            // Sample a few bytes to create a simple hash
            if let addr = baseAddress {
                let ptr = addr.assumingMemoryBound(to: UInt8.self)
                var hash = 0
                // Sample pixels from different parts of the frame
                for i in [0, bytesPerRow/4, bytesPerRow/2, bytesPerRow*3/4, bytesPerRow] {
                    hash ^= Int(ptr[i])
                }

                if hash == lastFrameHash && frameCount > 0 {
                    duplicateFrameCount += 1
                    print("⚠️ Frame \(frameCount): Camera frame appears IDENTICAL to previous frame! (duplicates: \(duplicateFrameCount))")
                } else {
                    if duplicateFrameCount > 0 {
                        print("✅ Frame \(frameCount): Camera frame is DIFFERENT (frame content is changing)")
                    }
                    duplicateFrameCount = 0
                }
                lastFrameHash = hash
            }
        }

        // Create output pixel buffer
        guard let pixelBufferPool = pixelBufferAdaptor?.pixelBufferPool else {
            return nil
        }

        var outputPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &outputPixelBuffer)

        guard status == kCVReturnSuccess, let outputBuffer = outputPixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        // Create graphics context
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(outputBuffer),
            width: CVPixelBufferGetWidth(outputBuffer),
            height: CVPixelBufferGetHeight(outputBuffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(outputBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        // Draw camera frame (use reusable ciContext - creating new context each frame kills performance!)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        // Convert to CGImage without rotation first
        guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // Get output dimensions
        let outputWidth = CVPixelBufferGetWidth(outputBuffer)
        let outputHeight = CVPixelBufferGetHeight(outputBuffer)

        // Apply rotation using CGContext transform instead of CIImage.oriented()
        // This ensures proper aspect ratio handling
        context.saveGState()

        let rotationAngle = connection.videoRotationAngle

        // Log rotation angle for debugging (only log every 120 frames to reduce memory)
        if frameCount % 120 == 0 {
            print("📹 Rotation: \(rotationAngle)° | Frame: \(frameCount)")
        }

        // Apply orientation correction based on videoRotationAngle
        // Note: videoRotationAngle tells us how much the video needs to be rotated to appear upright
        // The camera was producing upside-down video, so we need 180° rotation for landscape
        switch rotationAngle {
        case 90:
            // Portrait: rotate 90° clockwise
            context.translateBy(x: CGFloat(outputWidth), y: 0)
            context.rotate(by: .pi / 2)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(outputHeight), height: CGFloat(outputWidth)))

        case 180:
            // Landscape Left: rotate 180°
            context.translateBy(x: CGFloat(outputWidth), y: CGFloat(outputHeight))
            context.rotate(by: .pi)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(outputWidth), height: CGFloat(outputHeight)))

        case 270:
            // Portrait Upside Down: rotate 270° clockwise (or -90°)
            context.translateBy(x: 0, y: CGFloat(outputHeight))
            context.rotate(by: -.pi / 2)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(outputHeight), height: CGFloat(outputWidth)))

        default:
            // 0 or other = Landscape Right
            // Since video was upside-down with no rotation, apply 180° correction
            context.translateBy(x: CGFloat(outputWidth), y: CGFloat(outputHeight))
            context.rotate(by: .pi)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(outputWidth), height: CGFloat(outputHeight)))
        }

        context.restoreGState()

        // CRITICAL FIX: Read overlay image with explicit lock to ensure memory visibility
        // Even though we're on videoQueue, we need proper synchronization to see updates from main thread
        overlayLock.lock()
        let overlayImage = currentOverlayImage
        overlayLock.unlock()

        // Log overlay read every 120 frames (4 seconds) - reduced for memory
        if frameCount % 120 == 0 {
            print("🔒 Frame \(frameCount): Read overlay - \(overlayImage != nil ? "GOT IMAGE" : "NIL")")
            if let img = overlayImage {
                let pointer = Unmanaged.passUnretained(img).toOpaque()
                print("   READ UIImage pointer: \(String(describing: pointer))")
            }
        }

        if let overlayImage = overlayImage, let cgImage = overlayImage.cgImage {
            let overlayRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(outputBuffer), height: CVPixelBufferGetHeight(outputBuffer))

            // Set blend mode to normal with alpha compositing (ensures overlay appears on top)
            context.setBlendMode(.normal)

            // Draw overlay image
            context.draw(cgImage, in: overlayRect)

            // IMPORTANT: Flush context to ensure drawing is committed to pixel buffer
            context.flush()

            // Log every 120 frames (4 seconds) - reduced for memory
            if frameCount % 120 == 0 {
                let imagePointer = Unmanaged.passUnretained(cgImage).toOpaque()
                print("🎨 Drawing overlay on frame \(frameCount)")
                print("   CGImage pointer: \(String(describing: imagePointer))")
                if let game = currentLiveGame {
                    print("   Game data: \(game.teamName) \(game.homeScore)-\(game.awayScore) | \(game.currentClockDisplay)")
                }
            }
        } else {
            // Log if overlay is missing
            if frameCount % 30 == 0 {
                print("⚠️ NO OVERLAY IMAGE to draw on frame \(frameCount)")
                print("   currentOverlayImage: \(currentOverlayImage != nil ? "exists" : "nil")")
                if let img = currentOverlayImage {
                    print("   cgImage: \(img.cgImage != nil ? "exists" : "nil")")
                }
            }
        }

        return outputBuffer
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
                print("⚠️ captureOutput called but isRecording=false")
            }
            return
        }

        // Log first few delegate callbacks
        if frameCount < 3 {
            if output == videoDataOutput {
                print("📹 captureOutput: VIDEO frame received (frameCount: \(frameCount))")
            } else if output == audioDataOutput {
                print("🔊 captureOutput: AUDIO sample received")
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
                print("⚠️ handleVideoFrame: Missing writer/input/adaptor")
                return
            }

            // Start writing on first frame
            if recordingStartTime == nil {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                recordingStartTime = timestamp
                lastVideoTimestamp = timestamp

                print("🎬 First video frame received!")
                print("   Timestamp: \(CMTimeGetSeconds(timestamp))s")
                print("   Writer status: \(writer.status.rawValue)")

                if writer.status == .unknown {
                    writer.startWriting()
                    writer.startSession(atSourceTime: timestamp)
                    print("✅ Started asset writer session at time: \(CMTimeGetSeconds(timestamp))")
                } else {
                    print("⚠️ Writer status not .unknown, it's: \(writer.status.rawValue)")
                }
            }

            guard writer.status == .writing else {
                if writer.status == .failed {
                    print("❌ Asset writer failed: \(String(describing: writer.error))")
                } else if frameCount < 5 {
                    // Log status issues for first few frames
                    print("⚠️ Writer status not .writing: \(writer.status.rawValue)")
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
                        print("⚠️ DUPLICATE TIMESTAMP! Frame #\(frameCount) has same timestamp as previous frame: \(CMTimeGetSeconds(adjustedTimestamp))s")
                    }

                    lastVideoTimestamp = adjustedTimestamp
                    frameCount += 1

                    // Log first 5 frames, then every 30 frames
                    if frameCount <= 5 || frameCount % 30 == 0 {
                        print("📹 Written frame #\(frameCount) at \(String(format: "%.3f", CMTimeGetSeconds(adjustedTimestamp)))s")
                    }
                } else {
                    print("❌ Failed to compose frame at \(CMTimeGetSeconds(adjustedTimestamp))s")
                }
            } else {
                // Frame dropped because input not ready
                if frameCount < 5 {
                    print("⚠️ Video input not ready for frame (frameCount: \(frameCount))")
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
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let adjustedTimestamp = CMTimeSubtract(timestamp, recordingStartTime ?? .zero)

            audioInput.append(sampleBuffer)
        }
    }
}
