// CleanVideoRecordingView.swift - FIXED Camera Initialization

import SwiftUI
import AVFoundation
import MultipeerConnectivity

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
    
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
    // NEW: Add state for camera setup
    @State private var hasCameraSetup = false
    @State private var cameraSetupAttempts = 0
    @State private var showingCameraError = false
    @State private var cameraErrorMessage = ""
    
    @State private var orientationDebounceTimer: Timer?
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        self._overlayData = State(initialValue: SimpleScoreOverlayData(from: liveGame))
    }
    
    var body: some View {
        ZStack {
            // Camera preview fills entire screen
            SimpleCameraPreviewView(isCameraReady: $isCameraReady)
                .ignoresSafeArea(.all)
            /* TRY THIS
             GeometryReader { geometry in
                 SimpleCameraPreviewView(isCameraReady: $isCameraReady)
                     .frame(width: geometry.size.width, height: geometry.size.height)
             }
             .ignoresSafeArea(.all)
             */
            
            // Only show overlay and controls when camera is ready
            if isCameraReady {
                // Score overlay - orientation-aware
                SimpleScoreOverlay(
                    overlayData: overlayData,
                    orientation: orientation,
                    recordingDuration: recordingManager.recordingTimeString,
                    isRecording: recordingManager.isRecording
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
            print("🔍 CleanVideoRecordingView appeared - Multipeer connected: \(multipeer.isConnected)")
            print("🔍 Connected peers: \(multipeer.connectedPeers.map { $0.displayName })")
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
        ZStack {
            // Close button at top-left
            VStack {
                HStack {
                    Button(action: handleDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 40)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
    
    // Helper function to keep text upright in landscape mode
    private func getTextRotation() -> Double {
        let rotation: Double
        switch orientation {
        case .landscapeLeft:
            rotation = 90  // Rotate text to stay upright
        case .landscapeRight:
            rotation = -90 // Rotate text to stay upright
        default:
            rotation = 0   // No rotation needed in portrait
        }
        let _ = print("🟣 getTextRotation: orientation=\(orientation), returning rotation=\(rotation)")
        return rotation
    }
    
    // MARK: - Portrait Controls (Simplified - recording only in landscape)

    @ViewBuilder
    private var portraitControls: some View {
        VStack {
            HStack {
                // Close button only
                Button(action: handleDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
        }
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
        
        AppDelegate.orientationLock = .landscape
        UIViewController.attemptRotationToDeviceOrientation()
        
        setupOrientationNotifications()
        startOverlayUpdateTimer()
        setupBluetoothCallbacks()
        UIApplication.shared.isIdleTimerDisabled = true
        
        // CRITICAL: Wait for stable connection before camera setup
        if multipeer.isConnected {
            print("📱 Already connected, waiting 2s before camera setup")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.setupCamera()
            }
        } else {
            print("📱 Not connected, will setup camera after connection")
            setupCameraAfterConnection()
        }
    }
    
    private func setupCameraAfterConnection() {
        let setupCameraAction = { [setupCamera = self.setupCamera] in
            print("✅ Connection established, waiting 2s for stability")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                setupCamera()
            }
        }
        multipeer.onConnectionEstablished = setupCameraAction
    }
    
    private func cleanupView() {
        print("🎥 CleanVideoRecordingView: Cleaning up view")
        
        // Return to portrait when leaving
        AppDelegate.orientationLock = .portrait
        UIViewController.attemptRotationToDeviceOrientation()
        
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
        
        Task {
            do {
                // Check permissions
                let hasPermission = await recordingManager.checkForCameraPermission()
                
                guard hasPermission else {
                    await MainActor.run {
                        cameraErrorMessage = "Camera permission is required"
                        showingCameraError = true
                    }
                    return
                }
                
                // Start camera session (no artificial delays)
                await recordingManager.startCameraSession()
                hasCameraSetup = true
                
                // Poll for preview layer readiness
                var pollAttempts = 0
                while pollAttempts < 20 {
                    if recordingManager.previewLayer != nil {
                        await MainActor.run {
                            isCameraReady = true
                            print("✅ Camera ready after \(pollAttempts) polls")
                        }
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                    pollAttempts += 1
                }
                
                // Retry if needed
                await MainActor.run {
                    if cameraSetupAttempts < 3 {
                        hasCameraSetup = false
                        print("⚠️ Camera not ready, retrying...")
                        setupCamera()
                    } else {
                        cameraErrorMessage = "Failed to initialize camera after multiple attempts"
                        showingCameraError = true
                    }
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
    
    // This is the CORRECT version

    private func setupBluetoothCallbacks() {
        print("📱 Setting up Bluetooth callbacks for recorder")
         print("📱 Current connection state: \(multipeer.isConnected)")
         print("📱 Connected peers: \(multipeer.connectedPeers.map { $0.displayName })")
         
        multipeer.onRecordingStartRequested = {
            print("📱 Received recording start request from controller")
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                await recordingManager.startRecording()
                
                await MainActor.run {
                    print("✅ Recording started - sending state update to controller")
                    multipeer.sendRecordingStateUpdate(isRecording: true)
                }
            }
        }
        
        multipeer.onRecordingStopRequested = {
            print("📱 Received recording stop request from controller")
            Task {
                await recordingManager.stopRecording()

                await MainActor.run {
                    print("✅ Recording stopped - sending state update to controller")
                    multipeer.sendRecordingStateUpdate(isRecording: false)
                }
            }
        }
        multipeer.onGameEnded = { [self] gameId in
            print("Received game ended signal")
            
            // Stop recording if active
            if recordingManager.isRecording {
                Task {
                    await recordingManager.stopRecording()
                    
                    // Queue for upload
                    await recordingManager.saveRecordingAndQueueUpload(
                        gameId: gameId,
                        teamName: liveGame.teamName,
                        opponent: liveGame.opponent
                    )
                    
                    print("Recording stopped and queued for upload")
                }
            }
            
            // DON'T clear device role - keep it for next game
            // Just dismiss the recording view
            DispatchQueue.main.async {
                dismiss()
            }
        }
        
        // This block is now correctly inside the function.
        multipeer.onRecordingStateRequested = {
            print("📢 [Recorder] Controller requested recording state. Responding with current status.")
            // By removing 'self', we avoid confusing the compiler's type inference.
            multipeer.sendRecordingStateUpdate(isRecording: recordingManager.isRecording)
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
            // Debounce orientation changes
            orientationDebounceTimer?.invalidate()
            orientationDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                updateOrientation()
            }
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
        let newOrientation = UIDevice.current.orientation
        
        // Only update if it's a valid orientation (not faceUp/faceDown/unknown)
        switch newOrientation {
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            orientation = newOrientation
        default:
            // Ignore other orientations (faceUp, faceDown, unknown)
            break
        }
    }
    
    private func handleDismiss() {
        print("Dismissing recording view")
        
        if recordingManager.isRecording {
            print("Recording is active, stopping...")
            Task {
                await recordingManager.stopRecording()
                
                if let liveGame = FirebaseService.shared.getCurrentLiveGame(),
                   let gameId = liveGame.id {
                    print("Queueing video for upload - GameID: \(gameId)")
                    await recordingManager.saveRecordingAndQueueUpload(
                        gameId: gameId,
                        teamName: liveGame.teamName,
                        opponent: liveGame.opponent
                    )
                } else {
                    print("ERROR: No live game found!")
                }
            }
        } else {
            print("Recording not active")
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
