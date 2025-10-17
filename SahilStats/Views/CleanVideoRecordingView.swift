// CleanVideoRecordingView.swift - FINAL CORRECTED VERSION

import SwiftUI
import AVFoundation
import Combine
import MultipeerConnectivity

struct CleanVideoRecordingView: View {
    let liveGame: LiveGame
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @StateObject private var orientationManager = OrientationManager()
    @ObservedObject private var navigation = NavigationCoordinator.shared
    
    // Local state for overlay data
    @State private var overlayData: SimpleScoreOverlayData
    @State private var updateTimer: Timer?
    @State private var isCameraReady = false

    // NEW: Local game state updated via multipeer (no Firebase reads!)
    @State private var localGameState: LiveGame

    // NEW: Local clock management (independent countdown - smooth 60fps!)
    @State private var localClockValue: TimeInterval = 0
    @State private var clockStartTime: Date?
    @State private var clockAtStart: TimeInterval?
    @State private var isClockRunning = false
    @State private var clockUpdateTimer: Timer?
    
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
    // State for camera setup
    @State private var hasCameraSetup = false
    @State private var cameraSetupAttempts = 0
    @State private var showingCameraError = false
    @State private var cameraErrorMessage = ""

    // Zoom control
    @State private var currentZoomLevel: CGFloat = 1.0

