// File: SahilStats/Views/GameStatsEntryView.swift (Fixed for iPad Detection)

import SwiftUI
import FirebaseAuth
import Combine

// MARK: - Post Game Stats Entry View

struct PostGameStatsView: View {
    let gameConfig: GameConfig
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var gameStats = GameStatsData()
    @State private var showingSubmitAlert = false
    @State private var isSubmitting = false
    @State private var error = ""
    
    // iPad detection
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        // FORCE: Full-screen container
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // STICKY HEADER: Always visible at top
                postGameStickyHeader()
                
                // SCROLLABLE CONTENT: Stats entry
                ScrollView {
                    VStack(spacing: isIPad ? 32 : 24) {
                        // Player status
                        PostGamePlayerStatusCard(isIPad: isIPad)
                        
                        // Detailed stats entry
                        postGameDetailedStatsEntry()
                        
                        // Achievements preview
                        AchievementsPreview(stats: gameStats)
                        
                        // Bottom padding for iPad
                        Spacer(minLength: isIPad ? 120 : 100)
                    }
                    .padding(.horizontal, isIPad ? 32 : 24) // MORE padding on iPad
                    .padding(.top, isIPad ? 24 : 20)
                }
            }
        }
        .navigationBarHidden(true) // FORCE: No system nav
        .alert("Save Game", isPresented: $showingSubmitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                submitGame()
            }
        } message: {
            Text("Save this game with the entered stats?")
        }
        .alert("Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
        .overlay {
            if isSubmitting {
                ProgressView("Saving game...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - ENHANCED STICKY HEADER for iPad
    
    @ViewBuilder
    private func postGameStickyHeader() -> some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Game info header (more prominent on iPad)
            PostGameInfoHeader(config: gameConfig, isIPad: isIPad)
            
            // Score entry (bigger on iPad)
            PostGameScoreCard(
                myTeamScore: $gameStats.myTeamScore,
                opponentScore: $gameStats.opponentScore,
                teamName: gameConfig.teamName,
                opponent: gameConfig.opponent,
                isIPad: isIPad
            )
            
            // Action buttons (more prominent on iPad)
            PostGameActionButtons(
                isSubmitting: isSubmitting,
                isValid: gameStats.isValid,
                isIPad: isIPad,
                onSave: {
                    showingSubmitAlert = true
                },
                onCancel: {
                    dismiss()
                }
            )
        }
        .padding(.horizontal, isIPad ? 32 : 24) // MORE padding on iPad
        .padding(.vertical, isIPad ? 24 : 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                .ignoresSafeArea(.container, edges: .horizontal) // EXTEND: To edges
        )
    }
    
    // MARK: - ENHANCED DETAILED STATS for iPad
    
    private func postGameDetailedStatsEntry() -> some View {
        VStack(spacing: isIPad ? 32 : 24) {
            HStack {
                Text("Sahil's Stats")
                    .font(isIPad ? .largeTitle : .title2) // BIGGER on iPad
                    .fontWeight(.bold)
                Spacer()
                Text("Tap +/- to adjust")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
            }
            
            // Shooting Stats (better iPad spacing)
            VStack(spacing: isIPad ? 28 : 20) {
                HStack {
                    Text("Shooting")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 3 : 2), spacing: isIPad ? 20 : 16) {
                    CleanStatCard(
                        title: "2PT Made",
                        value: $gameStats.playerStats.fg2m,
                        max: gameStats.playerStats.fg2a,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "2PT Att",
                        value: $gameStats.playerStats.fg2a,
                        min: gameStats.playerStats.fg2m,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "3PT Made",
                        value: $gameStats.playerStats.fg3m,
                        max: gameStats.playerStats.fg3a,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "3PT Att",
                        value: $gameStats.playerStats.fg3a,
                        min: gameStats.playerStats.fg3m,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "FT Made",
                        value: $gameStats.playerStats.ftm,
                        max: gameStats.playerStats.fta,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "FT Att",
                        value: $gameStats.playerStats.fta,
                        min: gameStats.playerStats.ftm,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                }
            }
            
            // Other Stats (better iPad layout)
            VStack(spacing: isIPad ? 28 : 20) {
                HStack {
                    Text("Other Stats")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 3 : 2), spacing: isIPad ? 20 : 16) {
                    CleanStatCard(
                        title: "Rebounds",
                        value: $gameStats.playerStats.rebounds,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "Assists",
                        value: $gameStats.playerStats.assists,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "Steals",
                        value: $gameStats.playerStats.steals,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "Blocks",
                        value: $gameStats.playerStats.blocks,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "Fouls",
                        value: $gameStats.playerStats.fouls,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                    CleanStatCard(
                        title: "Turnovers",
                        value: $gameStats.playerStats.turnovers,
                        isIPad: isIPad,
                        onStatChange: { }
                    )
                }
            }
            
            // Current stats display (enhanced for iPad)
            LiveStatsDisplayCard(stats: gameStats.playerStats, isIPad: isIPad, isReadOnly: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 32 : 24)
        .padding(.horizontal, isIPad ? 32 : 24)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 20 : 16)
        .shadow(color: .black.opacity(0.05), radius: isIPad ? 8 : 4, x: 0, y: 2)
    }
    
    private func submitGame() {
        isSubmitting = true
        
        Task {
            do {
                let game = Game(
                    teamName: gameConfig.teamName,
                    opponent: gameConfig.opponent,
                    location: gameConfig.location,
                    timestamp: gameConfig.date,
                    gameFormat: gameConfig.gameFormat,
                    periodLength: gameConfig.periodLength,
                    myTeamScore: gameStats.myTeamScore,
                    opponentScore: gameStats.opponentScore,
                    fg2m: gameStats.playerStats.fg2m,
                    fg2a: gameStats.playerStats.fg2a,
                    fg3m: gameStats.playerStats.fg3m,
                    fg3a: gameStats.playerStats.fg3a,
                    ftm: gameStats.playerStats.ftm,
                    fta: gameStats.playerStats.fta,
                    rebounds: gameStats.playerStats.rebounds,
                    assists: gameStats.playerStats.assists,
                    steals: gameStats.playerStats.steals,
                    blocks: gameStats.playerStats.blocks,
                    fouls: gameStats.playerStats.fouls,
                    turnovers: gameStats.playerStats.turnovers,
                    adminName: authService.currentUser?.email
                )
                
                try await firebaseService.addGame(game)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to save game: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

// MARK: - ENHANCED iPad Components

// Update PostGameInfoHeader for better iPad layout
struct PostGameInfoHeader: View {
    let config: GameConfig
    let isIPad: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: isIPad ? 8 : 4) {
                Text("Enter Game Stats")
                    .font(isIPad ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(config.teamName) vs \(config.opponent)")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: isIPad ? 6 : 4) {
                Text(config.date, style: .date)
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.secondary)
                
                if !config.location.isEmpty {
                    Text(config.location)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.vertical, isIPad ? 20 : 12)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}


// MARK: - Live Game Stats Entry View

struct LiveGameStatsView: View {
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
    
    // iPad detection
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
        ScrollView {
            VStack(spacing: isIPad ? 24 : 20) {
                // Game Status Header
                LiveGameHeader(
                    liveGame: liveGame,
                    isGameRunning: $isGameRunning,
                    currentPeriod: $currentPeriod,
                    currentClock: $currentClock,
                    sahilOnBench: $sahilOnBench,
                    isIPad: isIPad
                )
                
                // Live Score Entry
                LiveScoreSection(
                    homeScore: $currentHomeScore,
                    awayScore: $currentAwayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    isIPad: isIPad,
                    onScoreChange: scheduleUpdate
                )
                
                // Player Status
                PlayerStatusSection(
                    sahilOnBench: $sahilOnBench,
                    isIPad: isIPad,
                    onStatusChange: scheduleUpdate
                )
                
                // Live Stats Entry (only if Sahil is playing)
                if !sahilOnBench {
                    LivePlayerStatsSection(
                        stats: $currentStats,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                    
                    // Quick Action Buttons
                    LiveQuickActions(
                        stats: $currentStats,
                        isIPad: isIPad,
                        onStatChange: scheduleUpdate
                    )
                }
                
                // Game Controls
                LiveGameControls(
                    isGameRunning: $isGameRunning,
                    isIPad: isIPad,
                    onFinishGame: finishGame
                )
                
                // Update status indicator
                if hasUnsavedChanges {
                    UpdateStatusIndicator(isUpdating: isUpdating)
                }
            }
            .padding(isIPad ? 24 : 16)
        }
        .navigationTitle("Live Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
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

// MARK: - Supporting Data Models

struct GameStatsData {
    var myTeamScore = 0
    var opponentScore = 0
    var playerStats = PlayerStats()
    
    var isValid: Bool {
        return myTeamScore >= 0 && opponentScore >= 0
    }
}

// MARK: - UI Components (Updated with iPad Support)

struct GameInfoHeader: View {
    let config: GameConfig
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(config.teamName) vs \(config.opponent)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(config.date, style: .date)
                .foregroundColor(.secondary)
            
            if !config.location.isEmpty {
                Text("📍 \(config.location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ScoreEntrySection: View {
    @Binding var myTeamScore: Int
    @Binding var opponentScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Final Score")
                .font(isIPad ? .title2 : .headline)
            
            HStack(spacing: isIPad ? 40 : 30) {
                // My team score
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(teamName)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    ScoreInputField(score: $myTeamScore, isIPad: isIPad)
                        .foregroundColor(.blue)
                }
                
                Text("–")
                    .font(isIPad ? .largeTitle : .title)
                    .foregroundColor(.secondary)
                
                // Opponent score
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(opponent)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    ScoreInputField(score: $opponentScore, isIPad: isIPad)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct ScoreInputField: View {
    @Binding var score: Int
    let isIPad: Bool
    
    var body: some View {
        HStack {
            Button("-") {
                if score > 0 { score -= 1 }
            }
            .buttonStyle(ScoreButtonStyle(isIPad: isIPad))
            
            Text("\(score)")
                .font(isIPad ? .largeTitle : .title)
                .fontWeight(.bold)
                .frame(minWidth: isIPad ? 60 : 50)
            
            Button("+") {
                score += 1
            }
            .buttonStyle(ScoreButtonStyle(isIPad: isIPad))
        }
    }
}

struct PlayerStatsEntrySection: View {
    @Binding var stats: PlayerStats
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Sahil's Stats")
                .font(isIPad ? .title2 : .headline)
            
            // Shooting Stats
            StatCategorySection(title: "Shooting", isIPad: isIPad) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    StatInputRow(label: "2PT Made", value: $stats.fg2m, max: stats.fg2a, isIPad: isIPad)
                    StatInputRow(label: "2PT Att", value: $stats.fg2a, min: stats.fg2m, isIPad: isIPad)
                    StatInputRow(label: "3PT Made", value: $stats.fg3m, max: stats.fg3a, isIPad: isIPad)
                    StatInputRow(label: "3PT Att", value: $stats.fg3a, min: stats.fg3m, isIPad: isIPad)
                    StatInputRow(label: "FT Made", value: $stats.ftm, max: stats.fta, isIPad: isIPad)
                    StatInputRow(label: "FT Att", value: $stats.fta, min: stats.ftm, isIPad: isIPad)
                }
            }
            
            // Other Stats
            StatCategorySection(title: "Other Stats", isIPad: isIPad) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    StatInputRow(label: "Rebounds", value: $stats.rebounds, isIPad: isIPad)
                    StatInputRow(label: "Assists", value: $stats.assists, isIPad: isIPad)
                    StatInputRow(label: "Steals", value: $stats.steals, isIPad: isIPad)
                    StatInputRow(label: "Blocks", value: $stats.blocks, isIPad: isIPad)
                    StatInputRow(label: "Fouls", value: $stats.fouls, isIPad: isIPad)
                    StatInputRow(label: "Turnovers", value: $stats.turnovers, isIPad: isIPad)
                }
            }
            
            // Calculated Stats
            CalculatedStatsDisplay(stats: stats, isIPad: isIPad)
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct StatCategorySection<Content: View>: View {
    let title: String
    let isIPad: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
            Text(title)
                .font(isIPad ? .title3 : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            content
        }
    }
}

struct StatInputRow: View {
    let label: String
    @Binding var value: Int
    let min: Int
    let max: Int?
    let isIPad: Bool
    
    init(label: String, value: Binding<Int>, min: Int = 0, max: Int? = nil, isIPad: Bool) {
        self.label = label
        self._value = value
        self.min = min
        self.max = max
        self.isIPad = isIPad
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text(label)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: isIPad ? 12 : 8) {
                Button("-") {
                    if value > min {
                        value -= 1
                    }
                }
                .buttonStyle(StatButtonStyle(isIPad: isIPad))
                .disabled(value <= min)
                
                Text("\(value)")
                    .font(isIPad ? .title3 : .headline)
                    .fontWeight(.semibold)
                    .frame(minWidth: isIPad ? 35 : 30)
                
                Button("+") {
                    if let max = max, value >= max {
                        // Don't increment if at max
                    } else {
                        value += 1
                    }
                }
                .buttonStyle(StatButtonStyle(isIPad: isIPad))
                .disabled(max != nil && value >= max!)
            }
        }
        .padding(.vertical, isIPad ? 12 : 8)
        .padding(.horizontal, isIPad ? 16 : 12)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

struct CalculatedStatsDisplay: View {
    let stats: PlayerStats
    let isIPad: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            Text("Calculated Stats")
                .font(isIPad ? .title3 : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 12 : 8) {
                CalculatedStatCard(title: "Points", value: "\(stats.points)", isIPad: isIPad)
                CalculatedStatCard(title: "FG%", value: fieldGoalPercentage, isIPad: isIPad)
                CalculatedStatCard(title: "3P%", value: threePointPercentage, isIPad: isIPad)
                CalculatedStatCard(title: "FT%", value: freeThrowPercentage, isIPad: isIPad)
            }
        }
    }
    
    private var fieldGoalPercentage: String {
        let totalMade = stats.fg2m + stats.fg3m
        let totalAttempted = stats.fg2a + stats.fg3a
        if totalAttempted > 0 {
            return String(format: "%.1f%%", Double(totalMade) / Double(totalAttempted) * 100)
        }
        return "0%"
    }
    
    private var threePointPercentage: String {
        if stats.fg3a > 0 {
            return String(format: "%.1f%%", Double(stats.fg3m) / Double(stats.fg3a) * 100)
        }
        return "0%"
    }
    
    private var freeThrowPercentage: String {
        if stats.fta > 0 {
            return String(format: "%.1f%%", Double(stats.ftm) / Double(stats.fta) * 100)
        }
        return "0%"
    }
}

struct CalculatedStatCard: View {
    let title: String
    let value: String
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Text(value)
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Text(title)
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, isIPad ? 8 : 6)
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(isIPad ? 8 : 6)
    }
}




struct AchievementsPreview: View {
    let stats: GameStatsData
    
    private var previewGame: Game {
        Game(
            teamName: "Preview",
            opponent: "Preview",
            myTeamScore: stats.myTeamScore,
            opponentScore: stats.opponentScore,
            fg2m: stats.playerStats.fg2m,
            fg2a: stats.playerStats.fg2a,
            fg3m: stats.playerStats.fg3m,
            fg3a: stats.playerStats.fg3a,
            ftm: stats.playerStats.ftm,
            fta: stats.playerStats.fta,
            rebounds: stats.playerStats.rebounds,
            assists: stats.playerStats.assists,
            steals: stats.playerStats.steals,
            blocks: stats.playerStats.blocks,
            fouls: stats.playerStats.fouls,
            turnovers: stats.playerStats.turnovers
        )
    }
    
    var body: some View {
        let achievements = Achievement.getEarnedAchievements(for: previewGame)
        
        if !achievements.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Achievements Earned 🎉")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(achievements.prefix(4), id: \.id) { achievement in
                        HStack(spacing: 8) {
                            Text(achievement.emoji)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(achievement.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                if achievements.count > 4 {
                    Text("+ \(achievements.count - 4) more achievements!")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Live Game Components (Updated with iPad Support)

struct LiveGameHeader: View {
    let liveGame: LiveGame
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    @Binding var sahilOnBench: Bool
    let isIPad: Bool
    
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
        }
        .padding(isIPad ? 20 : 16)
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

struct LiveScoreSection: View {
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
            
            HStack(spacing: isIPad ? 40 : 30) {
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(teamName)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    LiveScoreControl(
                        score: $homeScore,
                        isIPad: isIPad,
                        onScoreChange: onScoreChange
                    )
                    .foregroundColor(.blue)
                }
                
                Text("–")
                    .font(isIPad ? .largeTitle : .title)
                    .foregroundColor(.secondary)
                
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(opponent)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    LiveScoreControl(
                        score: $awayScore,
                        isIPad: isIPad,
                        onScoreChange: onScoreChange
                    )
                    .foregroundColor(.red)
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveScoreControl: View {
    @Binding var score: Int
    let isIPad: Bool
    let onScoreChange: () -> Void
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            Button("-") {
                if score > 0 {
                    score -= 1
                    onScoreChange()
                }
            }
            .buttonStyle(LiveScoreButtonStyle(isIPad: isIPad))
            
            Text("\(score)")
                .font(isIPad ? .system(size: 36, weight: .bold) : .largeTitle)
                .fontWeight(.bold)
                .frame(minWidth: isIPad ? 70 : 60)
            
            Button("+") {
                score += 1
                onScoreChange()
            }
            .buttonStyle(LiveScoreButtonStyle(isIPad: isIPad))
        }
    }
}

struct PlayerStatusSection: View {
    @Binding var sahilOnBench: Bool
    let isIPad: Bool
    let onStatusChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            Text("Player Status")
                .font(isIPad ? .title2 : .headline)
            
            HStack {
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
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LivePlayerStatsSection: View {
    @Binding var stats: PlayerStats
    let isIPad: Bool
    let onStatChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text("Live Stats")
                .font(isIPad ? .title2 : .headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: isIPad ? 16 : 12) {
                LiveStatCard(title: "PTS", value: stats.points, color: .purple, isIPad: isIPad)
                LiveStatCard(title: "REB", value: stats.rebounds, color: .mint, isIPad: isIPad)
                LiveStatCard(title: "AST", value: stats.assists, color: .cyan, isIPad: isIPad)
                LiveStatCard(title: "STL", value: stats.steals, color: .yellow, isIPad: isIPad)
                LiveStatCard(title: "BLK", value: stats.blocks, color: .red, isIPad: isIPad)
                LiveStatCard(title: "TO", value: stats.turnovers, color: .pink, isIPad: isIPad)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveStatCard: View {
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

struct LiveQuickActions: View {
    @Binding var stats: PlayerStats
    let isIPad: Bool
    let onStatChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            Text("Quick Actions")
                .font(isIPad ? .title2 : .headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: isIPad ? 12 : 8) {
                LiveActionButton(title: "2PT", color: .blue, isIPad: isIPad) {
                    stats.fg2m += 1
                    stats.fg2a += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "3PT", color: .green, isIPad: isIPad) {
                    stats.fg3m += 1
                    stats.fg3a += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "FT", color: .orange, isIPad: isIPad) {
                    stats.ftm += 1
                    stats.fta += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "REB", color: .mint, isIPad: isIPad) {
                    stats.rebounds += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "AST", color: .cyan, isIPad: isIPad) {
                    stats.assists += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "STL", color: .yellow, isIPad: isIPad) {
                    stats.steals += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "BLK", color: .red, isIPad: isIPad) {
                    stats.blocks += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "TO", color: .pink, isIPad: isIPad) {
                    stats.turnovers += 1
                    onStatChange()
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveActionButton: View {
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

struct LiveGameControls: View {
    @Binding var isGameRunning: Bool
    let isIPad: Bool
    let onFinishGame: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            HStack(spacing: isIPad ? 20 : 16) {
                Button(isGameRunning ? "⏸️ Pause Game" : "▶️ Start Game") {
                    isGameRunning.toggle()
                }
                .buttonStyle(SecondaryButtonStyle(isIPad: isIPad))
                
                Button("🏁 Finish Game") {
                    onFinishGame()
                }
                .buttonStyle(DestructiveButtonStyle(isIPad: isIPad))
            }
            
            if !isGameRunning {
                Text("Game is paused")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct UpdateStatusIndicator: View {
    let isUpdating: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isUpdating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(0.8)
                Text("Saving...")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Changes saved")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
