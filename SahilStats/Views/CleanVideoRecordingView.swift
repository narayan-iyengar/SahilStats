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
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5).tint(.white)
                    Text(loadingMessage).font(.headline).foregroundColor(.white)
                        .multilineTextAlignment(.center).padding(.horizontal)
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
            Button("Try Again", action: retryCameraSetup)
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
    
    private var portraitControls: some View {
        VStack {
            HStack {
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
        
        // Monitor connection state changes
        multipeer.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { connectionState in
                print("🔗 CleanVideoRecordingView: Connection state changed to \(connectionState)")
                if !connectionState.isConnected {
                    print("⚠️ CleanVideoRecordingView: Connection lost while in recording view!")
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
        // Give the view hierarchy time to setup, then initialize camera
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupCamera()
        }
    }
    
    private func setupCamera() {
        guard !hasCameraSetup else { return }
        cameraSetupAttempts += 1
        
        print("🎥 CleanVideoRecordingView: Setting up camera (attempt \(cameraSetupAttempts))")
        
        Task {
            let hasPermission = await recordingManager.checkForCameraPermission()
            guard hasPermission else {
                await MainActor.run {
                    cameraErrorMessage = "Camera permission is required to record."
                    showingCameraError = true
                }
                return
            }
            
            await MainActor.run {
                print("🎥 CleanVideoRecordingView: Camera permission granted, setting up hardware...")
                
                // Set up camera ready callback first
                self.recordingManager.onCameraReady = {
                    DispatchQueue.main.async {
                        print("✅ Camera session is ready")
                        self.isCameraReady = true
                    }
                }
                
                // Now setup and start the camera
                if self.recordingManager.setupCamera() != nil {
                    print("✅ Camera hardware setup completed, starting session...")
                    self.recordingManager.startCameraSession()
                    self.hasCameraSetup = true
                    
                    // Fallback timeout in case onCameraReady isn't called
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if !self.isCameraReady {
                            print("⚠️ Camera ready timeout, forcing ready state")
                            self.isCameraReady = true
                        }
                    }
                } else {
                    self.cameraErrorMessage = "Failed to set up camera hardware."
                    self.showingCameraError = true
                }
            }
        }
    }
    
    private func retryCameraSetup() {
        print("🔄 CleanVideoRecordingView: Retrying camera setup")
        hasCameraSetup = false
        isCameraReady = false
        setupCamera()
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



