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
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var shouldAutoDismissWhenGameEnds = true
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Group {
            if let liveGame = firebaseService.getCurrentLiveGame() {
                // Auto-assign role for single-device games with no role
                if roleManager.deviceRole == .none && !(liveGame.isMultiDeviceSetup ?? false) {
                    Color.clear
                        .onAppear {
                            // Auto-assign controller role for single-device game
                            Task {
                                if let gameId = liveGame.id {
                                    try? await DeviceRoleManager.shared.setDeviceRole(.controller, for: gameId)
                                }
                            }
                        }
                } else {
                    // Show appropriate view based on role
                    switch roleManager.deviceRole {
                    case .recorder:
                        CleanVideoRecordingView(liveGame: liveGame)
                            .ignoresSafeArea(.all)
                            .navigationBarHidden(true)
                            .statusBarHidden(true)
                    case .controller:
                        ControlDeviceView(liveGame: liveGame)
                    case .viewer:
                        LiveGameWatchView(liveGame: liveGame)
                    case .none:
                        // Only show this for multi-device games
                        RoleNotSetView()
                    }
                }
            } else {
                NoLiveGameView()
                    .onAppear {
                    // Clear the device role when game ends
                    Task {
                        await roleManager.clearDeviceRole()
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            print("LiveGameView appeared - Role: \(roleManager.deviceRole)")
            if firebaseService.getCurrentLiveGame() != nil {
                 shouldAutoDismissWhenGameEnds = true
             }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onChange(of: firebaseService.getCurrentLiveGame()) { oldGame, newGame in
             // If game just ended (went from existing to nil)
             if oldGame != nil && newGame == nil && shouldAutoDismissWhenGameEnds {
                 print("🎮 Live game ended, auto-dismissing...")
                 // Clear role first
                 Task {
                     await roleManager.clearDeviceRole()
                 }
                 // The NoLiveGameView will now show with proper "Back to Dashboard" button
             }
         }
    }
}

// MARK: - NEW: Role Not Set View (Redirect to Setup)

struct RoleNotSetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Role Not Set")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your device role hasn't been set for this game. Please go back to Game Setup to join with a specific role.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button("Back to Game Setup") {
                    dismiss()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                
                Button("Continue as Viewer") {
                    Task {
                        if let liveGame = FirebaseService.shared.getCurrentLiveGame(),
                           let gameId = liveGame.id {
                            try await DeviceRoleManager.shared.setDeviceRole(.viewer, for: gameId)
                        }
                    }
                }
                .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .onAppear {
            // Auto-assign role for single-device games
            Task {
                if let liveGame = firebaseService.getCurrentLiveGame(),
                   let gameId = liveGame.id,
                   !(liveGame.isMultiDeviceSetup ?? false) {
                    // Single-device game - auto-assign controller
                    try await DeviceRoleManager.shared.setDeviceRole(.controller, for: gameId)
                }
            }
        }
    }
}

// MARK: - Live Points Summary Card (Add this to LiveGameView.swift)

struct LivePointsSummaryCard: View {
    let stats: PlayerStats
    let isIPad: Bool
    
