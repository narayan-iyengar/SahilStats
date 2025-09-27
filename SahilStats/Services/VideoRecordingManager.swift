// Fixed VideoRecordingManager.swift - Clean version without errors

import Foundation
import AVFoundation
import UIKit
import Combine
import SwiftUI

class VideoRecordingManager: NSObject, ObservableObject {
    static let shared = VideoRecordingManager()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var canRecordVideo = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var shouldShowSettingsAlert = false
    @Published var error: Error?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
            return _previewLayer
        }
    private var _previewLayer: AVCaptureVideoPreviewLayer?
    
    
        
        // Add missing properties for UI
        var recordingTimeString: String {
            let minutes = Int(recordingDuration) / 60
            let seconds = Int(recordingDuration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    
    
    // Current overlay data for live games
    private var currentOverlayData: ScoreOverlayData?
    
    // MARK: - Computed Properties
    
    var shouldRequestAccess: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .denied
    }
    
    var overlayData: ScoreOverlayData {
        return currentOverlayData ?? ScoreOverlayData(
            homeScore: 0, awayScore: 0, period: 1, clock: "0:00",
            teamName: "Team", opponent: "Opponent", timestamp: Date(), isLiveGame: false
        )
    }
    
    private override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Camera Session Management
    
    func updatePreviewOrientation() {
        // 1. Ensure we have a valid preview layer connection
        guard let connection = self.previewLayer?.connection else {
            print("No preview layer connection available")
            return
        }

        // 2. Get the current device orientation
        let orientation = UIDevice.current.orientation
        let rotationAngle: CGFloat

        // 3. Determine the correct rotation angle based on orientation
        switch orientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            // This corresponds to the home button being on the right
            rotationAngle = 0
        case .landscapeRight:
            // This corresponds to the home button being on the left
            rotationAngle = 180
        default:
            // If the orientation is unknown (e.g., face up/down), we don't change the angle
            return
        }

        // 4. Check if the *specific* angle is supported before applying it
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        } else {
            print("Rotation angle \(rotationAngle) is not supported.")
        }
    }
    
    @objc private func handleOrientationChange() {
        updatePreviewOrientation()
    }

    func startCameraSession() {
        guard !isRecording else { return }

        if _previewLayer == nil {
            // setupCamera() returns the layer, which we already assign to _previewLayer
            _ = setupCamera()
        }

        // Start listening for orientation changes ONLY when the session is starting
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()

            // Once the session is running, set the initial orientation on the main thread
            DispatchQueue.main.async {
                self?.updatePreviewOrientation()
            }
        }
    }
    
    // In VideoRecordingManager.swift

    func stopCameraSession() {
        // Stop listening for orientation changes
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }
    
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
        
        // Configure audio session first
        configureAudioSession()
        
        do {
            // Create capture session
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            // Set up video input
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
            
            // Set up audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
            
            // Set up video output
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                self.videoOutput = movieOutput
            }
            
            // Create preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            updatePreviewOrientation()
            
            self.captureSession = session
            self._previewLayer = previewLayer
            
            // Start session on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
            
            NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.updatePreviewOrientation()
            }
            return previewLayer
            
        } catch {
            print("Camera setup error: \(error)")
            self.error = error
            return nil
        }
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use modern API without deprecated options
            try audioSession.setCategory(.playAndRecord,
                                       mode: .videoRecording,
                                       options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() async {
        guard let videoOutput = videoOutput,
              !isRecording else { return }
        
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).mov")
        
        // Start recording
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        await MainActor.run {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.startRecordingTimer()
        }
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
    
    // MARK: - Recording Timer
    
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
    
    // MARK: - Overlay Management
    
    func updateOverlay(homeScore: Int, awayScore: Int, period: Int, clock: String, teamName: String, opponent: String) {
        currentOverlayData = ScoreOverlayData(
            homeScore: homeScore,
            awayScore: awayScore,
            period: period,
            clock: clock,
            teamName: teamName,
            opponent: opponent,
            timestamp: Date(),
            isLiveGame: true
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        _previewLayer = nil
        stopRecordingTimer()
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
            // Here you could save to photo library or process the video
        }
    }
}

// MARK: - Score Overlay Data Model

struct ScoreOverlayData {
    let homeScore: Int
    let awayScore: Int
    let period: Int
    let clock: String
    let teamName: String
    let opponent: String
    let timestamp: Date
    let isLiveGame: Bool
}

// MARK: - Camera Preview View


