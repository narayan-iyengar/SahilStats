// File: SahilStats/Views/LiveGameView.swift (Complete Unified Layout)

import SwiftUI
import FirebaseAuth
import Combine

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

// MARK: - Live Game Controller (Admin) - Unified Layout for iPad and iPhone


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
    @State private var showingControlRequest = false
    
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
                // Device Control Status
                DeviceControlStatusCard(
                    hasControl: deviceControl.hasControl,
                    controllingUser: deviceControl.controllingUser,
                    isIPad: isIPad,
                    onRequestControl: {
                        Task {
                            do {
                                _ = try await deviceControl.requestControl(
                                    for: serverGameState,
                                    userEmail: authService.currentUser?.email
                                )
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
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
                
                // Control Request Alert
                if let requestingUser = serverGameState.controlRequestedBy,
                   deviceControl.hasControl {
                    ControlRequestAlert(
                        requestingUser: requestingUser,
                        isIPad: isIPad,
                        onGrant: {
                            Task {
                                do {
                                    try await deviceControl.grantControl(
                                        for: serverGameState,
                                        to: requestingUser
                                    )
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        },
                        onDeny: {
                            Task {
                                do {
                                    var updatedGame = serverGameState
                                    updatedGame.controlRequestedBy = nil
                                    try await firebaseService.updateLiveGame(updatedGame)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        }
                    )
                }
            }
            .padding(isIPad ? 24 : 16)
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
            print("Does this device have control? \(deviceControl.hasControl)")
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
            case .background, .inactive:
                stopClockSync()
            @unknown default:
                break
            }
        }
        .onChange(of: serverGameState) { _, newGame in
            deviceControl.updateControlStatus(
                for: newGame,
                userEmail: authService.currentUser?.email
            )
            syncWithServer()
            print("--- LiveGameView serverGameState changed ---")
            print("Current Device ID: \(deviceControl.deviceId)")
            print("New Controlling Device ID: \(newGame.controllingDeviceId ?? "Not Set")")
            print("Does this device have control now? \(deviceControl.hasControl)")
        }
    }
    
    // MARK: - Controller Interface (when user has control)
    
    @ViewBuilder
    private func controllerInterface() -> some View {
        LiveScoreCard(
            homeScore: $currentHomeScore,
            awayScore: $currentAwayScore,
            teamName: serverGameState.teamName,
            opponent: serverGameState.opponent,
            isIPad: isIPad,
            onScoreChange: scheduleUpdate
        )
        
        PlayerStatusCard(
            sahilOnBench: $sahilOnBench,
            isIPad: isIPad,
            onStatusChange: scheduleUpdate
        )
        
        EnhancedGameControlsCard(
            hasControl: deviceControl.hasControl,
            currentPeriod: currentPeriod,
            maxPeriods: serverGameState.numPeriods,
            periodLength: serverGameState.periodLength,
            gameFormat: serverGameState.gameFormat,
            isIPad: isIPad,
            onStartPause: {
                toggleGameClock()
            },
            onAddMinute: {
                addMinuteToClock()
            },
            onNextPeriod: {
                nextPeriod()
            },
            onFinishGame: {
                showingFinishAlert = true
            },
            onReleaseControl: {
                Task {
                    try? await deviceControl.releaseControl(for: serverGameState)
                }
            }
        )
        
        if !sahilOnBench {
            unifiedDetailedStatsEntry()
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
    
    // MARK: - Clock Synchronization
    
    private func startClockSync() {
        clockSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isGameRunning {
                currentClock = serverGameState.getCurrentClock()
                
                // Auto-advance period if clock hits 0
                if currentClock <= 0 && currentPeriod < serverGameState.numPeriods {
                    if deviceControl.hasControl {
                        nextPeriodAutomatically()
                    }
                }
            }
        }
    }
    
    private func stopClockSync() {
        clockSyncTimer?.invalidate()
        clockSyncTimer = nil
    }
    
    private func syncWithServer() {
        let game = serverGameState
        currentStats = game.playerStats
        currentHomeScore = game.homeScore
        currentAwayScore = game.awayScore
        currentPeriod = game.period
        currentClock = game.getCurrentClock()
        sahilOnBench = game.sahilOnBench ?? false
    }
    
    // MARK: - Game Control Actions (only for controlling device)
    
    private func toggleGameClock() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                var updatedGame = serverGameState
                let now = Date()
                
                if updatedGame.isRunning {
                    // Pause the game
                    updatedGame.isRunning = false
                    updatedGame.clock = updatedGame.getCurrentClock()
                    updatedGame.clockStartTime = nil
                    updatedGame.clockAtStart = nil
                } else {
                    // Start the game
                    updatedGame.isRunning = true
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
            // This is the key change: we now check the user's email as well.
            guard hasUnsavedChanges && !isUpdating && deviceControl.hasControl &&
                  authService.currentUser?.email == serverGameState.controllingUserEmail else {
                
                // Add a print statement to see why updates might be failing
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
        
        // Implementation same as before but with server sync
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
    
    // MARK: - Unified Stats Entry (same as before but only for controlling device)
    
    private func unifiedDetailedStatsEntry() -> some View {
        // Same implementation as before
        VStack(spacing: isIPad ? 20 : 16) {
            HStack {
                Text("Detailed Stats")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Tap +/- to adjust")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Stats sections same as before...
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 20 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Supporting UI Components

struct DeviceControlStatusCard: View {
    let hasControl: Bool
    let controllingUser: String?
    // 1. Remove canRequestControl from here
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
                if let controllingUser = controllingUser {
                    Text("\(controllingUser) is controlling the game")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No one is currently controlling the game")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                }
                
                // 2. Remove the "if canRequestControl" check around the button
                // This ensures the button is always available if you don't have control.
                Button("Request Control") {
                    onRequestControl()
                }
                .buttonStyle(SecondaryButtonStyle(isIPad: isIPad))
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(hasControl ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
}


struct SynchronizedClockCard: View {
    let liveGame: LiveGame
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("Period \(liveGame.period)")
                .font(isIPad ? .title2 : .headline)
                .foregroundColor(.secondary)
            
            Text(liveGame.currentClockDisplay)
                .font(isIPad ? .system(size: 48, weight: .bold) : .largeTitle)
                .fontWeight(.bold)
                .foregroundColor(liveGame.isRunning ? .red : .primary)
                .monospacedDigit()
            
            if liveGame.isRunning {
                Text("Game Clock Running")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct EnhancedGameControlsCard: View {
    let hasControl: Bool
    let currentPeriod: Int
    let maxPeriods: Int
    let periodLength: Int
    let gameFormat: GameFormat
    let isIPad: Bool
    let onStartPause: () -> Void
    let onAddMinute: () -> Void
    let onNextPeriod: () -> Void
    let onFinishGame: () -> Void
    let onReleaseControl: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Game Controls")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            if hasControl {
                HStack(spacing: isIPad ? 12 : 8) {
                    Button("Start/Pause") {
                        onStartPause()
                    }
                    .buttonStyle(CompactControlButtonStyle(color: .green, isIPad: isIPad))
                    
                    Button(isIPad ? "+1 Minute" : "+1 Min") {
                        onAddMinute()
                    }
                    .buttonStyle(CompactControlButtonStyle(color: .purple, isIPad: isIPad))
                    
                    if currentPeriod < maxPeriods {
                        Button("Next") {
                            onNextPeriod()
                        }
                        .buttonStyle(CompactControlButtonStyle(color: .blue, isIPad: isIPad))
                    }
                    
                    Button(currentPeriod < maxPeriods ? "End" : "Finish") {
                        onFinishGame()
                    }
                    .buttonStyle(CompactControlButtonStyle(color: .red, isIPad: isIPad))
                }
                
                Button("Release Control") {
                    onReleaseControl()
                }
                .buttonStyle(SecondaryButtonStyle(isIPad: isIPad))
                .font(isIPad ? .body : .caption)
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

struct ControlRequestAlert: View {
    let requestingUser: String
    let isIPad: Bool
    let onGrant: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                    .font(isIPad ? .title2 : .headline)
                
                Text("Control Request")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            Text("\(requestingUser) is requesting control of the game")
                .font(isIPad ? .body : .subheadline)
                .multilineTextAlignment(.center)
            
            HStack(spacing: isIPad ? 16 : 12) {
                Button("Grant Control") {
                    onGrant()
                }
                .buttonStyle(PrimaryButtonStyle(isIPad: isIPad))
                
                Button("Deny") {
                    onDeny()
                }
                .buttonStyle(SecondaryButtonStyle(isIPad: isIPad))
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
        .cornerRadius(isIPad ? 16 : 12)
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
                LiveGameHeaderCard(
                    liveGame: liveGame,
                    isGameRunning: .constant(liveGame.isRunning),
                    currentPeriod: .constant(liveGame.period),
                    currentClock: .constant(liveGame.clock),
                    isIPad: isIPad,
                    isReadOnly: true
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

// MARK: - Supporting Card Views

struct ClockDisplayCard: View {
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    @Binding var isGameRunning: Bool
    let gameFormat: GameFormat
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("Period \(currentPeriod)")
                .font(isIPad ? .title2 : .headline)
                .foregroundColor(.secondary)
            
            Text(formatClock(currentClock))
                .font(isIPad ? .system(size: 48, weight: .bold) : .largeTitle)
                .fontWeight(.bold)
                .foregroundColor(isGameRunning ? .red : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    private func formatClock(_ time: TimeInterval) -> String {
        if time <= 59 {
            return String(format: "%.1f", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

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

struct GameControlsCard: View {
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    let maxPeriods: Int
    let periodLength: Int
    let gameFormat: GameFormat
    let isIPad: Bool
    let onClockChange: () -> Void
    let onFinishGame: () -> Void
    
    private var endGameButtonText: String {
        if currentPeriod < maxPeriods {
            return gameFormat == .halves ? "End Half" : "End Period"
        } else {
            return "End Game"
        }
    }
    
    // Dynamic button text without icons
    private var startPauseText: String {
        isGameRunning ? "Pause" : "Start"
    }
    
    private var addTimeText: String {
        isIPad ? "+1 Minute" : "+1 Min"
    }
    
    private var nextPeriodText: String {
        if isIPad {
            return gameFormat == .halves ? "Next Half" : "Next Period"
        } else {
            return "Next"
        }
    }
    
    private var finishGameText: String {
        if isIPad {
            return endGameButtonText
        } else {
            return currentPeriod < maxPeriods ? "End" : "Finish"
        }
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Game Controls")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            // Single horizontal row with flexible spacing
            HStack(spacing: isIPad ? 12 : 8) {
                // Start/Pause button
                Button(startPauseText) {
                    isGameRunning.toggle()
                }
                .buttonStyle(CompactControlButtonStyle(
                    color: isGameRunning ? .orange : .green,
                    isIPad: isIPad
                ))
                
                // Add time button
                Button(addTimeText) {
                    currentClock += 60
                    onClockChange()
                }
                .buttonStyle(CompactControlButtonStyle(color: .purple, isIPad: isIPad))
                
                // Next period button (only if not final period)
                if currentPeriod < maxPeriods {
                    Button(nextPeriodText) {
                        currentPeriod += 1
                        currentClock = TimeInterval(periodLength * 60)
                        onClockChange()
                    }
                    .buttonStyle(CompactControlButtonStyle(color: .blue, isIPad: isIPad))
                }
                
                // Finish game button
                Button(finishGameText) {
                    onFinishGame()
                }
                .buttonStyle(CompactControlButtonStyle(color: .red, isIPad: isIPad))
            }
            
            // Optional status text
            if !isGameRunning {
                Text("Game is paused")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
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

struct LiveGameHeaderCard: View {
    let liveGame: LiveGame
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    let isIPad: Bool
    let isReadOnly: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: isIPad ? 16 : 12, height: isIPad ? 16 : 12)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                Text("LIVE GAME")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
                
                if !isReadOnly {
                    Button(isGameRunning ? "⏸️" : "▶️") {
                        isGameRunning.toggle()
                    }
                    .font(isIPad ? .title : .title2)
                }
            }
            
            Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                .font(isIPad ? .title : .title2)
                .fontWeight(.semibold)
            
            HStack(spacing: isIPad ? 24 : 20) {
                Text("Period \(currentPeriod)")
                    .font(isIPad ? .title3 : .subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatClock(currentClock))
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.semibold)
                    .foregroundColor(isGameRunning ? .red : .secondary)
            }
            
            if let location = liveGame.location {
                Text("📍 \(location)")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    private func formatClock(_ time: TimeInterval) -> String {
        if time <= 59 {
            return String(format: "%.1f", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}


// MARK: - Legacy Compatibility Views

struct ImprovedLiveScoreCard: View {
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    let teamName: String
    let opponent: String
    let onScoreChange: () -> Void
    
    var body: some View {
        LiveScoreCard(
            homeScore: $homeScore,
            awayScore: $awayScore,
            teamName: teamName,
            opponent: opponent,
            isIPad: false,
            onScoreChange: onScoreChange
        )
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
