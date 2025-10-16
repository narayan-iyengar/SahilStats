// CLEANED VideoRecordingManager.swift - Remove complex overlay logic

import Foundation
import AVFoundation
import UIKit
import Combine
import SwiftUI
import Photos



// Forward declaration to avoid missing type issues
extension VideoRecordingManager {
    // This ensures YouTubeUploadManager is available
}

class VideoRecordingManager: NSObject, ObservableObject {
    static let shared = VideoRecordingManager()

    // MARK: - Feature Flags
    /// Toggle between real-time overlay recording (Option 1) and post-processing (Option 2)
    /// - Option 1 (true): Burns overlay directly into video during recording - guaranteed preview/video match
    /// - Option 2 (false): Records clean video, adds overlay in post-processing - more stable multipeer connection
    static var useRealTimeOverlay: Bool = false  // MUST stay false - real-time causes high CPU and connection issues
    static var useLetterboxPreview: Bool = true  // Use .resizeAspect (letterbox) instead of .resizeAspectFill for camera preview

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var canRecordVideo = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var shouldShowSettingsAlert = false
    @Published var error: Error?
    @Published var currentZoomLevel: CGFloat = 1.0  // Current zoom level for indicator display
    private var outputURL: URL?
    //private var lastRecordingURL: URL?
    private var isSavingVideo = false  // Prevent duplicate saves

