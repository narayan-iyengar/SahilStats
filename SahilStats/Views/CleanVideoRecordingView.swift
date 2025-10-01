// CleanVideoRecordingView.swift - FIXED Camera Initialization

import SwiftUI
import AVFoundation

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Local state for overlay data
    @State private var overlayData: SimpleScoreOverlayData
    @State private var updateTimer: Timer?
    @State private var isCameraReady = false
    @State private var orientation = UIDeviceOrientation.portrait
    
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    
    // NEW: Add state for camera setup
    @State private var hasCameraSetup = false
    @State private var cameraSetupAttempts = 0
    @State private var showingCameraError = false
    @State private var cameraErrorMessage = ""
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        self._overlayData = State(initialValue: SimpleScoreOverlayData(from: liveGame))
    }
    
    var body: some View {
        ZStack {
            // Camera preview fills entire screen
            SimpleCameraPreviewView(isCameraReady: $isCameraReady)
                .ignoresSafeArea(.all)
            
            // Only show overlay and controls when camera is ready
            if isCameraReady {
                // Score overlay - orientation-aware
                SimpleScoreOverlay(
                    overlayData: overlayData,
                    orientation: orientation,
                    recordingDuration: recordingManager.recordingTimeString
                )
                
                // Recording controls - orientation aware
                if orientation == .landscapeLeft || orientation == .landscapeRight {
                    landscapeControls
                } else {
                    portraitControls
                }
            } else {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text(loadingMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onAppear {
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .alert("Camera Error", isPresented: $showingCameraError) {
            Button("Try Again") {
                retryCameraSetup()
            }
            Button("Cancel") {
                handleDismiss()
            }
        } message: {
            Text(cameraErrorMessage)
        }
    }
    
    // MARK: - Landscape Controls
    
    @ViewBuilder
    private var landscapeControls: some View {
        HStack {
            VStack(spacing: 20) {
                // Close button
                Button(action: handleDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                Spacer()
                Spacer()
                
                // Record button
                recordButton
            }
            .padding(.leading, 16)
            .padding(.vertical, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Portrait Controls
    
    @ViewBuilder
    private var portraitControls: some View {
        VStack {
            HStack {
                // Close button
                Button(action: handleDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                // Recording status
                if recordingManager.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recordingManager.isRecording)
                        
                        Text("REC")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text(recordingManager.recordingTimeString)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                
                Spacer()
                
                // Record button
                recordButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Record Button
    
    @ViewBuilder
    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                if recordingManager.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.red)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 50)
                }
            }
        }
        .disabled(!isCameraReady)
    }
    
    // MARK: - Computed Properties
    
    private var loadingMessage: String {
        if cameraSetupAttempts == 0 {
            return "Starting Camera..."
        } else {
            return "Initializing camera (Attempt \(cameraSetupAttempts))..."
        }
    }
    
    // MARK: - Setup and Cleanup Methods
    
    private func setupView() {
        print("🎥 CleanVideoRecordingView: Setting up view")
        
        // Setup orientation notifications
        setupOrientationNotifications()
        
        // FIXED: Add delay before camera setup to avoid gesture conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            setupCamera()
        }
        
        // Setup overlay update timer
        startOverlayUpdateTimer()
        
        // Setup Bluetooth callbacks
        setupBluetoothCallbacks()
        
        // Disable idle timer
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func cleanupView() {
        print("🎥 CleanVideoRecordingView: Cleaning up view")
        
        removeOrientationNotifications()
        recordingManager.stopCameraSession()
        stopOverlayUpdateTimer()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func setupCamera() {
        guard !hasCameraSetup else {
            print("⚠️ Camera already setup, skipping")
            return
        }
        
        cameraSetupAttempts += 1
        print("🎥 Setting up camera (Attempt \(cameraSetupAttempts))")
        
        // FIXED: Request permissions first
        Task {
            do {
                // Request camera permission
                await recordingManager.requestCameraAccess()
                
                // Check authorization status
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                
                if status != .authorized {
                    await MainActor.run {
                        cameraErrorMessage = "Camera permission is required for recording. Please enable it in Settings."
                        showingCameraError = true
                    }
                    return
                }
                
                // FIXED: Add delay after permission before starting camera
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    recordingManager.startCameraSession()
                    hasCameraSetup = true
                    
                    // FIXED: Add delay before marking camera as ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if recordingManager.previewLayer != nil {
                            isCameraReady = true
                            print("✅ Camera ready!")
                        } else if cameraSetupAttempts < 3 {
                            // Retry setup
                            hasCameraSetup = false
                            setupCamera()
                        } else {
                            cameraErrorMessage = "Failed to start camera after multiple attempts. Please try again."
                            showingCameraError = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Camera setup error: \(error)")
                    cameraErrorMessage = "Camera setup failed: \(error.localizedDescription)"
                    showingCameraError = true
                }
            }
        }
    }
    
    private func retryCameraSetup() {
        hasCameraSetup = false
        isCameraReady = false
        cameraSetupAttempts = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            setupCamera()
        }
    }
    
    private func setupBluetoothCallbacks() {
        multipeer.onRecordingStartRequested = {
            print("📱 Received recording start request from controller")
            Task {
                // FIXED: Add delay to ensure camera is ready
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                await recordingManager.startRecording()
            }
        }
        
        multipeer.onRecordingStopRequested = {
            print("📱 Received recording stop request from controller")
            Task {
                await recordingManager.stopRecording()
            }
        }
    }
    
    private func toggleRecording() {
        print("🎥 Toggle recording - current state: \(recordingManager.isRecording)")
        
        if recordingManager.isRecording {
            Task {
                await recordingManager.stopRecording()
                multipeer.sendRecordingStateUpdate(isRecording: false)
            }
        } else {
            Task {
                await recordingManager.startRecording()
                multipeer.sendRecordingStateUpdate(isRecording: true)
            }
        }
    }
    
    private func startOverlayUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateOverlayData()
        }
    }
    
    private func stopOverlayUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateOverlayData() {
        guard let currentGame = FirebaseService.shared.getCurrentLiveGame() else {
            return
        }
        
        overlayData = SimpleScoreOverlayData(
            from: currentGame,
            isRecording: recordingManager.isRecording,
            recordingDuration: recordingManager.recordingTimeString
        )
    }
    
    private func setupOrientationNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            updateOrientation()
        }
        updateOrientation()
    }
    
    private func removeOrientationNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    private func updateOrientation() {
        orientation = UIDevice.current.orientation
    }
    
    private func handleDismiss() {
        // Stop recording if active
        if recordingManager.isRecording {
            Task {
                await recordingManager.stopRecording()
            }
        }
        
        // Clear the device role when recorder exits
        Task {
            await roleManager.clearDeviceRole()
        }
        
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    let sampleLiveGame = LiveGame(
        teamName: "Warriors",
        opponent: "Lakers",
        gameFormat: .halves,
        quarterLength: 20,
        createdBy: "preview"
    )
    
    CleanVideoRecordingView(liveGame: sampleLiveGame)
}
