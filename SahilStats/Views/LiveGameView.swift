// File: SahilStats/Views/LiveGameView.swift (WITH STICKY HEADER)

import SwiftUI
import UIKit
import FirebaseAuth
import Combine
import FirebaseFirestore

// MARK: - Refresh Trigger for Force UI Updates

class RefreshTrigger: ObservableObject {
    func trigger() {
        objectWillChange.send()
    }
}


struct LiveGameView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @ObservedObject private var deviceControl = DeviceControlManager.shared

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
                    // Show appropriate view based on role AND control status
                    // If a viewer has control, show them the controller view
                    switch roleManager.deviceRole {
                    case .recorder:
                        CleanVideoRecordingView(liveGame: liveGame)
                            .ignoresSafeArea(.all)
                            .navigationBarHidden(true)
                            .statusBarHidden(true)
                    case .controller:
                        ControlDeviceView(liveGame: liveGame)
                    case .viewer:
                        // IMPORTANT: If viewer has control, show controller view
                        if deviceControl.hasControl {
                            ControlDeviceView(liveGame: liveGame)
                        } else {
                            LiveGameWatchView(liveGame: liveGame)
                        }
                    case .none:
                        // Only show this for multi-device games
                        RoleNotSetView()
                    }
                }
            } else {
                //NoLiveGameView()
                NoLiveGameLottieView()
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
            debugPrint("LiveGameView appeared - Role: \(roleManager.deviceRole)")
            if firebaseService.getCurrentLiveGame() != nil {
                 shouldAutoDismissWhenGameEnds = true
             }
        }
        .navigationBarHidden(true)
        .onChange(of: firebaseService.getCurrentLiveGame()) { oldGame, newGame in
             // If game just ended (went from existing to nil)
             if oldGame != nil && newGame == nil && shouldAutoDismissWhenGameEnds {
                 debugPrint("🎮 Live game ended, auto-dismissing...")
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
        .background(Color(.systemBackground))
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
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var deviceControl = DeviceControlManager.shared
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var navigation = NavigationCoordinator.shared
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
    @State private var showingQRCode = false

    // Control transfer alerts
    @State private var showingControlRequestAlert = false
    @State private var requestingUser = ""
    @State private var requestingDeviceId = ""
    
    // Force UI refresh capability
    @StateObject private var refreshTrigger = RefreshTrigger()
    
    // Local clock state
    @State private var localClockTime: TimeInterval = 0
    @State private var lastServerUpdate: Date = Date()
    
    
    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    
    @State private var gameStateAnnounceTimer: Timer?
    @State private var pingTimer: Timer?

    // Timeline recording state
    @ObservedObject private var timelineTracker = ScoreTimelineTracker.shared
    @State private var timelineRecordingDuration: TimeInterval = 0
    @State private var timelineTimer: Timer?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

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
        .sheet(isPresented: $showingQRCode) {
            GameQRCodeDisplayView(liveGame: serverGameState)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
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
            
            deviceControl.updateControlStatus(
                for: serverGameState,
                userEmail: authService.currentUser?.email
            )
            
            autoGrantInitialControl()
            
            if serverGameState.currentTimeSegment == nil && deviceControl.hasControl {
                startInitialTimeTracking()
            }
            
            // START KEEP-ALIVE MECHANISMS ONLY FOR MULTI-DEVICE GAMES
            if deviceControl.hasControl && (serverGameState.isMultiDeviceSetup ?? false) {
                debugPrint("❤️ [Multi-Device] Starting ping and game state announcement timers")
                startPinging()
                startAnnouncingGameState()

                // Request recording state after connection is stable
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if multipeer.connectionState.isConnected {
                        debugPrint("📤 Requesting recording state from recorder")
                        multipeer.sendRequestForRecordingState()
                    } else {
                        debugPrint("⚠️ WARNING: Not connected when requesting recording state!")
                    }
                }
            } else if !( serverGameState.isMultiDeviceSetup ?? false) {
                debugPrint("📱 [Single-Device] Skipping multipeer mechanisms")
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
        debugPrint("❤️ [Controller] Starting to ping recorder every 2.5 seconds.")
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            // Only send pings if this device has control
            if deviceControl.hasControl {
                Task { @MainActor in
                    multipeer.sendPing()
                }
            }
        }
    }

    private func stopPinging() {
        pingTimer?.invalidate()
        pingTimer = nil
        debugPrint("💔 [Controller] Stopped pinging recorder.")
    }
    
    
    
    private func startAnnouncingGameState() {
        // Invalidate any existing timer to prevent duplicates
        stopAnnouncingGameState()

        debugPrint("📢 [Controller] Starting to announce game state every 15 seconds (backup only).")

        // Send one announcement immediately upon starting
        announceGameState()

        // Schedule the timer to repeat (reduced from 3s to 15s - now just a backup/recovery mechanism)
        gameStateAnnounceTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            announceGameState()

            // ALSO: Send periodic clock sync for drift correction
            Task { @MainActor in
                multipeer.sendClockSync(clockValue: localClockTime, isRunning: serverGameState.isRunning)
            }
        }
    }

    private func stopAnnouncingGameState() {
        gameStateAnnounceTimer?.invalidate()
        gameStateAnnounceTimer = nil
        debugPrint("📢 [Controller] Stopped announcing game state.")
    }

    private func announceGameState() {
        // Only send if this device is in control and has a valid game ID
        guard deviceControl.hasControl, let gameId = serverGameState.id else {
            return
        }

        // Send FULL game state to recorder (no Firebase reads needed!)
        let gameState: [String: String] = [
            "gameId": gameId,
            "homeScore": String(currentHomeScore),
            "awayScore": String(currentAwayScore),
            "clock": String(format: "%.1f", localClockTime),
            "quarter": String(currentQuarter),
            "isRunning": serverGameState.isRunning ? "true" : "false",
            "teamName": serverGameState.teamName,
            "opponent": serverGameState.opponent
        ]
        multipeer.sendGameState(gameState)
        // Log only every 10 announcements to reduce noise (30 seconds)
        if (Int(Date().timeIntervalSince1970) % 30 == 0) {
            debugPrint("📢 [Controller] Sent game state: \(currentHomeScore)-\(currentAwayScore) | Clock: \(String(format: "%.0f", localClockTime))s")
        }
    }
    
    
    
    // MARK: - Fixed Game Header
    @ViewBuilder
    private func fixedGameHeader() -> some View {
        VStack(spacing: isIPad ? 6 : 4) {
            // Done button with device status
            HStack {
                Button(action: handleDone) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Done")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .contentShape(Rectangle())
                .frame(minWidth: 80, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                Spacer()

                // QR Code Button (only show for multi-device games when controlling)
                if (serverGameState.isMultiDeviceSetup ?? false) && deviceControl.hasControl {
                    Button(action: { showingQRCode = true }) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                }

                // Device Control Status (moved to same row)
                CompactDeviceControlStatusCard(
                    hasControl: deviceControl.hasControl,
                    controllingUser: deviceControl.controllingUser,
                    canRequestControl: deviceControl.canRequestControl,
                    pendingRequest: deviceControl.pendingControlRequest,
                    isIPad: isIPad,
                    onRequestControl: requestControl,
                    showBluetoothStatus: (serverGameState.isMultiDeviceSetup ?? false) && DeviceRoleManager.shared.deviceRole == .controller,
                    isRecording: multipeer.isRemoteRecording ?? false,
                    onToggleRecording: DeviceRoleManager.shared.deviceRole == .controller ? {
                        let isRecording = self.multipeer.isRemoteRecording ?? false
                        if isRecording {
                            multipeer.sendStopRecording()
                        } else {
                            multipeer.sendStartRecording()
                        }
                    } : nil
                )
            }
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

            // Timeline Recording Control (Standalone)
            if deviceControl.hasControl {
                TimelineRecordingCard(
                    isRecording: timelineTracker.isRecording,
                    duration: timelineRecordingDuration,
                    isIPad: isIPad,
                    onToggleRecording: toggleTimelineRecording,
                    onExportTimeline: exportTimeline
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
        .padding(.horizontal, isIPad ? 12 : 10)
        .padding(.vertical, isIPad ? 8 : 6)
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

                // iPad: Horizontal layout | iPhone: Vertical layout
                if isIPad {
                    HStack(spacing: 8) {
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
                } else {
                    VStack(spacing: 6) {
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

                // iPad: Horizontal layout | iPhone: Vertical layout
                if isIPad {
                    HStack(spacing: 8) {
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
                } else {
                    VStack(spacing: 6) {
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
            debugPrint("📍 No active time segment to end")
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
            debugPrint("📍 Added \(segmentDuration) minutes to PLAYING time (new total: \(updatedGame.totalPlayingTimeMinutes))")
        } else {
            updatedGame.benchTimeMinutes += segmentDuration
            debugPrint("📍 Added \(segmentDuration) minutes to BENCH time (new total: \(updatedGame.benchTimeMinutes))")
        }
        
        debugPrint("📍 Ending time segment: \(currentSegment.isOnCourt ? "Court" : "Bench"), Duration: \(segmentDuration) minutes")
        debugPrint("📍 UPDATED TOTALS - Playing: \(updatedGame.totalPlayingTimeMinutes), Bench: \(updatedGame.benchTimeMinutes)")
        debugPrint("📍 Total segments: \(updatedGame.timeSegments.count)")
        
        // Save to Firebase with updated totals
        try await firebaseService.updateLiveGame(updatedGame)
        
        // Return the updated game state
        return updatedGame
    }

    private func updatePlayingStatus() {
        
        debugPrint("🔥 DEBUG: updatePlayingStatus() CALLED")
        let wasOnCourt = serverGameState.currentTimeSegment?.isOnCourt ?? true
        let isNowOnCourt = !sahilOnBench

        debugPrint("🔥 DEBUG: wasOnCourt: \(wasOnCourt), isNowOnCourt: \(isNowOnCourt)")
        debugPrint("🔥 DEBUG: sahilOnBench: \(sahilOnBench)")
        
        // DEBUG: Print current status
        debugPrint("🔍 Status change: \(wasOnCourt ? "Court" : "Bench") → \(isNowOnCourt ? "Court" : "Bench")")

        
        // Only update time tracking if status actually changed
        if wasOnCourt != isNowOnCourt {
            debugPrint("📍 Playing status changed: \(wasOnCourt ? "Court" : "Bench") → \(isNowOnCourt ? "Court" : "Bench")")
            
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
                    forcePrint("✅ Time tracking updated successfully")
                    
                } catch {
                    forcePrint("❌ Failed to update time tracking: \(error)")
                }
            }
        } else {
            debugPrint("🔥 DEBUG: No status change, calling scheduleUpdate()")
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
            debugPrint("✅ Initial time tracking started")
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
        debugPrint("--- Syncing Non-Clock Data with Server ---")
        
        currentStats = game.playerStats
        currentHomeScore = game.homeScore
        currentAwayScore = game.awayScore
        currentQuarter = game.quarter
        sahilOnBench = game.sahilOnBench ?? false
        
        if !deviceControl.hasControl ||
           abs(localClockTime - game.getCurrentClock()) > 5.0 {
            debugPrint("🔄 Syncing clock due to large difference or no control")
            localClockTime = game.getCurrentClock()
        }
        
        lastServerUpdate = Date()
    }
    
    private func syncWithServer() {
        let game = serverGameState
        
        debugPrint("--- Initial Sync with Server ---")
        debugPrint("Server isRunning: \(game.isRunning)")
        debugPrint("Server clock: \(game.clock)")
        debugPrint("Calculated current clock: \(game.getCurrentClock())")
        
        currentStats = game.playerStats
        currentHomeScore = game.homeScore
        currentAwayScore = game.awayScore
        currentQuarter = game.quarter
        sahilOnBench = game.sahilOnBench ?? false
        localClockTime = game.getCurrentClock()
        
        debugPrint("Local clock initialized to: \(localClockTime)")
    }
    
    private func autoGrantInitialControl() {
        guard authService.showAdminFeatures,
              let userEmail = authService.currentUser?.email else {
            forcePrint("❌ Auto-grant failed: Not admin or no email")
            return
        }
        
        let game = serverGameState
        
        debugPrint("--- Auto-Grant Control Check ---")
        debugPrint("Device ID: \(deviceControl.deviceId)")
        debugPrint("Server Controlling Device: \(game.controllingDeviceId ?? "nil")")
        debugPrint("Server Controlling User: \(game.controllingUserEmail ?? "nil")")
        debugPrint("Current User: \(userEmail)")
        debugPrint("Device Has Control: \(deviceControl.hasControl)")
        
        if game.controllingDeviceId == deviceControl.deviceId &&
           game.controllingUserEmail == userEmail &&
           !deviceControl.hasControl {
            
            debugPrint("🔧 FORCE SYNC: Server says we have control but local state disagrees")
            deviceControl.updateControlStatus(for: game, userEmail: userEmail)
            return
        }
        
        if game.controllingDeviceId == nil || game.controllingUserEmail == nil {
            debugPrint("✅ Auto-granting control - no one has it")
            
            Task {
                do {
                    _ = try await deviceControl.requestControl(for: game, userEmail: userEmail)
                } catch {
                    forcePrint("❌ Failed to auto-grant control: \(error)")
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
        debugPrint("--- Checking for Control Requests ---")
        debugPrint("Device has control: \(deviceControl.hasControl)")
        debugPrint("Control requested by: \(game.controlRequestedBy ?? "None")")
        debugPrint("Control requesting device: \(game.controlRequestingDeviceId ?? "None")")
        
        var isRequestActive = false
        if let requestTimestamp = game.controlRequestTimestamp {
            let timeElapsed = Date().timeIntervalSince(requestTimestamp)
            isRequestActive = timeElapsed <= 120
            
            if !isRequestActive {
                debugPrint("⏰ Control request has expired")
                return
            }
        }
        
        if deviceControl.hasControl,
           let requestingUser = game.controlRequestedBy,
           let requestingDeviceId = game.controlRequestingDeviceId,
           requestingDeviceId != deviceControl.deviceId,
           isRequestActive,
           !showingControlRequestAlert {
            
            debugPrint("✅ Showing control request alert")
            self.requestingUser = requestingUser
            self.requestingDeviceId = requestingDeviceId
            showingControlRequestAlert = true
        }
        
        if (game.controlRequestedBy == nil || !isRequestActive) && showingControlRequestAlert {
            debugPrint("Hiding control request alert - no pending request or expired")
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

                // CRITICAL FIX: Preserve local changes (scores, stats, bench status)
                updatedGame.playerStats = currentStats
                updatedGame.homeScore = currentHomeScore
                updatedGame.awayScore = currentAwayScore
                updatedGame.sahilOnBench = sahilOnBench

                if updatedGame.isRunning {
                    debugPrint("🛑 Pausing game")
                    updatedGame.isRunning = false
                    updatedGame.clock = localClockTime
                    updatedGame.clockStartTime = nil
                    updatedGame.clockAtStart = nil
                    debugPrint("Paused at: \(localClockTime)")
                    debugPrint("Scores preserved: \(currentHomeScore)-\(currentAwayScore)")
                } else {
                    debugPrint("▶️ Starting game")
                    updatedGame.isRunning = true
                    updatedGame.clockStartTime = now
                    updatedGame.clockAtStart = localClockTime
                    updatedGame.clock = localClockTime
                    debugPrint("Started with clock: \(localClockTime)")
                    debugPrint("Scores preserved: \(currentHomeScore)-\(currentAwayScore)")

                    // Send sync marker for native Camera app workflow (first time only)
                    if serverGameState.isMultiDeviceSetup ?? false, currentQuarter == 1, localClockTime >= (Double(serverGameState.quarterLength) * 60.0 - 5.0) {
                        debugPrint("🎬 First clock start - sending sync marker for video sync")
                        multipeer.sendGameClockStarted(timestamp: now)
                    }
                }

                updatedGame.lastClockUpdate = now

                // INSTANT: Send clock control immediately via multipeer (no delay!) - only for multi-device
                if serverGameState.isMultiDeviceSetup ?? false {
                    multipeer.sendClockControl(isRunning: updatedGame.isRunning, clockValue: localClockTime, timestamp: now)
                }

                try await firebaseService.updateLiveGame(updatedGame)
                debugPrint("✅ Game clock toggle successful")

            } catch {
                forcePrint("❌ Game clock toggle failed: \(error)")
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

                // CRITICAL FIX: Preserve local changes
                updatedGame.playerStats = currentStats
                updatedGame.homeScore = currentHomeScore
                updatedGame.awayScore = currentAwayScore
                updatedGame.sahilOnBench = sahilOnBench

                localClockTime += 60

                updatedGame.clock = localClockTime
                if updatedGame.isRunning {
                    updatedGame.clockStartTime = now
                    updatedGame.clockAtStart = localClockTime
                }
                updatedGame.lastClockUpdate = now

                try await firebaseService.updateLiveGame(updatedGame)
                debugPrint("✅ Added minute, scores preserved: \(currentHomeScore)-\(currentAwayScore)")
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

                // Allow advancing beyond numQuarter for overtime periods
                // No limit check - overtime is unlimited!
                debugPrint("⏭️ Advancing to next period from Q\(updatedGame.quarter)")
                if updatedGame.quarter >= updatedGame.numQuarter {
                    debugPrint("   🏀 Entering OVERTIME period")
                }

                // CRITICAL FIX: Preserve local changes
                updatedGame.playerStats = currentStats
                updatedGame.homeScore = currentHomeScore
                updatedGame.awayScore = currentAwayScore
                updatedGame.sahilOnBench = sahilOnBench

                updatedGame.quarter += 1

                // Overtime periods default to 5 minutes, regular periods use quarterLength
                // User can adjust with +1m/-1m buttons if needed
                let overtimePeriod = updatedGame.quarter > updatedGame.numQuarter
                let newClockTime = TimeInterval(overtimePeriod ? 5 * 60 : updatedGame.quarterLength * 60)

                updatedGame.clock = newClockTime
                updatedGame.isRunning = false
                updatedGame.clockStartTime = nil
                updatedGame.clockAtStart = nil
                updatedGame.lastClockUpdate = now

                localClockTime = newClockTime
                currentQuarter = updatedGame.quarter

                // INSTANT: Send period change immediately via multipeer (no delay!) - only for multi-device
                if serverGameState.isMultiDeviceSetup ?? false {
                    multipeer.sendPeriodChange(quarter: updatedGame.quarter, clockValue: newClockTime, gameFormat: updatedGame.gameFormat)
                }

                try await firebaseService.updateLiveGame(updatedGame)
                forcePrint("✅ Advanced quarter to \(updatedGame.quarter)/\(updatedGame.numQuarter), scores preserved: \(currentHomeScore)-\(currentAwayScore)")
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

        // INSTANT: Send score updates immediately via multipeer (no delay!) - only for multi-device
        if serverGameState.isMultiDeviceSetup ?? false {
            multipeer.sendScoreUpdate(homeScore: currentHomeScore, awayScore: currentAwayScore)
        }

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

                // Update timeline if recording
                if timelineTracker.isRecording {
                    timelineTracker.updateScore(game: updatedGame)
                }

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
    
   

    private func handleDone() {
        debugPrint("🏠 Done button pressed - returning to dashboard")
        // Stop timeline recording if active
        if timelineTracker.isRecording {
            stopTimelineRecording()
        }
        // Clean up navigation state
        navigation.returnToDashboard()
        // Actually dismiss the view
        dismiss()
    }

    // MARK: - Timeline Recording Controls

    private func toggleTimelineRecording() {
        if timelineTracker.isRecording {
            stopTimelineRecording()
        } else {
            startTimelineRecording()
        }
    }

    private func startTimelineRecording() {
        // Get team logo URLs
        let homeLogoURL = serverGameState.teamLogoURL
        let awayLogoURL = serverGameState.opponentLogoURL

        // Start timeline recording
        timelineTracker.startRecording(
            initialGame: serverGameState,
            homeLogoURL: homeLogoURL,
            awayLogoURL: awayLogoURL,
            captureInterval: 1.0 // Second-by-second
        )

        // Start UI timer for duration display
        timelineRecordingDuration = 0
        timelineTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.timelineRecordingDuration += 1
            }
        }

        debugPrint("📊 Standalone timeline recording started")
    }

    private func stopTimelineRecording() {
        // Stop the tracker
        let timeline = timelineTracker.stopRecording()

        // Stop UI timer
        timelineTimer?.invalidate()
        timelineTimer = nil
        timelineRecordingDuration = 0

        // Save timeline to disk
        if let gameId = serverGameState.id {
            timelineTracker.saveTimeline(timeline, forGameId: gameId)
            forcePrint("📊 Timeline saved: \(timeline.count) snapshots for game \(gameId)")
        }

        debugPrint("📊 Standalone timeline recording stopped")
    }

    private func exportTimeline() {
        guard let gameId = serverGameState.id,
              let timelineURL = timelineTracker.getTimelineURL(forGameId: gameId) else {
            forcePrint("❌ No timeline found to export")
            return
        }

        // Set up share sheet
        shareURL = timelineURL
        showingShareSheet = true
    }

    private func finishGame() {
        guard deviceControl.hasControl else { return }

        Task {
            do {
                // 1. Await the definitive, updated game object after ending the last segment.
                let finalServerState = try await endCurrentTimeSegment()

                // 🔍 DEBUG: Print detailed playing time information
                debugPrint("🔍 ========== FINAL GAME TIME DEBUG ==========")
                debugPrint("📊 Raw Stored Values:")
                debugPrint("   totalPlayingTimeMinutes: \(finalServerState.totalPlayingTimeMinutes)")
                debugPrint("   benchTimeMinutes: \(finalServerState.benchTimeMinutes)")
                debugPrint("   timeSegments count: \(finalServerState.timeSegments.count)")
                
                // Show each completed segment
                for (index, segment) in finalServerState.timeSegments.enumerated() {
                    let durationSeconds = segment.durationMinutes * 60
                    let minutes = Int(durationSeconds) / 60
                    let seconds = Int(durationSeconds) % 60
                    debugPrint("   Segment \(index + 1): \(segment.isOnCourt ? "Court" : "Bench") - \(minutes)m \(seconds)s")
                }
                
                // Check if there's still an active segment (shouldn't be any after endCurrentTimeSegment)
                if let current = finalServerState.currentTimeSegment {
                    let currentDuration = Date().timeIntervalSince(current.startTime)
                    let minutes = Int(currentDuration) / 60
                    let seconds = Int(currentDuration) % 60
                    debugPrint("   ⚠️ WARNING: Still has active segment: \(current.isOnCourt ? "Court" : "Bench") - \(minutes)m \(seconds)s")
                } else {
                    debugPrint("   ✅ No active segment (correct)")
                }
                
                // Calculate totals using the computed properties
                let totalPlayingTime = finalServerState.totalPlayingTime
                let totalBenchTime = finalServerState.totalBenchTime
                let totalTime = totalPlayingTime + totalBenchTime
                
                debugPrint("📈 Computed Totals (what will be saved to Game):")
                let playingMinutes = Int(totalPlayingTime)
                let playingSeconds = Int((totalPlayingTime - Double(playingMinutes)) * 60)
                let benchMinutes = Int(totalBenchTime)
                let benchSeconds = Int((totalBenchTime - Double(benchMinutes)) * 60)
                let totalMinutes = Int(totalTime)
                let totalSecondsRemainder = Int((totalTime - Double(totalMinutes)) * 60)
                
                debugPrint("   Total Playing Time: \(playingMinutes)m \(playingSeconds)s (\(totalPlayingTime) minutes)")
                debugPrint("   Total Bench Time: \(benchMinutes)m \(benchSeconds)s (\(totalBenchTime) minutes)")
                debugPrint("   Total Game Time: \(totalMinutes)m \(totalSecondsRemainder)s (\(totalTime) minutes)")
                
                if totalTime > 0 {
                    let percentage = (totalPlayingTime / totalTime) * 100
                    debugPrint("   Playing Percentage: \(String(format: "%.1f", percentage))%")
                }
                
                debugPrint("🔍 ==========================================")

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
                    gameTimeTracking: finalServerState.timeSegments,
                    isMultiDeviceSetup: finalServerState.isMultiDeviceSetup
                )
                
                // CRITICAL: Use the same game ID from live game for the final game
                guard let liveGameId = finalServerState.id else {
                    throw NSError(domain: "LiveGameView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live game ID is missing"])
                }

                // Save the final game with the SAME ID as the live game
                var finalGameWithId = finalGame
                finalGameWithId.id = liveGameId

                // Use setData to save with specific ID (NOT addGame which creates new ID)
                let db = Firestore.firestore()
                try db.collection("games").document(liveGameId).setData(from: finalGameWithId)

                forcePrint("✅ Game saved with ID: \(liveGameId)")

                // CRITICAL: Delay before sending gameEnded to allow alert dismissal to be captured in recording
                if serverGameState.isMultiDeviceSetup ?? false {
                    debugPrint("⏳ Waiting 2 seconds for alert dismissal animation...")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
                    multipeer.sendGameEnded(gameId: liveGameId)
                    debugPrint("📤 Sent gameEnded message with gameId: \(liveGameId)")
                }

                // Delete the live game
                try await firebaseService.deleteLiveGame(liveGameId)

                // 🔍 DEBUG: Print what's actually in the Game object before saving
                debugPrint("🔍 ========== FINAL GAME OBJECT DEBUG ==========")
                debugPrint("📊 Game Object Time Values:")
                debugPrint("   finalGame.totalPlayingTimeMinutes: \(finalGame.totalPlayingTimeMinutes)")
                debugPrint("   finalGame.benchTimeMinutes: \(finalGame.benchTimeMinutes)")
                debugPrint("   finalGame.gameTimeTracking.count: \(finalGame.gameTimeTracking.count)")
                debugPrint("   finalGame.playingTimePercentage: \(finalGame.playingTimePercentage)")
                debugPrint("🔍 =============================================")

                await MainActor.run {
                    navigation.returnToDashboard()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to finish game: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Timeline Recording Card

struct TimelineRecordingCard: View {
    let isRecording: Bool
    let duration: TimeInterval
    let isIPad: Bool
    let onToggleRecording: () -> Void
    let onExportTimeline: () -> Void

    private var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            // Timeline icon
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: isIPad ? 22 : 18))
                .foregroundColor(isRecording ? .orange : .secondary)
                .frame(width: isIPad ? 32 : 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Timeline Recording")
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("REC \(durationString)")
                            .font(isIPad ? .caption : .caption2)
                            .foregroundColor(.red)
                    }
                } else {
                    Text("For post-processing overlays")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Record/Stop button
            Button(action: onToggleRecording) {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: isIPad ? 32 : 28))
                    .foregroundColor(isRecording ? .red : .orange)
            }

            // Export button (only shown when not recording)
            if !isRecording {
                Button(action: onExportTimeline) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: isIPad ? 20 : 18))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(isIPad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 14 : 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

