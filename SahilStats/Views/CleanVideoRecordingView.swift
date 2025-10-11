// CleanVideoRecordingView.swift - FINAL CORRECTED VERSION

import SwiftUI
import AVFoundation
import MultipeerConnectivity
import Combine

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var orientationManager = OrientationManager()
    @ObservedObject private var navigation = NavigationCoordinator.shared
    
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
        
        // IMPROVED: Enhanced connection state monitoring with recovery
        multipeer.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { connectionState in
                print("🔗 CleanVideoRecordingView: Connection state changed to \(connectionState)")
                
                switch connectionState {
                case .connected:
                    print("✅ CleanVideoRecordingView: Successfully connected to controller")
                    self.handleConnectionRestored()
                case .connecting(let peerName):
                    print("🔄 CleanVideoRecordingView: Attempting to connect to controller: \(peerName)")
                case .disconnected:
                    print("⚠️ CleanVideoRecordingView: Disconnected from controller")
                    self.handleConnectionLoss()
                case .idle:
                    print("⚠️ CleanVideoRecordingView: Connection is idle")
                case .searching:
                    print("🔍 CleanVideoRecordingView: Searching for controller")
                }
            }
            .store(in: &cancellables)
    }
    
    private func cleanupView() {
        print("🎥 CleanVideoRecordingView: Cleaning up view")

        // CRITICAL: Save any recording before cleanup
        Task { @MainActor in
            // Stop recording if still active
            if recordingManager.isRecording {
                print("⚠️ Recording still active during cleanup - stopping...")
                await recordingManager.stopRecording()
            }

            // Check if we have an unsaved recording
            let hasRecording = recordingManager.getLastRecordingURL() != nil
            print("   Has unsaved recording: \(hasRecording)")

            if hasRecording {
                print("💾 Saving recording during cleanup...")
                await recordingManager.saveRecordingAndQueueUpload(
                    gameId: liveGame.id ?? "unknown",
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent
                )
                print("✅ Recording saved during cleanup")
            }

            // Now do the actual cleanup
            AppDelegate.orientationLock = .portrait
            UIViewController.attemptRotationToDeviceOrientation()

            recordingManager.stopCameraSession()
            stopOverlayUpdateTimer()
            UIApplication.shared.isIdleTimerDisabled = false
            cancellables.removeAll()

            print("✅ Cleanup complete")
        }
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
        // Filter out noisy pong messages from logs
        if message.type != .pong {
            print("📱 [CleanVideoRecordingView] Received message: \(message.type)")
            print("   Message payload: \(String(describing: message.payload))")
        }

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
            print("   Payload: \(String(describing: message.payload))")

            if let gameId = message.payload?["gameId"] as? String {
                print("   ✅ Found gameId in payload: \(gameId)")
                handleGameEnd(gameId: gameId)
            } else {
                print("   ❌ No gameId found in payload!")
                // Try to get it from liveGame instead
                if let gameId = liveGame.id {
                    print("   Using gameId from liveGame: \(gameId)")
                    handleGameEnd(gameId: gameId)
                } else {
                    print("   ❌ No gameId available at all - cannot save recording")
                }
            }
        case .pong:
            // Heartbeat message - ignore silently
            break
        default:
            print("   Unhandled message type: \(message.type)")
            break
        }
    }

    private func handleGameEnd(gameId: String) {
        print("🎬 CleanVideoRecordingView: handleGameEnd called for gameId: \(gameId)")
        print("   Current recording state: isRecording=\(recordingManager.isRecording)")

        Task { @MainActor in
            // Stop recording if still active
            if recordingManager.isRecording {
                print("🎬 Recording is active, stopping...")
                await self.recordingManager.stopRecording()
                print("✅ Recording stopped")
            }

            // Check if we have a recording to save (even if it's already stopped)
            let hasRecording = recordingManager.getLastRecordingURL() != nil
            print("   Has recording to save: \(hasRecording)")

            if hasRecording {
                print("📹 Saving and queueing recording for upload...")
                await self.recordingManager.saveRecordingAndQueueUpload(
                    gameId: gameId,
                    teamName: self.liveGame.teamName,
                    opponent: self.liveGame.opponent
                )
                print("✅ Recording saved and queued for upload")
            } else {
                print("⚠️ No recording to save")
            }

            print("🏠 Returning to dashboard...")
            self.navigation.returnToDashboard()
        }
    }
    
    private func handleDismiss() {
        print("🎬 CleanVideoRecordingView: handleDismiss called - navigating back to waiting room")
        print("🎬 Current recording state: isRecording=\(recordingManager.isRecording)")

        Task { @MainActor in
            // Check if we have a recording (even if not currently recording)
            let hasRecording = recordingManager.getLastRecordingURL() != nil
            print("🎬 Has recording: \(hasRecording)")

            // Stop recording if active and notify controller
            if recordingManager.isRecording {
                print("🎬 Stopping recording before dismissing...")
                await recordingManager.stopRecording()

                // Notify controller that recording has stopped
                multipeer.sendRecordingStateUpdate(isRecording: false)
                print("✅ Recording stopped and controller notified")
            }

            // Queue any completed recording for upload
            if hasRecording {
                print("📹 Saving and queueing recording for upload...")
                await recordingManager.saveRecordingAndQueueUpload(
                    gameId: liveGame.id ?? "unknown",
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent
                )
                print("✅ Recording saved and queued for upload")
            } else {
                print("⚠️ No recording to queue for upload")
            }

            // Navigate back to waiting room after recording is stopped
            print("🏠 Navigating back to waiting room...")
            navigation.currentFlow = .waitingToRecord(liveGame)
        }
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
    
    private func handleConnectionRestored() {
        print("🔗 CleanVideoRecordingView: Connection to controller restored.")
        // Optionally, reset any UI state or dismiss connection error alerts as needed.
        // For example:
        // self.showingConnectionError = false
    }
    
    private func handleConnectionLoss() {
        print("🔗 CleanVideoRecordingView: Connection to controller lost.")
        // Optionally, present an alert or UI state update for lost connection here.
    }
}

