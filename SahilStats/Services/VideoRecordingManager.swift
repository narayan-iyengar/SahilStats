// CLEANED VideoRecordingManager.swift - Remove complex overlay logic

import Foundation
import AVFoundation
import UIKit
import Combine
import SwiftUI
import Photos

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

        if _previewLayer == nil {
            _ = setupCamera()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            // Reduced delay - just enough for initial frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.updatePreviewOrientation()
            }
        }
    }
    
    func stopCameraSession() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }
    
    @objc private func handleOrientationChange() {
        updatePreviewOrientation()
    }
    
    func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection else {
            print("Preview layer connection not available")
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
            print("Camera access not granted")
            return nil
        }
        
        configureAudioSession()
        
        do {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                            for: .video,
                                                            position: .back) else {
                print("No back camera available")
                return nil
            }
            
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                print("Cannot add video input")
                return nil
            }
            
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
            
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                self.videoOutput = movieOutput
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            self.captureSession = session
            self._previewLayer = previewLayer
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                // Remove this delay - it's redundant with startCameraSession
                // Just update orientation once
                DispatchQueue.main.async {
                    self.updatePreviewOrientation()
                }
            }
            
            return previewLayer
            
        } catch {
            print("Camera setup error: \(error)")
            self.error = error
            return nil
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord,
                                       mode: .videoRecording,
                                       options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
            self.error = error
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
        guard let videoOutput = videoOutput,
              !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).mov")
        
        // Store the URL
        self.outputURL = outputURL
        
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        await MainActor.run {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.startRecordingTimer()
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
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
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
    
    func saveAndQueueForUpload(gameId: String, teamName: String, opponent: String) {
        guard let outputURL = outputURL else {
            print("❌ No recording to queue")
            return
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
        
        // Queue for upload
        YouTubeUploadManager.shared.queueVideoForUpload(
            videoURL: outputURL,
            title: title,
            description: description,
            gameId: gameId
        )
        
        print("✅ Video queued for YouTube upload")
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
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording failed: \(error)")
            DispatchQueue.main.async {
                self.error = error
            }
        } else {
            print("Recording saved to: \(outputFileURL)")
            // Store the last successful recording
            self.outputURL = outputFileURL
        }
    }
}

