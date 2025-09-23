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


// MARK: - Live Points Summary Card (Add this to LiveGameView.swift)

struct LivePointsSummaryCard: View {
    let stats: PlayerStats
    let isIPad: Bool
    
    private var totalPoints: Int {
        return (stats.fg2m * 2) + (stats.fg3m * 3) + stats.ftm
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
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


// MARK: - Collapsing Live Game Header Component

struct CollapsingLiveGameHeader: View {
    let deviceControl: DeviceControlManager
    let serverGameState: LiveGame
    @Binding var currentHomeScore: Int
    @Binding var currentAwayScore: Int
    let localClockTime: TimeInterval
    let currentPeriod: Int
    @Binding var sahilOnBench: Bool
    let isHeaderCollapsed: Bool
    let isIPad: Bool
    
    let onRequestControl: () -> Void
    let onStartPause: () -> Void
    let onAddMinute: () -> Void
    let onAdvancePeriod: () -> Void
    let onFinishGame: () -> Void
    let onScoreChange: () -> Void
    let onStatusChange: () -> Void
    
    var body: some View {
        VStack(spacing: isHeaderCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 16 : 12)) {
            // Always show device control status (but make it smaller when collapsed)
            CompactDeviceControlStatusCard(
                hasControl: deviceControl.hasControl,
                controllingUser: deviceControl.controllingUser,
                canRequestControl: deviceControl.canRequestControl,
                pendingRequest: deviceControl.pendingControlRequest,
                isIPad: isIPad,
                onRequestControl: onRequestControl
            )
            .scaleEffect(isHeaderCollapsed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: isHeaderCollapsed)
            
            if !isHeaderCollapsed {
                // Expanded: Show clock
                CompactClockCard(
                    period: currentPeriod,
                    clockTime: localClockTime,
                    isGameRunning: serverGameState.isRunning,
                    gameFormat: serverGameState.gameFormat,
                    isIPad: isIPad
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
            
            // Score (always visible but smaller when collapsed)
            Group {
                if deviceControl.hasControl {
                    CollapsibleLiveScoreCard(
                        homeScore: $currentHomeScore,
                        awayScore: $currentAwayScore,
                        teamName: serverGameState.teamName,
                        opponent: serverGameState.opponent,
                        isCollapsed: isHeaderCollapsed,
                        isIPad: isIPad,
                        onScoreChange: onScoreChange
                    )
                } else {
                    CollapsibleLiveScoreDisplayCard(
                        homeScore: serverGameState.homeScore,
                        awayScore: serverGameState.awayScore,
                        teamName: serverGameState.teamName,
                        opponent: serverGameState.opponent,
                        isCollapsed: isHeaderCollapsed,
                        isIPad: isIPad
                    )
                }
            }
            
            if !isHeaderCollapsed {
                // Expanded: Show player status and game controls
                VStack(spacing: isIPad ? 12 : 8) {
                    PlayerStatusCard(
                        sahilOnBench: $sahilOnBench,
                        isIPad: isIPad,
                        hasControl: deviceControl.hasControl,
                        onStatusChange: onStatusChange
                    )
                    
                    if deviceControl.hasControl {
                        CompactGameControlsCard(
                            currentPeriod: currentPeriod,
                            maxPeriods: serverGameState.numPeriods,
                            gameFormat: serverGameState.gameFormat,
                            isGameRunning: serverGameState.isRunning,
                            isIPad: isIPad,
                            onStartPause: onStartPause,
                            onAddMinute: onAddMinute,
                            onAdvancePeriod: onAdvancePeriod,
                            onFinishGame: onFinishGame
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.vertical, isHeaderCollapsed ? (isIPad ? 16 : 12) : (isIPad ? 16 : 12))
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: isHeaderCollapsed)
    }
}

// MARK: - Collapsible Live Score Cards

struct CollapsibleLiveScoreCard: View {
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    let teamName: String
    let opponent: String
    let isCollapsed: Bool
    let isIPad: Bool
    let onScoreChange: () -> Void
    
    var body: some View {
        VStack(spacing: isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 16)) {
            if !isCollapsed {
                Text("Live Score")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .transition(.opacity)
            }
            
            HStack(spacing: isCollapsed ? (isIPad ? 24 : 20) : (isIPad ? 32 : 24)) {
                // Home team
                VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 12)) {
                    if !isCollapsed {
                        Text(teamName)
                            .font(isIPad ? .body : .caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    }
                    
                    VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 12)) {
                        Text("\(homeScore)")
                            .font(isCollapsed ?
                                  (isIPad ? .system(size: 40, weight: .heavy) : .system(size: 36, weight: .heavy)) :
                                  (isIPad ? .system(size: 64, weight: .heavy) : .system(size: 56, weight: .heavy))
                            )
                            .foregroundColor(.blue)
                            .frame(minWidth: isCollapsed ? (isIPad ? 60 : 50) : (isIPad ? 80 : 70))
                            .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                        
                        if !isCollapsed {
                            HStack(spacing: isIPad ? 20 : 16) {
                                Button("-") {
                                    if homeScore > 0 {
                                        homeScore -= 1
                                        onScoreChange()
                                    }
                                }
                                .buttonStyle(CollapsibleScoreButtonStyle(isCollapsed: isCollapsed, isIPad: isIPad))
                                
                                Button("+") {
                                    homeScore += 1
                                    onScoreChange()
                                }
                                .buttonStyle(CollapsibleScoreButtonStyle(isCollapsed: isCollapsed, isIPad: isIPad))
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                
                Text("–")
                    .font(isCollapsed ?
                          (isIPad ? .system(size: 24, weight: .medium) : .system(size: 20, weight: .medium)) :
                          (isIPad ? .system(size: 40, weight: .medium) : .system(size: 36, weight: .medium))
                    )
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                
                // Away team
                VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 12)) {
                    if !isCollapsed {
                        Text(opponent)
                            .font(isIPad ? .body : .caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    }
                    
                    VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 12)) {
                        Text("\(awayScore)")
                            .font(isCollapsed ?
                                  (isIPad ? .system(size: 40, weight: .heavy) : .system(size: 36, weight: .heavy)) :
                                  (isIPad ? .system(size: 64, weight: .heavy) : .system(size: 56, weight: .heavy))
                            )
                            .foregroundColor(.red)
                            .frame(minWidth: isCollapsed ? (isIPad ? 60 : 50) : (isIPad ? 80 : 70))
                            .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                        
                        if !isCollapsed {
                            HStack(spacing: isIPad ? 20 : 16) {
                                Button("-") {
                                    if awayScore > 0 {
                                        awayScore -= 1
                                        onScoreChange()
                                    }
                                }
                                .buttonStyle(CollapsibleScoreButtonStyle(isCollapsed: isCollapsed, isIPad: isIPad))
                                
                                Button("+") {
                                    awayScore += 1
                                    onScoreChange()
                                }
                                .buttonStyle(CollapsibleScoreButtonStyle(isCollapsed: isCollapsed, isIPad: isIPad))
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, isCollapsed ? (isIPad ? 20 : 16) : (isIPad ? 28 : 24))
        .padding(.vertical, isCollapsed ? (isIPad ? 16 : 12) : (isIPad ? 28 : 24))
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 16))
                .stroke(Color.orange.opacity(0.4), lineWidth: 2)
        )
        .cornerRadius(isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 16))
        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
    }
}

struct CollapsibleLiveScoreDisplayCard: View {
    let homeScore: Int
    let awayScore: Int
    let teamName: String
    let opponent: String
    let isCollapsed: Bool
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 16)) {
            if !isCollapsed {
                Text("Live Score")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .transition(.opacity)
            }
            
            HStack(spacing: isCollapsed ? (isIPad ? 32 : 24) : (isIPad ? 40 : 32)) {
                VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 12)) {
                    if !isCollapsed {
                        Text(teamName)
                            .font(isIPad ? .body : .caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    }
                    
                    Text("\(homeScore)")
                        .font(isCollapsed ?
                              (isIPad ? .system(size: 48, weight: .heavy) : .system(size: 40, weight: .heavy)) :
                              (isIPad ? .system(size: 72, weight: .heavy) : .system(size: 64, weight: .heavy))
                        )
                        .foregroundColor(.blue)
                        .frame(minWidth: isCollapsed ? (isIPad ? 70 : 60) : (isIPad ? 90 : 80))
                        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                }
                
                Text("–")
                    .font(isCollapsed ?
                          (isIPad ? .system(size: 28, weight: .medium) : .system(size: 24, weight: .medium)) :
                          (isIPad ? .system(size: 44, weight: .medium) : .system(size: 40, weight: .medium))
                    )
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                
                VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 12)) {
                    if !isCollapsed {
                        Text(opponent)
                            .font(isIPad ? .body : .caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    }
                    
                    Text("\(awayScore)")
                        .font(isCollapsed ?
                              (isIPad ? .system(size: 48, weight: .heavy) : .system(size: 40, weight: .heavy)) :
                              (isIPad ? .system(size: 72, weight: .heavy) : .system(size: 64, weight: .heavy))
                        )
                        .foregroundColor(.red)
                        .frame(minWidth: isCollapsed ? (isIPad ? 70 : 60) : (isIPad ? 90 : 80))
                        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                }
            }
        }
        .padding(.horizontal, isCollapsed ? (isIPad ? 20 : 16) : (isIPad ? 28 : 24))
        .padding(.vertical, isCollapsed ? (isIPad ? 16 : 12) : (isIPad ? 28 : 24))
        .background(Color(.systemGray6))
        .cornerRadius(isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 16))
        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
    }
}

