// File: SahilStats/Views/LiveGameView.swift (Complete and Fixed)

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
        // Remove navigation elements since we're using custom navigation
    }
}

// MARK: - Live Game Controller (Admin) - Fixed UI Issues

struct LiveGameControllerView: View {
    let liveGame: LiveGame
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var currentStats: PlayerStats
    @State private var currentHomeScore: Int
    @State private var currentAwayScore: Int
    @State private var isGameRunning: Bool
    @State private var currentPeriod: Int
    @State private var currentClock: TimeInterval
    @State private var sahilOnBench: Bool
    
    @State private var isUpdating = false
    @State private var error = ""
    @State private var updateTimer: Timer?
    @State private var hasUnsavedChanges = false
    @State private var clockTimer: Timer?
    @State private var showingFinishAlert = false
    
    // iPad specific layout
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    init(liveGame: LiveGame) {
        self.liveGame = liveGame
        _currentStats = State(initialValue: liveGame.playerStats)
        _currentHomeScore = State(initialValue: liveGame.homeScore)
        _currentAwayScore = State(initialValue: liveGame.awayScore)
        _isGameRunning = State(initialValue: liveGame.isRunning)
        _currentPeriod = State(initialValue: liveGame.period)
        _currentClock = State(initialValue: liveGame.clock)
        _sahilOnBench = State(initialValue: liveGame.sahilOnBench ?? false)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isIPad {
                iPadLayout(geometry: geometry)
            } else {
                iPhoneLayout()
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
            startClockIfNeeded()
        }
        .onDisappear {
            stopClock()
            updateTimer?.invalidate()
            if hasUnsavedChanges {
                updateLiveGameImmediately()
            }
        }
        .onChange(of: isGameRunning) { _, newValue in
            if newValue {
                startClock()
            } else {
                stopClock()
            }
            scheduleUpdate()
        }
    }
    
    // MARK: - iPad Layout (Two Column)
    
    private func iPadLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left Column - Game Status & Score
            VStack(spacing: 20) {
                // Game Header
                LiveGameHeaderCard(
                    liveGame: liveGame,
                    isGameRunning: $isGameRunning,
                    currentPeriod: $currentPeriod,
                    currentClock: $currentClock
                )
                
                // Score Section - Fixed alignment
                ImprovedLiveScoreCard(
                    homeScore: $currentHomeScore,
                    awayScore: $currentAwayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    onScoreChange: scheduleUpdate
                )
                
                // Player Status
                PlayerStatusCard(
                    sahilOnBench: $sahilOnBench,
                    onStatusChange: scheduleUpdate
                )
                
                // Game Controls - Single line layout
                SingleLineGameControlsCard(
                    isGameRunning: $isGameRunning,
                    currentPeriod: $currentPeriod,
                    currentClock: $currentClock,
                    maxPeriods: liveGame.numPeriods,
                    periodLength: liveGame.periodLength,
                    gameFormat: liveGame.gameFormat,
                    onClockChange: scheduleUpdate,
                    onFinishGame: {
                        showingFinishAlert = true
                    }
                )
                
                Spacer()
            }
            .frame(width: geometry.size.width * 0.4)
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // Right Column - Stats Only
            ScrollView {
                VStack(spacing: 20) {
                    if !sahilOnBench {
                        // Detailed Stats Entry
                        iPadDetailedStatsGrid()
                        
                        // Live Stats Display moved below steppers
                        LiveStatsDisplayCard(stats: currentStats)
                        
                        // Additional space at bottom
                        Spacer(minLength: 20)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "figure.basketball")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                            
                            Text("Sahil is on the bench")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text("Stats tracking is paused while on bench")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(width: geometry.size.width * 0.6)
            .padding()
        }
    }
    
    // MARK: - iPhone Layout (Scrollable)
    
    private func iPhoneLayout() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Clock Display
                ClockDisplayCard(
                    currentPeriod: $currentPeriod,
                    currentClock: $currentClock,
                    isGameRunning: $isGameRunning,
                    gameFormat: liveGame.gameFormat
                )
                
                // Live Score Entry - Fixed alignment
                ImprovedLiveScoreCard(
                    homeScore: $currentHomeScore,
                    awayScore: $currentAwayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    onScoreChange: scheduleUpdate
                )
                
                // Player Status
                PlayerStatusCard(
                    sahilOnBench: $sahilOnBench,
                    onStatusChange: scheduleUpdate
                )
                
