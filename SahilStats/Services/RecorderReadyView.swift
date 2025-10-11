//
//  RecorderReadyView.swift
//  SahilStats
//
//  Recorder waiting state before recording starts
//

import SwiftUI
import Combine
import MultipeerConnectivity
import FirebaseFirestore

struct RecorderReadyView: View {
    let liveGame: LiveGame?  // Now optional - may not have game info yet
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var firebaseService = FirebaseService.shared

    @State private var connectionLostTime: Date?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showingRecordingView = false
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    @State private var availableStorage: String = "Calculating..."
    @State private var batteryTimer: Timer?
    @State private var receivedLiveGame: LiveGame?  // Game info received from controller
    
    var body: some View {
        ZStack {
            // Dark background for recording setup
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Game Info Card (reusing design patterns)
                gameInfoCard
                
                // Connection Status (reusing AdminStatusIndicator style)
                connectionStatusCard
                
                // Recording Readiness Status
                readinessStatusCard
                
                // System Status
                systemStatusCard
                
                Spacer()
                
                // Emergency Exit (reusing DismissButton)
                DismissButton(action: handleEmergencyExit)
                    .padding(.bottom, 40)
            }
            .padding(24)
            
            // Fullscreen recording view when activated
            .fullScreenCover(isPresented: $showingRecordingView) {
                if let game = effectiveGame {
                    CleanVideoRecordingView(liveGame: game)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .onChange(of: multipeer.connectionState) { oldState, newState in
            handleConnectionChange(oldState: oldState, newState: newState)
        }
    }
    
    // MARK: - Computed Properties

    /// The effective game to use - prioritizes received game from controller, falls back to passed-in game
    private var effectiveGame: LiveGame? {
        receivedLiveGame ?? liveGame ?? firebaseService.getCurrentLiveGame()
    }

    // MARK: - View Components (Reusing existing design patterns)

    private var gameInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "basketball.fill")
                    .font(.title)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recording Setup")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let game = effectiveGame {
                        Text("\(game.teamName) vs \(game.opponent)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    } else {
                        Text("Waiting for game info...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .italic()
                    }
                }

                Spacer()
            }

