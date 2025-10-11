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
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var canRecordVideo = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var shouldShowSettingsAlert = false
    @Published var error: Error?
    private var outputURL: URL?
    //private var lastRecordingURL: URL?
    
    var onCameraReady: (() -> Void)?
    
    
    
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var _previewLayer: AVCaptureVideoPreviewLayer?
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        return _previewLayer
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
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
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
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: nil)
        
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
            return
        }

        let rotationAngle: CGFloat

        switch orientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            rotationAngle = 0
        case .landscapeRight:
            rotationAngle = 180
        default:
            return
        }

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            UIView.animate(withDuration: 0.3) {
                connection.videoRotationAngle = rotationAngle
            }
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
                print("Preview layer connection not available after retries")
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
            rotationAngle = 0
        case .landscapeRight:
            rotationAngle = 180
        default:
            return
        }

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
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
            
            // IMPROVED: Use sessionPreset that's less resource intensive during networking
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
                print("📹 Using 720p quality preset for better stability")
            } else if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
                print("⚠️ Falling back to high quality preset")
            }
            
            // IMPROVED: Try multiple camera fallbacks
            var videoDevice: AVCaptureDevice?
            
            // Try back wide angle camera first
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            // Fall back to any back camera
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                print("⚠️ Using dual camera as fallback")
            }
            
            // Last resort: front camera
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                print("⚠️ Using front camera as fallback")
            }
            
            guard let device = videoDevice else {
                print("❌ No camera device available at all")
                return nil
            }
            
            print("🎥 VideoRecordingManager: Found camera device: \(device.localizedName)")
            
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
                
                // IMPROVED: Reduce frame rate for better network stability
                let formatDescription = device.activeFormat.formatDescription
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                print("📹 Camera resolution: \(dimensions.width)x\(dimensions.height)")
                
                // Try to set a lower frame rate for better stability
                for range in device.activeFormat.videoSupportedFrameRateRanges {
                    if range.minFrameRate <= 30 && range.maxFrameRate >= 30 {
                        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                        print("📹 Set frame rate to 30fps for stability")
                        break
                    }
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
            
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                self.videoOutput = movieOutput
                print("✅ Movie output added to session")
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
                                       options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            
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
    
    func startRecording() async {
        print("🎥 VideoRecordingManager: startRecording() called")
        print("   videoOutput exists: \(videoOutput != nil)")
        print("   isRecording: \(isRecording)")
        print("   captureSession running: \(captureSession?.isRunning ?? false)")

        guard let videoOutput = videoOutput else {
            print("❌ Cannot start recording - videoOutput is nil (camera not setup)")
            return
        }

        guard !isRecording else {
            print("❌ Cannot start recording - already recording")
            return
        }

        print("🎥 Starting video recording...")

        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).mov")

        // Store the URL
        self.outputURL = outputURL

        print("🎥 Recording to: \(outputURL)")

        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        print("🎥 AVCaptureMovieFileOutput.startRecording() called")

        await MainActor.run {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.startRecordingTimer()

            // Update Live Activity
            LiveActivityManager.shared.updateRecordingState(isRecording: true)
            print("✅ Recording state updated - isRecording=true")
        }
    }
    
    func getLastRecordingURL() -> URL? {
        return outputURL
    }
    
    
    func stopRecording() async {
        guard isRecording else { return }

        videoOutput?.stopRecording()

        await MainActor.run {
            self.isRecording = false
            self.recordingStartTime = nil
            self.stopRecordingTimer()

            // Update Live Activity
            LiveActivityManager.shared.updateRecordingState(isRecording: false)
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)

            // Update Live Activity every second (not every 0.1s to avoid too many updates)
            let duration = Int(self.recordingDuration)
            if duration > 0 && duration % 1 == 0 {
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
    
    func cleanup() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        _previewLayer = nil
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
    func saveRecordingAndQueueUpload(gameId: String, teamName: String, opponent: String) async -> URL? {
        print("📹 saveRecordingAndQueueUpload called")
        print("   Game ID: \(gameId)")
        print("   Teams: \(teamName) vs \(opponent)")
        print("   outputURL: \(String(describing: outputURL))")

        guard let outputURL = outputURL else {
            print("❌ No recording to save and queue - outputURL is nil")
            return nil
        }

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: outputURL.path)
        print("   File exists at outputURL: \(fileExists)")

        if !fileExists {
            print("❌ Recording file does not exist at path: \(outputURL.path)")
            return nil
        }

        // Generate title and description
        let title = "🏀 \(teamName) vs \(opponent) - \(Date().formatted(date: .abbreviated, time: .shortened))"
        let description = """
        Game Recording
        \(teamName) vs \(opponent)
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
            try FileManager.default.copyItem(at: outputURL, to: youtubeURL)
            print("✅ Created copy for YouTube upload at: \(youtubeURL.lastPathComponent)")

            // Queue the COPY for upload (not the original)
            YouTubeUploadManager.shared.queueVideoForUpload(
                videoURL: youtubeURL,
                title: title,
                description: description,
                gameId: gameId
            )

            print("✅ Video queued for YouTube upload, now saving original to photo library")
        } catch {
            print("❌ Failed to create copy for YouTube: \(error)")
            // Fallback: still try to queue the original (might fail later, but better than nothing)
            YouTubeUploadManager.shared.queueVideoForUpload(
                videoURL: outputURL,
                title: title,
                description: description,
                gameId: gameId
            )
        }

        // Save the ORIGINAL to photo library (this will move/delete the original file)
        await saveToPhotoLibrary()

        print("✅ saveRecordingAndQueueUpload completed")
        print("   Local video URL will be stored in Firebase when upload completes: \(youtubeURL.path)")

        // Return the youtube copy URL (the one that persists)
        // Note: The videoURL will be stored in Firebase by YouTubeUploadManager when the upload completes
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