    private var totalPoints: Int {
        return (stats.fg2m * 2) + (stats.fg3m * 3) + stats.ftm
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            HStack {
                Text("Points Breakdown")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Spacer()
                Text("\(totalPoints) Total")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            
            HStack(spacing: isIPad ? 24 : 20) {
                LivePointBreakdownItem(
                    title: "2PT",
                    made: stats.fg2m,
                    points: stats.fg2m * 2,
                    color: .blue,
                    isIPad: isIPad
                )
                
                LivePointBreakdownItem(
                    title: "3PT",
                    made: stats.fg3m,
                    points: stats.fg3m * 3,
                    color: .green,
                    isIPad: isIPad
                )
                
                LivePointBreakdownItem(
                    title: "FT",
                    made: stats.ftm,
                    points: stats.ftm,
                    color: .orange,
                    isIPad: isIPad
                )
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
}


struct LivePointBreakdownItem: View {
    let title: String
    let made: Int
    let points: Int
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .foregroundColor(color)
                .fontWeight(.medium)
            
            Text("\(made) × \(title == "3PT" ? 3 : (title == "2PT" ? 2 : 1))")
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
            
            Text("\(points)")
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

struct LiveSmartShootingStatCard: View {
    let title: String
    let shotType: SmartShootingStatCard.ShotType
    @Binding var made: Int
    @Binding var attempted: Int
    let currentPoints: Int // Read-only points for display
    let isIPad: Bool
    let onStatChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 12) {
            // Made shots section
            VStack(spacing: isIPad ? 12 : 8) {
                Text(shotType.madeTitle)
                    .font(isIPad ? .title3 : .subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                HStack(spacing: isIPad ? 16 : 12) {
                    Button("-") {
                        decrementMade()
                    }
                    .buttonStyle(CleanStatButtonStyle(color: .red, isIPad: isIPad))
                    .disabled(made <= 0)
                    
                    Text("\(made)")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                        .frame(minWidth: isIPad ? 40 : 35)
                        .foregroundColor(.primary)
                    
                    Button("+") {
                        incrementMade()
                    }
                    .buttonStyle(CleanStatButtonStyle(color: .green, isIPad: isIPad))
                }
            }
            
            // Attempted shots section
            VStack(spacing: isIPad ? 12 : 8) {
                Text(shotType.attemptedTitle)
                    .font(isIPad ? .title3 : .subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                HStack(spacing: isIPad ? 16 : 12) {
                    Button("-") {
                        decrementAttempted()
                    }
                    .buttonStyle(CleanStatButtonStyle(color: .red, isIPad: isIPad))
                    .disabled(attempted <= made)
                    
                    Text("\(attempted)")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                        .frame(minWidth: isIPad ? 40 : 35)
                        .foregroundColor(.primary)
                    
                    Button("+") {
                        incrementAttempted()
                    }
                    .buttonStyle(CleanStatButtonStyle(color: .orange, isIPad: isIPad))
                }
            }
            
            // Shooting percentage display
            if attempted > 0 {
                let percentage = Double(made) / Double(attempted) * 100
                Text("\(Int(percentage))%")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    // MARK: - Smart Logic Methods (same as before)
    
    private func incrementMade() {
        made += 1
        attempted += 1
        onStatChange()
    }
    
    private func decrementMade() {
        if made > 0 {
            made -= 1
            onStatChange()
        }
    }
    
    private func incrementAttempted() {
        attempted += 1
        onStatChange()
    }
    
    private func decrementAttempted() {
        if attempted > made {
            attempted -= 1
            onStatChange()
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
    @State private var currentQuarter: Int
    @State private var currentClock: TimeInterval
    @State private var sahilOnBench: Bool
    
    @State private var isUpdating = false
    @State private var error = ""
    @State private var updateTimer: Timer?
    @State private var hasUnsavedChanges = false
    @State private var clockSyncTimer: Timer?
    @State private var showingFinishAlert = false
    
    // Control transfer alerts
    @State private var showingControlRequestAlert = false
    @State private var requestingUser = ""
    @State private var requestingDeviceId = ""
    
    // Force UI refresh capability
    @StateObject private var refreshTrigger = RefreshTrigger()
    
    // Local clock state
    @State private var localClockTime: TimeInterval = 0
    @State private var lastServerUpdate: Date = Date()
    
    
    // NEW: Header collapse state
    @State private var headerHeight: CGFloat = 0
    @State private var isHeaderCollapsed = false
    @State private var scrollOffset: CGFloat = 0
    
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
    @State private var gameStateAnnounceTimer: Timer?
    @State private var pingTimer: Timer?
    
    
    
    //@State private var isRemoteRecording = false
    
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
    
    // NEW: Compute header states
     private var expandedHeaderHeight: CGFloat {
         isIPad ? 400 : 320 // Adjust based on your actual header size
     }
     
     private var collapsedHeaderHeight: CGFloat {
         isIPad ? 120 : 100 // Minimal header size
     }
     
     private var headerProgress: Double {
         guard expandedHeaderHeight > collapsedHeaderHeight else { return 1.0 }
         let progress = (headerHeight - collapsedHeaderHeight) / (expandedHeaderHeight - collapsedHeaderHeight)
         return max(0, min(1, progress))
     }
    
    
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        _currentStats = State(initialValue: liveGame.playerStats)
        _currentHomeScore = State(initialValue: liveGame.homeScore)
        _currentAwayScore = State(initialValue: liveGame.awayScore)
        _currentQuarter = State(initialValue: liveGame.quarter)
        _currentClock = State(initialValue: liveGame.clock)
        _sahilOnBench = State(initialValue: liveGame.sahilOnBench ?? false)
        _localClockTime = State(initialValue: liveGame.getCurrentClock())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // The fixed header stays the same
            fixedGameHeader()
            
            // --- NEW LOGIC ---
            // If Sahil is NOT on the bench, show the scrollable stats view
            if !sahilOnBench {
                ScrollView {
                    VStack(spacing: isIPad ? 24 : 20) {
                        if deviceControl.hasControl {
                            detailedStatsEntryView()
                        } else {
                             // This is where the viewer stats would go
                             PlayerStatsSection(
                                 game: .constant(Game(
                                     teamName: serverGameState.teamName,
                                     opponent: serverGameState.opponent,
                                     myTeamScore: serverGameState.homeScore,
                                     opponentScore: serverGameState.awayScore,
                                     fg2m: serverGameState.playerStats.fg2m,
                                     fg2a: serverGameState.playerStats.fg2a,
                                     fg3m: serverGameState.playerStats.fg3m,
                                     fg3a: serverGameState.playerStats.fg3a,
                                     ftm: serverGameState.playerStats.ftm,
                                     fta: serverGameState.playerStats.fta,
                                     rebounds: serverGameState.playerStats.rebounds,
                                     assists: serverGameState.playerStats.assists,
                                     steals: serverGameState.playerStats.steals,
                                     blocks: serverGameState.playerStats.blocks,
                                     fouls: serverGameState.playerStats.fouls,
                                     turnovers: serverGameState.playerStats.turnovers
                                 )),
                                 authService: authService,
                                 firebaseService: firebaseService,
                                 isIPad: isIPad
                             )
                        }
                        
                        PlayingTimeCard(
                            liveGame: serverGameState,
                            isIPad: isIPad
                        )
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, isIPad ? 20 : 16)
                    .padding(.vertical, isIPad ? 12 : 8)
                }
            } else {
                OnBenchMessage(isIPad: isIPad)
            }
        }
        .background(Color(.systemGroupedBackground))
        // Keep all your existing alerts and onChange handlers...
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
            
            deviceControl.updateControlStatus(
                for: serverGameState,
                userEmail: authService.currentUser?.email
            )
            
            autoGrantInitialControl()
            
            if serverGameState.currentTimeSegment == nil && deviceControl.hasControl {
                startInitialTimeTracking()
            }
            
            // Request recording state after a brief delay to ensure connection is stable
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if multipeer.isConnected {
                    print("📤 Requesting recording state from recorder")
                    multipeer.sendRequestForRecordingState()
                }
            }
        }
        .onDisappear {
            stopFixedClockSync()
            updateTimer?.invalidate()
            stopAnnouncingGameState()
            stopPinging()
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
            deviceControl.updateControlStatus(
                for: newGame,
                userEmail: authService.currentUser?.email
            )
            
            syncNonClockDataWithServer(newGame)
            refreshTrigger.trigger()
            checkForControlRequests(newGame)
        }
    }
    
    private func startPinging() {
        stopPinging() // Prevent duplicate timers
        print("❤️ [Controller] Starting to ping recorder every 2.5 seconds.")
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            // Only send pings if this device has control
            if deviceControl.hasControl {
                multipeer.sendPing()
            }
        }
    }

    private func stopPinging() {
        pingTimer?.invalidate()
        pingTimer = nil
        print("💔 [Controller] Stopped pinging recorder.")
    }
    
    
    
    private func startAnnouncingGameState() {
        // Invalidate any existing timer to prevent duplicates
        stopAnnouncingGameState()
        
        print("📢 [Controller] Starting to announce game state every 3 seconds.")
        
        // Send one announcement immediately upon starting
        announceGameState()
        
        // Schedule the timer to repeat
        gameStateAnnounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            announceGameState()
        }
    }

    private func stopAnnouncingGameState() {
        gameStateAnnounceTimer?.invalidate()
        gameStateAnnounceTimer = nil
        print("📢 [Controller] Stopped announcing game state.")
    }

    private func announceGameState() {
        // Only send if this device is in control and has a valid game ID
        guard deviceControl.hasControl, let gameId = serverGameState.id else {
            return
        }
        
        let gameState: [String: String] = [
            "gameId": gameId,
            "isRunning": "true" // Let the recorder know the game is active
        ]
        multipeer.sendGameState(gameState)
        print("📢 [Controller] Sent game state announcement for gameId: \(gameId)")
    }
    
    
    
    // MARK: - FIXED: Single Game Header (All Info in One Place)
    @ViewBuilder
    private func fixedGameHeader() -> some View {
        VStack(spacing: isIPad ? 6 : 4) {
            // Device Control Status
            CompactDeviceControlStatusCard(
                hasControl: deviceControl.hasControl,
                controllingUser: deviceControl.controllingUser,
                canRequestControl: deviceControl.canRequestControl,
                pendingRequest: deviceControl.pendingControlRequest,
                isIPad: isIPad,
                onRequestControl: requestControl,
                showBluetoothStatus: DeviceRoleManager.shared.deviceRole == .controller,
                isRecording: multipeer.isRemoteRecording,
                    onToggleRecording: multipeer.isConnected ? {
                        // Use a guard to safely unwrap the optional value
                        guard let isRecording = self.multipeer.isRemoteRecording else { return }
                        if isRecording {
                            self.multipeer.sendStopRecording()
                        } else {
                            self.multipeer.sendStartRecording()
                        }
                    } : nil
                )
            
            // Clock Display
            CompactClockCard(
                quarter: currentQuarter,
                clockTime: localClockTime,
                isGameRunning: isGameRunning,
                gameFormat: serverGameState.gameFormat,
                isIPad: isIPad
            )
            .frame(maxWidth: .infinity)
            
            // Score Display
            if deviceControl.hasControl {
                CompactLiveScoreCard(
                    homeScore: $currentHomeScore,
                    awayScore: $currentAwayScore,
                    teamName: serverGameState.teamName,
                    opponent: serverGameState.opponent,
                    isIPad: isIPad,
                    onScoreChange: scheduleUpdate
                )
                .frame(maxWidth: .infinity)
            } else {
                CompactLiveScoreDisplayCard(
                    homeScore: serverGameState.homeScore,
                    awayScore: serverGameState.awayScore,
                    teamName: serverGameState.teamName,
                    opponent: serverGameState.opponent,
                    isIPad: isIPad
                )
                .frame(maxWidth: .infinity)
            }
            
            // Player Status
            PlayerStatusCard(
                sahilOnBench: $sahilOnBench,
                isIPad: isIPad,
                hasControl: deviceControl.hasControl,
                onStatusChange: {
                    updatePlayingStatus()
                }
            )
            
            // Game Controls
            if deviceControl.hasControl {
                CompactGameControlsCard(
                    currentQuarter: currentQuarter,
                    maxQuarter: serverGameState.numQuarter,
                    gameFormat: serverGameState.gameFormat,
                    isGameRunning: serverGameState.isRunning,
                    isIPad: isIPad,
                    onStartPause: toggleGameClock,
                    onAddMinute: addMinuteToClock,
                    onAdvanceQuarter: nextQuarter,
                    onFinishGame: { showingFinishAlert = true }
                )
            }
        }
        .padding(.horizontal, isIPad ? 20 : 16)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - FIXED: Detailed Stats Entry (NO Score Cards Here)
    
    @ViewBuilder
    private func detailedStatsEntryView() -> some View {
        VStack(spacing: isIPad ? 24 : 20) {
            HStack {
                Text("Detailed Stats")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
            }
            
            // Shooting Stats with Smart Logic
            VStack(spacing: isIPad ? 20 : 16) {
                HStack {
                    Text("Shooting")
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                VStack(spacing: isIPad ? 8 : 6) {
                    SmartShootingStatCard(
                        title: "2-Point Shots",
                        shotType: .twoPoint,
                        made: $currentStats.fg2m,
                        attempted: $currentStats.fg2a,
                        liveScore: $currentHomeScore,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    
                    SmartShootingStatCard(
                        title: "3-Point Shots",
                        shotType: .threePoint,
                        made: $currentStats.fg3m,
                        attempted: $currentStats.fg3a,
                        liveScore: $currentHomeScore,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    
                    SmartShootingStatCard(
                        title: "Free Throws",
                        shotType: .freeThrow,
                        made: $currentStats.ftm,
                        attempted: $currentStats.fta,
                        liveScore: $currentHomeScore,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
            }
            
            // Other Stats Section
            VStack(spacing: isIPad ? 20 : 16) {
                HStack {
                    Text("Other Stats")
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    RegularStatCard(
                        title: "Rebounds",
                        value: $currentStats.rebounds,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Assists",
                        value: $currentStats.assists,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Steals",
                        value: $currentStats.steals,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Blocks",
                        value: $currentStats.blocks,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Fouls",
                        value: $currentStats.fouls,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Turnovers",
                        value: $currentStats.turnovers,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
            }
            
            // Points summary for live game
            LivePointsSummaryCard(stats: currentStats, isIPad: isIPad)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 24 : 20)
        .padding(.horizontal, isIPad ? 24 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
        .shadow(color: .black.opacity(0.05), radius: isIPad ? 8 : 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func shootingStatsSection() -> some View {
        VStack(spacing: isIPad ? 20 : 16) {
            HStack {
                Text("Shooting")
                    .font(isIPad ? .title3 : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            VStack(spacing: isIPad ? 8 : 6) {
                // FIXED: Reuse existing SmartShootingStatCard WITHOUT score integration
                SmartShootingStatCard(
                    title: "2-Point Shots",
                    shotType: .twoPoint,
                    made: $currentStats.fg2m,
                    attempted: $currentStats.fg2a,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                
                SmartShootingStatCard(
                    title: "3-Point Shots",
                    shotType: .threePoint,
                    made: $currentStats.fg3m,
                    attempted: $currentStats.fg3a,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                
                SmartShootingStatCard(
                    title: "Free Throws",
                    shotType: .freeThrow,
                    made: $currentStats.ftm,
                    attempted: $currentStats.fta,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
            }
        }
    }
    
    @ViewBuilder
    private func otherStatsSection() -> some View {
        VStack(spacing: isIPad ? 20 : 16) {
            HStack {
                Text("Other Stats")
                    .font(isIPad ? .title3 : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                RegularStatCard(
                    title: "Rebounds",
                    value: $currentStats.rebounds,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                RegularStatCard(
                    title: "Assists",
                    value: $currentStats.assists,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                RegularStatCard(
                    title: "Steals",
                    value: $currentStats.steals,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                RegularStatCard(
                    title: "Blocks",
                    value: $currentStats.blocks,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                RegularStatCard(
                    title: "Fouls",
                    value: $currentStats.fouls,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
                RegularStatCard(
                    title: "Turnovers",
                    value: $currentStats.turnovers,
                    isIPad: isIPad,
                    onStatChange: scheduleUpdate
                )
            }
        }
    }
    
    @ViewBuilder
    private func pointsSummarySection() -> some View {
        // FIXED: Reuse existing PointsSummaryCard component
        PointsSummaryCard(
            gameStats: GameStatsData(
                myTeamScore: currentHomeScore,
                opponentScore: currentAwayScore,
                playerStats: currentStats
            ),
            isIPad: isIPad
        )
    }
    
    // FIXED: Calculated points from stats
    private var calculatedPoints: Int {
        return (currentStats.fg2m * 2) + (currentStats.fg3m * 3) + currentStats.ftm
    }
    

    
    // MARK: - Clean Detailed Stats Entry (COMPLETE)
    
    private func cleanDetailedStatsEntry() -> some View {
        VStack(spacing: isIPad ? 24 : 20) {
            HStack {
                Text("Detailed Stats")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
            }
            
            // Shooting Stats with Smart Logic
            VStack(spacing: isIPad ? 20 : 16) {
                HStack {
                    Text("Shooting")
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                VStack(spacing: isIPad ? 8 : 6) {
                    SmartShootingStatCard(
                        title: "2-Point Shots",
                        shotType: .twoPoint,
                        made: $currentStats.fg2m,
                        attempted: $currentStats.fg2a,
                        liveScore: $currentHomeScore,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    
                    SmartShootingStatCard(
                        title: "3-Point Shots",
                        shotType: .threePoint,
                        made: $currentStats.fg3m,
                        attempted: $currentStats.fg3a,
                        liveScore: $currentHomeScore,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    
                    SmartShootingStatCard(
                        title: "Free Throws",
                        shotType: .freeThrow,
                        made: $currentStats.ftm,
                        attempted: $currentStats.fta,
                        liveScore: $currentHomeScore,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
            }
            
            // Other Stats Section
            VStack(spacing: isIPad ? 20 : 16) {
                HStack {
                    Text("Other Stats")
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    RegularStatCard(
                        title: "Rebounds",
                        value: $currentStats.rebounds,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Assists",
                        value: $currentStats.assists,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Steals",
                        value: $currentStats.steals,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Blocks",
                        value: $currentStats.blocks,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Fouls",
                        value: $currentStats.fouls,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    RegularStatCard(
                        title: "Turnovers",
                        value: $currentStats.turnovers,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
            }
            
            // Points summary for live game
            LivePointsSummaryCard(stats: currentStats, isIPad: isIPad)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 24 : 20)
        .padding(.horizontal, isIPad ? 24 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
        .shadow(color: .black.opacity(0.05), radius: isIPad ? 8 : 4, x: 0, y: 2)
    }
    
/*
    private func startTimeTracking(onCourt: Bool) {
        // End current segment if exists
        endCurrentTimeSegment()
        
        // Start new segment
        let newSegment = GameTimeSegment(
            startTime: Date(),
            endTime: nil,
            isOnCourt: onCourt
        )
        
        var updatedGame = serverGameState
        updatedGame.currentTimeSegment = newSegment
        
        Task {
            try await firebaseService.updateLiveGame(updatedGame)
        }
    }
*/
    private func startTimeTracking(onCourt: Bool) {
        Task {
            // First, properly end the previous segment and get the updated game state.
            let gameAfterEndingSegment = try await endCurrentTimeSegment()
            
            // Now, start the new segment on the guaranteed latest game state.
            let newSegment = GameTimeSegment(
                startTime: Date(),
                endTime: nil,
                isOnCourt: onCourt
            )
            
            var updatedGame = gameAfterEndingSegment
            updatedGame.currentTimeSegment = newSegment
            
            try await firebaseService.updateLiveGame(updatedGame)
        }
    }
    


    private func endCurrentTimeSegment() async throws -> LiveGame {
        guard var currentSegment = serverGameState.currentTimeSegment else {
            // If there's no active segment, just return the current state
            print("📍 No active time segment to end")
            return serverGameState
        }
        
        currentSegment.endTime = Date()
        let segmentDuration = currentSegment.durationMinutes
        
        var updatedGame = serverGameState
        
        // Add completed segment to array
        updatedGame.timeSegments.append(currentSegment)
        updatedGame.currentTimeSegment = nil
        
        // 🔥 CRITICAL FIX: Update the stored cumulative totals
        if currentSegment.isOnCourt {
            updatedGame.totalPlayingTimeMinutes += segmentDuration
            print("📍 Added \(segmentDuration) minutes to PLAYING time (new total: \(updatedGame.totalPlayingTimeMinutes))")
        } else {
            updatedGame.benchTimeMinutes += segmentDuration
            print("📍 Added \(segmentDuration) minutes to BENCH time (new total: \(updatedGame.benchTimeMinutes))")
        }
        
        print("📍 Ending time segment: \(currentSegment.isOnCourt ? "Court" : "Bench"), Duration: \(segmentDuration) minutes")
        print("📍 UPDATED TOTALS - Playing: \(updatedGame.totalPlayingTimeMinutes), Bench: \(updatedGame.benchTimeMinutes)")
        print("📍 Total segments: \(updatedGame.timeSegments.count)")
        
        // Save to Firebase with updated totals
        try await firebaseService.updateLiveGame(updatedGame)
        
        // Return the updated game state
        return updatedGame
    }

    private func updatePlayingStatus() {
        
        print("🔥 DEBUG: updatePlayingStatus() CALLED")
        let wasOnCourt = serverGameState.currentTimeSegment?.isOnCourt ?? true
        let isNowOnCourt = !sahilOnBench

        print("🔥 DEBUG: wasOnCourt: \(wasOnCourt), isNowOnCourt: \(isNowOnCourt)")
        print("🔥 DEBUG: sahilOnBench: \(sahilOnBench)")
        
        // DEBUG: Print current status
        print("🔍 Status change: \(wasOnCourt ? "Court" : "Bench") → \(isNowOnCourt ? "Court" : "Bench")")

        
        // Only update time tracking if status actually changed
        if wasOnCourt != isNowOnCourt {
            print("📍 Playing status changed: \(wasOnCourt ? "Court" : "Bench") → \(isNowOnCourt ? "Court" : "Bench")")
            
            Task {
                do {
                    // FIXED: Properly await the endCurrentTimeSegment to avoid race condition
                    let gameAfterEndingSegment = try await endCurrentTimeSegment()
                    
                    // Start new segment with the guaranteed latest game state
                    let newSegment = GameTimeSegment(
                        startTime: Date(),
                        endTime: nil,
                        isOnCourt: isNowOnCourt
                    )
                    
                    var updatedGame = gameAfterEndingSegment
                    updatedGame.currentTimeSegment = newSegment
                    updatedGame.sahilOnBench = sahilOnBench // Update bench status too
                    
                    try await firebaseService.updateLiveGame(updatedGame)
                    print("✅ Time tracking updated successfully")
                    
                } catch {
                    print("❌ Failed to update time tracking: \(error)")
                }
            }
        } else {
            print("🔥 DEBUG: No status change, calling scheduleUpdate()")
            scheduleUpdate()
        }
    }
    
    
    
    // MARK: - ALSO ENSURE: Start time tracking when game begins
    // Add this to your game start logic if not already present

    private func startInitialTimeTracking() {
        let initialSegment = GameTimeSegment(
            startTime: Date(),
            endTime: nil,
            isOnCourt: !sahilOnBench // Start based on current bench status
        )
        
        var updatedGame = serverGameState
        updatedGame.currentTimeSegment = initialSegment
        
        Task {
            try await firebaseService.updateLiveGame(updatedGame)
            print("✅ Initial time tracking started")
        }
    }
    // MARK: - All existing methods remain the same...
    
    private func startFixedClockSync() {
        clockSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let game = serverGameState
            
            if game.isRunning {
                if let startTime = game.clockStartTime,
                   let clockAtStart = game.clockAtStart {
                    
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    let calculatedTime = max(0, clockAtStart - elapsedTime)
                    
                    localClockTime = calculatedTime
                    
                    if calculatedTime <= 0 && currentQuarter < serverGameState.numQuarter && deviceControl.hasControl {
                        nextQuarterAutomatically()
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
        currentQuarter = game.quarter
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
        currentQuarter = game.quarter
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
                // This function now directly takes control and doesn't return a value.
                try await deviceControl.requestControl(
                    for: serverGameState,
                    userEmail: authService.currentUser?.email
                )
                // Since control is taken immediately, we no longer need to check if it was granted.
                // The UI will update automatically when the game state changes in Firebase.
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
    
    private func nextQuarter() {
        guard deviceControl.hasControl else { return }
        
        Task {
            do {
                var updatedGame = serverGameState
                let now = Date()
                
                updatedGame.quarter += 1
                let newClockTime = TimeInterval(updatedGame.quarterLength * 60)
                updatedGame.clock = newClockTime
                updatedGame.isRunning = false
                updatedGame.clockStartTime = nil
                updatedGame.clockAtStart = nil
                updatedGame.lastClockUpdate = now
                
                localClockTime = newClockTime
                currentQuarter = updatedGame.quarter
                
                try await firebaseService.updateLiveGame(updatedGame)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func nextQuarterAutomatically() {
        guard deviceControl.hasControl,
              currentQuarter < serverGameState.numQuarter else {
            return
        }
        
        nextQuarter()
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
                // 1. Await the definitive, updated game object after ending the last segment.
                let finalServerState = try await endCurrentTimeSegment()

                // 🔍 DEBUG: Print detailed playing time information
                print("🔍 ========== FINAL GAME TIME DEBUG ==========")
                print("📊 Raw Stored Values:")
                print("   totalPlayingTimeMinutes: \(finalServerState.totalPlayingTimeMinutes)")
                print("   benchTimeMinutes: \(finalServerState.benchTimeMinutes)")
                print("   timeSegments count: \(finalServerState.timeSegments.count)")
                
                // Show each completed segment
                for (index, segment) in finalServerState.timeSegments.enumerated() {
                    let durationSeconds = segment.durationMinutes * 60
                    let minutes = Int(durationSeconds) / 60
                    let seconds = Int(durationSeconds) % 60
                    print("   Segment \(index + 1): \(segment.isOnCourt ? "Court" : "Bench") - \(minutes)m \(seconds)s")
                }
                
                // Check if there's still an active segment (shouldn't be any after endCurrentTimeSegment)
                if let current = finalServerState.currentTimeSegment {
                    let currentDuration = Date().timeIntervalSince(current.startTime)
                    let minutes = Int(currentDuration) / 60
                    let seconds = Int(currentDuration) % 60
                    print("   ⚠️ WARNING: Still has active segment: \(current.isOnCourt ? "Court" : "Bench") - \(minutes)m \(seconds)s")
                } else {
                    print("   ✅ No active segment (correct)")
                }
                
                // Calculate totals using the computed properties
                let totalPlayingTime = finalServerState.totalPlayingTime
                let totalBenchTime = finalServerState.totalBenchTime
                let totalTime = totalPlayingTime + totalBenchTime
                
                print("📈 Computed Totals (what will be saved to Game):")
                let playingMinutes = Int(totalPlayingTime)
                let playingSeconds = Int((totalPlayingTime - Double(playingMinutes)) * 60)
                let benchMinutes = Int(totalBenchTime)
                let benchSeconds = Int((totalBenchTime - Double(benchMinutes)) * 60)
                let totalMinutes = Int(totalTime)
                let totalSecondsRemainder = Int((totalTime - Double(totalMinutes)) * 60)
                
                print("   Total Playing Time: \(playingMinutes)m \(playingSeconds)s (\(totalPlayingTime) minutes)")
                print("   Total Bench Time: \(benchMinutes)m \(benchSeconds)s (\(totalBenchTime) minutes)")
                print("   Total Game Time: \(totalMinutes)m \(totalSecondsRemainder)s (\(totalTime) minutes)")
                
                if totalTime > 0 {
                    let percentage = (totalPlayingTime / totalTime) * 100
                    print("   Playing Percentage: \(String(format: "%.1f", percentage))%")
                }
                
                print("🔍 ==========================================")

                // 2. Create the final Game object with correct time data.
                let finalGame = Game(
                    teamName: finalServerState.teamName,
                    opponent: finalServerState.opponent,
                    location: finalServerState.location,
                    timestamp: finalServerState.createdAt ?? Date(),
                    gameFormat: finalServerState.gameFormat,
                    quarterLength: finalServerState.quarterLength,
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
                    adminName: authService.currentUser?.email,
                    totalPlayingTimeMinutes: totalPlayingTime,
                    benchTimeMinutes: totalBenchTime,
                    gameTimeTracking: finalServerState.timeSegments
                )
                
                try await firebaseService.addGame(finalGame)
                try await firebaseService.deleteLiveGame(finalServerState.id ?? "")
                
                // 🔍 DEBUG: Print what's actually in the Game object before saving
                print("🔍 ========== FINAL GAME OBJECT DEBUG ==========")
                print("📊 Game Object Time Values:")
                print("   finalGame.totalPlayingTimeMinutes: \(finalGame.totalPlayingTimeMinutes)")
                print("   finalGame.benchTimeMinutes: \(finalGame.benchTimeMinutes)")
                print("   finalGame.gameTimeTracking.count: \(finalGame.gameTimeTracking.count)")
                print("   finalGame.playingTimePercentage: \(finalGame.playingTimePercentage)")
                print("🔍 =============================================")
                
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
}

