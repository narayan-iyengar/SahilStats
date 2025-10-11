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

    // Output
    private var outputURL: URL?

    // Reusable CI context for frame composition (creating this is expensive!)
    private lazy var ciContext: CIContext = {
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    // MARK: - Public API

    func setupOutputs(for session: AVCaptureSession) -> Bool {
        print("🎥 RealTimeOverlayRecorder: Setting up outputs")

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

        guard !isRecording else {
            print("❌ Already recording")
            return nil
        }

        // Store game for overlay updates
        self.currentLiveGame = liveGame

        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent("realtime_\(Date().timeIntervalSince1970).mov")
        self.outputURL = url

        // Initialize asset writer
        guard setupAssetWriter(outputURL: url) else {
            print("❌ Failed to setup asset writer")
            return nil
        }

        // Start overlay update timer
        startOverlayUpdates()

        isRecording = true
        recordingStartTime = nil // Will be set on first frame
        frameCount = 0 // Reset frame counter

        print("✅ Recording started, output URL: \(url.lastPathComponent)")
        return url
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        print("🎥 RealTimeOverlayRecorder: Stopping recording")
        print("   Total frames written: \(frameCount)")

        guard isRecording else {
            print("❌ Not currently recording")
            completion(nil)
            return
        }

        isRecording = false
        stopOverlayUpdates()

        // Finish writing
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        guard let writer = assetWriter else {
            print("❌ No asset writer")
            completion(nil)
            return
        }

        let outputURL = self.outputURL

        writer.finishWriting {
            DispatchQueue.main.async {
                if writer.status == .completed {
                    print("✅ Recording completed successfully")
                    completion(outputURL)
                } else if let error = writer.error {
                    print("❌ Recording failed: \(error)")
                    completion(nil)
                } else {
                    print("❌ Recording failed with unknown error")
                    completion(nil)
                }
            }
        }
    }

    func updateGame(_ liveGame: LiveGame) {
        self.currentLiveGame = liveGame
        // Overlay will be updated on next timer tick
    }

    // MARK: - Asset Writer Setup

    private func setupAssetWriter(outputURL: URL) -> Bool {
        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

            // Video input settings - 720p for good quality and performance
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6_000_000, // 6 Mbps
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            // Set video transform for landscape recording
            let deviceOrientation = UIDevice.current.orientation
            let transform: CGAffineTransform

            switch deviceOrientation {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: .pi / 2) // 90 degrees
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: -.pi / 2) // -90 degrees
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: .pi) // 180 degrees
            default: // portrait or unknown
                transform = .identity
            }
            videoInput.transform = transform

            if writer.canAdd(videoInput) {
                writer.add(videoInput)
                self.videoWriterInput = videoInput
                print("✅ Added video input to asset writer")
            } else {
                print("❌ Cannot add video input")
                return false
            }

            // Pixel buffer adaptor
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 1280,
                kCVPixelBufferHeightKey as String: 720
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
        // Update overlay 4 times per second for real-time feel
        overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateOverlay()
        }
        RunLoop.current.add(overlayUpdateTimer!, forMode: .common)

        // Generate initial overlay
        updateOverlay()
    }

    private func stopOverlayUpdates() {
        overlayUpdateTimer?.invalidate()
        overlayUpdateTimer = nil
    }

    private func updateOverlay() {
        guard let game = currentLiveGame else { return }

        // Generate overlay image
        let overlayImage = renderOverlayImage(for: game)

        // Store for frame composition
        videoQueue.async {
            self.currentOverlayImage = overlayImage
        }
    }

    private func renderOverlayImage(for game: LiveGame) -> UIImage? {
        // Render size matches video resolution
        let size = CGSize(width: 1280, height: 720)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Clear background (transparent)
            cgContext.clear(CGRect(origin: .zero, size: size))

            // Draw scoreboard overlay
            drawScoreboardOverlay(in: cgContext, size: size, game: game)
        }

        return image
    }

    private func drawScoreboardOverlay(in context: CGContext, size: CGSize, game: LiveGame) {
        // Match SwiftUI SimpleScoreOverlay design
        let scaleFactor = size.height / 375.0 // Scale based on video height

        let scoreboardWidth: CGFloat = 246 * scaleFactor
        let scoreboardHeight: CGFloat = 56 * scaleFactor

        // Position at bottom center
        let scoreboardRect = CGRect(
            x: (size.width - scoreboardWidth) / 2,
            y: size.height - scoreboardHeight - (40 * scaleFactor),
            width: scoreboardWidth,
            height: scoreboardHeight
        )

        // Semi-transparent background
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(scoreboardRect)

        // Border
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1)
        context.stroke(scoreboardRect)

        // Corner radius (approximate - Core Graphics doesn't have native rounded rect with individual corners)
        let cornerRadius = 14 * scaleFactor
        let path = UIBezierPath(roundedRect: scoreboardRect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fillPath()

        // Text attributes
        let homeTeamName = formatTeamName(game.teamName, maxLength: 4)
        let awayTeamName = formatTeamName(game.opponent, maxLength: 4)
        let periodText = formatPeriod(quarter: game.quarter, gameFormat: game.gameFormat)
        let clockText = game.currentClockDisplay

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

    private func composeFrame(from sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

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
        if let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(outputBuffer), height: CVPixelBufferGetHeight(outputBuffer)))
        }

        // Draw overlay
        if let overlayImage = currentOverlayImage, let cgImage = overlayImage.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(outputBuffer), height: CVPixelBufferGetHeight(outputBuffer)))
        }

        return outputBuffer
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

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }

        if output == videoDataOutput {
            handleVideoFrame(sampleBuffer)
        } else if output == audioDataOutput {
            handleAudioSample(sampleBuffer)
        }
    }

    private func handleVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter,
              let videoInput = videoWriterInput,
              let adaptor = pixelBufferAdaptor else {
            return
        }

        // Start writing on first frame
        if recordingStartTime == nil {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            recordingStartTime = timestamp
            lastVideoTimestamp = timestamp

            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: timestamp)
                print("✅ Started asset writer session at time: \(CMTimeGetSeconds(timestamp))")
            }
        }

        guard writer.status == .writing else {
            if writer.status == .failed {
                print("❌ Asset writer failed: \(String(describing: writer.error))")
            }
            return
        }

        // Write frame if input is ready
        if videoInput.isReadyForMoreMediaData {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Adjust timestamp relative to recording start
            let adjustedTimestamp = CMTimeSubtract(timestamp, recordingStartTime ?? .zero)

            // Compose frame with overlay
            if let composedPixelBuffer = composeFrame(from: sampleBuffer) {
                adaptor.append(composedPixelBuffer, withPresentationTime: adjustedTimestamp)
                lastVideoTimestamp = adjustedTimestamp
                frameCount += 1

                // Log every 30 frames (roughly once per second at 30fps)
                if frameCount % 30 == 0 {
                    print("📹 Written \(frameCount) frames (\(String(format: "%.1f", CMTimeGetSeconds(adjustedTimestamp)))s)")
                }
            } else {
                print("❌ Failed to compose frame at \(CMTimeGetSeconds(adjustedTimestamp))s")
            }
        } else {
            // Frame dropped because input not ready
            if frameCount == 0 {
                print("⚠️ Video input not ready for first frame!")
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
