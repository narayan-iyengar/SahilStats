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
        debugPrint("🎥 VideoRecordingManager: startCameraSession called")

        if _previewLayer == nil {
            debugPrint("🎥 VideoRecordingManager: Setting up camera hardware...")
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
                debugPrint("🎥 VideoRecordingManager: Starting capture session...")
                session.startRunning()
                
                // Wait for session to fully start before updating orientation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    debugPrint("🎥 VideoRecordingManager: Session started, updating orientation...")
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
            debugPrint("⚠️ Camera session interrupted for unknown reason")
            return
        }
        
        debugPrint("⚠️ Camera session interrupted: \(reason)")
        
        switch reason {
        case .videoDeviceNotAvailableInBackground:
            debugPrint("📱 Camera not available in background")
        case .audioDeviceInUseByAnotherClient:
            debugPrint("🔊 Audio device in use by another client")
        case .videoDeviceInUseByAnotherClient:
            debugPrint("📷 Video device in use by another client")
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            debugPrint("📱 Camera not available with multiple foreground apps")
        default:
            debugPrint("⚠️ Other interruption reason: \(reason.rawValue)")
        }
    }
    
    @objc private func sessionInterruptionEnded(notification: NSNotification) {
        forcePrint("✅ Camera session interruption ended")
        
        // Restart session if needed
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  !session.isRunning else { return }
            
            debugPrint("🔄 Restarting camera session after interruption")
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
            debugPrint("Preview layer connection not available")
            return
        }

        let orientation = UIDevice.current.orientation

        // Only handle valid orientations
        guard orientation != .unknown && orientation != .faceUp && orientation != .faceDown else {
            debugPrint("⚠️ Ignoring invalid orientation: \(orientation.rawValue)")
            return
        }

        let rotationAngle: CGFloat

        switch orientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            rotationAngle = 0    // Device home button on left - swapped back
        case .landscapeRight:
            rotationAngle = 180  // Device home button on right - swapped back
        default:
            return
        }

        debugPrint("🔄 Updating preview orientation: \(orientation.rawValue) → \(rotationAngle)°")

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            UIView.animate(withDuration: 0.3) {
                connection.videoRotationAngle = rotationAngle
            }
        } else {
            debugPrint("⚠️ Rotation angle \(rotationAngle)° not supported")
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
                debugPrint("⚠️ Preview layer connection not available after \(retryCount) retries")
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
            rotationAngle = 0    // Device home button on left - swapped back
        case .landscapeRight:
            rotationAngle = 180  // Device home button on right - swapped back
        default:
            debugPrint("⚠️ Invalid orientation in performOrientationUpdate: \(orientation.rawValue)")
            return
        }

        debugPrint("🔄 performOrientationUpdate: \(orientation.rawValue) → \(rotationAngle)°")

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        } else {
            debugPrint("⚠️ Rotation angle \(rotationAngle)° not supported in performOrientationUpdate")
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
            forcePrint("❌ Camera access not granted")
            return nil
        }
        
        debugPrint("🎥 VideoRecordingManager: Setting up camera hardware...")
        configureAudioSession()
        
        do {
            let session = AVCaptureSession()

            // Use camera settings from user preferences
            let settings = CameraSettingsManager.shared.settings
            let desiredPreset = settings.resolution.sessionPreset

            if session.canSetSessionPreset(desiredPreset) {
                session.sessionPreset = desiredPreset
                debugPrint("📹 Using \(settings.resolution.displayName) preset (\(settings.resolution.dimensions.width)×\(settings.resolution.dimensions.height))")
            } else {
                // Fallback to lower resolutions if preferred isn't supported
                debugPrint("⚠️ Preferred resolution \(settings.resolution.displayName) not supported, trying fallbacks...")

                if session.canSetSessionPreset(.hd1920x1080) {
                    session.sessionPreset = .hd1920x1080
                    debugPrint("📹 Using 1080p fallback preset")
                } else if session.canSetSessionPreset(.hd1280x720) {
                    session.sessionPreset = .hd1280x720
                    debugPrint("📹 Using 720p fallback preset")
                } else if session.canSetSessionPreset(.high) {
                    session.sessionPreset = .high
                    debugPrint("📹 Using high quality fallback preset")
                } else {
                    session.sessionPreset = .medium
                    debugPrint("⚠️ Using medium quality fallback preset (low-end device)")
                }
            }
            
            // IMPROVED: Try multiple camera fallbacks with ultra-wide support for 0.5x zoom
            var videoDevice: AVCaptureDevice?

            // First priority: Triple camera (ultra-wide 0.5x, wide 1x, telephoto 2x+) - iPhone 11 Pro and newer Pro models
            videoDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            if videoDevice != nil {
                debugPrint("📹 Using triple camera system (supports 0.5x ultra-wide zoom)")
            }

            // Second priority: Dual wide camera (ultra-wide 0.5x, wide 1x) - iPhone 11 and newer non-Pro models
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                if videoDevice != nil {
                    debugPrint("📹 Using dual wide camera system (supports 0.5x ultra-wide zoom)")
                }
            }

            // Third priority: Dual camera (wide, telephoto) - older iPhones
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                if videoDevice != nil {
                    debugPrint("⚠️ Using dual camera (no ultra-wide - 0.5x zoom not available)")
                }
            }

            // Fourth priority: Wide angle camera only
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                if videoDevice != nil {
                    debugPrint("⚠️ Using wide angle camera only (no ultra-wide - 0.5x zoom not available)")
                }
            }

            // Last resort: front camera
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                if videoDevice != nil {
                    debugPrint("⚠️ Using front camera as last resort")
                }
            }

            guard let device = videoDevice else {
                forcePrint("❌ No camera device available at all")
                return nil
            }
            
            debugPrint("🎥 VideoRecordingManager: Found camera device: \(device.localizedName)")
            debugPrint("📹 Zoom range: \(device.minAvailableVideoZoomFactor)x - \(device.maxAvailableVideoZoomFactor)x")

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
                debugPrint("📹 Camera resolution: \(dimensions.width)x\(dimensions.height)")

                let desiredFPS = Int32(CameraSettingsManager.shared.settings.frameRate.rawValue)
                for range in device.activeFormat.videoSupportedFrameRateRanges {
                    if range.minFrameRate <= Float64(desiredFPS) && range.maxFrameRate >= Float64(desiredFPS) {
                        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: desiredFPS)
                        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: desiredFPS)
                        debugPrint("📹 Set frame rate to \(desiredFPS)fps from user settings")
                        break
                    }
                }

                // Enable video stabilization if requested
                if CameraSettingsManager.shared.settings.stabilizationEnabled {
                    debugPrint("📹 Video stabilization enabled in settings")
                }
                
                device.unlockForConfiguration()
                debugPrint("✅ Camera device configured for optimal stability")
                
            } catch {
                debugPrint("⚠️ Could not configure camera device: \(error)")
                // Continue anyway - basic functionality should still work
            }
            
            let videoInput = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                debugPrint("✅ Video input added to session")
            } else {
                forcePrint("❌ Cannot add video input")
                return nil
            }
            
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    debugPrint("✅ Audio input added to session")
                }
            }

            // Setup traditional recording with post-processing overlay
            debugPrint("🎬 Setting up video recording with post-processing overlay...")
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                self.videoOutput = movieOutput
                debugPrint("✅ Movie output added - will use post-processing overlay")
            } else {
                forcePrint("❌ Failed to add movie output")
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self._previewLayer = previewLayer
            
            debugPrint("✅ Camera hardware setup completed successfully")
            
            return previewLayer
            
        } catch {
            forcePrint("❌ Camera setup error: \(error)")
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
            debugPrint("✅ Audio session configured successfully")
            
        } catch let error as NSError {
            forcePrint("❌ Audio session setup failed: \(error.localizedDescription)")
            debugPrint("   Error code: \(error.code)")
            debugPrint("   Error domain: \(error.domain)")
            
            // --- FIX: Add a simpler fallback configuration ---
            do {
                debugPrint("⚠️ Trying fallback audio session configuration...")
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .default)
                try audioSession.setActive(true)
                debugPrint("✅ Audio session configured with fallback settings")
            } catch {
                forcePrint("❌ Even fallback audio session failed: \(error.localizedDescription)")
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
        debugPrint("🎥 VideoRecordingManager: startRecording() called")
        debugPrint("   videoOutput exists: \(videoOutput != nil)")
        debugPrint("   isRecording: \(isRecording)")
        debugPrint("   captureSession running: \(captureSession?.isRunning ?? false)")

        guard !isRecording else {
            forcePrint("❌ Cannot start recording - already recording")
            return
        }

        guard let game = liveGame else {
            forcePrint("❌ Cannot start recording - liveGame is required")
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).mov")

        // Store the URL
        self.outputURL = outputURL
        debugPrint("🎥 Recording to: \(outputURL)")

        // Start recording with post-processing overlay
        if let videoOutput = videoOutput {
            debugPrint("🎬 Starting video recording with post-processing overlay...")

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
                    rotationAngle = 0    // Home button on left - swapped back
                case .landscapeRight:
                    rotationAngle = 180  // Home button on right - swapped back
                default:
                    rotationAngle = 180 // Default to landscape
                }

                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                    debugPrint("🎥 Set recording orientation to \(rotationAngle)° for device orientation: \(deviceOrientation.rawValue)")
                } else {
                    debugPrint("⚠️ Rotation angle \(rotationAngle)° NOT SUPPORTED - trying alternatives")
                    let supportedAngles = [0.0, 90.0, 180.0, 270.0].filter { connection.isVideoRotationAngleSupported($0) }
                    debugPrint("   Supported angles: \(supportedAngles)")
                }

                // Apply video stabilization from settings
                if CameraSettingsManager.shared.settings.stabilizationEnabled {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                        debugPrint("🎥 Video stabilization enabled for recording")
                    } else {
                        debugPrint("⚠️ Video stabilization not supported on this device/connection")
                    }
                }
            }

            videoOutput.startRecording(to: outputURL, recordingDelegate: self)
            debugPrint("🎥 AVCaptureMovieFileOutput.startRecording() called")

            await MainActor.run {
                self.isRecording = true
                self.recordingStartTime = Date()
                self.startRecordingTimer()

                // Start tracking score timeline for post-processing
                ScoreTimelineTracker.shared.startRecording(initialGame: game)

                // Update Live Activity (disabled via feature flag for recorder device)
                LiveActivityManager.shared.updateRecordingState(isRecording: true)
                debugPrint("✅ Recording state updated - isRecording=true")
            }
        } else {
            forcePrint("❌ Cannot start recording - no recording output available")
        }
    }
    
    func getLastRecordingURL() -> URL? {
        return outputURL
    }

    /// Clear the last recording URL reference (used when discarding recordings)
    @MainActor
    func clearLastRecording() {
        outputURL = nil
        debugPrint("🗑️ Cleared last recording URL reference")
    }

    /// Update game data during recording
    /// Tracked in ScoreTimelineTracker for post-processing overlay
    func updateGameData(_ liveGame: LiveGame) {
        // Score timeline is automatically tracked by ScoreTimelineTracker
        // No action needed here - overlay will be added during post-processing
        debugPrint("📊 Game data tracked for post-processing")
    }

    /// Show end game banner (no-op for post-processing mode)
    /// End game banner would be added during post-processing if desired
    func showEndGameBanner(liveGame: LiveGame) {
        debugPrint("⏭️ End game banner tracking (for post-processing)")
    }

    func stopRecording() async {
        guard isRecording else { return }

        debugPrint("🎥 Stopping recording...")

        // Stop recording
        if let videoOutput = videoOutput {
            debugPrint("🎬 Stopping video recording...")
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
            debugPrint("✅ Recording stopped - isRecording=false")
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
            debugPrint("Flash toggle failed: \(error)")
        }
    }
    
    func capturePhoto() {
        // Implement photo capture if needed
        debugPrint("Photo capture requested")
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
            debugPrint("Camera flip failed: \(error)")
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
            debugPrint("⚠️ Cannot set zoom - no video device")
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
            debugPrint("⚠️ Failed to set zoom: \(error)")
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
            debugPrint("⚠️ Cannot focus - no video device")
            return
        }

        guard device.isFocusPointOfInterestSupported,
              device.isFocusModeSupported(.autoFocus) else {
            debugPrint("⚠️ Focus point of interest not supported on this device")
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
            debugPrint("📍 Focus set to point: (\(String(format: "%.2f", point.x)), \(String(format: "%.2f", point.y)))")
        } catch {
            debugPrint("⚠️ Failed to set focus: \(error)")
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
            debugPrint("🔄 Reset to continuous autofocus")
        } catch {
            debugPrint("⚠️ Failed to reset focus: \(error)")
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
    /// Returns the Photos asset identifier if successful, nil otherwise.
    @MainActor
    func saveToPhotoLibrary() async -> String? {
        guard let url = getLastRecordingURL() else {
            forcePrint("❌ No video to save to photo library")
            return nil
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if newStatus != .authorized && newStatus != .limited {
                forcePrint("❌ Photo Library access denied")
                return nil
            }
        } else if status != .authorized && status != .limited {
            forcePrint("❌ Photo Library access denied")
            return nil
        }
        return await withCheckedContinuation { continuation in
            var assetIdentifier: String?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                assetIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                if success, let identifier = assetIdentifier {
                    forcePrint("✅ Video saved to photo library with asset ID: \(identifier)")
                    continuation.resume(returning: identifier)
                } else {
                    forcePrint("❌ Failed to save video to photo library: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Handles saving recording and queuing for upload - used by recording view
    /// Returns the local video URL for storage in the game record
    @discardableResult
    func saveRecordingAndQueueUpload(liveGame: LiveGame, scoreTimeline: [ScoreTimelineTracker.ScoreSnapshot]) async -> URL? {
        // Prevent duplicate saves
        guard !isSavingVideo else {
            debugPrint("⚠️ Already saving video - skipping duplicate save")
            return nil
        }

        isSavingVideo = true
        defer { isSavingVideo = false }

        let gameId = liveGame.id ?? "unknown"
        let teamName = liveGame.teamName
        let opponent = liveGame.opponent

        debugPrint("📹 saveRecordingAndQueueUpload called")
        debugPrint("   Game ID: \(gameId)")
        debugPrint("   Teams: \(teamName) vs \(opponent)")
        debugPrint("   Score timeline: \(scoreTimeline.count) snapshots")
        debugPrint("   outputURL: \(String(describing: outputURL))")

        guard let originalURL = outputURL else {
            forcePrint("❌ No recording to save and queue - outputURL is nil")
            return nil
        }

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: originalURL.path)
        debugPrint("   File exists at outputURL: \(fileExists)")

        if !fileExists {
            forcePrint("❌ Recording file does not exist at path: \(originalURL.path)")
            return nil
        }

        // Save score timeline for future reference (only used in fallback mode)
        ScoreTimelineTracker.shared.saveTimeline(scoreTimeline, forGameId: gameId)

        // Add overlay via GPU-accelerated post-processing
        debugPrint("🎨 Adding GPU-accelerated overlay with Core Animation...")

        let compositedURL = await withCheckedContinuation { continuation in
            HardwareAcceleratedOverlayCompositor.addAnimatedOverlay(
                to: originalURL,
                scoreTimeline: scoreTimeline
            ) { result in
                switch result {
                case .success(let url):
                    forcePrint("✅ GPU-accelerated overlay added successfully")
                    continuation.resume(returning: url)
                case .failure(let error):
                    forcePrint("❌ Overlay composition failed: \(error)")
                    debugPrint("   Falling back to original video")
                    continuation.resume(returning: originalURL)
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

        debugPrint("📹 Processing video for upload...")

        // Update outputURL to point to composited video for photo library save
        self.outputURL = compositedURL

        // Save the composited video to photo library and get asset identifier
        let photosAssetId = await saveToPhotoLibrary()

        guard let assetId = photosAssetId else {
            forcePrint("❌ Failed to save video to Photos library")
            return nil
        }

        forcePrint("✅ Video saved to Photos with asset ID: \(assetId)")

        // IMPORTANT: Store Photos asset ID in Firebase (accessible across all devices)
        debugPrint("📹 Storing Photos asset ID in Firebase...")
        await FirebaseService.shared.updateGamePhotosAssetId(gameId: gameId, photosAssetId: assetId)
        debugPrint("✅ Photos asset ID stored in Firebase: \(assetId)")

        // Only queue for YouTube upload if enabled
        if YouTubeUploadManager.shared.isYouTubeUploadEnabled {
            debugPrint("📺 YouTube upload enabled - creating copy for upload...")

            // Copy the file for YouTube upload
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let youtubeURL = documentsPath.appendingPathComponent("youtube_\(Date().timeIntervalSince1970).mov")

            do {
                try FileManager.default.copyItem(at: compositedURL, to: youtubeURL)
                forcePrint("✅ Created copy for YouTube upload at: \(youtubeURL.lastPathComponent)")

                // Queue the COPY for upload (not the original)
                YouTubeUploadManager.shared.queueVideoForUpload(
                    videoURL: youtubeURL,
                    title: title,
                    description: description,
                    gameId: gameId
                )

                debugPrint("✅ Video queued for YouTube upload")
            } catch {
                forcePrint("❌ Failed to create copy for YouTube: \(error)")
            }
        } else {
            debugPrint("⏸️ YouTube upload disabled - video only in Photos library")
        }

        debugPrint("✅ saveRecordingAndQueueUpload completed")

        // Clear outputURL to prevent duplicate saves
        self.outputURL = nil

        // Return the composited URL for reference
        return compositedURL
    }

}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        debugPrint("🎥 fileOutput delegate called - recording finished")
        debugPrint("   Output URL: \(outputFileURL)")
        debugPrint("   Error: \(String(describing: error))")

        if let error = error {
            forcePrint("❌ Recording failed: \(error)")
            DispatchQueue.main.async {
                self.error = error
            }
        } else {
            // Check if file exists
            let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
            debugPrint("   File exists: \(fileExists)")

            if fileExists {
                forcePrint("✅ Recording saved successfully to: \(outputFileURL)")
                // Store the last successful recording
                DispatchQueue.main.async {
                    self.outputURL = outputFileURL
                    debugPrint("   outputURL stored in VideoRecordingManager")
                }
            } else {
                forcePrint("❌ Recording file does not exist at expected path")
            }
        }
    }
}