            if effectiveGame != nil {
                Text("Waiting for controller to start recording...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connected. Controller will send game details shortly...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.3))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var connectionStatusCard: some View {
        HStack(spacing: 16) {
            // Connection status icon (similar to AdminStatusIndicator)
            ZStack {
                Circle()
                    .fill(connectionStatusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: connectionStatusIcon)
                    .font(.headline)
                    .foregroundColor(connectionStatusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Controller Connection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(connectionStatusText)
                    .font(.caption)
                    .foregroundColor(connectionStatusColor)
            }
            
            Spacer()
            
            if multipeer.connectionState.isConnected {
                Text(multipeer.connectedPeers.first?.displayName ?? "Connected")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var readinessStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: recordingManager.canRecordVideo ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(recordingManager.canRecordVideo ? .green : .red)
                
                Text("Camera Ready")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if !recordingManager.canRecordVideo {
                Text("Camera permission required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var systemStatusCard: some View {
        HStack(spacing: 20) {
            // Battery status
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                    Text("\(Int(batteryLevel * 100))%")
                        .font(.caption)
                        .foregroundColor(batteryColor)
                }
                Text("Battery")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Divider()
                .frame(height: 30)
                .background(Color.gray)
            
            // Storage status
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.blue)
                    Text(availableStorage)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Text("Storage")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatusColor: Color {
        if let lostTime = connectionLostTime {
            let timeLost = Date().timeIntervalSince(lostTime)
            return timeLost > 30 ? .red : .orange
        }
        
        switch multipeer.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        default: return .red
        }
    }
    
    private var connectionStatusIcon: String {
        if connectionLostTime != nil {
            return "wifi.exclamationmark"
        }
        
        switch multipeer.connectionState {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "antenna.radiowaves.left.and.right"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private var connectionStatusText: String {
        if let lostTime = connectionLostTime {
            let timeLost = Date().timeIntervalSince(lostTime)
            return "Reconnecting... (\(Int(timeLost))s)"
        }
        
        switch multipeer.connectionState {
        case .connected: return "Connected to Controller"
        case .connecting: return "Connecting..."
        default: return "Connection Lost"
        }
    }
    
    private var batteryIcon: String {
        switch batteryLevel {
        case 0.75...1.0: return "battery.100"
        case 0.5..<0.75: return "battery.75"
        case 0.25..<0.5: return "battery.50"
        case 0.1..<0.25: return "battery.25"
        default: return "battery.0"
        }
    }
    
    private var batteryColor: Color {
        switch batteryLevel {
        case 0.3...1.0: return .green
        case 0.15..<0.3: return .orange
        default: return .red
        }
    }
    
    // MARK: - Lifecycle Methods
    
    private func setupView() {
        print("🎬 RecorderReadyView: Setting up recorder ready state")

        // Keep screen awake
        UIApplication.shared.isIdleTimerDisabled = true

        // Setup message handling for recording commands
        multipeer.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { message in
                self.handleRecordingMessage(message)
            }
            .store(in: &cancellables)

        // Listen for live game updates from Firebase (in case controller creates game)
        firebaseService.$liveGames
            .receive(on: DispatchQueue.main)
            .sink { liveGames in
                // If we don't have game info yet and a live game appears, use it
                if self.receivedLiveGame == nil, let game = self.firebaseService.getCurrentLiveGame() {
                    print("📱 RecorderReadyView: Live game detected from Firebase: \(game.teamName) vs \(game.opponent)")
                    self.receivedLiveGame = game
                }
            }
            .store(in: &cancellables)

        // Setup battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryLevel()

        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.updateBatteryLevel()
            self.updateStorageInfo()
        }

        // Initial storage calculation
        updateStorageInfo()

        // Setup camera (but don't start session yet)
        recordingManager.setupCamera()
    }
    
    private func cleanupView() {
        print("🎬 RecorderReadyView: Cleaning up")
        UIApplication.shared.isIdleTimerDisabled = false
        UIDevice.current.isBatteryMonitoringEnabled = false
        batteryTimer?.invalidate()
        cancellables.removeAll()
    }
    
    private func handleConnectionChange(oldState: MultipeerConnectivityManager.ConnectionState, newState: MultipeerConnectivityManager.ConnectionState) {
        print("🔄 RecorderReadyView: Connection changed from \(oldState) to \(newState)")

        switch newState {
        case .connected:
            // Connection restored
            connectionLostTime = nil
            print("✅ Connection restored - ready for recording commands")

        case .disconnected:
            // Connection lost - start tracking time and attempt reconnection
            if connectionLostTime == nil {
                connectionLostTime = Date()
                print("⚠️ Connection lost - will attempt auto-reconnect and continue if recording")

                // Start reconnection attempts
                startReconnectionAttempts()
            }

        case .connecting:
            print("🔄 Attempting to reconnect...")

        case .idle:
            print("⚠️ Connection idle - not connected")

        case .searching:
            print("🔍 Searching for controller...")
        }
    }
    
    private func startReconnectionAttempts() {
        // If we're already recording and lose connection, keep recording
        // and try to reconnect in the background
        
        print("🔄 Starting auto-reconnection attempts")
        
        // Use existing MultipeerConnectivity auto-reconnection for trusted devices
        // The connection manager will handle the reconnection automatically
        
        // Monitor for extended disconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) { // 1 minute
            if let lostTime = self.connectionLostTime {
                let timeLost = Date().timeIntervalSince(lostTime)
                if timeLost > 60 {
                    print("⚠️ Extended disconnection (\(Int(timeLost))s) - but continuing to record")
                    // Continue recording anyway - controller can reconnect when they return
                }
            }
        }
    }
    
    private func handleRecordingMessage(_ message: MultipeerConnectivityManager.Message) {
        print("📱 RecorderReadyView: Received message: \(message.type)")

        switch message.type {
        case .gameStarting:
            print("🎮 Received gameStarting message - fetching game info from Firebase")
            if let gameId = message.payload?["gameId"] as? String {
                print("   Game ID: \(gameId)")
                // Fetch the game info from Firebase and update our state
                Task {
                    do {
                        let db = Firestore.firestore()
                        let document = try await db.collection("liveGames").document(gameId).getDocument()
                        if let game = try? document.data(as: LiveGame.self) {
                            await MainActor.run {
                                print("✅ Received game info: \(game.teamName) vs \(game.opponent)")
                                var gameWithId = game
                                gameWithId.id = gameId
                                self.receivedLiveGame = gameWithId
                            }
                        }
                    } catch {
                        print("❌ Failed to fetch game info: \(error)")
                    }
                }
            }

        case .startRecording:
            print("🎬 Received START RECORDING command")
            startRecordingTransition()

        case .stopRecording:
            print("🎬 Received STOP RECORDING command")
            // If we're in ready state, this doesn't apply to us

        case .gameEnded:
            print("🎬 Game ended - returning to dashboard")
            navigation.returnToDashboard()

        default:
            break
        }
    }
    
    private func startRecordingTransition() {
        print("🎬 Starting transition to recording view")
        
        // Ensure we have camera access
        guard recordingManager.canRecordVideo else {
            print("❌ Cannot start recording - no camera access")
            return
        }
        
        // Start camera session before transitioning
        recordingManager.startCameraSession()
        
        // Small delay to ensure camera is ready, then transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingRecordingView = true
        }
    }
    
    private func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    private func updateStorageInfo() {
        if let available = getAvailableStorage() {
            availableStorage = formatBytes(available)
        }
    }
    
    private func getAvailableStorage() -> Int64? {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            return nil
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func handleEmergencyExit() {
        print("🚨 Emergency exit from recorder ready view - returning to dashboard")
        navigation.returnToDashboard()
    }
}

// MARK: - Preview

#Preview("With Game Info") {
    RecorderReadyView(liveGame: LiveGame(
        teamName: "Warriors",
        opponent: "Lakers",
        gameFormat: .halves,
        quarterLength: 20
    ))
}

#Preview("Waiting for Game Info") {
    RecorderReadyView(liveGame: nil)
}

