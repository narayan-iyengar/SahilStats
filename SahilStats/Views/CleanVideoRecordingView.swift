// CleanVideoRecordingView.swift - FINAL CORRECTED VERSION

import SwiftUI
import AVFoundation
import MultipeerConnectivity
import Combine

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Local state for overlay data
    @State private var overlayData: SimpleScoreOverlayData
    @State private var updateTimer: Timer?
    @State private var isCameraReady = false
    @State private var orientation = UIDevice.current.orientation
    
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
                    orientation: orientation,
                    recordingDuration: recordingManager.recordingTimeString,
                    isRecording: recordingManager.isRecording
                )
                
                if orientation.isLandscape {
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
        cameraSetupAttempts == 0 ? "Starting Camera..." : "Initializing camera (Attempt \(cameraSetupAttempts))..."
    }
    
    // MARK: - Setup and Cleanup Methods
    
    private func setupView() {
        print("🎥 CleanVideoRecordingView: Setting up view")
        print("🔗 CleanVideoRecordingView: Current multipeer connection state: \(multipeer.connectionState)")
        print("🔗 CleanVideoRecordingView: Connected peers: \(multipeer.connectedPeers.map { $0.displayName })")
        
        AppDelegate.orientationLock = .landscape
        UIViewController.attemptRotationToDeviceOrientation()
        
        setupOrientationNotifications()
        startOverlayUpdateTimer()
        setupBluetoothCallbacks()
        UIApplication.shared.isIdleTimerDisabled = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupCamera()
        }
        
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
        
        removeOrientationNotifications()
        recordingManager.stopCameraSession()
        stopOverlayUpdateTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        cancellables.removeAll()
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
            
            // Start the camera session (this is not async)
            await MainActor.run {
                recordingManager.startCameraSession()
                hasCameraSetup = true
            }
            
            // Wait for the preview layer to be available
            for attempt in 0..<30 {  // Increased attempts
                if recordingManager.previewLayer != nil {
                    await MainActor.run {
                        print("✅ Camera preview layer is ready (attempt \(attempt + 1))")
                        isCameraReady = true
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))  // Increased delay
            }
            
            await MainActor.run {
                cameraErrorMessage = "Failed to initialize the camera after \(cameraSetupAttempts) attempts."
                showingCameraError = true
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
        
        multipeer.messagePublisher
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
            Task {
                await recordingManager.startRecording()
                multipeer.sendRecordingStateUpdate(isRecording: true)
            }
        case .stopRecording:
            print("📱 Received stopRecording command via publisher.")
            Task {
                await recordingManager.stopRecording()
                multipeer.sendRecordingStateUpdate(isRecording: false)
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
        if recordingManager.isRecording {
            Task {
                await recordingManager.stopRecording()
                await recordingManager.saveRecordingAndQueueUpload(
                    gameId: gameId,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent
                )
                // Let the manager handle the state reset
                LiveGameManager.shared.reset()
            }
        } else {
            LiveGameManager.shared.reset()
        }
    }
    
    private func handleDismiss() {
        print("Dismissing recording view via user action.")
        // Use the gameId from the liveGame object
        handleGameEnd(gameId: liveGame.id ?? "unknown-game-id")
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
    
    private func setupOrientationNotifications() {
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            self.orientation = UIDevice.current.orientation
        }
        self.orientation = UIDevice.current.orientation
    }
    
    private func removeOrientationNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}