                // Game Controls - Single line layout
                SingleLineGameControlsCard(
                    isGameRunning: $isGameRunning,
                    currentPeriod: $currentPeriod,
                    currentClock: $currentClock,
                    maxPeriods: liveGame.numPeriods,
                    periodLength: liveGame.periodLength,
                    gameFormat: liveGame.gameFormat,
                    onClockChange: scheduleUpdate,
                    onFinishGame: {
                        showingFinishAlert = true
                    }
                )
                
                // Stats Entry (only if Sahil is playing)
                if !sahilOnBench {
                    iPhoneDetailedStatsEntry()
                    
                    // Live Stats moved below steppers
                    LiveStatsDisplayCard(stats: currentStats)
                }
            }
            .padding()
        }
    }
    
    // MARK: - iPad Quick Actions (Larger Buttons)
    
    private func iPadQuickActionsGrid() -> some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                iPadActionButton(title: "2PT", subtitle: "Made", color: .blue) {
                    currentStats.fg2m += 1
                    currentStats.fg2a += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "3PT", subtitle: "Made", color: .green) {
                    currentStats.fg3m += 1
                    currentStats.fg3a += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "FT", subtitle: "Made", color: .orange) {
                    currentStats.ftm += 1
                    currentStats.fta += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "REB", subtitle: "", color: .mint) {
                    currentStats.rebounds += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "AST", subtitle: "", color: .cyan) {
                    currentStats.assists += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "STL", subtitle: "", color: .yellow) {
                    currentStats.steals += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "BLK", subtitle: "", color: .red) {
                    currentStats.blocks += 1
                    scheduleUpdate()
                }
                
                iPadActionButton(title: "TO", subtitle: "", color: .pink) {
                    currentStats.turnovers += 1
                    scheduleUpdate()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func iPadActionButton(title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(8)
        }
    }
    
    // MARK: - iPad Detailed Stats
    
    private func iPadDetailedStatsGrid() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Detailed Stats")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Tap +/- to adjust")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Shooting Stats Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.blue)
                    Text("Shooting")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    iPadStatControl(title: "2PT Made", value: $currentStats.fg2m, max: currentStats.fg2a, color: .blue)
                    iPadStatControl(title: "2PT Attempts", value: $currentStats.fg2a, min: currentStats.fg2m, color: .blue)
                    iPadStatControl(title: "3PT Made", value: $currentStats.fg3m, max: currentStats.fg3a, color: .green)
                    iPadStatControl(title: "3PT Attempts", value: $currentStats.fg3a, min: currentStats.fg3m, color: .green)
                    iPadStatControl(title: "FT Made", value: $currentStats.ftm, max: currentStats.fta, color: .orange)
                    iPadStatControl(title: "FT Attempts", value: $currentStats.fta, min: currentStats.ftm, color: .orange)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Other Stats Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                    Text("Game Stats")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    iPadStatControl(title: "Rebounds", value: $currentStats.rebounds, color: .mint)
                    iPadStatControl(title: "Assists", value: $currentStats.assists, color: .cyan)
                    iPadStatControl(title: "Steals", value: $currentStats.steals, color: .yellow)
                    iPadStatControl(title: "Blocks", value: $currentStats.blocks, color: .red)
                    iPadStatControl(title: "Fouls", value: $currentStats.fouls, color: .pink)
                    iPadStatControl(title: "Turnovers", value: $currentStats.turnovers, color: .indigo)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func iPadStatControl(title: String, value: Binding<Int>, min: Int = 0, max: Int? = nil, color: Color = .orange) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                Button("-") {
                    if value.wrappedValue > min {
                        value.wrappedValue -= 1
                        scheduleUpdate()
                    }
                }
                .buttonStyle(iPadStatButtonStyle(color: color))
                .disabled(value.wrappedValue <= min)
                
                Text("\(value.wrappedValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(minWidth: 35)
                
                Button("+") {
                    if let max = max, value.wrappedValue >= max {
                        // Don't increment if at max
                    } else {
                        value.wrappedValue += 1
                        scheduleUpdate()
                    }
                }
                .buttonStyle(iPadStatButtonStyle(color: color))
                .disabled(max != nil && value.wrappedValue >= max!)
            }
            
            // Show ratio for shooting stats
            if max != nil && value.wrappedValue > 0 {
                Text("\(value.wrappedValue)/\(max!)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - iPhone Quick Actions (Compact)
    
    private func iPhoneQuickActionsGrid() -> some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                iPhoneActionButton(title: "2PT", color: .blue) {
                    currentStats.fg2m += 1
                    currentStats.fg2a += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "3PT", color: .green) {
                    currentStats.fg3m += 1
                    currentStats.fg3a += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "FT", color: .orange) {
                    currentStats.ftm += 1
                    currentStats.fta += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "REB", color: .mint) {
                    currentStats.rebounds += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "AST", color: .cyan) {
                    currentStats.assists += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "STL", color: .yellow) {
                    currentStats.steals += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "BLK", color: .red) {
                    currentStats.blocks += 1
                    scheduleUpdate()
                }
                
                iPhoneActionButton(title: "TO", color: .pink) {
                    currentStats.turnovers += 1
                    scheduleUpdate()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iPhoneActionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(6)
        }
    }
    
    // MARK: - iPhone Detailed Stats
    
    private func iPhoneDetailedStatsEntry() -> some View {
        VStack(spacing: 16) {
            Text("Detailed Stats")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                iPhoneStatControl(title: "2PT Made", value: $currentStats.fg2m, max: currentStats.fg2a)
                iPhoneStatControl(title: "2PT Att", value: $currentStats.fg2a, min: currentStats.fg2m)
                iPhoneStatControl(title: "3PT Made", value: $currentStats.fg3m, max: currentStats.fg3a)
                iPhoneStatControl(title: "3PT Att", value: $currentStats.fg3a, min: currentStats.fg3m)
                iPhoneStatControl(title: "FT Made", value: $currentStats.ftm, max: currentStats.fta)
                iPhoneStatControl(title: "FT Att", value: $currentStats.fta, min: currentStats.ftm)
                iPhoneStatControl(title: "Rebounds", value: $currentStats.rebounds)
                iPhoneStatControl(title: "Assists", value: $currentStats.assists)
                iPhoneStatControl(title: "Steals", value: $currentStats.steals)
                iPhoneStatControl(title: "Blocks", value: $currentStats.blocks)
                iPhoneStatControl(title: "Fouls", value: $currentStats.fouls)
                iPhoneStatControl(title: "Turnovers", value: $currentStats.turnovers)
            }
        }
        .frame(maxWidth: .infinity) // Ensure full width
        .padding(.horizontal, 16) // Consistent horizontal padding
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iPhoneStatControl(title: String, value: Binding<Int>, min: Int = 0, max: Int? = nil) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.black)
                .fontWeight(.bold)
            
            HStack(spacing: 8) {
                Button("-") {
                    if value.wrappedValue > min {
                        value.wrappedValue -= 1
                        scheduleUpdate()
                    }
                }
                .buttonStyle(iPhoneStatButtonStyle())
                .disabled(value.wrappedValue <= min)
                
                Text("\(value.wrappedValue)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(minWidth: 30)
                
                Button("+") {
                    if let max = max, value.wrappedValue >= max {
                        // Don't increment if at max
                    } else {
                        value.wrappedValue += 1
                        scheduleUpdate()
                    }
                }
                .buttonStyle(iPhoneStatButtonStyle())
                .disabled(max != nil && value.wrappedValue >= max!)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Clock Management
    
    private func startClockIfNeeded() {
        if isGameRunning {
            startClock()
        }
    }
    
    private func startClock() {
        stopClock() // Stop any existing timer
        
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if currentClock > 0 {
                currentClock -= 0.1
                
                // Auto-pause when clock reaches 0
                if currentClock <= 0 {
                    currentClock = 0
                    isGameRunning = false
                    stopClock()
                    
                    // Move to next period if not the final period
                    if currentPeriod < liveGame.numPeriods {
                        currentPeriod += 1
                        currentClock = TimeInterval(liveGame.periodLength * 60)
                    }
                    
                    scheduleUpdate()
                }
            }
        }
    }
    
    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
    
    // MARK: - Update Methods
    
    private func scheduleUpdate() {
        hasUnsavedChanges = true
        
        // Cancel existing timer
        updateTimer?.invalidate()
        
        // Schedule new update after 1 second of inactivity
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            updateLiveGameImmediately()
        }
    }
    
    private func updateLiveGameImmediately() {
        guard hasUnsavedChanges && !isUpdating else { return }
        
        isUpdating = true
        hasUnsavedChanges = false
        
        Task {
            do {
                var updatedGame = liveGame
                updatedGame.playerStats = currentStats
                updatedGame.homeScore = currentHomeScore
                updatedGame.awayScore = currentAwayScore
                updatedGame.sahilOnBench = sahilOnBench
                updatedGame.isRunning = isGameRunning
                updatedGame.period = currentPeriod
                updatedGame.clock = currentClock
                
                try await firebaseService.updateLiveGame(updatedGame)
                
                await MainActor.run {
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to update game: \(error.localizedDescription)"
                    isUpdating = false
                    hasUnsavedChanges = true // Mark as needing update again
                }
            }
        }
    }
    
    private func finishGame() {
        // Save any pending changes first
        updateTimer?.invalidate()
        stopClock()
        
        if hasUnsavedChanges {
            updateLiveGameImmediately()
        }
        
        Task {
            do {
                // Create final game record
                let finalGame = Game(
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    location: liveGame.location,
                    timestamp: liveGame.createdAt ?? Date(),
                    gameFormat: liveGame.gameFormat,
                    periodLength: liveGame.periodLength,
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
                
                // Save final game
                try await firebaseService.addGame(finalGame)
                
                // Delete live game
                try await firebaseService.deleteLiveGame(liveGame.id ?? "")
                
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
                    isReadOnly: true
                )
                
                // Score display (read-only)
                LiveScoreDisplayCard(
                    homeScore: liveGame.homeScore,
                    awayScore: liveGame.awayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent
                )
                
                // Stats display (read-only)
                if !(liveGame.sahilOnBench ?? false) {
                    LiveStatsDisplayCard(stats: liveGame.playerStats, isReadOnly: true)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.basketball")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Sahil is on the bench")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Stats tracking is paused")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
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

// MARK: - Improved Supporting Card Views

struct LiveGameHeaderCard: View {
    let liveGame: LiveGame
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    let isReadOnly: Bool
    
    init(liveGame: LiveGame, isGameRunning: Binding<Bool>, currentPeriod: Binding<Int>, currentClock: Binding<TimeInterval>, isReadOnly: Bool = false) {
        self.liveGame = liveGame
        self._isGameRunning = isGameRunning
        self._currentPeriod = currentPeriod
        self._currentClock = currentClock
        self.isReadOnly = isReadOnly
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                Text("LIVE GAME")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
                
                if !isReadOnly {
                    Button(isGameRunning ? "⏸️" : "▶️") {
                        isGameRunning.toggle()
                    }
                    .font(.title2)
                }
            }
            
            Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                Text("Period \(currentPeriod)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatClock(currentClock))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(isGameRunning ? .red : .secondary)
            }
            
            if let location = liveGame.location {
                Text("📍 \(location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
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

// MARK: - Improved Score Card (Fixed Alignment)

// MARK: - Clock Display Card

struct ClockDisplayCard: View {
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    @Binding var isGameRunning: Bool
    let gameFormat: GameFormat
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Period \(currentPeriod)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(formatClock(currentClock))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(isGameRunning ? .red : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
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

struct ImprovedLiveScoreCard: View {
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    let teamName: String
    let opponent: String
    let onScoreChange: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Live Score")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Home team (left side)
                VStack(spacing: 8) {
                    Text(teamName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Button("-") {
                            if homeScore > 0 {
                                homeScore -= 1
                                onScoreChange()
                            }
                        }
                        .buttonStyle(ImprovedScoreButtonStyle())
                        
                        Text("\(homeScore)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(minWidth: 60)
                        
                        Button("+") {
                            homeScore += 1
                            onScoreChange()
                        }
                        .buttonStyle(ImprovedScoreButtonStyle())
                    }
                }
                
                // Separator
                Text("–")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                // Away team (right side)
                VStack(spacing: 8) {
                    Text(opponent)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Button("-") {
                            if awayScore > 0 {
                                awayScore -= 1
                                onScoreChange()
                            }
                        }
                        .buttonStyle(ImprovedScoreButtonStyle())
                        
                        Text("\(awayScore)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(minWidth: 60)
                        
                        Button("+") {
                            awayScore += 1
                            onScoreChange()
                        }
                        .buttonStyle(ImprovedScoreButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity) // Force full width
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LiveScoreDisplayCard: View {
    let homeScore: Int
    let awayScore: Int
    let teamName: String
    let opponent: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Live Score")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text(teamName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(homeScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .frame(minWidth: 60)
                }
                
                Text("–")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text(opponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(awayScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(minWidth: 60)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct PlayerStatusCard: View {
    @Binding var sahilOnBench: Bool
    let onStatusChange: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Sahil's Status")
                .font(.headline)
            
            HStack(spacing: 8) {
                Button("On Court") {
                    sahilOnBench = false
                    onStatusChange()
                }
                .buttonStyle(StatusButtonStyle(isSelected: !sahilOnBench))
                
                Button("On Bench") {
                    sahilOnBench = true
                    onStatusChange()
                }
                .buttonStyle(StatusButtonStyle(isSelected: sahilOnBench))
            }
        }
        .frame(maxWidth: .infinity) // Force full width
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Single Line Game Controls (Cleaner Layout)

struct SingleLineGameControlsCard: View {
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    let maxPeriods: Int
    let periodLength: Int
    let gameFormat: GameFormat
    let onClockChange: () -> Void
    let onFinishGame: () -> Void
    
    private var endGameButtonText: String {
        if currentPeriod < maxPeriods {
            return gameFormat == .halves ? "End Half" : "End Period"
        } else {
            return "End Game"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Game Controls")
                .font(.headline)
            
            // All controls on one line
            HStack(spacing: 12) {
                Button(isGameRunning ? "Pause" : "Start") {
                    isGameRunning.toggle()
                }
                .buttonStyle(LargerControlButtonStyle(color: isGameRunning ? .orange : .green))
                
                Button("+1 Min") {
                    currentClock += 60
                    onClockChange()
                }
                .buttonStyle(LargerControlButtonStyle(color: .purple))
                
                if currentPeriod < maxPeriods {
                    Button("Next") {
                        currentPeriod += 1
                        currentClock = TimeInterval(periodLength * 60)
                        onClockChange()
                    }
                    .buttonStyle(LargerControlButtonStyle(color: .blue))
                }
                
                Button(endGameButtonText) {
                    onFinishGame()
                }
                .buttonStyle(LargerControlButtonStyle(color: .red))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LargerControlButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ImprovedGameControlsCard: View {
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    let maxPeriods: Int
    let periodLength: Int
    let onClockChange: () -> Void
    let onFinishGame: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Game Controls")
                .font(.headline)
            
            // Single row layout for better spacing
            HStack(spacing: 12) {
                Button(isGameRunning ? "⏸️ Pause" : "▶️ Start") {
                    isGameRunning.toggle()
                }
                .buttonStyle(CompactGameControlButtonStyle(color: isGameRunning ? .orange : .green))
                
                Button("Reset") {
                    currentClock = TimeInterval(periodLength * 60)
                    onClockChange()
                }
                .buttonStyle(CompactGameControlButtonStyle(color: .gray))
                
                Button("+1 Min") {
                    currentClock += 60
                    onClockChange()
                }
                .buttonStyle(CompactGameControlButtonStyle(color: .purple))
            }
            
            // Second row for period control and finish
            HStack(spacing: 12) {
                if currentPeriod < maxPeriods {
                    Button("Next Period") {
                        currentPeriod += 1
                        currentClock = TimeInterval(periodLength * 60)
                        onClockChange()
                    }
                    .buttonStyle(CompactGameControlButtonStyle(color: .blue))
                }
                
                Button("🏁 Finish Game") {
                    onFinishGame()
                }
                .buttonStyle(CompactGameControlButtonStyle(color: .red))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LiveStatsDisplayCard: View {
    let stats: PlayerStats
    let isReadOnly: Bool
    
    init(stats: PlayerStats, isReadOnly: Bool = false) {
        self.stats = stats
        self.isReadOnly = isReadOnly
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(isReadOnly ? "Current Stats" : "Live Stats")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                LiveStatDisplayCard(title: "PTS", value: stats.points, color: .purple)
                LiveStatDisplayCard(title: "REB", value: stats.rebounds, color: .mint)
                LiveStatDisplayCard(title: "AST", value: stats.assists, color: .cyan)
                LiveStatDisplayCard(title: "STL", value: stats.steals, color: .yellow)
                LiveStatDisplayCard(title: "BLK", value: stats.blocks, color: .red)
                LiveStatDisplayCard(title: "TO", value: stats.turnovers, color: .pink)
            }
            
            // Shooting percentages
            if stats.fg2a > 0 || stats.fg3a > 0 || stats.fta > 0 {
                Divider()
                
                HStack(spacing: 20) {
                    if stats.fg2a > 0 {
                        ShootingStatCard(
                            title: "FG%",
                            made: stats.fg2m + stats.fg3m,
                            attempted: stats.fg2a + stats.fg3a
                        )
                    }
                    
                    if stats.fg3a > 0 {
                        ShootingStatCard(
                            title: "3P%",
                            made: stats.fg3m,
                            attempted: stats.fg3a
                        )
                    }
                    
                    if stats.fta > 0 {
                        ShootingStatCard(
                            title: "FT%",
                            made: stats.ftm,
                            attempted: stats.fta
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LiveStatDisplayCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ShootingStatCard: View {
    let title: String
    let made: Int
    let attempted: Int
    
    private var percentage: Double {
        return attempted > 0 ? Double(made) / Double(attempted) : 0.0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(percentage * 100))%")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("\(made)/\(attempted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Improved Button Styles

struct ImprovedScoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StatusButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .white : .orange)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.orange : Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactGameControlButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct iPadStatButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = .orange) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(color)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct iPhoneStatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
