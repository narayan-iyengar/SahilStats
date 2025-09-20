// File: SahilStats/Views/LiveGameView.swift (WITH STICKY HEADER)

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

// MARK: - Enhanced Live Game Controller with STICKY HEADER

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
    
    // FIXED: Separate local clock state that doesn't get overridden by server
    @State private var localClockTime: TimeInterval = 0
    @State private var lastServerUpdate: Date = Date()
    
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
        _localClockTime = State(initialValue: liveGame.getCurrentClock())
    }
    
    var body: some View {
        // NEW: Use VStack with sticky header instead of ScrollView
        VStack(spacing: 0) {
            // STICKY HEADER: Always visible at top
            stickyHeader()
            
            // SCROLLABLE CONTENT: Stats and other details
            ScrollView {
                VStack(spacing: isIPad ? 24 : 20) {
                    // REMOVED: Player Status (now in sticky header)
                    // PlayerStatusCard moved to sticky header
                    
                    // Detailed stats (only if playing AND has control)
                    if !sahilOnBench && deviceControl.hasControl {
                        cleanDetailedStatsEntry()
                        LiveStatsDisplayCard(stats: currentStats, isIPad: isIPad)
                    } else if !sahilOnBench {
                        // Viewer stats (read-only)
                        LiveStatsDisplayCard(
                            stats: serverGameState.playerStats,
                            isIPad: isIPad,
                            isReadOnly: true
                        )
                    } else {
                        // On bench message
                        onBenchMessage()
                    }
                    
                    // Add some bottom padding for better scrolling
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, isIPad ? 24 : 16)
                .padding(.top, isIPad ? 20 : 16)
            }
        }
        // All the same alerts and onChange handlers as before
        .alert("Control Request", isPresented: $showingControlRequestAlert) {
            Button("Grant Control", role: .none) {
                grantControlToRequester()
            }
            Button("Deny", role: .cancel) {
                denyControlRequest()
            }
        } message: {
            let deviceInfo = requestingDeviceId.suffix(6)
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
            startFixedClockSync()
            syncWithServer()
            
            print("--- LiveGameView onAppear ---")
            print("Current Device ID: \(deviceControl.deviceId)")
            print("Controlling Device ID from Server: \(serverGameState.controllingDeviceId ?? "Not Set")")
            print("Initial hasControl: \(deviceControl.hasControl)")
            
            deviceControl.updateControlStatus(
                for: serverGameState,
                userEmail: authService.currentUser?.email
            )
            
            autoGrantInitialControl()
            
            print("After initial update - hasControl: \(deviceControl.hasControl)")
        }
        .onDisappear {
            stopFixedClockSync()
            updateTimer?.invalidate()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                startFixedClockSync()
                syncWithServer()
                autoGrantInitialControl()
            case .background, .inactive:
                stopFixedClockSync()
            @unknown default:
                break
            }
        }
        .onChange(of: serverGameState) { _, newGame in
            print("🔄 SERVER STATE CHANGED on \(deviceControl.hasControl ? "CONTROLLER" : "VIEWER")")
            
            deviceControl.updateControlStatus(
                for: newGame,
                userEmail: authService.currentUser?.email
            )
            
            // FIXED: Only sync non-clock data, let local clock continue
            syncNonClockDataWithServer(newGame)
            
            // Force UI update
            refreshTrigger.trigger()
            
            // Check for control requests
            checkForControlRequests(newGame)
        }
    }
    
    // MARK: - NEW STICKY HEADER


    @ViewBuilder
    private func stickyHeader() -> some View {
        VStack(spacing: isIPad ? 16 : 12) {
            // Device Control Status (compact version)
            CompactDeviceControlStatusCard(
                hasControl: deviceControl.hasControl,
                controllingUser: deviceControl.controllingUser,
                canRequestControl: deviceControl.canRequestControl,
                pendingRequest: deviceControl.pendingControlRequest,
                isIPad: isIPad,
                onRequestControl: {
                    requestControl()
                }
            )
            
            // FIXED: Clock Display with game format
            CompactClockCard(
                period: currentPeriod,
                clockTime: localClockTime,
                isGameRunning: isGameRunning,
                gameFormat: serverGameState.gameFormat, // PASS GAME FORMAT
                isIPad: isIPad
            )
            
            // Score Controls (always visible)
            if deviceControl.hasControl {
                CompactLiveScoreCard(
                    homeScore: $currentHomeScore,
                    awayScore: $currentAwayScore,
                    teamName: serverGameState.teamName,
                    opponent: serverGameState.opponent,
                    isIPad: isIPad,
                    onScoreChange: scheduleUpdate
                )
            } else {
                CompactLiveScoreDisplayCard(
                    homeScore: serverGameState.homeScore,
                    awayScore: serverGameState.awayScore,
                    teamName: serverGameState.teamName,
                    opponent: serverGameState.opponent,
                    isIPad: isIPad
                )
            }
            
            // Player Status
            PlayerStatusCard(
                sahilOnBench: $sahilOnBench,
                isIPad: isIPad,
                hasControl: deviceControl.hasControl,
                onStatusChange: scheduleUpdate
            )
            
            // FIXED: Game Controls with correct format
            if deviceControl.hasControl {
                CompactGameControlsCard(
                    currentPeriod: currentPeriod,
                    maxPeriods: serverGameState.numPeriods,
                    gameFormat: serverGameState.gameFormat, // ALREADY PASSING THIS
                    isGameRunning: serverGameState.isRunning,
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
            }
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    
    @ViewBuilder
    private func onBenchMessage() -> some View {
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
    
    // MARK: - All the existing methods remain the same...
    // (startFixedClockSync, syncNonClockDataWithServer, etc.)
    
    private func startFixedClockSync() {
        clockSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let game = serverGameState
            
            if game.isRunning {
                if let startTime = game.clockStartTime,
                   let clockAtStart = game.clockAtStart {
                    
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    let calculatedTime = max(0, clockAtStart - elapsedTime)
                    
                    localClockTime = calculatedTime
                    
                    if calculatedTime <= 0 && currentPeriod < serverGameState.numPeriods && deviceControl.hasControl {
                        nextPeriodAutomatically()
                    }
                } else {
                    localClockTime = game.clock
                }
            } else {
                localClockTime = game.clock
            }
            
            DispatchQueue.main.async {
                self.refreshTrigger.trigger()
            }
        }
        
        if let timer = clockSyncTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopFixedClockSync() {
        clockSyncTimer?.invalidate()
        clockSyncTimer = nil
    }
    
    private func syncNonClockDataWithServer(_ game: LiveGame) {
        print("--- Syncing Non-Clock Data with Server ---")
        
        currentStats = game.playerStats
        currentHomeScore = game.homeScore
        currentAwayScore = game.awayScore
        currentPeriod = game.period
        sahilOnBench = game.sahilOnBench ?? false
        
        if !deviceControl.hasControl ||
           abs(localClockTime - game.getCurrentClock()) > 5.0 {
            print("🔄 Syncing clock due to large difference or no control")
            localClockTime = game.getCurrentClock()
        }
        
        lastServerUpdate = Date()
    }
    
    private func syncWithServer() {
        let game = serverGameState
        
        print("--- Initial Sync with Server ---")
        print("Server isRunning: \(game.isRunning)")
        print("Server clock: \(game.clock)")
        print("Calculated current clock: \(game.getCurrentClock())")
        
        currentStats = game.playerStats
        currentHomeScore = game.homeScore
        currentAwayScore = game.awayScore
        currentPeriod = game.period
        sahilOnBench = game.sahilOnBench ?? false
        localClockTime = game.getCurrentClock()
        
        print("Local clock initialized to: \(localClockTime)")
    }
    
    private func autoGrantInitialControl() {
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
        
        if game.controllingDeviceId == deviceControl.deviceId &&
           game.controllingUserEmail == userEmail &&
           !deviceControl.hasControl {
            
            print("🔧 FORCE SYNC: Server says we have control but local state disagrees")
            deviceControl.updateControlStatus(for: game, userEmail: userEmail)
            return
        }
        
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
    
    private func requestControl() {
        Task {
            do {
                let granted = try await deviceControl.requestControl(
                    for: serverGameState,
                    userEmail: authService.currentUser?.email
                )
                
                if !granted {
                    await MainActor.run {
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
        print("--- Checking for Control Requests ---")
        print("Device has control: \(deviceControl.hasControl)")
        print("Control requested by: \(game.controlRequestedBy ?? "None")")
        print("Control requesting device: \(game.controlRequestingDeviceId ?? "None")")
        
        var isRequestActive = false
        if let requestTimestamp = game.controlRequestTimestamp {
            let timeElapsed = Date().timeIntervalSince(requestTimestamp)
            isRequestActive = timeElapsed <= 120
            
            if !isRequestActive {
                print("⏰ Control request has expired")
                return
            }
        }
        
        if deviceControl.hasControl,
           let requestingUser = game.controlRequestedBy,
           let requestingDeviceId = game.controlRequestingDeviceId,
           requestingDeviceId != deviceControl.deviceId,
           isRequestActive,
           !showingControlRequestAlert {
            
            print("✅ Showing control request alert")
            self.requestingUser = requestingUser
            self.requestingDeviceId = requestingDeviceId
            showingControlRequestAlert = true
        }
        
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
    
    private func toggleGameClock() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                var updatedGame = serverGameState
                let now = Date()
                
                if updatedGame.isRunning {
                    print("🛑 Pausing game")
                    updatedGame.isRunning = false
                    updatedGame.clock = localClockTime
                    updatedGame.clockStartTime = nil
                    updatedGame.clockAtStart = nil
                    print("Paused at: \(localClockTime)")
                } else {
                    print("▶️ Starting game")
                    updatedGame.isRunning = true
                    updatedGame.clockStartTime = now
                    updatedGame.clockAtStart = localClockTime
                    updatedGame.clock = localClockTime
                    print("Started with clock: \(localClockTime)")
                }
                
                updatedGame.lastClockUpdate = now
                
                try await firebaseService.updateLiveGame(updatedGame)
                print("✅ Game clock toggle successful")
                
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
                
                localClockTime += 60
                
                updatedGame.clock = localClockTime
                if updatedGame.isRunning {
                    updatedGame.clockStartTime = now
                    updatedGame.clockAtStart = localClockTime
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
                let newClockTime = TimeInterval(updatedGame.periodLength * 60)
                updatedGame.clock = newClockTime
                updatedGame.isRunning = false
                updatedGame.clockStartTime = nil
                updatedGame.clockAtStart = nil
                updatedGame.lastClockUpdate = now
                
                localClockTime = newClockTime
                currentPeriod = updatedGame.period
                
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
    
    // MARK: - Clean Detailed Stats Entry (same as before)
    
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
            
            // Shooting Stats
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
            
            // Other Stats
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
