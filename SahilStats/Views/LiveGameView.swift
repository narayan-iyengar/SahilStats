// File: SahilStats/Views/LiveGameView.swift (Enhanced Control System)

import SwiftUI
import FirebaseAuth
import Combine

// MARK: - Refresh Trigger for Force UI Updates

class RefreshTrigger: ObservableObject {
    func trigger() {
        objectWillChange.send()
    }
}

struct LiveGameView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if let liveGame = firebaseService.getCurrentLiveGame() {
                if authService.showAdminFeatures {
                    // Admin view - can control the game
                    LiveGameControllerView(liveGame: liveGame)
                } else {
                    // Viewer - watch only
                    LiveGameWatchView(liveGame: liveGame)
                }
            } else {
                // No live game
                NoLiveGameView()
            }
        }
    }
}

// MARK: - Enhanced Live Game Controller with Proper Control Transfer

struct LiveGameControllerView: View {
    let liveGame: LiveGame
    @StateObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var deviceControl = DeviceControlManager.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) var scenePhase
    
    @State private var currentStats: PlayerStats
    @State private var currentHomeScore: Int
    @State private var currentAwayScore: Int
    @State private var currentPeriod: Int
    @State private var currentClock: TimeInterval
    @State private var sahilOnBench: Bool
    
    @State private var isUpdating = false
    @State private var error = ""
    @State private var updateTimer: Timer?
    @State private var hasUnsavedChanges = false
    @State private var clockSyncTimer: Timer?
    @State private var showingFinishAlert = false
    
    // NEW: Control transfer alerts
    @State private var showingControlRequestAlert = false
    @State private var requestingUser = ""
    @State private var requestingDeviceId = ""
    
    // ADDED: Force UI refresh capability
    @StateObject private var refreshTrigger = RefreshTrigger()
    
    // iPad detection
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    // Computed game state from server
    private var serverGameState: LiveGame {
        firebaseService.getCurrentLiveGame() ?? liveGame
    }
    
    private var isGameRunning: Bool {
        serverGameState.isRunning
    }
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        _currentStats = State(initialValue: liveGame.playerStats)
        _currentHomeScore = State(initialValue: liveGame.homeScore)
        _currentAwayScore = State(initialValue: liveGame.awayScore)
        _currentPeriod = State(initialValue: liveGame.period)
        _currentClock = State(initialValue: liveGame.clock)
        _sahilOnBench = State(initialValue: liveGame.sahilOnBench ?? false)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: isIPad ? 24 : 20) {
                // Enhanced Device Control Status
                EnhancedDeviceControlStatusCard(
                    hasControl: deviceControl.hasControl,
                    controllingUser: deviceControl.controllingUser,
                    canRequestControl: deviceControl.canRequestControl,
                    pendingRequest: deviceControl.pendingControlRequest,
                    isIPad: isIPad,
                    onRequestControl: {
                        requestControl()
                    }
                )
                
                // Synchronized Clock Display (always shows server time)
                SynchronizedClockCard(
                    liveGame: serverGameState,
                    isIPad: isIPad
                )
                
                // Only show controls if user has control
                if deviceControl.hasControl {
                    controllerInterface()
                } else {
                    viewerInterface()
                }
            }
            .padding(isIPad ? 24 : 16)
        }
        // Enhanced alerts for control management
        .alert("Control Request", isPresented: $showingControlRequestAlert) {
            Button("Grant Control", role: .none) {
                grantControlToRequester()
            }
            Button("Deny", role: .cancel) {
                denyControlRequest()
            }
        } message: {
            // IMPROVED: Show device info instead of just email for same-email scenarios
            let deviceInfo = requestingDeviceId.suffix(6) // Show last 6 chars of device ID
            Text("Another device (\(deviceInfo)) is requesting control of the game. Grant control?")
        }
        .alert("Finish Game", isPresented: $showingFinishAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Finish", role: .destructive) {
                finishGame()
            }
        } message: {
            Text("Are you sure you want to finish this game? This will save the final stats and end the live tracking.")
        }
        .alert("Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
        .onAppear {
            startClockSync()
            syncWithServer()
            
            print("--- LiveGameView onAppear ---")
            print("Current Device ID: \(deviceControl.deviceId)")
            print("Controlling Device ID from Server: \(serverGameState.controllingDeviceId ?? "Not Set")")
            print("Initial hasControl: \(deviceControl.hasControl)")
            
            // FORCE IMMEDIATE CONTROL STATUS UPDATE
            deviceControl.updateControlStatus(
                for: serverGameState,
                userEmail: authService.currentUser?.email
            )
            
            // AUTO-GRANT CONTROL: If this device created the game and we're an admin, auto-grant control
            autoGrantInitialControl()
            
            print("After initial update - hasControl: \(deviceControl.hasControl)")
        }
        .onDisappear {
            stopClockSync()
            updateTimer?.invalidate()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Handle app lifecycle to maintain sync
            switch newPhase {
            case .active:
                startClockSync()
                syncWithServer()
                autoGrantInitialControl() // Check again when app becomes active
            case .background, .inactive:
                stopClockSync()
            @unknown default:
                break
            }
        }
        .onChange(of: serverGameState) { _, newGame in
            print("🔄 SERVER STATE CHANGED on \(deviceControl.hasControl ? "CONTROLLER" : "VIEWER")")
            print("New isRunning: \(newGame.isRunning)")
            print("New clock: \(newGame.clock)")
            print("New clockStartTime: \(newGame.clockStartTime?.description ?? "nil")")
            print("New calculated clock: \(newGame.getCurrentClock())")
            
            deviceControl.updateControlStatus(
                for: newGame,
                userEmail: authService.currentUser?.email
            )
            
            // FIXED: Force immediate sync when server state changes
            syncWithServer()
            
            // FORCE: Immediate UI update for clock changes
            refreshTrigger.trigger()
            
            // Check for control requests - FIXED: Better detection logic
            checkForControlRequests(newGame)
            
            print("--- LiveGameView serverGameState changed ---")
            print("Current Device ID: \(deviceControl.deviceId)")
            print("New Controlling Device ID: \(newGame.controllingDeviceId ?? "Not Set")")
            print("Control Requested By: \(newGame.controlRequestedBy ?? "None")")
            print("Control Requesting Device: \(newGame.controlRequestingDeviceId ?? "None")")
            print("Does this device have control now? \(deviceControl.hasControl)")
            print("Game isRunning: \(newGame.isRunning)")
            print("Server clock: \(newGame.clock)")
            print("Current calculated clock: \(newGame.getCurrentClock())")
        }
    }
    
    // MARK: - Auto-Grant Initial Control
    
    private func autoGrantInitialControl() {
        // Auto-grant control if:
        // 1. User is an admin
        // 2. This device should have control but doesn't
        
        guard authService.showAdminFeatures,
              let userEmail = authService.currentUser?.email else {
            print("❌ Auto-grant failed: Not admin or no email")
            return
        }
        
        let game = serverGameState
        
        print("--- Auto-Grant Control Check ---")
        print("Device ID: \(deviceControl.deviceId)")
        print("Server Controlling Device: \(game.controllingDeviceId ?? "nil")")
        print("Server Controlling User: \(game.controllingUserEmail ?? "nil")")
        print("Current User: \(userEmail)")
        print("Device Has Control: \(deviceControl.hasControl)")
        
        // If this device should have control according to server but local state says no, force request
        if game.controllingDeviceId == deviceControl.deviceId &&
           game.controllingUserEmail == userEmail &&
           !deviceControl.hasControl {
            
            print("🔧 FORCE SYNC: Server says we have control but local state disagrees")
            deviceControl.updateControlStatus(for: game, userEmail: userEmail)
            return
        }
        
        // If no one has control, auto-grant to this device
        if game.controllingDeviceId == nil || game.controllingUserEmail == nil {
            print("✅ Auto-granting control - no one has it")
            
            Task {
                do {
                    _ = try await deviceControl.requestControl(for: game, userEmail: userEmail)
                } catch {
                    print("❌ Failed to auto-grant control: \(error)")
                }
            }
        }
    }
    
    // MARK: - Control Request Management
    
    private func requestControl() {
        Task {
            do {
                let granted = try await deviceControl.requestControl(
                    for: serverGameState,
                    userEmail: authService.currentUser?.email
                )
                
                if !granted {
                    // Control was not granted immediately, show waiting message
                    await MainActor.run {
                        // You could show a toast or temporary message here
                        print("Control request sent, waiting for approval...")
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func checkForControlRequests(_ game: LiveGame) {
        // ENHANCED: Handle timeouts and same email on multiple devices properly
        
        print("--- Checking for Control Requests ---")
        print("Device has control: \(deviceControl.hasControl)")
        print("Control requested by: \(game.controlRequestedBy ?? "None")")
        print("Control requesting device: \(game.controlRequestingDeviceId ?? "None")")
        print("Current user email: \(authService.currentUser?.email ?? "None")")
        print("Current device ID: \(deviceControl.deviceId)")
        print("Already showing alert: \(showingControlRequestAlert)")
        
        // Check if the control request has timed out (2 minutes = 120 seconds)
        var isRequestActive = false
        if let requestTimestamp = game.controlRequestTimestamp {
            let timeElapsed = Date().timeIntervalSince(requestTimestamp)
            isRequestActive = timeElapsed <= 120
            
            if !isRequestActive {
                print("⏰ Control request has expired, will be cleaned up automatically")
                // Don't show alert for expired requests
                return
            }
        }
        
        // Show control request alert if:
        // 1. We have control AND
        // 2. Someone is requesting control AND
        // 3. The requesting device is NOT this device (even if same email) AND
        // 4. The request is still active (not timed out) AND
        // 5. We're not already showing the alert
        if deviceControl.hasControl,
           let requestingUser = game.controlRequestedBy,
           let requestingDeviceId = game.controlRequestingDeviceId,
           requestingDeviceId != deviceControl.deviceId, // KEY FIX: Compare device IDs, not emails
           isRequestActive, // NEW: Only show for active requests
           !showingControlRequestAlert { // Don't show multiple alerts
            
            print("✅ Showing control request alert")
            print("Requesting user: \(requestingUser)")
            print("Requesting device: \(requestingDeviceId)")
            print("Our device: \(deviceControl.deviceId)")
            
            self.requestingUser = requestingUser
            self.requestingDeviceId = requestingDeviceId
            showingControlRequestAlert = true
        }
        
        // Hide the alert if there's no longer a pending request or it has expired
        if (game.controlRequestedBy == nil || !isRequestActive) && showingControlRequestAlert {
            print("Hiding control request alert - no pending request or expired")
            showingControlRequestAlert = false
        }
    }
    
    private func grantControlToRequester() {
        Task {
            do {
                try await deviceControl.grantControl(
                    for: serverGameState,
                    to: requestingUser
                )
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func denyControlRequest() {
        Task {
            do {
                try await deviceControl.denyControlRequest(for: serverGameState)
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func confirmReleaseControl() {
        Task {
            do {
                // First grant control to the requester
                try await deviceControl.grantControl(
                    for: serverGameState,
                    to: requestingUser
                )
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Controller Interface (when user has control)
    
    @ViewBuilder
    private func controllerInterface() -> some View {
        // NEW FLOW: Score -> Game Controls -> Player Status -> Stats
        
        LiveScoreCard(
            homeScore: $currentHomeScore,
            awayScore: $currentAwayScore,
            teamName: serverGameState.teamName,
            opponent: serverGameState.opponent,
            isIPad: isIPad,
            onScoreChange: scheduleUpdate
        )
        
        // MOVED: Game Controls now after score
        DynamicGameControlsCard(
            hasControl: deviceControl.hasControl,
            currentPeriod: currentPeriod,
            maxPeriods: serverGameState.numPeriods,
            periodLength: serverGameState.periodLength,
            gameFormat: serverGameState.gameFormat,
            isGameRunning: serverGameState.isRunning, // FIXED: Use server state
            isIPad: isIPad,
            onStartPause: {
                toggleGameClock()
            },
            onAddMinute: {
                addMinuteToClock()
            },
            onAdvancePeriod: {
                nextPeriod()
            },
            onFinishGame: {
                showingFinishAlert = true
            }
        )
        
        PlayerStatusCard(
            sahilOnBench: $sahilOnBench,
            isIPad: isIPad,
            onStatusChange: scheduleUpdate
        )
        
        if !sahilOnBench {
            // IMPROVED: Cleaner, less crowded detailed stats
            cleanDetailedStatsEntry()
            LiveStatsDisplayCard(stats: currentStats, isIPad: isIPad)
        }
    }
    
    // MARK: - Viewer Interface (when user doesn't have control)
    
    @ViewBuilder
    private func viewerInterface() -> some View {
        LiveScoreDisplayCard(
            homeScore: serverGameState.homeScore,
            awayScore: serverGameState.awayScore,
            teamName: serverGameState.teamName,
            opponent: serverGameState.opponent,
            isIPad: isIPad
        )
        
        Text("Sahil's Status: \(serverGameState.sahilOnBench ?? false ? "On Bench" : "On Court")")
            .font(isIPad ? .title3 : .body)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(isIPad ? 16 : 12)
        
        if !(serverGameState.sahilOnBench ?? false) {
            LiveStatsDisplayCard(
                stats: serverGameState.playerStats,
                isIPad: isIPad,
                isReadOnly: true
            )
        }
    }
    
    // MARK: - Clock Synchronization (FIXED: Always use server state)
    
    private func startClockSync() {
        clockSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // FIXED: Always sync local currentClock with server calculation
            let serverTime = serverGameState.getCurrentClock()
            
            // Update local clock to match server
            currentClock = serverTime
            
            // Auto-advance period if clock hits 0 and we have control
            if currentClock <= 0 && currentPeriod < serverGameState.numPeriods && deviceControl.hasControl {
                nextPeriodAutomatically()
            }
            
            // IMPORTANT: Force UI update on main thread
            DispatchQueue.main.async {
                self.refreshTrigger.trigger()
            }
        }
        
        // IMPORTANT: Keep timer running even when scrolling
        if let timer = clockSyncTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopClockSync() {
        clockSyncTimer?.invalidate()
        clockSyncTimer = nil
    }
    
    private func syncWithServer() {
        let game = serverGameState
        
        print("--- Syncing with Server ---")
        print("Server isRunning: \(game.isRunning)")
        print("Server clock: \(game.clock)")
        print("Server clockStartTime: \(game.clockStartTime?.description ?? "nil")")
        print("Server clockAtStart: \(game.clockAtStart?.description ?? "nil")")
        print("Calculated current clock: \(game.getCurrentClock())")
        
        // Update all local state from server
        currentStats = game.playerStats
        currentHomeScore = game.homeScore
        currentAwayScore = game.awayScore
        currentPeriod = game.period
        currentClock = game.getCurrentClock() // Use calculated current time
        sahilOnBench = game.sahilOnBench ?? false
        
        print("Local currentClock set to: \(currentClock)")
    }
    
    // MARK: - Game Control Actions (same as before but with proper permissions)
    
    private func toggleGameClock() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                var updatedGame = serverGameState
                let now = Date()
                
                if updatedGame.isRunning {
                    // Pause the game
                    print("🛑 Pausing game")
                    let currentTime = updatedGame.getCurrentClock()
                    updatedGame.isRunning = false
                    updatedGame.clock = currentTime // Save current calculated time
                    updatedGame.clockStartTime = nil
                    updatedGame.clockAtStart = nil
                    print("Paused at: \(currentTime)")
                } else {
                    // Start the game
                    print("▶️ Starting game")
                    print("Current clock value: \(updatedGame.clock)")
                    updatedGame.isRunning = true
                    updatedGame.clockStartTime = now
                    updatedGame.clockAtStart = updatedGame.clock // Use current clock as starting point
                    print("Set clockStartTime: \(now)")
                    print("Set clockAtStart: \(updatedGame.clock)")
                }
                
                updatedGame.lastClockUpdate = now
                
                // FIXED: Force immediate local update before server sync
                await MainActor.run {
                    // Update local state immediately for responsive UI
                    if updatedGame.isRunning {
                        // Game is starting
                        print("🔄 Updating local state: game starting")
                    } else {
                        // Game is pausing
                        print("🔄 Updating local state: game pausing")
                        currentClock = updatedGame.clock
                    }
                    
                    // Force UI refresh
                    refreshTrigger.trigger()
                }
                
                try await firebaseService.updateLiveGame(updatedGame)
                print("✅ Game clock toggle successful")
                
                // FIXED: Wait for server to sync and then force refresh
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                await MainActor.run {
                    syncWithServer()
                    refreshTrigger.trigger()
                    print("🔄 Final sync completed")
                }
                
            } catch {
                print("❌ Game clock toggle failed: \(error)")
                self.error = error.localizedDescription
            }
        }
    }
    
    private func addMinuteToClock() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                var updatedGame = serverGameState
                let now = Date()
                
                updatedGame.clock = updatedGame.getCurrentClock() + 60
                if updatedGame.isRunning {
                    updatedGame.clockStartTime = now
                    updatedGame.clockAtStart = updatedGame.clock
                }
                updatedGame.lastClockUpdate = now
                
                try await firebaseService.updateLiveGame(updatedGame)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func nextPeriod() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                var updatedGame = serverGameState
                let now = Date()
                
                updatedGame.period += 1
                updatedGame.clock = TimeInterval(updatedGame.periodLength * 60)
                updatedGame.isRunning = false
                updatedGame.clockStartTime = nil
                updatedGame.clockAtStart = nil
                updatedGame.lastClockUpdate = now
                
                try await firebaseService.updateLiveGame(updatedGame)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func nextPeriodAutomatically() {
        guard deviceControl.hasControl,
              currentPeriod < serverGameState.numPeriods else {
            return
        }
        
        nextPeriod()
    }
    
    // MARK: - Stats Update (same as before)
    
    private func scheduleUpdate() {
        guard deviceControl.hasControl else { return }
        
        hasUnsavedChanges = true
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            updateLiveGameImmediately()
        }
    }
    
    private func updateLiveGameImmediately() {
        guard hasUnsavedChanges && !isUpdating && deviceControl.hasControl &&
              authService.currentUser?.email == serverGameState.controllingUserEmail else {
            
            print("Update blocked. Has Control: \(deviceControl.hasControl), User Email Matches: \(authService.currentUser?.email == serverGameState.controllingUserEmail)")
            return
        }

        isUpdating = true
        hasUnsavedChanges = false
        
        Task {
            do {
                var updatedGame = serverGameState
                updatedGame.playerStats = currentStats
                updatedGame.homeScore = currentHomeScore
                updatedGame.awayScore = currentAwayScore
                updatedGame.sahilOnBench = sahilOnBench
                
                try await firebaseService.updateLiveGame(updatedGame)
                
                await MainActor.run {
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to update game: \(error.localizedDescription)"
                    isUpdating = false
                    hasUnsavedChanges = true
                }
            }
        }
    }
    
    private func finishGame() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                let finalGame = Game(
                    teamName: serverGameState.teamName,
                    opponent: serverGameState.opponent,
                    location: serverGameState.location,
                    timestamp: serverGameState.createdAt ?? Date(),
                    gameFormat: serverGameState.gameFormat,
                    periodLength: serverGameState.periodLength,
                    myTeamScore: currentHomeScore,
                    opponentScore: currentAwayScore,
                    fg2m: currentStats.fg2m,
                    fg2a: currentStats.fg2a,
                    fg3m: currentStats.fg3m,
                    fg3a: currentStats.fg3a,
                    ftm: currentStats.ftm,
                    fta: currentStats.fta,
                    rebounds: currentStats.rebounds,
                    assists: currentStats.assists,
                    steals: currentStats.steals,
                    blocks: currentStats.blocks,
                    fouls: currentStats.fouls,
                    turnovers: currentStats.turnovers,
                    adminName: authService.currentUser?.email
                )
                
                try await firebaseService.addGame(finalGame)
                try await firebaseService.deleteLiveGame(serverGameState.id ?? "")
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to finish game: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Clean Detailed Stats Entry (Less Crowded, No Quick Actions)
    
    private func cleanDetailedStatsEntry() -> some View {
        VStack(spacing: isIPad ? 24 : 20) {
            HStack {
                Text("Detailed Stats")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Tap +/- to adjust")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Shooting Stats - 2 columns for better spacing
            VStack(spacing: isIPad ? 20 : 16) {
                HStack {
                    Text("Shooting")
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    CleanStatCard(
                        title: "2PT Made",
                        value: $currentStats.fg2m,
                        max: currentStats.fg2a,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "2PT Att",
                        value: $currentStats.fg2a,
                        min: currentStats.fg2m,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "3PT Made",
                        value: $currentStats.fg3m,
                        max: currentStats.fg3a,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "3PT Att",
                        value: $currentStats.fg3a,
                        min: currentStats.fg3m,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "FT Made",
                        value: $currentStats.ftm,
                        max: currentStats.fta,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "FT Att",
                        value: $currentStats.fta,
                        min: currentStats.ftm,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
            }
            
            // Other Stats - 2 columns for better spacing
            VStack(spacing: isIPad ? 20 : 16) {
                HStack {
                    Text("Other Stats")
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    CleanStatCard(
                        title: "Rebounds",
                        value: $currentStats.rebounds,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "Assists",
                        value: $currentStats.assists,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "Steals",
                        value: $currentStats.steals,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "Blocks",
                        value: $currentStats.blocks,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "Fouls",
                        value: $currentStats.fouls,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    CleanStatCard(
                        title: "Turnovers",
                        value: $currentStats.turnovers,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 24 : 20)
        .padding(.horizontal, isIPad ? 24 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Enhanced Device Control Status Card

struct EnhancedDeviceControlStatusCard: View {
    let hasControl: Bool
    let controllingUser: String?
    let canRequestControl: Bool
    let pendingRequest: String?
    let isIPad: Bool
    let onRequestControl: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            HStack {
                Image(systemName: hasControl ? "gamecontroller.fill" : "eye.fill")
                    .foregroundColor(hasControl ? .green : .blue)
                    .font(isIPad ? .title3 : .body)
                
                Text(hasControl ? "You have control" : "Viewing live game")
                    .font(isIPad ? .title3 : .body)
                    .fontWeight(.semibold)
                    .foregroundColor(hasControl ? .green : .blue)
                
                Spacer()
            }
            
            if !hasControl {
                // IMPROVED: Show device info for same-email scenarios
                if let controllingUser = controllingUser {
                    Text("Another device is controlling the game")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No one is currently controlling the game")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                }
                
                // Show different button states based on pending request
                if let pendingUser = pendingRequest {
                    Text("Control request sent")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                        .padding(.vertical, 4)
                    
                    Text("Waiting for approval...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if canRequestControl {
                    Button("Request Control") {
                        onRequestControl()
                    }
                    .buttonStyle(SecondaryButtonStyle(isIPad: isIPad))
                } else {
                    Text("Control request pending")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(hasControl ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Clean Stat Card Component (Less Crowded)

struct CleanStatCard: View {
    let title: String
    @Binding var value: Int
    let min: Int
    let max: Int?
    let isIPad: Bool
    let onStatChange: () -> Void
    
    init(title: String, value: Binding<Int>, min: Int = 0, max: Int? = nil, isIPad: Bool, onStatChange: @escaping () -> Void) {
        self.title = title
        self._value = value
        self.min = min
        self.max = max
        self.isIPad = isIPad
        self.onStatChange = onStatChange
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 10) {
            Text(title)
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            HStack(spacing: isIPad ? 16 : 12) {
                Button("-") {
                    if value > min {
                        value -= 1
                        onStatChange()
                    }
                }
                .buttonStyle(CleanStatButtonStyle(color: .red, isIPad: isIPad))
                .disabled(value <= min)
                
                Text("\(value)")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .frame(minWidth: isIPad ? 40 : 35)
                    .foregroundColor(.primary)
                
                Button("+") {
                    if let max = max, value >= max {
                        // Don't increment if at max
                    } else {
                        value += 1
                        onStatChange()
                    }
                }
                .buttonStyle(CleanStatButtonStyle(color: .green, isIPad: isIPad))
                .disabled(max != nil && value >= max!)
            }
        }
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct CleanStatButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title2 : .title3)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 44 : 36, height: isIPad ? 44 : 36)
            .background(color)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct QuickActionButton: View {
    let title: String
    let color: Color
    let isIPad: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, isIPad ? 12 : 8)
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(isIPad ? 8 : 6)
        }
    }
}

// MARK: - Existing Supporting Components (keeping same implementations)

struct SynchronizedClockCard: View {
    let liveGame: LiveGame
    let isIPad: Bool
    @State private var displayTime: TimeInterval
    @State private var clockTimer: Timer?
    
    init(liveGame: LiveGame, isIPad: Bool) {
        self.liveGame = liveGame
        self.isIPad = isIPad
        _displayTime = State(initialValue: liveGame.getCurrentClock())
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("Period \(liveGame.period)")
                .font(isIPad ? .title2 : .headline)
                .foregroundColor(.secondary)
            
            Text(formatClockTime(displayTime))
                .font(isIPad ? .system(size: 48, weight: .bold) : .largeTitle)
                .fontWeight(.bold)
                .foregroundColor(liveGame.isRunning ? .red : .primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
        .onAppear {
            startLocalClockSync()
        }
        .onDisappear {
            stopLocalClockSync()
        }
        .onChange(of: liveGame.id) { _, _ in
            // Restart sync when game changes
            stopLocalClockSync()
            startLocalClockSync()
        }
    }
    
    private func startLocalClockSync() {
        stopLocalClockSync() // Ensure we don't have multiple timers
        
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // FIXED: Always update, let the getCurrentClock() method handle the logic
            let newTime = liveGame.getCurrentClock()
            
            // Update the display time
            DispatchQueue.main.async {
                self.displayTime = newTime
            }
        }
        
        // IMPORTANT: Keep timer running even when scrolling
        if let timer = clockTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopLocalClockSync() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
    
    private func formatClockTime(_ time: TimeInterval) -> String {
        if time <= 59 {
            return String(format: "%.1f", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct DynamicGameControlsCard: View {
    let hasControl: Bool
    let currentPeriod: Int
    let maxPeriods: Int
    let periodLength: Int
    let gameFormat: GameFormat
    let isGameRunning: Bool
    let isIPad: Bool
    let onStartPause: () -> Void
    let onAddMinute: () -> Void
    let onAdvancePeriod: () -> Void
    let onFinishGame: () -> Void
    
    // IMPROVED: Dynamic button text (no icons, cleaner text)
    private var startPauseText: String {
        isGameRunning ? "Pause" : "Start"
    }
    
    private var startPauseColor: Color {
        isGameRunning ? .orange : .green
    }
    
    private var advancePeriodText: String {
        let periodName = gameFormat == .halves ? "Half" : "Period"
        
        if currentPeriod < maxPeriods {
            return "End \(periodName)"
        } else {
            return "End Game"
        }
    }
    
    private var advancePeriodColor: Color {
        currentPeriod < maxPeriods ? .blue : .red
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Game Controls")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            if hasControl {
                // IMPROVED: Larger fonts, no icons, cleaner design
                HStack(spacing: isIPad ? 12 : 8) {
                    // Start/Pause button - larger font, no icon
                    Button(startPauseText) {
                        onStartPause()
                    }
                    .buttonStyle(ImprovedControlButtonStyle(color: startPauseColor, isIPad: isIPad))
                    
                    // Add time button - larger font
                    Button(isIPad ? "+1 Minute" : "+1 Min") {
                        onAddMinute()
                    }
                    .buttonStyle(ImprovedControlButtonStyle(color: .purple, isIPad: isIPad))
                    
                    // IMPROVED: Dynamic end period/game button - larger font
                    Button(advancePeriodText) {
                        if currentPeriod < maxPeriods {
                            onAdvancePeriod()
                        } else {
                            onFinishGame()
                        }
                    }
                    .buttonStyle(ImprovedControlButtonStyle(color: advancePeriodColor, isIPad: isIPad))
                }
            } else {
                Text("Only the controlling device can manage the game")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Improved Control Button Style (Larger Font, Better Design)

struct ImprovedControlButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body) // LARGER FONT
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 16 : 14) // More padding for bigger buttons
            .padding(.horizontal, isIPad ? 20 : 16)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(isIPad ? 12 : 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// New compact button style for single-row layout
struct CompactControlButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool
    
    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 14 : 12)
            .padding(.horizontal, isIPad ? 16 : 12)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(isIPad ? 10 : 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Existing Card Components (keeping same implementations)

struct LiveScoreCard: View {
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    let onScoreChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Live Score")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            HStack(spacing: isIPad ? 32 : 24) {
                // Home team (left side)
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(teamName)
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: isIPad ? 16 : 12) {
                        Button("-") {
                            if homeScore > 0 {
                                homeScore -= 1
                                onScoreChange()
                            }
                        }
                        .buttonStyle(ScoreButtonStyle(isIPad: isIPad))
                        
                        Text("\(homeScore)")
                            .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(minWidth: isIPad ? 80 : 60)
                        
                        Button("+") {
                            homeScore += 1
                            onScoreChange()
                        }
                        .buttonStyle(ScoreButtonStyle(isIPad: isIPad))
                    }
                }
                
                // Separator
                Text("–")
                    .font(isIPad ? .largeTitle : .title)
                    .foregroundColor(.secondary)
                
                // Away team (right side)
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(opponent)
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: isIPad ? 16 : 12) {
                        Button("-") {
                            if awayScore > 0 {
                                awayScore -= 1
                                onScoreChange()
                            }
                        }
                        .buttonStyle(ScoreButtonStyle(isIPad: isIPad))
                        
                        Text("\(awayScore)")
                            .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(minWidth: isIPad ? 80 : 60)
                        
                        Button("+") {
                            awayScore += 1
                            onScoreChange()
                        }
                        .buttonStyle(ScoreButtonStyle(isIPad: isIPad))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveScoreDisplayCard: View {
    let homeScore: Int
    let awayScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Live Score")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            HStack(spacing: isIPad ? 40 : 30) {
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(teamName)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(homeScore)")
                        .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .frame(minWidth: isIPad ? 80 : 60)
                }
                
                Text("–")
                    .font(isIPad ? .largeTitle : .title)
                    .foregroundColor(.secondary)
                
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(opponent)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(awayScore)")
                        .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(minWidth: isIPad ? 80 : 60)
                }
            }
        }
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct PlayerStatusCard: View {
    @Binding var sahilOnBench: Bool
    let isIPad: Bool
    let onStatusChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            Text("Sahil's Status")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            HStack(spacing: isIPad ? 12 : 8) {
                Button("On Court") {
                    sahilOnBench = false
                    onStatusChange()
                }
                .buttonStyle(StatusButtonStyle(isSelected: !sahilOnBench, isIPad: isIPad))
                
                Button("On Bench") {
                    sahilOnBench = true
                    onStatusChange()
                }
                .buttonStyle(StatusButtonStyle(isSelected: sahilOnBench, isIPad: isIPad))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveStatsDisplayCard: View {
    let stats: PlayerStats
    let isIPad: Bool
    let isReadOnly: Bool
    
    init(stats: PlayerStats, isIPad: Bool = false, isReadOnly: Bool = false) {
        self.stats = stats
        self.isIPad = isIPad
        self.isReadOnly = isReadOnly
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text(isReadOnly ? "Current Stats" : "Live Stats")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: isIPad ? 16 : 12) {
                LiveStatDisplayCard(title: "PTS", value: stats.points, color: .purple, isIPad: isIPad)
                LiveStatDisplayCard(title: "REB", value: stats.rebounds, color: .mint, isIPad: isIPad)
                LiveStatDisplayCard(title: "AST", value: stats.assists, color: .cyan, isIPad: isIPad)
                LiveStatDisplayCard(title: "STL", value: stats.steals, color: .yellow, isIPad: isIPad)
                LiveStatDisplayCard(title: "BLK", value: stats.blocks, color: .red, isIPad: isIPad)
                LiveStatDisplayCard(title: "TO", value: stats.turnovers, color: .pink, isIPad: isIPad)
            }
            
            // Shooting percentages
            if stats.fg2a > 0 || stats.fg3a > 0 || stats.fta > 0 {
                Divider()
                
                HStack(spacing: isIPad ? 24 : 20) {
                    if stats.fg2a > 0 {
                        ShootingStatCard(
                            title: "FG%",
                            made: stats.fg2m + stats.fg3m,
                            attempted: stats.fg2a + stats.fg3a,
                            isIPad: isIPad
                        )
                    }
                    
                    if stats.fg3a > 0 {
                        ShootingStatCard(
                            title: "3P%",
                            made: stats.fg3m,
                            attempted: stats.fg3a,
                            isIPad: isIPad
                        )
                    }
                    
                    if stats.fta > 0 {
                        ShootingStatCard(
                            title: "FT%",
                            made: stats.ftm,
                            attempted: stats.fta,
                            isIPad: isIPad
                        )
                    }
                }
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveStatDisplayCard: View {
    let title: String
    let value: Int
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text("\(value)")
                .font(isIPad ? .title : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, isIPad ? 16 : 12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

struct ShootingStatCard: View {
    let title: String
    let made: Int
    let attempted: Int
    let isIPad: Bool
    
    private var percentage: Double {
        return attempted > 0 ? Double(made) / Double(attempted) : 0.0
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(percentage * 100))%")
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("\(made)/\(attempted)")
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, isIPad ? 12 : 8)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(isIPad ? 8 : 6)
    }
}

// MARK: - Live Game Watch View (Non-Admin)

struct LiveGameWatchView: View {
    let liveGame: LiveGame
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Watch-only header
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                        
                        Text("WATCHING LIVE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    
                    Text("You're watching in real-time. Only admins can control the game.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                // Game info (read-only)
                SynchronizedClockCard(
                    liveGame: liveGame,
                    isIPad: isIPad
                )
                
                // Score display (read-only)
                LiveScoreDisplayCard(
                    homeScore: liveGame.homeScore,
                    awayScore: liveGame.awayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    isIPad: isIPad
                )
                
                // Stats display (read-only)
                if !(liveGame.sahilOnBench ?? false) {
                    LiveStatsDisplayCard(
                        stats: liveGame.playerStats,
                        isIPad: isIPad,
                        isReadOnly: true
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.basketball")
                            .font(.system(size: isIPad ? 80 : 60))
                            .foregroundColor(.secondary)
                        
                        Text("Sahil is on the bench")
                            .font(isIPad ? .title : .title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Stats tracking is paused")
                            .font(isIPad ? .title3 : .body)
                            .foregroundColor(.secondary)
                    }
                    .padding(isIPad ? 32 : 24)
                    .background(Color(.systemGray6))
                    .cornerRadius(isIPad ? 16 : 12)
                }
            }
            .padding(isIPad ? 24 : 16)
        }
    }
}

// MARK: - No Live Game View

struct NoLiveGameView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Live Game")
                .font(.title)
                .fontWeight(.bold)
            
            Text("There's no live game currently in progress.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if authService.showAdminFeatures {
                NavigationLink("Start New Live Game") {
                    GameSetupView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            LiveGameView()
                .environmentObject(AuthService())
        }
    } else {
        NavigationView {
            LiveGameView()
                .environmentObject(AuthService())
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