    var onCameraReady: (() -> Void)?
    
    
    
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var realtimeRecorder: RealTimeOverlayRecorder? // Real-time overlay recording
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var _previewLayer: AVCaptureVideoPreviewLayer?
    private var currentVideoDevice: AVCaptureDevice? // Reference to active camera device for zoom/focus control
    private var lastLiveActivityUpdateSecond: Int = -1 // Track last updated second to throttle Live Activity updates
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        return _previewLayer
    }

    var isCameraSessionRunning: Bool {
        return captureSession?.isRunning ?? false
    }

    var recordingTimeString: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Camera Session Management

    func startCameraSession() {
        guard !isRecording else { return }
        print("🎥 VideoRecordingManager: startCameraSession called")

        if _previewLayer == nil {
            print("🎥 VideoRecordingManager: Setting up camera hardware...")
            _ = setupCamera()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // IMPROVED: Add session interruption handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: captureSession
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // IMPROVED: Check session state before starting
            if let session = self.captureSession, !session.isRunning {
                print("🎥 VideoRecordingManager: Starting capture session...")
                session.startRunning()
                
                // Wait for session to fully start before updating orientation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🎥 VideoRecordingManager: Session started, updating orientation...")
                    self.updatePreviewOrientation()
                    
                    // Trigger the onCameraReady callback if set
                    self.onCameraReady?()
                }
            } else {
                DispatchQueue.main.async {
                    self.onCameraReady?()
                }
            }
        }
    }
    
    @objc private func sessionWasInterrupted(notification: NSNotification) {
        guard let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
              let reasonIntegerValue = userInfoValue.integerValue,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) else {
            print("⚠️ Camera session interrupted for unknown reason")
            return
        }
        
        print("⚠️ Camera session interrupted: \(reason)")
        
        switch reason {
        case .videoDeviceNotAvailableInBackground:
            print("📱 Camera not available in background")
        case .audioDeviceInUseByAnotherClient:
            print("🔊 Audio device in use by another client")
        case .videoDeviceInUseByAnotherClient:
            print("📷 Video device in use by another client")
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            print("📱 Camera not available with multiple foreground apps")
        default:
            print("⚠️ Other interruption reason: \(reason.rawValue)")
        }
    }
    
    @objc private func sessionInterruptionEnded(notification: NSNotification) {
        print("✅ Camera session interruption ended")
        
        // Restart session if needed
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  !session.isRunning else { return }
            
            print("🔄 Restarting camera session after interruption")
            session.startRunning()
        }
    }
    
    func stopCameraSession() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVCaptureSession.wasInterruptedNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVCaptureSession.interruptionEndedNotification, object: nil)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }
    
    @objc private func handleOrientationChange() {
        // Debounce orientation changes to avoid rapid updates
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updatePreviewOrientationDelayed), object: nil)
        perform(#selector(updatePreviewOrientationDelayed), with: nil, afterDelay: 0.3)
    }
    
    @objc private func updatePreviewOrientationDelayed() {
        updatePreviewOrientation()
    }
    
    func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection else {
            print("Preview layer connection not available")
            return
        }

        let orientation = UIDevice.current.orientation

        // Only handle valid orientations
        guard orientation != .unknown && orientation != .faceUp && orientation != .faceDown else {
            print("⚠️ Ignoring invalid orientation: \(orientation.rawValue)")
            return
        }

        let rotationAngle: CGFloat

        switch orientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            rotationAngle = 180  // Home button on left, camera on right
        case .landscapeRight:
            rotationAngle = 0    // Home button on right, camera on left (natural landscape)
        default:
            return
        }

        print("🔄 Updating preview orientation: \(orientation.rawValue) → \(rotationAngle)°")

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            UIView.animate(withDuration: 0.3) {
                connection.videoRotationAngle = rotationAngle
            }
        } else {
            print("⚠️ Rotation angle \(rotationAngle)° not supported")
        }
    }
    
    private func performOrientationUpdate(retryCount: Int = 0) {
        guard let connection = self.previewLayer?.connection else {
            // Retry up to 5 times with increasing delays
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(retryCount + 1)) {
                    self.performOrientationUpdate(retryCount: retryCount + 1)
                }
            } else {
                print("⚠️ Preview layer connection not available after \(retryCount) retries")
            }
            return
        }

        let orientation = UIDevice.current.orientation
        let rotationAngle: CGFloat

        switch orientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            rotationAngle = 180  // Swapped with landscapeRight
        case .landscapeRight:
            rotationAngle = 0    // Try 0° - scoreboard currently vertical on left
        default:
            print("⚠️ Invalid orientation in performOrientationUpdate: \(orientation.rawValue)")
            return
        }

        print("🔄 performOrientationUpdate: \(orientation.rawValue) → \(rotationAngle)°")

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        } else {
            print("⚠️ Rotation angle \(rotationAngle)° not supported in performOrientationUpdate")
        }
    }
    
    // MARK: - Permission Handling
    
    private func checkPermissions() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        updateCanRecordVideo()
    }
    
    func requestCameraAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            self.updateCanRecordVideo()
            if !granted {
                self.shouldShowSettingsAlert = true
            }
        }
    }
    
    private func updateCanRecordVideo() {
        canRecordVideo = authorizationStatus == .authorized
    }
    
    func openCameraSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Camera Setup
    
    func setupCamera() -> AVCaptureVideoPreviewLayer? {
        guard canRecordVideo else {
            print("❌ Camera access not granted")
            return nil
        }
        
        print("🎥 VideoRecordingManager: Setting up camera hardware...")
        configureAudioSession()
        
        do {
            let session = AVCaptureSession()

            // DON'T set session preset yet - it constrains ultra-wide zoom range!
            // We'll set it AFTER adding the camera input

            // IMPROVED: Use discovery session to find actual ultra-wide camera for 0.5x zoom
            var videoDevice: AVCaptureDevice?

            // For iPhone 13+ with ultra-wide, we need to discover the actual physical camera
            // The virtual device types (triple/dual camera) have minZoom of 1.0x
            print("📹 Discovering available cameras...")

            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInUltraWideCamera,  // iPhone 11+ ultra-wide (0.5x)
                    .builtInWideAngleCamera,  // Standard wide (1.0x)
                    .builtInTelephotoCamera,  // Telephoto (2x+)
                    .builtInTripleCamera,     // Virtual device
                    .builtInDualWideCamera,   // Virtual device
                    .builtInDualCamera        // Virtual device
                ],
                mediaType: .video,
                position: .back
            )

            // Log all available cameras
            print("📹 Found \(discoverySession.devices.count) camera(s):")
            for device in discoverySession.devices {
                print("   - \(device.localizedName): zoom \(device.minAvailableVideoZoomFactor)x - \(device.maxAvailableVideoZoomFactor)x")
            }

            // STRATEGY: Use physical ultra-wide camera as PRIMARY for full court coverage
            // Ultra-wide camera at 1.0x zoom gives the widest field of view
            // Can zoom in to 2x+ by increasing zoom factor

            // Priority 1: Use physical ultra-wide camera (best for full court view)
            videoDevice = discoverySession.devices.first { $0.deviceType == .builtInUltraWideCamera }
            if videoDevice != nil {
                print("📹 Using ultra-wide camera (1.0x = ultra-wide, zoom in for tighter shots)")
            }

            // Priority 2: Try virtual triple camera as fallback
            if videoDevice == nil {
                videoDevice = discoverySession.devices.first { $0.deviceType == .builtInTripleCamera }
                if videoDevice != nil {
                    print("📹 Using triple camera system (fallback)")
                }
            }

            // Priority 3: Try virtual dual wide camera
            if videoDevice == nil {
                videoDevice = discoverySession.devices.first { $0.deviceType == .builtInDualWideCamera }
                if videoDevice != nil {
                    print("📹 Using dual wide camera system (fallback)")
                }
            }

            // Priority 4: Try regular wide camera as last resort
            if videoDevice == nil {
                videoDevice = discoverySession.devices.first { $0.deviceType == .builtInWideAngleCamera }
                if videoDevice != nil {
                    print("⚠️ Using wide angle camera only (no ultra-wide available)")
                }
            }

            // Last resort: front camera
            if videoDevice == nil {
                let frontDiscovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: .front
                )
                videoDevice = frontDiscovery.devices.first
                if videoDevice != nil {
                    print("⚠️ Using front camera as last resort")
                }
            }

            guard let device = videoDevice else {
                print("❌ No camera device available at all")
                return nil
            }
            
            print("🎥 VideoRecordingManager: Found camera device: \(device.localizedName)")
            print("📹 Zoom range: \(device.minAvailableVideoZoomFactor)x - \(device.maxAvailableVideoZoomFactor)x")

            // Check virtual device switchover points (tells us actual available zoom range)
            if #available(iOS 13.0, *) {
                if let switchoverFactors = device.virtualDeviceSwitchOverVideoZoomFactors as? [NSNumber] {
                    let factors = switchoverFactors.map { $0.doubleValue }
                    print("📹 Virtual device camera switchover points: \(factors)")
                    print("   This means zoom below \(factors.first ?? 1.0)x will use constituent cameras")
                } else {
                    print("📹 Not a virtual device - no camera switching available")
                }
            }

            // Store device reference for zoom/focus controls
            self.currentVideoDevice = device

            // IMPROVED: Configure device settings before creating input
            do {
                try device.lockForConfiguration()
                
                // Set focus and exposure modes for better video
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                
                // Set frame rate from user preferences
                let formatDescription = device.activeFormat.formatDescription
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                print("📹 Camera resolution: \(dimensions.width)x\(dimensions.height)")

                let desiredFPS = Int32(CameraSettingsManager.shared.settings.frameRate.rawValue)
                for range in device.activeFormat.videoSupportedFrameRateRanges {
                    if range.minFrameRate <= Float64(desiredFPS) && range.maxFrameRate >= Float64(desiredFPS) {
                        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: desiredFPS)
                        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: desiredFPS)
                        print("📹 Set frame rate to \(desiredFPS)fps from user settings")
                        break
                    }
                }

                // Enable video stabilization if requested
                if CameraSettingsManager.shared.settings.stabilizationEnabled {
                    print("📹 Video stabilization enabled in settings")
                }
                
                device.unlockForConfiguration()
                print("✅ Camera device configured for optimal stability")
                
            } catch {
                print("⚠️ Could not configure camera device: \(error)")
                // Continue anyway - basic functionality should still work
            }
            
            let videoInput = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("✅ Video input added to session")

                // EXPERIMENTAL: Try NOT setting session preset to preserve full zoom range
                // Let the device use its default active format
                print("📹 Using device default format (no session preset) to preserve full zoom range")
            } else {
                print("❌ Cannot add video input")
                return nil
            }

            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    print("✅ Audio input added to session")
                }
            }

            // Choose recording method based on feature flag
            if Self.useRealTimeOverlay {
                // OPTION 1: Use real-time overlay recorder (burns overlay during recording)
                print("🎨 Setting up real-time overlay recorder (Option 1)...")
                let recorder = RealTimeOverlayRecorder()
                if recorder.setupOutputs(for: session) {
                    self.realtimeRecorder = recorder
                    print("✅ Real-time overlay recorder setup complete")
                    print("   📹 Overlay will be burned into video during recording")
                } else {
                    print("❌ Failed to setup real-time recorder, falling back to post-processing")
                    // Fallback to traditional recording
                    let movieOutput = AVCaptureMovieFileOutput()
                    if session.canAddOutput(movieOutput) {
                        session.addOutput(movieOutput)
                        self.videoOutput = movieOutput
                        print("✅ Movie output added - will use post-processing")
                    } else {
                        print("❌ Failed to add movie output")
                    }
                }
            } else {
                // OPTION 2: Use traditional recording with post-processing overlay
                print("🎬 Setting up traditional recording (Option 2 - post-processing)...")
                let movieOutput = AVCaptureMovieFileOutput()
                if session.canAddOutput(movieOutput) {
                    session.addOutput(movieOutput)
                    self.videoOutput = movieOutput
                    print("✅ Movie output added - will use post-processing overlay")
                } else {
                    print("❌ Failed to add movie output")
                }
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self._previewLayer = previewLayer
            
            print("✅ Camera hardware setup completed successfully")
            
            return previewLayer
            
        } catch {
            print("❌ Camera setup error: \(error)")
            self.error = error
            return nil
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // --- FIX: More robust audio session configuration for video recording ---
            try audioSession.setCategory(.playAndRecord,
                                       mode: .videoRecording,
                                       options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully")
            
        } catch let error as NSError {
            print("❌ Audio session setup failed: \(error.localizedDescription)")
            print("   Error code: \(error.code)")
            print("   Error domain: \(error.domain)")
            
            // --- FIX: Add a simpler fallback configuration ---
            do {
                print("⚠️ Trying fallback audio session configuration...")
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .default)
                try audioSession.setActive(true)
                print("✅ Audio session configured with fallback settings")
            } catch {
                print("❌ Even fallback audio session failed: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
    
    


    /// Checks for camera permission without requesting it.
    func checkForCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            // If not determined, we must request it.
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            // Denied, restricted.
            return false
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording(liveGame: LiveGame? = nil) async {
        print("🎥 VideoRecordingManager: startRecording() called")
        print("   Feature flag: useRealTimeOverlay = \(Self.useRealTimeOverlay)")
        print("   realtimeRecorder exists: \(realtimeRecorder != nil)")
        print("   videoOutput exists: \(videoOutput != nil)")
        print("   isRecording: \(isRecording)")
        print("   captureSession running: \(captureSession?.isRunning ?? false)")

        guard !isRecording else {
            print("❌ Cannot start recording - already recording")
            return
        }

        guard let game = liveGame else {
            print("❌ Cannot start recording - liveGame is required")
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).mov")

        // Store the URL
        self.outputURL = outputURL
        print("🎥 Recording to: \(outputURL)")

        // Choose recording method based on feature flag
        if Self.useRealTimeOverlay, let recorder = realtimeRecorder {
            // OPTION 1: Real-time overlay recording
            print("🎨 Starting real-time overlay recording (Option 1)...")

            if let recordingURL = recorder.startRecording(liveGame: game) {
                // Update outputURL to match what recorder returned
                self.outputURL = recordingURL

                await MainActor.run {
                    self.isRecording = true
                    self.recordingStartTime = Date()
                    self.startRecordingTimer()

                    // Real-time recorder manages its own game state
                    // No need for ScoreTimelineTracker

                    // Update Live Activity (disabled via feature flag for recorder device)
                    LiveActivityManager.shared.updateRecordingState(isRecording: true)
                    print("✅ Real-time recording started - isRecording=true")
                }
            } else {
                print("❌ Failed to start real-time recording")
            }

        } else if let videoOutput = videoOutput {
            // OPTION 2: Traditional recording with post-processing
            print("🎬 Starting traditional recording (Option 2 - post-processing)...")

            // Set video orientation and stabilization on recording connection
            if let connection = videoOutput.connection(with: .video) {
                let deviceOrientation = UIDevice.current.orientation
                let rotationAngle: CGFloat

                switch deviceOrientation {
                case .portrait:
                    rotationAngle = 90
                case .portraitUpsideDown:
                    rotationAngle = 270
                case .landscapeLeft:
                    rotationAngle = 270  // Match preview orientation
                case .landscapeRight:
                    rotationAngle = 180  // FIXED: Match preview orientation
                default:
                    rotationAngle = 180 // Default to landscape right
                }

                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                    print("🎥 Set recording orientation to \(rotationAngle)° for device orientation: \(deviceOrientation.rawValue)")
                } else {
                    print("⚠️ Rotation angle \(rotationAngle)° NOT SUPPORTED - trying alternatives")
                    let supportedAngles = [0.0, 90.0, 180.0, 270.0].filter { connection.isVideoRotationAngleSupported($0) }
                    print("   Supported angles: \(supportedAngles)")
                }

                // Apply video stabilization from settings
                if CameraSettingsManager.shared.settings.stabilizationEnabled {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                        print("🎥 Video stabilization enabled for recording")
                    } else {
                        print("⚠️ Video stabilization not supported on this device/connection")
                    }
                }
            }

            videoOutput.startRecording(to: outputURL, recordingDelegate: self)
            print("🎥 AVCaptureMovieFileOutput.startRecording() called")

            await MainActor.run {
                self.isRecording = true
                self.recordingStartTime = Date()
                self.startRecordingTimer()

                // Start tracking score timeline for post-processing
                ScoreTimelineTracker.shared.startRecording(initialGame: game)

                // Update Live Activity (disabled via feature flag for recorder device)
                LiveActivityManager.shared.updateRecordingState(isRecording: true)
                print("✅ Recording state updated - isRecording=true")
            }
        } else {
            print("❌ Cannot start recording - no recording output available")
        }
    }
    
    func getLastRecordingURL() -> URL? {
        return outputURL
    }

    /// Update game data during recording
    /// - Option 1: Feeds real-time recorder to update overlay immediately
    /// - Option 2: Tracked in ScoreTimelineTracker for post-processing
    func updateGameData(_ liveGame: LiveGame) {
        if Self.useRealTimeOverlay, let recorder = realtimeRecorder {
            // OPTION 1: Update real-time recorder
            recorder.updateGame(liveGame)
            print("🎨 Real-time overlay updated with game data")
        } else {
            // OPTION 2: Track for post-processing
            // Score timeline is automatically tracked by ScoreTimelineTracker
            // No action needed here - GPU will handle overlay during export
            print("📊 Game data tracked for post-processing")
        }
    }

    /// Show end game banner with final score and winner
    /// - Only works with real-time overlay recording (Option 1)
    func showEndGameBanner(liveGame: LiveGame) {
        if Self.useRealTimeOverlay, let recorder = realtimeRecorder {
            recorder.showEndGameBanner(game: liveGame)
            print("🏆 End game banner shown in real-time recorder")
        } else {
            print("⚠️ End game banner not supported in post-processing mode")
        }
    }

    func stopRecording() async {
        guard isRecording else { return }

        print("🎥 Stopping recording...")
        print("   Feature flag: useRealTimeOverlay = \(Self.useRealTimeOverlay)")

        // Choose stop method based on feature flag
        if Self.useRealTimeOverlay, let recorder = realtimeRecorder {
            // OPTION 1: Stop real-time recording (async with completion)
            print("🎨 Stopping real-time overlay recording (Option 1)...")

            await withCheckedContinuation { continuation in
                recorder.stopRecording { url in
                    if let url = url {
                        print("✅ Real-time recording saved to: \(url)")
                        self.outputURL = url
                    } else {
                        print("❌ Real-time recording failed")
                    }
                    continuation.resume()
                }
            }
        } else if let videoOutput = videoOutput {
            // OPTION 2: Stop traditional recording
            print("🎬 Stopping traditional recording (Option 2)...")
            videoOutput.stopRecording()
        }

        await MainActor.run {
            self.isRecording = false
            self.recordingStartTime = nil
            self.stopRecordingTimer()

            // DON'T call ScoreTimelineTracker.stopRecording() here
            // It will be called later when saving the video to get the timeline

            // Update Live Activity (disabled via feature flag for recorder device)
            LiveActivityManager.shared.updateRecordingState(isRecording: false)
            print("✅ Recording stopped - isRecording=false")
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)

            // Update Live Activity (disabled via feature flag for recorder device)
            let currentSecond = Int(self.recordingDuration)
            if currentSecond != self.lastLiveActivityUpdateSecond && currentSecond > 0 {
                self.lastLiveActivityUpdateSecond = currentSecond
                Task { @MainActor in
                    LiveActivityManager.shared.updateRecordingState(
                        isRecording: true,
                        duration: self.recordingTimeString
                    )
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
        lastLiveActivityUpdateSecond = -1  // Reset throttle for next recording
    }
    
    // MARK: - Additional Camera Controls (from your existing code)
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.isTorchActive ? .off : .on
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle failed: \(error)")
        }
    }
    
    func capturePhoto() {
        // Implement photo capture if needed
        print("Photo capture requested")
    }
    
    func flipCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove current video input
        for input in session.inputs {
            if let videoInput = input as? AVCaptureDeviceInput,
               videoInput.device.hasMediaType(.video) {
                session.removeInput(videoInput)
            }
        }
        
        // Add new video input with opposite camera
        do {
            let currentPosition: AVCaptureDevice.Position = .back // You'll need to track this
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                         for: .video,
                                                         position: newPosition) else {
                session.commitConfiguration()
                return
            }
            
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print("Camera flip failed: \(error)")
        }
        
        session.commitConfiguration()
    }

    // MARK: - Advanced Camera Controls

    /// Set camera zoom level (0.5x = ultra-wide, 1.0 = wide, 2.0+ = telephoto)
    /// Requires device with multi-camera support for 0.5x zoom
    /// Returns the actual zoom factor applied (clamped to device limits)
    @discardableResult
    func setZoom(factor: CGFloat) -> CGFloat {
        guard let device = currentVideoDevice else {
            print("⚠️ Cannot set zoom - no video device")
            return 1.0
        }

        // Clamp zoom factor to device capabilities
        let clampedFactor = max(device.minAvailableVideoZoomFactor,
                               min(factor, device.maxAvailableVideoZoomFactor))

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()

            // Update published zoom level for UI display
            Task { @MainActor in
                self.currentZoomLevel = clampedFactor
            }

            return clampedFactor
        } catch {
            print("⚠️ Failed to set zoom: \(error)")
            return device.videoZoomFactor
        }
    }

    /// Get current zoom factor
    func getCurrentZoom() -> CGFloat {
        return currentVideoDevice?.videoZoomFactor ?? 1.0
    }

    /// Get minimum allowed zoom factor (0.5x for ultra-wide cameras)
    func getMinZoom() -> CGFloat {
        return currentVideoDevice?.minAvailableVideoZoomFactor ?? 1.0
    }

    /// Get maximum allowed zoom factor
    func getMaxZoom() -> CGFloat {
        return currentVideoDevice?.maxAvailableVideoZoomFactor ?? 1.0
    }

    /// Get current video device (for gesture recognizers)
    func getCurrentVideoDevice() -> AVCaptureDevice? {
        return currentVideoDevice
    }

    /// Focus camera at a specific point in the preview (0,0 = top-left, 1,1 = bottom-right)
    /// Point coordinates should be normalized (0.0 to 1.0)
    func focusAt(point: CGPoint) {
        guard let device = currentVideoDevice else {
            print("⚠️ Cannot focus - no video device")
            return
        }

        guard device.isFocusPointOfInterestSupported,
              device.isFocusModeSupported(.autoFocus) else {
            print("⚠️ Focus point of interest not supported on this device")
            return
        }

        do {
            try device.lockForConfiguration()

            // Set focus point
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus

            // Also set exposure point for better results
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
            print("📍 Focus set to point: (\(String(format: "%.2f", point.x)), \(String(format: "%.2f", point.y)))")
        } catch {
            print("⚠️ Failed to set focus: \(error)")
        }
    }

    /// Reset to continuous autofocus mode
    func resetFocus() {
        guard let device = currentVideoDevice else { return }

        guard device.isFocusModeSupported(.continuousAutoFocus) else { return }

        do {
            try device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus

            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
            print("🔄 Reset to continuous autofocus")
        } catch {
            print("⚠️ Failed to reset focus: \(error)")
        }
    }

    func cleanup() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        _previewLayer = nil
        currentVideoDevice = nil
        stopRecordingTimer()
    }
    

    
    /// Saves the last recorded video to the user's photo library (requires user permission).
    @MainActor
    func saveToPhotoLibrary() async {
        guard let url = getLastRecordingURL() else {
            print("❌ No video to save to photo library")
            return
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if newStatus != .authorized && newStatus != .limited {
                print("❌ Photo Library access denied")
                return
            }
        } else if status != .authorized && status != .limited {
            print("❌ Photo Library access denied")
            return
        }
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if success {
                    print("✅ Video saved to photo library")
                } else {
                    print("❌ Failed to save video to photo library: \(error?.localizedDescription ?? "Unknown error")")
                }
                continuation.resume()
            }
        }
    }
    
    /// Handles saving recording and queuing for upload - used by recording view
    /// Returns the local video URL for storage in the game record
    @discardableResult
    func saveRecordingAndQueueUpload(liveGame: LiveGame, scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot]) async -> URL? {
        // Prevent duplicate saves
        guard !isSavingVideo else {
            print("⚠️ Already saving video - skipping duplicate save")
            return nil
        }

        isSavingVideo = true
        defer { isSavingVideo = false }

        let gameId = liveGame.id ?? "unknown"
        let teamName = liveGame.teamName
        let opponent = liveGame.opponent

        print("📹 saveRecordingAndQueueUpload called")
        print("   Game ID: \(gameId)")
        print("   Teams: \(teamName) vs \(opponent)")
        print("   Score timeline: \(scoreTimeline.count) snapshots")
        print("   outputURL: \(String(describing: outputURL))")

        guard let originalURL = outputURL else {
            print("❌ No recording to save and queue - outputURL is nil")
            return nil
        }

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: originalURL.path)
        print("   File exists at outputURL: \(fileExists)")

        if !fileExists {
            print("❌ Recording file does not exist at path: \(originalURL.path)")
            return nil
        }

        // Save score timeline for future reference (only used in fallback mode)
        ScoreTimelineTracker.shared.saveTimeline(scoreTimeline, forGameId: gameId)

        let compositedURL: URL

        // Choose post-processing based on feature flag
        if Self.useRealTimeOverlay {
            // OPTION 1: Real-time recording - overlay already burned in, skip post-processing
            print("🎨 Using real-time recording (Option 1) - overlay already in video, skipping post-processing")
            compositedURL = originalURL

        } else {
            // OPTION 2: Traditional recording - add overlay via post-processing
            print("🎨 Adding GPU-accelerated overlay with Core Animation (Option 2 - post-processing)...")

            compositedURL = await withCheckedContinuation { continuation in
                HardwareAcceleratedOverlayCompositor.addAnimatedOverlay(
                    to: originalURL,
                    scoreTimeline: scoreTimeline
                ) { result in
                    switch result {
                    case .success(let url):
                        print("✅ GPU-accelerated overlay added successfully")
                        continuation.resume(returning: url)
                    case .failure(let error):
                        print("❌ Overlay composition failed: \(error)")
                        print("   Falling back to original video")
                        continuation.resume(returning: originalURL)
                    }
                }
            }
        }

        // Generate title and description
        let title = "🏀 \(teamName) vs \(opponent) - \(Date().formatted(date: .abbreviated, time: .shortened))"
        let description = """
        Game Recording
        \(teamName) vs \(opponent)
        Score: \(liveGame.homeScore)-\(liveGame.awayScore)
        Recorded: \(Date().formatted(date: .complete, time: .shortened))
        Game ID: \(gameId)

        Automatically uploaded by SahilStats
        """

        print("📹 Queuing video for upload with title: \(title)")

        // IMPORTANT: Copy the file for YouTube upload before saving to Photos
        // Photos library MOVES the file, so we need a separate copy for YouTube
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let youtubeURL = documentsPath.appendingPathComponent("youtube_\(Date().timeIntervalSince1970).mov")

        do {
            try FileManager.default.copyItem(at: compositedURL, to: youtubeURL)
            print("✅ Created copy for YouTube upload at: \(youtubeURL.lastPathComponent)")

            // Queue the COPY for upload (not the original)
            YouTubeUploadManager.shared.queueVideoForUpload(
                videoURL: youtubeURL,
                title: title,
                description: description,
                gameId: gameId
            )

            print("✅ Video queued for YouTube upload, now saving composited video to photo library")
        } catch {
            print("❌ Failed to create copy for YouTube: \(error)")
            // Fallback: still try to queue the composited video
            YouTubeUploadManager.shared.queueVideoForUpload(
                videoURL: compositedURL,
                title: title,
                description: description,
                gameId: gameId
            )
        }

        // Update outputURL to point to composited video for photo library save
        self.outputURL = compositedURL

        // Save the composited video to photo library
        await saveToPhotoLibrary()

        // IMPORTANT: Store video URL in Firebase immediately (don't wait for YouTube upload)
        // This ensures the video is available in game details even if YouTube upload is disabled
        print("📹 Storing local video URL in Firebase...")
        await FirebaseService.shared.updateGameVideoURL(gameId: gameId, videoURL: youtubeURL.path)
        print("✅ Local video URL stored in Firebase: \(youtubeURL.path)")

        print("✅ saveRecordingAndQueueUpload completed")

        // Clear outputURL to prevent duplicate saves
        self.outputURL = nil

        // Return the youtube copy URL (the one that persists)
        return youtubeURL
    }

}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("🎥 fileOutput delegate called - recording finished")
        print("   Output URL: \(outputFileURL)")
        print("   Error: \(String(describing: error))")

        if let error = error {
            print("❌ Recording failed: \(error)")
            DispatchQueue.main.async {
                self.error = error
            }
        } else {
            // Check if file exists
            let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
            print("   File exists: \(fileExists)")

            if fileExists {
                print("✅ Recording saved successfully to: \(outputFileURL)")
                // Store the last successful recording
                DispatchQueue.main.async {
                    self.outputURL = outputFileURL
                    print("   outputURL stored in VideoRecordingManager")
                }
            } else {
                print("❌ Recording file does not exist at expected path")
            }
        }
    }
}
