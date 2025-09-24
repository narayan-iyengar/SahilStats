//
//  VideoRecordingManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/23/25.
//

// File: SahilStats/Services/VideoRecordingManager.swift
// Video recording with live score overlay similar to PWA

import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

class VideoRecordingManager: NSObject, ObservableObject {
    static let shared = VideoRecordingManager()
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var error: RecordingError?
    @Published var recordedVideoURL: URL?
    
    // Camera and recording setup
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    
    // Recording state
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var outputURL: URL?
    
    // Overlay data
    @Published var overlayData = ScoreOverlayData()
    
    enum RecordingError: LocalizedError {
        case cameraAccessDenied
        case microphoneAccessDenied
        case deviceNotFound
        case sessionConfigurationFailed
        case recordingFailed(String)
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .cameraAccessDenied:
                return "Camera access denied. Please enable in Settings."
            case .microphoneAccessDenied:
                return "Microphone access denied. Please enable in Settings."
            case .deviceNotFound:
                return "Camera device not found."
            case .sessionConfigurationFailed:
                return "Failed to configure camera session."
            case .recordingFailed(let message):
                return "Recording failed: \(message)"
            case .saveFailed:
                return "Failed to save video to photo library."
            }
        }
    }
    
    override init() {
        super.init()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    // MARK: - Authorization
    
    func requestCameraAccess() async -> Bool {
        let cameraStatus = await AVCaptureDevice.requestAccess(for: .video)
        let microphoneStatus = await AVCaptureDevice.requestAccess(for: .audio)
        
        await MainActor.run {
            self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        
        if !cameraStatus {
            await MainActor.run {
                self.error = .cameraAccessDenied
            }
            return false
        }
        
        if !microphoneStatus {
            await MainActor.run {
                self.error = .microphoneAccessDenied
            }
            return false
        }
        
        return true
    }
    
    // MARK: - Camera Setup
    
    func setupCamera() async -> AVCaptureVideoPreviewLayer? {
        guard await requestCameraAccess() else { return nil }
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            await MainActor.run {
                self.error = .deviceNotFound
            }
            return nil
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                currentDevice = videoDevice
            }
        } catch {
            await MainActor.run {
                self.error = .sessionConfigurationFailed
            }
            return nil
        }
        
        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                print("Failed to add audio input: \(error)")
            }
        }
        
        // Movie file output
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            videoOutput = movieOutput
        }
        
        // Preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        captureSession = session
        self.previewLayer = previewLayer
        
        return previewLayer
    }
    
    // MARK: - Recording Control
    
    func startRecording() async {
        guard let captureSession = captureSession,
              let videoOutput = videoOutput else {
            return
        }
        
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("sahil_game_\(Int(Date().timeIntervalSince1970)).mov")
        self.outputURL = outputURL
        
        // Start recording
        captureSession.startRunning()
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        await MainActor.run {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.startRecordingTimer()
        }
    }
    
    func stopRecording() async {
        guard let videoOutput = videoOutput else { return }
        
        videoOutput.stopRecording()
        captureSession?.stopRunning()
        
        await MainActor.run {
            self.isRecording = false
            self.isPaused = false
            self.stopRecordingTimer()
        }
    }
    
    func pauseRecording() {
        // AVCaptureMovieFileOutput doesn't support pause/resume
        // This would need to be implemented by stopping and starting a new recording
        // and then combining the clips later
        isPaused.toggle()
    }
    
    // MARK: - Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = self.recordingStartTime {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    // MARK: - Overlay Updates
    
    func updateOverlay(homeScore: Int, awayScore: Int, period: Int, clock: String, teamName: String, opponent: String) {
        overlayData.homeScore = homeScore
        overlayData.awayScore = awayScore
        overlayData.period = period
        overlayData.clock = clock
        overlayData.teamName = teamName
        overlayData.opponent = opponent
        overlayData.timestamp = Date()
    }
    
    // MARK: - Helper Methods
    
    func openCameraSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    var canRecordVideo: Bool {
        return authorizationStatus == .authorized
    }
    
    var shouldRequestAccess: Bool {
        return authorizationStatus == .notDetermined
    }
    
    var shouldShowSettingsAlert: Bool {
        return authorizationStatus == .denied
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = .recordingFailed(error.localizedDescription)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.recordedVideoURL = outputFileURL
        }
        
        // Save to photo library
        Task {
            await saveVideoToPhotoLibrary(outputFileURL)
        }
    }
    
    private func saveVideoToPhotoLibrary(_ videoURL: URL) async {
        guard await PhotosManager.shared.requestPhotoLibraryAccess() else {
            await MainActor.run {
                self.error = .saveFailed
            }
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: videoURL)
            
        } catch {
            await MainActor.run {
                self.error = .saveFailed
            }
        }
    }
}

