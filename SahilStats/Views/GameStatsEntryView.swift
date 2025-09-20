// File: SahilStats/Views/GameStatsEntryView.swift (Full Screen & No Player Status)

import SwiftUI
import FirebaseAuth
import Combine

// MARK: - Post Game Stats Entry View (Full Screen)

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
        // FULL SCREEN: VStack with sticky header instead of scrollview navigation
        VStack(spacing: 0) {
            // STICKY HEADER: Always visible at top
            postGameStickyHeader()
            
            // SCROLLABLE CONTENT: Stats entry
            ScrollView {
                VStack(spacing: isIPad ? 32 : 24) {
                    // REMOVED: Player status card (as requested)
                    
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
        .navigationBarHidden(true) // FORCE: No system nav for full screen
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

struct PostGameScoreCard: View {
    @Binding var myTeamScore: Int
    @Binding var opponentScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(isIPad ? .title2 : .title3)
                    .foregroundColor(.orange)
                
                Text("Final Score")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: isIPad ? 40 : 30) {
                // My team score
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(teamName)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    PostGameScoreControl(score: $myTeamScore, isIPad: isIPad)
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
                        .lineLimit(1)
                    
                    PostGameScoreControl(score: $opponentScore, isIPad: isIPad)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}


struct PostGameScoreControl: View {
    @Binding var score: Int
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            Button("-") {
                if score > 0 { score -= 1 }
            }
            .buttonStyle(PostGameScoreButtonStyle(isIPad: isIPad))
            
            Text("\(score)")
                .font(isIPad ? .system(size: 32, weight: .bold) : .largeTitle)
                .fontWeight(.bold)
                .frame(minWidth: isIPad ? 60 : 50)
            
            Button("+") {
                score += 1
            }
            .buttonStyle(PostGameScoreButtonStyle(isIPad: isIPad))
        }
    }
}

struct PostGameActionButtons: View {
    let isSubmitting: Bool
    let isValid: Bool
    let isIPad: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: isIPad ? 20 : 16) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(PostGameSecondaryButtonStyle(isIPad: isIPad))
            
            Button("Save Game") {
                onSave()
            }
            .buttonStyle(PostGamePrimaryButtonStyle(isIPad: isIPad))
            .disabled(!isValid || isSubmitting)
        }
    }
}
// MARK: - ENHANCED iPad Components (keeping the existing ones from your file)

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

// MARK: - Supporting Data Models

struct GameStatsData {
    var myTeamScore = 0
    var opponentScore = 0
    var playerStats = PlayerStats()
    
    var isValid: Bool {
        return myTeamScore >= 0 && opponentScore >= 0
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