// MARK: - Button Style for Collapsible Score

struct CollapsibleScoreButtonStyle: ButtonStyle {
    let isCollapsed: Bool
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCollapsed ?
                  (isIPad ? .system(size: 18, weight: .bold) : .body) :
                  (isIPad ? .system(size: 28, weight: .bold) : .system(size: 24, weight: .bold))
            )
            .foregroundColor(.white)
            .frame(
                width: isCollapsed ? (isIPad ? 36 : 32) : (isIPad ? 56 : 48),
                height: isCollapsed ? (isIPad ? 36 : 32) : (isIPad ? 56 : 48)
            )
            .background(
                Circle()
                    .fill(Color.orange)
                    .shadow(color: .orange.opacity(0.3), radius: configuration.isPressed ? 2 : 4, x: 0, y: configuration.isPressed ? 1 : 2)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.25), value: isCollapsed)
    }
}

// MARK: - ScrollView with Offset Tracking (Keep this from previous artifact)

struct ScrollViewWithOffset<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let onOffsetChange: (CGFloat) -> Void
    let content: Content
    
    init(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        onOffsetChange: @escaping (CGFloat) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.onOffsetChange = onOffsetChange
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).origin.y
                )
            }
            .frame(height: 0)
            
            content
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: onOffsetChange)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
    @State private var currentPeriod: Int
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
    
    // FIXED: Calculate header height to prevent content overlap
    private var headerHeight: CGFloat {
       return 0
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
        VStack(spacing: 0) {
            // SIMPLE: Fixed header at top
            fixedHeader()
            
            // SIMPLE: Main content in scroll view with proper header padding
            ScrollView {
                VStack(spacing: isIPad ? 24 : 20) {
                    // Only show stats if playing AND has control OR is viewer
                    if !sahilOnBench && deviceControl.hasControl {
                        cleanDetailedStatsEntry()
                        LiveStatsDisplayCard(stats: currentStats, isIPad: isIPad)
                        PlayingTimeCard(
                            totalPlayingTime: serverGameState.totalPlayingTime,
                            totalBenchTime: serverGameState.totalBenchTime,
                            isIPad: isIPad
                        )
                    } else if !sahilOnBench {
                        // Viewer stats (read-only)
                        LiveStatsDisplayCard(
                            stats: serverGameState.playerStats,
                            isIPad: isIPad,
                            isReadOnly: true
                        )
                    } else {
                        VStack {
                            // On bench message with extra top spacing
                            Spacer(minLength: isIPad ? 90 : 50) // Add this spacer
                            onBenchMessage()
                        }
                    }
                    
                    // Add bottom padding for safe scrolling
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, isIPad ? 24 : 16)
                //.padding(.top, headerHeight + (isIPad ? 20 : 16))
                .padding(.top, headerHeight) // FIXED: Add header height to top padding
            }
        }
        .background(Color(.systemBackground))
        // Keep all your existing alerts and onChange handlers
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
            
            syncNonClockDataWithServer(newGame)
            refreshTrigger.trigger()
            checkForControlRequests(newGame)
        }
    }
    
    // SIMPLE: Fixed header that doesn't collapse
    @ViewBuilder
    private func fixedHeader() -> some View {
        VStack(spacing: isIPad ? 16 : 12) {
            // Device Control Status
            CompactDeviceControlStatusCard(
                hasControl: deviceControl.hasControl,
                controllingUser: deviceControl.controllingUser,
                canRequestControl: deviceControl.canRequestControl,
                pendingRequest: deviceControl.pendingControlRequest,
                isIPad: isIPad,
                onRequestControl: requestControl
            )
            
            // Clock Display
            CompactClockCard(
                period: currentPeriod,
                clockTime: localClockTime,
                isGameRunning: isGameRunning,
                gameFormat: serverGameState.gameFormat,
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
                onStatusChange: updatePlayingStatus
            )
            
            // Game Controls
            if deviceControl.hasControl {
                CompactGameControlsCard(
                    currentPeriod: currentPeriod,
                    maxPeriods: serverGameState.numPeriods,
                    gameFormat: serverGameState.gameFormat,
                    isGameRunning: serverGameState.isRunning,
                    isIPad: isIPad,
                    onStartPause: toggleGameClock,
                    onAddMinute: addMinuteToClock,
                    onAdvancePeriod: nextPeriod,
                    onFinishGame: { showingFinishAlert = true }
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
                
                VStack(spacing: isIPad ? 16 : 12) {
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

    private func endCurrentTimeSegment() {
        guard var currentSegment = serverGameState.currentTimeSegment else { return }
        
        currentSegment.endTime = Date()
        
        var updatedGame = serverGameState
        updatedGame.timeSegments.append(currentSegment)
        updatedGame.currentTimeSegment = nil
        
        Task {
            try await firebaseService.updateLiveGame(updatedGame)
        }
    }

    private func updatePlayingStatus() {
        let wasOnCourt = serverGameState.currentTimeSegment?.isOnCourt ?? true
        let isNowOnCourt = !sahilOnBench
        
        if wasOnCourt != isNowOnCourt {
            startTimeTracking(onCourt: isNowOnCourt)
        }
        
        scheduleUpdate()
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
        
        // End current time segment
        endCurrentTimeSegment()
        
        // Calculate total playing time
        let totalPlayingTime = serverGameState.totalPlayingTime
        let totalBenchTime = serverGameState.totalBenchTime
        
        
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
                    adminName: authService.currentUser?.email,
                    totalPlayingTimeMinutes: totalPlayingTime,
                    benchTimeMinutes: totalBenchTime,
                    gameTimeTracking: serverGameState.timeSegments
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
}