// MARK: - Score Overlay Data

struct ScoreOverlayData {
    var homeScore: Int = 0
    var awayScore: Int = 0
    var period: Int = 1
    var clock: String = "20:00"
    var teamName: String = ""
    var opponent: String = ""
    var timestamp: Date = Date()
    var isLiveGame: Bool = false
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

// MARK: - Score Overlay View

struct ScoreOverlayView: View {
    let overlayData: ScoreOverlayData
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                // Score overlay in top right
                scoreOverlay
                    .padding(.trailing, isIPad ? 24 : 16)
                    .padding(.top, isIPad ? 60 : 50) // Account for safe area
            }
            
            Spacer()
        }
    }
    
    private var scoreOverlay: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            // Game info
            HStack(spacing: isIPad ? 16 : 12) {
                Text("\(overlayData.teamName)")
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("\(overlayData.homeScore)")
                    .font(isIPad ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("-")
                    .font(isIPad ? .title2 : .title3)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(overlayData.awayScore)")
                    .font(isIPad ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("\(overlayData.opponent)")
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            // Time and period
            HStack(spacing: isIPad ? 16 : 12) {
                Text("Period \(overlayData.period)")
                    .font(isIPad ? .caption : .caption2)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(overlayData.clock)
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                .fill(.black.opacity(0.7))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Video Recording View

struct VideoRecordingView: View {
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var photosManager = PhotosManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // Live game data for overlay
    let liveGame: LiveGame?
    
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var showingPermissionAlert = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera preview
            if let previewLayer = previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .ignoresSafeArea()
            } else {
                cameraSetupView
            }
            
            // Score overlay (only when recording and have live game)
            if recordingManager.isRecording, let _ = liveGame {
                ScoreOverlayView(overlayData: recordingManager.overlayData)
            }
            
            // Recording controls
            VStack {
                Spacer()
                recordingControlsView
            }
            
            // Top controls
            VStack {
                topControlsView
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupCamera()
            setupOverlayData()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            updateOverlayFromLiveGame()
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            if recordingManager.shouldShowSettingsAlert {
                Button("Settings") {
                    recordingManager.openCameraSettings()
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } else {
                Button("Allow Access") {
                    setupCamera()
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }
        } message: {
            Text("SahilStats needs camera access to record game videos with live score overlays.")
        }
        .alert("Recording Error", isPresented: .constant(recordingManager.error != nil)) {
            Button("OK") {
                recordingManager.error = nil
            }
        } message: {
            if let error = recordingManager.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    @ViewBuilder
    private var cameraSetupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Setting up camera...")
                .font(.title2)
                .foregroundColor(.white)
            
            if recordingManager.shouldRequestAccess {
                Button("Enable Camera Access") {
                    setupCamera()
                }
                .buttonStyle(VideoControlButtonStyle(isIPad: isIPad))
            }
        }
    }
    
    @ViewBuilder
    private var topControlsView: some View {
        HStack {
            // Close button
            Button(action: {
                if recordingManager.isRecording {
                    Task {
                        await recordingManager.stopRecording()
                    }
                }
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            
            Spacer()
            
            // Recording status
            if recordingManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    
                    Text("REC")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text(formatDuration(recordingManager.recordingDuration))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.7))
                        .background(.ultraThinMaterial)
                )
            }
            
            Spacer()
            
            // Settings/options (placeholder)
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .disabled(recordingManager.isRecording)
        }
        .padding(.horizontal, 24)
        .padding(.top, 50) // Safe area
    }
    
    @ViewBuilder
    private var recordingControlsView: some View {
        HStack(spacing: 40) {
            // Gallery button
            Button(action: {
                // Open photo library or show recent recordings
            }) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.3))
                    .frame(width: isIPad ? 60 : 50, height: isIPad ? 60 : 50)
                    .overlay {
                        Image(systemName: "photo.on.rectangle")
                            .font(isIPad ? .title2 : .title3)
                            .foregroundColor(.white)
                    }
            }
            .disabled(recordingManager.isRecording)
            
            Spacer()
            
            // Record button
            Button(action: {
                if recordingManager.isRecording {
                    Task {
                        await recordingManager.stopRecording()
                    }
                } else {
                    Task {
                        await recordingManager.startRecording()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: isIPad ? 80 : 70, height: isIPad ? 80 : 70)
                    
                    if recordingManager.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.red)
                            .frame(width: isIPad ? 30 : 25, height: isIPad ? 30 : 25)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: isIPad ? 65 : 55, height: isIPad ? 65 : 55)
                    }
                }
            }
            .scaleEffect(recordingManager.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: recordingManager.isRecording)
            
            Spacer()
            
            // Camera flip button
            Button(action: {
                // Flip camera (front/back)
            }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(isIPad ? .title2 : .title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .disabled(recordingManager.isRecording)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, isIPad ? 40 : 30)
    }
    
    private func setupCamera() {
        Task {
            let layer = await recordingManager.setupCamera()
            await MainActor.run {
                self.previewLayer = layer
                if !recordingManager.canRecordVideo && recordingManager.shouldRequestAccess {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func setupOverlayData() {
        guard let liveGame = liveGame else { return }
        
        recordingManager.updateOverlay(
            homeScore: liveGame.homeScore,
            awayScore: liveGame.awayScore,
            period: liveGame.period,
            clock: liveGame.currentClockDisplay,
            teamName: liveGame.teamName,
            opponent: liveGame.opponent
        )
    }
    
    private func updateOverlayFromLiveGame() {
        guard let liveGame = FirebaseService.shared.getCurrentLiveGame() else { return }
        
        recordingManager.updateOverlay(
            homeScore: liveGame.homeScore,
            awayScore: liveGame.awayScore,
            period: liveGame.period,
            clock: liveGame.currentClockDisplay,
            teamName: liveGame.teamName,
            opponent: liveGame.opponent
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Video Control Button Style

struct VideoControlButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .padding(.horizontal, isIPad ? 24 : 20)
            .padding(.vertical, isIPad ? 16 : 12)
            .background(.white)
            .cornerRadius(isIPad ? 12 : 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Integration with Live Game

extension LiveGameView {
    func presentVideoRecording() {
        // This would be called from a button in the live game view
        // You'd present the VideoRecordingView as a full screen cover
    }
}

// MARK: - Video Recording Button for Live Game

struct VideoRecordingButton: View {
    let liveGame: LiveGame?
    @State private var showingVideoRecording = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Button(action: {
            showingVideoRecording = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(isIPad ? .body : .caption)
                
                Text("Record")
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, isIPad ? 16 : 12)
            .padding(.vertical, isIPad ? 12 : 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.red, .red.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(isIPad ? 12 : 8)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingVideoRecording) {
            VideoRecordingView(liveGame: liveGame)
        }
    }
}