    @State private var cancellables = Set<AnyCancellable>() // To hold our subscription


    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        self._overlayData = State(initialValue: SimpleScoreOverlayData(from: liveGame))
        self._localGameState = State(initialValue: liveGame)
        self._localClockValue = State(initialValue: liveGame.getCurrentClock())
        self._isClockRunning = State(initialValue: liveGame.isRunning)
    }
    
    var body: some View {
        ZStack {
            if isCameraReady {
                SimpleCameraPreviewView(isCameraReady: $isCameraReady)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onChange(of: isCameraReady) { _, newValue in
            if newValue {
                // Set default zoom to 0.5x (ultra-wide) when camera is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let actualZoom = recordingManager.setZoom(factor: 0.5)
                    currentZoomLevel = actualZoom
                    print("📹 Camera ready - set initial zoom to \(actualZoom)x (ultra-wide)")
                }
            }
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
        print("🔗 CleanVideoRecordingView: Is recording: \(recordingManager.isRecording)")

        AppDelegate.orientationLock = .landscape
        // Request orientation update (iOS 16+ compatible)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }

        startOverlayUpdateTimer()
        startLocalClockTimer()  // NEW: Start independent clock countdown
        setupBluetoothCallbacks()
        UIApplication.shared.isIdleTimerDisabled = true

        // Skip camera setup if already running (started early in RecorderReadyView)
        if recordingManager.isCameraSessionRunning {
            print("✅ Camera session already running - marking as ready immediately")
            isCameraReady = true
        } else if !recordingManager.isRecording {
            print("🎥 Camera session not running yet - setting up now")
            setupCameraWithDelay()
        } else {
            print("⚠️ Already recording - skipping camera setup to avoid interruption")
            isCameraReady = true
        }
        
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

        Task { @MainActor in
            // Stop recording if still active
            if recordingManager.isRecording {
                print("⚠️ Recording still active during cleanup - stopping...")
                await recordingManager.stopRecording()
            }

            // DISCARD any unsaved recording - cleanup means game was abandoned
            await discardRecording()

            // Now do the actual cleanup
            AppDelegate.orientationLock = .portrait
            // Request orientation update (iOS 16+ compatible)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }

            recordingManager.stopCameraSession()
            stopOverlayUpdateTimer()
            stopLocalClockTimer()  // NEW: Stop clock timer
            UIApplication.shared.isIdleTimerDisabled = false
            cancellables.removeAll()

            print("✅ Cleanup complete")
        }
    }
    
    private func setupCameraWithDelay() {
        // Setup camera on lower priority to not interfere with multipeer connection
        print("🎥 CleanVideoRecordingView: Scheduling camera setup on background priority")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Reduced delay to minimize connection drop window
            Task(priority: .background) {
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

        // IMPROVED: Move camera setup to low priority background thread to not interfere with multipeer
        Task.detached(priority: .utility) {
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

                // CRITICAL: Setup camera hardware FIRST (creates the session)
                if self.recordingManager.setupCamera() != nil {
                    print("✅ Camera hardware setup completed")
                    self.hasCameraSetup = true

                    // NOW start the camera session (after it's been created)
                    self.recordingManager.startCameraSession()
                    print("🎥 Camera session started")

                    // Give the camera session time to fully start before marking ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
                await self.recordingManager.startRecording(liveGame: self.liveGame)
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
        case .gameState:
            // Receive full game state from controller (backup/recovery only - every 15s)
            if let payload = message.payload {
                print("📱 [CleanVideoRecordingView] Received gameState update via multipeer (backup)")
                updateLocalGameState(from: payload)
            } else {
                print("⚠️ [CleanVideoRecordingView] gameState message has no payload")
            }
        case .scoreUpdate:
            // INSTANT: Score changed on controller (0ms delay!)
            if let payload = message.payload {
                print("⚡ [CleanVideoRecordingView] Received INSTANT score update")
                updateScoreFromPayload(payload)
            }
        case .clockControl:
            // INSTANT: Clock started/stopped on controller (0ms delay!)
            if let payload = message.payload {
                print("⚡ [CleanVideoRecordingView] Received INSTANT clock control")
                updateClockControlFromPayload(payload)
            }
        case .periodChange:
            // INSTANT: Period/quarter changed on controller (0ms delay!)
            if let payload = message.payload {
                print("⚡ [CleanVideoRecordingView] Received INSTANT period change")
                updatePeriodFromPayload(payload)
            }
        case .clockSync:
            // Periodic clock sync for drift correction (every 15s)
            if let payload = message.payload {
                syncClockFromPayload(payload)
            }
        case .pong:
            // Heartbeat message - ignore silently
            break
        default:
            print("   Unhandled message type: \(message.type)")
            break
        }
    }

    private func updateLocalGameState(from payload: [String: Any]) {
        // Parse game state from controller's multipeer message
        guard let gameId = payload["gameId"] as? String,
              let homeScoreStr = payload["homeScore"] as? String,
              let awayScoreStr = payload["awayScore"] as? String,
              let clockStr = payload["clock"] as? String,
              let quarterStr = payload["quarter"] as? String,
              let isRunningStr = payload["isRunning"] as? String,
              let teamName = payload["teamName"] as? String,
              let opponent = payload["opponent"] as? String else {
            print("⚠️ [CleanVideoRecordingView] Invalid gameState payload")
            return
        }

        // Convert strings to proper types
        guard let homeScore = Int(homeScoreStr),
              let awayScore = Int(awayScoreStr),
              let clock = Double(clockStr),
              let quarter = Int(quarterStr) else {
            print("⚠️ [CleanVideoRecordingView] Failed to parse gameState values")
            return
        }

        let isRunning = isRunningStr == "true"

        // Update local game state (no Firebase read needed!)
        localGameState.id = gameId
        localGameState.homeScore = homeScore
        localGameState.awayScore = awayScore
        localGameState.clock = clock  // Update clock property, not computed currentClockDisplay
        localGameState.quarter = quarter
        localGameState.isRunning = isRunning
        localGameState.teamName = teamName
        localGameState.opponent = opponent

        // Log every 10 updates to verify it's working (not too verbose)
        let timestamp = Int(Date().timeIntervalSince1970)
        if timestamp % 30 == 0 {
            print("✅ [CleanVideoRecordingView] Updated local game state from multipeer:")
            print("   Score: \(homeScore)-\(awayScore) | Clock: \(String(format: "%.0f", clock))s | Q\(quarter)")
        }
    }

    // MARK: - Event-Driven Update Handlers

    private func updateScoreFromPayload(_ payload: [String: Any]) {
        guard let homeScoreStr = payload["homeScore"] as? String,
              let awayScoreStr = payload["awayScore"] as? String,
              let homeScore = Int(homeScoreStr),
              let awayScore = Int(awayScoreStr) else {
            print("⚠️ Invalid scoreUpdate payload")
            return
        }

        // Update local game state instantly (no delay!)
        localGameState.homeScore = homeScore
        localGameState.awayScore = awayScore

        print("⚡ Score updated instantly: \(homeScore)-\(awayScore)")
    }

    private func updateClockControlFromPayload(_ payload: [String: Any]) {
        guard let isRunningStr = payload["isRunning"] as? String,
              let clockValueStr = payload["clockValue"] as? String,
              let timestampStr = payload["timestamp"] as? String,
              let clockValue = Double(clockValueStr),
              let timestamp = Double(timestampStr) else {
            print("⚠️ Invalid clockControl payload")
            return
        }

        let isRunning = isRunningStr == "true"
        let controllerTime = Date(timeIntervalSince1970: timestamp)

        // Update local clock state
        localClockValue = clockValue
        isClockRunning = isRunning

        if isRunning {
            // Clock started - begin local countdown from this point
            clockStartTime = Date()
            clockAtStart = clockValue

            // Adjust for network latency (time since controller sent the message)
            let latency = Date().timeIntervalSince(controllerTime)
            if latency > 0 && latency < 1.0 {  // Only adjust if latency is reasonable
                localClockValue = max(0, clockValue - latency)
                print("⚡ Clock started at \(String(format: "%.0f", localClockValue))s (adjusted for \(Int(latency * 1000))ms latency)")
            } else {
                print("⚡ Clock started at \(String(format: "%.0f", clockValue))s")
            }
        } else {
            // Clock paused - stop local countdown
            clockStartTime = nil
            clockAtStart = nil
            print("⚡ Clock paused at \(String(format: "%.0f", clockValue))s")
        }

        // Update game state
        localGameState.isRunning = isRunning
        localGameState.clock = localClockValue  // Update clock property, not computed currentClockDisplay
    }

    private func updatePeriodFromPayload(_ payload: [String: Any]) {
        guard let quarterStr = payload["quarter"] as? String,
              let clockValueStr = payload["clockValue"] as? String,
              let quarter = Int(quarterStr),
              let clockValue = Double(clockValueStr) else {
            print("⚠️ Invalid periodChange payload")
            return
        }

        // CRITICAL FIX: Validate quarter doesn't exceed game's max periods
        let maxQuarter = localGameState.numQuarter
        if quarter > maxQuarter {
            print("❌ REJECTED period change - quarter \(quarter) exceeds maxQuarter \(maxQuarter)")
            print("   This appears to be an 'End Game' signal, not a period change!")
            print("   Ignoring this signal to prevent premature game end.")
            return
        }

        // Update local state
        localGameState.quarter = quarter
        localClockValue = clockValue
        localGameState.clock = clockValue  // Update clock property, not computed currentClockDisplay
        localGameState.isRunning = false  // CRITICAL: Keep game state in sync
        isClockRunning = false  // Clock is always paused when period changes
        clockStartTime = nil
        clockAtStart = nil

        print("⚡ Period changed: Q\(quarter)/\(maxQuarter) | Clock reset to \(String(format: "%.0f", clockValue))s | Clock PAUSED")
    }

    private func syncClockFromPayload(_ payload: [String: Any]) {
        guard let clockValueStr = payload["clockValue"] as? String,
              let isRunningStr = payload["isRunning"] as? String,
              let clockValue = Double(clockValueStr) else {
            return
        }

        let isRunning = isRunningStr == "true"

        // Check for significant drift (>2 seconds)
        let drift = abs(localClockValue - clockValue)
        if drift > 2.0 {
            print("⚠️ Clock drift detected: \(String(format: "%.1f", drift))s - syncing to \(String(format: "%.0f", clockValue))s")
            localClockValue = clockValue

            // If clock is running, restart from this synced value
            if isRunning {
                clockStartTime = Date()
                clockAtStart = clockValue
            }
        }
    }

    private func handleGameEnd(gameId: String) {
        print("🎬 CleanVideoRecordingView: handleGameEnd called for gameId: \(gameId)")
        print("   Current recording state: isRecording=\(recordingManager.isRecording)")

        Task { @MainActor in
            // Stop recording if active
            if recordingManager.isRecording {
                print("🎬 Stopping recording...")
                await self.recordingManager.stopRecording()
                print("✅ Recording stopped")
            }

            // Check if we have a recording to save (even if it's already stopped)
            let hasRecording = recordingManager.getLastRecordingURL() != nil
            print("   Has recording to save: \(hasRecording)")

            if hasRecording {
                print("📹 Saving and queueing recording for upload...")
                let timeline = ScoreTimelineTracker.shared.stopRecording()
                print("   📊 Got timeline with \(timeline.count) snapshots")
                await self.recordingManager.saveRecordingAndQueueUpload(liveGame: self.liveGame, scoreTimeline: timeline)
                print("✅ Recording saved and queued for upload")
            } else {
                print("⚠️ No recording to save")
            }

            print("🏠 Returning to dashboard...")
            self.navigation.returnToDashboard()
        }
    }
    
    private func handleDismiss() {
        print("🎬 CleanVideoRecordingView: handleDismiss called - user backing out without finishing game")
        print("🎬 Current recording state: isRecording=\(recordingManager.isRecording)")

        Task { @MainActor in
            // Stop recording if active and notify controller
            if recordingManager.isRecording {
                print("🎬 Stopping recording before dismissing...")
                await recordingManager.stopRecording()

                // Notify controller that recording has stopped
                multipeer.sendRecordingStateUpdate(isRecording: false)
                print("✅ Recording stopped and controller notified")
            }

            // DISCARD any recording - game was abandoned, not finished
            await discardRecording()

            // Navigate back to waiting room after recording is discarded
            print("🏠 Navigating back to waiting room...")
            navigation.currentFlow = .waitingToRecord(Optional(liveGame))
        }
    }

    // MARK: - Video Discard Helper

    private func discardRecording() async {
        print("🗑️ CleanVideoRecordingView: Discarding recording (game not finished)")

        // Get the recording URL if it exists
        if let recordingURL = recordingManager.getLastRecordingURL() {
            print("   Found recording to discard: \(recordingURL.lastPathComponent)")

            // Delete the video file
            do {
                if FileManager.default.fileExists(atPath: recordingURL.path) {
                    try FileManager.default.removeItem(at: recordingURL)
                    print("   ✅ Deleted video file: \(recordingURL.lastPathComponent)")
                } else {
                    print("   ⚠️ Video file doesn't exist at path: \(recordingURL.path)")
                }
            } catch {
                print("   ❌ Failed to delete video file: \(error.localizedDescription)")
            }

            // Clear the recording manager's reference
            await recordingManager.clearLastRecording()
        } else {
            print("   No recording to discard")
        }

        // Clear score timeline tracker
        _ = ScoreTimelineTracker.shared.stopRecording()
        print("   ✅ Cleared score timeline tracker")

        print("✅ Recording discarded successfully")
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

    // MARK: - Local Clock Management (Independent Countdown)

    private func startLocalClockTimer() {
        stopLocalClockTimer()

        // Update clock every 0.1 seconds for smooth countdown (10 FPS is enough for 1-second clock updates)
        clockUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // No need for [weak self] - SwiftUI views are structs, not classes
            if self.isClockRunning, let startTime = self.clockStartTime, let clockAtStart = self.clockAtStart {
                // Calculate elapsed time and update local clock
                let elapsed = Date().timeIntervalSince(startTime)
                self.localClockValue = max(0, clockAtStart - elapsed)

                // Update game state clock property for overlay
                self.localGameState.clock = self.localClockValue
            }
        }
    }

    private func stopLocalClockTimer() {
        clockUpdateTimer?.invalidate()
        clockUpdateTimer = nil
    }
    
    // Track update calls for logging (at type level)
    private static var updateCallCount = 0

    private func updateOverlayData() {
        // CRITICAL: Log EVERY call to verify timer is running
        CleanVideoRecordingView.updateCallCount += 1
        let callCount = CleanVideoRecordingView.updateCallCount

        // NEW: Use local game state updated via multipeer (no Firebase reads!)
        let currentGame = localGameState

        // Log every 5 seconds for normal monitoring (not too verbose)
        let shouldLog = callCount % 5 == 0
        if shouldLog {
            print("🎮 CleanVideoRecordingView.updateOverlayData() - call #\(callCount) [from LOCAL state]")
            print("   Score: \(currentGame.homeScore)-\(currentGame.awayScore)")
            print("   Clock: \(currentGame.currentClockDisplay)")
            print("   Period: Q\(currentGame.quarter)")
            print("   isRecording: \(recordingManager.isRecording)")
        }

        overlayData = SimpleScoreOverlayData(
            from: currentGame,
            isRecording: recordingManager.isRecording,
            recordingDuration: recordingManager.recordingTimeString
        )

        // Update recording with current game data
        if recordingManager.isRecording {
            // NEW: Update real-time recorder with game data for overlay
            recordingManager.updateGameData(currentGame)

            // Fallback: Also update score timeline for post-processing mode
            ScoreTimelineTracker.shared.updateScore(game: currentGame)
        } else if callCount % 5 == 0 {
            print("   ⚠️ Not recording - skipping game data update")
        }
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

