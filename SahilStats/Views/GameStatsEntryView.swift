//
//  GameStatsEntryView.swift
//  SahilStats
//
//  Enhanced stat entry system for post-game and live game scenarios
//

import SwiftUI
import FirebaseAuth
import Combine

// MARK: - Post Game Stats Entry View

struct PostGameStatsView: View {
    let gameConfig: GameConfig
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var gameStats = GameStatsData()
    @State private var showingSubmitAlert = false
    @State private var isSubmitting = false
    @State private var error = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Game Info Header
                GameInfoHeader(config: gameConfig)
                
                // Score Entry
                ScoreEntrySection(
                    myTeamScore: $gameStats.myTeamScore,
                    opponentScore: $gameStats.opponentScore,
                    teamName: gameConfig.teamName,
                    opponent: gameConfig.opponent
                )
                
                // Stats Entry
                PlayerStatsEntrySection(stats: $gameStats.playerStats)
                
                // Quick Actions
                QuickStatsButtons(stats: $gameStats.playerStats)
                
                // Achievements Preview
                AchievementsPreview(stats: gameStats)
                
                // Submit Button
                VStack(spacing: 12) {
                    Button("Save Game") {
                        showingSubmitAlert = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting || !gameStats.isValid)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Enter Stats")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func submitGame() {
        isSubmitting = true
        
        Task {
            do {
                // Create game with all stats (outcome is calculated automatically)
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

// MARK: - Live Game Stats Entry View

struct LiveGameStatsView: View {
    let liveGame: LiveGame
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
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
            VStack(spacing: 20) {
                // Game Status Header
                LiveGameHeader(
                    liveGame: liveGame,
                    isGameRunning: $isGameRunning,
                    currentPeriod: $currentPeriod,
                    currentClock: $currentClock,
                    sahilOnBench: $sahilOnBench
                )
                
                // Live Score Entry
                LiveScoreSection(
                    homeScore: $currentHomeScore,
                    awayScore: $currentAwayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    onScoreChange: scheduleUpdate
                )
                
                // Player Status
                PlayerStatusSection(
                    sahilOnBench: $sahilOnBench,
                    onStatusChange: scheduleUpdate
                )
                
                // Live Stats Entry (only if Sahil is playing)
                if !sahilOnBench {
                    LivePlayerStatsSection(
                        stats: $currentStats,
                        onStatChange: scheduleUpdate
                    )
                    
                    // Quick Action Buttons
                    LiveQuickActions(
                        stats: $currentStats,
                        onStatChange: scheduleUpdate
                    )
                }
                
                // Game Controls
                LiveGameControls(
                    isGameRunning: $isGameRunning,
                    onFinishGame: finishGame
                )
                
                // Update status indicator
                if hasUnsavedChanges {
                    UpdateStatusIndicator(isUpdating: isUpdating)
                }
            }
            .padding()
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

// MARK: - UI Components

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
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Final Score")
                .font(.headline)
            
            HStack(spacing: 30) {
                // My team score
                VStack(spacing: 8) {
                    Text(teamName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScoreInputField(score: $myTeamScore)
                        .foregroundColor(.blue)
                }
                
                Text("–")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                // Opponent score
                VStack(spacing: 8) {
                    Text(opponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScoreInputField(score: $opponentScore)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ScoreInputField: View {
    @Binding var score: Int
    
    var body: some View {
        HStack {
            Button("-") {
                if score > 0 { score -= 1 }
            }
            .buttonStyle(ScoreButtonStyle())
            
            Text("\(score)")
                .font(.title)
                .fontWeight(.bold)
                .frame(minWidth: 50)
            
            Button("+") {
                score += 1
            }
            .buttonStyle(ScoreButtonStyle())
        }
    }
}

struct PlayerStatsEntrySection: View {
    @Binding var stats: PlayerStats
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Sahil's Stats")
                .font(.headline)
            
            // Shooting Stats
            StatCategorySection(title: "Shooting") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    StatInputRow(label: "2PT Made", value: $stats.fg2m, max: stats.fg2a)
                    StatInputRow(label: "2PT Att", value: $stats.fg2a, min: stats.fg2m)
                    StatInputRow(label: "3PT Made", value: $stats.fg3m, max: stats.fg3a)
                    StatInputRow(label: "3PT Att", value: $stats.fg3a, min: stats.fg3m)
                    StatInputRow(label: "FT Made", value: $stats.ftm, max: stats.fta)
                    StatInputRow(label: "FT Att", value: $stats.fta, min: stats.ftm)
                }
            }
            
            // Other Stats
            StatCategorySection(title: "Other Stats") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    StatInputRow(label: "Rebounds", value: $stats.rebounds)
                    StatInputRow(label: "Assists", value: $stats.assists)
                    StatInputRow(label: "Steals", value: $stats.steals)
                    StatInputRow(label: "Blocks", value: $stats.blocks)
                    StatInputRow(label: "Fouls", value: $stats.fouls)
                    StatInputRow(label: "Turnovers", value: $stats.turnovers)
                }
            }
            
            // Calculated Stats
            CalculatedStatsDisplay(stats: stats)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatCategorySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
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
    
    init(label: String, value: Binding<Int>, min: Int = 0, max: Int? = nil) {
        self.label = label
        self._value = value
        self.min = min
        self.max = max
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Button("-") {
                    if value > min {
                        value -= 1
                    }
                }
                .buttonStyle(StatButtonStyle())
                .disabled(value <= min)
                
                Text("\(value)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(minWidth: 30)
                
                Button("+") {
                    if let max = max, value >= max {
                        // Don't increment if at max
                    } else {
                        value += 1
                    }
                }
                .buttonStyle(StatButtonStyle())
                .disabled(max != nil && value >= max!)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct CalculatedStatsDisplay: View {
    let stats: PlayerStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculated Stats")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                CalculatedStatCard(title: "Points", value: "\(stats.points)")
                CalculatedStatCard(title: "FG%", value: fieldGoalPercentage)
                CalculatedStatCard(title: "3P%", value: threePointPercentage)
                CalculatedStatCard(title: "FT%", value: freeThrowPercentage)
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
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(6)
    }
}

struct QuickStatsButtons: View {
    @Binding var stats: PlayerStats
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                QuickActionButton(title: "2PT Made", color: .blue) {
                    stats.fg2m += 1
                    stats.fg2a += 1
                }
                
                QuickActionButton(title: "3PT Made", color: .green) {
                    stats.fg3m += 1
                    stats.fg3a += 1
                }
                
                QuickActionButton(title: "FT Made", color: .orange) {
                    stats.ftm += 1
                    stats.fta += 1
                }
                
                QuickActionButton(title: "Rebound", color: .mint) {
                    stats.rebounds += 1
                }
                
                QuickActionButton(title: "Assist", color: .cyan) {
                    stats.assists += 1
                }
                
                QuickActionButton(title: "Steal", color: .yellow) {
                    stats.steals += 1
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(8)
        }
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

// MARK: - Live Game Components

struct LiveGameHeader: View {
    let liveGame: LiveGame
    @Binding var isGameRunning: Bool
    @Binding var currentPeriod: Int
    @Binding var currentClock: TimeInterval
    @Binding var sahilOnBench: Bool
    
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

struct LiveScoreSection: View {
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    let teamName: String
    let opponent: String
    let onScoreChange: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Live Score")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text(teamName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LiveScoreControl(
                        score: $homeScore,
                        onScoreChange: onScoreChange
                    )
                    .foregroundColor(.blue)
                }
                
                Text("–")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text(opponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LiveScoreControl(
                        score: $awayScore,
                        onScoreChange: onScoreChange
                    )
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LiveScoreControl: View {
    @Binding var score: Int
    let onScoreChange: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button("-") {
                if score > 0 {
                    score -= 1
                    onScoreChange()
                }
            }
            .buttonStyle(ScoreButtonStyle())
            
            Text("\(score)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(minWidth: 60)
            
            Button("+") {
                score += 1
                onScoreChange()
            }
            .buttonStyle(ScoreButtonStyle())
        }
    }
}

struct PlayerStatusSection: View {
    @Binding var sahilOnBench: Bool
    let onStatusChange: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Player Status")
                .font(.headline)
            
            HStack {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LivePlayerStatsSection: View {
    @Binding var stats: PlayerStats
    let onStatChange: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Live Stats")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                LiveStatCard(title: "PTS", value: stats.points, color: .purple)
                LiveStatCard(title: "REB", value: stats.rebounds, color: .mint)
                LiveStatCard(title: "AST", value: stats.assists, color: .cyan)
                LiveStatCard(title: "STL", value: stats.steals, color: .yellow)
                LiveStatCard(title: "BLK", value: stats.blocks, color: .red)
                LiveStatCard(title: "TO", value: stats.turnovers, color: .pink)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LiveStatCard: View {
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

struct LiveQuickActions: View {
    @Binding var stats: PlayerStats
    let onStatChange: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                LiveActionButton(title: "2PT", color: .blue) {
                    stats.fg2m += 1
                    stats.fg2a += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "3PT", color: .green) {
                    stats.fg3m += 1
                    stats.fg3a += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "FT", color: .orange) {
                    stats.ftm += 1
                    stats.fta += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "REB", color: .mint) {
                    stats.rebounds += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "AST", color: .cyan) {
                    stats.assists += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "STL", color: .yellow) {
                    stats.steals += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "BLK", color: .red) {
                    stats.blocks += 1
                    onStatChange()
                }
                
                LiveActionButton(title: "TO", color: .pink) {
                    stats.turnovers += 1
                    onStatChange()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LiveActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
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
}

struct LiveGameControls: View {
    @Binding var isGameRunning: Bool
    let onFinishGame: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(isGameRunning ? "⏸️ Pause Game" : "▶️ Start Game") {
                    isGameRunning.toggle()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("🏁 Finish Game") {
                    onFinishGame()
                }
                .buttonStyle(DestructiveButtonStyle())
            }
            
            if !isGameRunning {
                Text("Game is paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ScoreButtonStyle: ButtonStyle {
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

struct StatButtonStyle: ButtonStyle {
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
