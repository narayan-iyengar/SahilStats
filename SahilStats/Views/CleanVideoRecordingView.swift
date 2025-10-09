// CleanVideoRecordingView.swift - FINAL CORRECTED VERSION

import SwiftUI
import AVFoundation
import MultipeerConnectivity
import Combine

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var orientationManager = OrientationManager()
    @Environment(\.dismiss) private var dismiss
    
    // Local state for overlay data
    @State private var overlayData: SimpleScoreOverlayData
    @State private var updateTimer: Timer?
    @State private var isCameraReady = false
    
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
    // State for camera setup
    @State private var hasCameraSetup = false
    @State private var cameraSetupAttempts = 0
    @State private var showingCameraError = false
    @State private var cameraErrorMessage = ""
    
    @State private var cancellables = Set<AnyCancellable>() // To hold our subscription

    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        self._overlayData = State(initialValue: SimpleScoreOverlayData(from: liveGame))
    }
    
    var body: some View {
        ZStack {
            if isCameraReady {
                SimpleCameraPreviewView(isCameraReady: $isCameraReady)
                    .ignoresSafeArea(.all)
                
                SimpleScoreOverlay(
                    overlayData: overlayData,
                    orientation: orientationManager.orientation,
                    recordingDuration: recordingManager.recordingTimeString,
                    isRecording: recordingManager.isRecording
                )
                
                if orientationManager.isLandscape {
                    landscapeControls
                } else {
                    portraitControls
                }
            } else {
                LoadingView()
                    .preferredColorScheme(.dark)
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
                Task {
                    await retryCameraSetup()
                }
            }
            Button("Cancel", role: .cancel, action: handleDismiss)
        } message: {
            Text(cameraErrorMessage)
        }
    }
    
    // MARK: - Child Views
    
    private var landscapeControls: some View {
        ZStack {
            VStack {
                HStack {
                    DismissButton(action: handleDismiss, isIPad: false)
                        .padding(.leading, 20)
                        .padding(.top, 40)
                    
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
    private var portraitControls: some View {
        VStack {
            HStack {
                DismissButton(action: handleDismiss, isIPad: false)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            Spacer()
        }
    }
    
    private var loadingMessage: String {
        if cameraSetupAttempts == 0 {
            return "Starting Camera..."
        } else if cameraSetupAttempts == 1 {
            return "Initializing Camera..."
        } else {
            return "Setting up camera (Attempt \(cameraSetupAttempts))..."
        }
    }
    
    // MARK: - Setup and Cleanup Methods
    
    private func setupView() {
        print("🎥 CleanVideoRecordingView: Setting up view")
        print("🔗 CleanVideoRecordingView: Current multipeer connection state: \(multipeer.connectionState)")
        print("🔗 CleanVideoRecordingView: Connected peers: \(multipeer.connectedPeers.map { $0.displayName })")
        
        AppDelegate.orientationLock = .landscape
        UIViewController.attemptRotationToDeviceOrientation()
        
        startOverlayUpdateTimer()
        setupBluetoothCallbacks()
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupCameraWithDelay()
        
        // IMPROVED: Enhanced connection state monitoring
        multipeer.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { connectionState in
                print("🔗 CleanVideoRecordingView: Connection state changed to \(connectionState)")
                
                switch connectionState {
                case .connected:
                    print("✅ CleanVideoRecordingView: Successfully connected to controller")
                case .connecting(let peerName):
                    print("🔄 CleanVideoRecordingView: Attempting to connect to controller: \(peerName)")
                case .disconnected:
                    print("⚠️ CleanVideoRecordingView: Disconnected from controller")
                    // Don't immediately exit - the connection might recover
                }
            }
            .store(in: &cancellables)
        
        // IMPROVED: Monitor connected peers changes
        multipeer.$connectedPeers
            .receive(on: DispatchQueue.main)
            .sink { peers in
                print("🔗 CleanVideoRecordingView: Connected peers changed: \(peers.map { $0.displayName })")
                if peers.isEmpty {
                    print("⚠️ CleanVideoRecordingView: No peers connected - recorder may be isolated")
                }
            }
            .store(in: &cancellables)
    }
    
    private func cleanupView() {
        print("🎥 CleanVideoRecordingView: Cleaning up view")
        AppDelegate.orientationLock = .portrait
        UIViewController.attemptRotationToDeviceOrientation()
        
        recordingManager.stopCameraSession()
        stopOverlayUpdateTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        cancellables.removeAll()
    }
    
    private func setupCameraWithDelay() {
        // IMPROVED: Give more time for connection to stabilize before starting heavy camera operations
        print("🎥 CleanVideoRecordingView: Scheduling camera setup with delay to avoid connection interference")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Increased from 0.5 to 1.5 seconds
            Task {
                await self.setupCamera()
            }
        }
    }
    
    private func setupCamera() async {
        guard !hasCameraSetup else {
            print("🎥 CleanVideoRecordingView: Camera already setup, skipping")
            return
        }
        
        // IMPROVED: Don't start camera setup if we're already in the middle of attempts and failing
        guard cameraSetupAttempts < 3 else {
            print("❌ CleanVideoRecordingView: Too many camera setup attempts, giving up")
            await MainActor.run {
                cameraErrorMessage = "Camera setup failed after multiple attempts. Please check camera permissions and try again."
                showingCameraError = true
            }
            return
        }
        
        cameraSetupAttempts += 1
        print("🎥 CleanVideoRecordingView: Setting up camera (attempt \(cameraSetupAttempts))")
        
        // IMPROVED: Move camera setup to background thread to avoid blocking UI and connection handling
        Task.detached(priority: .userInitiated) {
            let hasPermission = await self.recordingManager.checkForCameraPermission()
            
            guard hasPermission else {
                await MainActor.run {
                    self.cameraErrorMessage = "Camera permission is required to record."
                    self.showingCameraError = true
                }
                return
            }
            
            await MainActor.run {
                print("🎥 CleanVideoRecordingView: Camera permission granted, setting up hardware...")
                
                // IMPORTANT: Start the camera session BEFORE setting up preview
                self.recordingManager.startCameraSession()
                
                // Now setup the camera and get the preview layer
                if self.recordingManager.setupCamera() != nil {
                    print("✅ Camera hardware setup completed")
                    self.hasCameraSetup = true
                    
                    // Give the camera session time to start before marking ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("✅ Marking camera as ready")
                        self.isCameraReady = true
                    }
                } else {
                    self.cameraErrorMessage = "Failed to set up camera hardware."
                    self.showingCameraError = true
                }
            }
        }
        }
    
    private func retryCameraSetup() async {
        print("🔄 CleanVideoRecordingView: Retrying camera setup")
        hasCameraSetup = false
        isCameraReady = false
        await setupCamera()
    }
    
    // ** THIS IS THE CORRECTED VERSION **
    private func setupBluetoothCallbacks() {
        print("📱 [CleanVideoRecordingView] Subscribing to multipeer message publisher.")
        
        self.multipeer.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { message in // Removed [weak self]
                self.handleMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleMessage(_ message: MultipeerConnectivityManager.Message) {
        switch message.type {
        case .startRecording:
            print("📱 Received startRecording command via publisher.")
            Task { @MainActor in
                await self.recordingManager.startRecording()
                self.multipeer.sendRecordingStateUpdate(isRecording: true)
            }
        case .stopRecording:
            print("📱 Received stopRecording command via publisher.")
            Task { @MainActor in
                await self.recordingManager.stopRecording()
                self.multipeer.sendRecordingStateUpdate(isRecording: false)
            }
        case .gameEnded:
            print("📱 Received gameEnded command via publisher.")
            if let gameId = message.payload?["gameId"] {
                handleGameEnd(gameId: gameId)
            }
        default:
            break
        }
    }

    private func handleGameEnd(gameId: String) {
        print("🎬 CleanVideoRecordingView: handleGameEnd called for gameId: \(gameId)")
        
        if recordingManager.isRecording {
            print("🎬 Recording is active, stopping and saving...")
            Task { @MainActor in
                await self.recordingManager.stopRecording()
                await self.recordingManager.saveRecordingAndQueueUpload(
                    gameId: gameId,
                    teamName: self.liveGame.teamName,
                    opponent: self.liveGame.opponent
                )
                
                print("🎬 Recording saved, dismissing view...")
                // Reset the state and dismiss
                LiveGameManager.shared.reset()
                self.dismiss()
            }
        } else {
            print("🎬 No recording active, dismissing view...")
            LiveGameManager.shared.reset()
            dismiss()
        }
    }
    
    private func handleDismiss() {
        print("🎬 CleanVideoRecordingView: handleDismiss called")
        // Use the gameId from the liveGame object or provide a fallback
        let gameId = liveGame.id ?? "unknown-game-id"
        handleGameEnd(gameId: gameId)
    }
    
    // MARK: - Timer and UI Update Methods
    
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
        guard let currentGame = FirebaseService.shared.getCurrentLiveGame() else { return }
        overlayData = SimpleScoreOverlayData(
            from: currentGame,
            isRecording: recordingManager.isRecording,
            recordingDuration: recordingManager.recordingTimeString
        )
    }
}



