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
    
    // Scroll tracking state
    @State private var scrollOffset: CGFloat = 0
    @State private var isHeaderCollapsed = false
    
    // iPad detection
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    // Header collapse threshold
    private var collapseThreshold: CGFloat {
        isIPad ? 100 : 80
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content with scroll tracking
            ScrollViewWithOffset(
                axes: .vertical,
                showsIndicators: true,
                onOffsetChange: { offset in
                    let newOffset = -offset
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollOffset = newOffset
                        isHeaderCollapsed = newOffset > collapseThreshold
                    }
                }
            ) {
                VStack(spacing: 0) {
                    // Spacer to account for sticky header height
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: isHeaderCollapsed ? compactHeaderHeight : expandedHeaderHeight)
                    
                    // Main stats content
                    VStack(spacing: isIPad ? 40 : 24) {
                        postGameDetailedStatsEntry()
                        AchievementsPreview(stats: gameStats)
                        Spacer(minLength: isIPad ? 150 : 100)
                    }
                    .padding(.horizontal, isIPad ? 40 : 24)
                    .padding(.top, isIPad ? 32 : 20)
                }
            }
            
            // Sticky header that collapses/expands
            VStack(spacing: 0) {
                CollapsingPostGameHeader(
                    gameConfig: gameConfig,
                    gameStats: $gameStats,
                    isCollapsed: isHeaderCollapsed,
                    isSubmitting: isSubmitting,
                    isValid: gameStats.isValid,
                    isIPad: isIPad,
                    onSave: { showingSubmitAlert = true },
                    onCancel: { dismiss() }
                )
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert("Save Game", isPresented: $showingSubmitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save") { submitGame() }
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
    
    // Header height calculations
    private var expandedHeaderHeight: CGFloat {
        isIPad ? 320 : 280
    }
    
    private var compactHeaderHeight: CGFloat {
        isIPad ? 140 : 120
    }
    
    // Keep your existing submitGame() method
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
    
    // Keep your existing postGameDetailedStatsEntry() method unchanged
    private func postGameDetailedStatsEntry() -> some View {
        // Your existing implementation
        VStack(spacing: isIPad ? 40 : 24) {
            HStack {
                Text("Sahil's Stats")
                    .font(isIPad ? .system(size: 32, weight: .bold) : .title2)
                    .fontWeight(.bold)
            }
            
            // Your existing shooting and other stats sections
            // ... (keep all your existing stat card implementations)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 40 : 24)
        .padding(.horizontal, isIPad ? 40 : 24)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 24 : 16)
        .shadow(color: .black.opacity(0.05), radius: isIPad ? 12 : 4, x: 0, y: 2)
    }
}

// MARK: - Compact Action Buttons

struct CompactActionButtons: View {
    let isSubmitting: Bool
    let isValid: Bool
    let isIPad: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(CompactSecondaryButtonStyle(isIPad: isIPad))
            
            Button("Save") {
                onSave()
            }
            .buttonStyle(CompactPrimaryButtonStyle(isIPad: isIPad))
            .disabled(!isValid || isSubmitting)
        }
    }
}

// MARK: - Button Styles for Collapsible Header



struct CompactPrimaryButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, isIPad ? 24 : 20)
            .padding(.vertical, isIPad ? 12 : 10)
            .background(Color.orange)
            .cornerRadius(isIPad ? 12 : 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CompactSecondaryButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .subheadline)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, isIPad ? 24 : 20)
            .padding(.vertical, isIPad ? 12 : 10)
            .background(Color(.systemGray5))
            .cornerRadius(isIPad ? 12 : 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}




struct CollapsingPostGameHeader: View {
    let gameConfig: GameConfig
    @Binding var gameStats: GameStatsData
    let isCollapsed: Bool
    let isSubmitting: Bool
    let isValid: Bool
    let isIPad: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 24 : 16)) {
            if !isCollapsed {
                // Expanded: Show game info
                PostGameInfoHeader(config: gameConfig, isIPad: isIPad)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
            
            // Always show score (but make it more compact when collapsed)
            CollapsibleScoreCard(
                myTeamScore: $gameStats.myTeamScore,
                opponentScore: $gameStats.opponentScore,
                teamName: gameConfig.teamName,
                opponent: gameConfig.opponent,
                isCollapsed: isCollapsed,
                isIPad: isIPad
            )
            
            if !isCollapsed {
                // Expanded: Show action buttons
                PostGameActionButtons(
                    isSubmitting: isSubmitting,
                    isValid: isValid,
                    isIPad: isIPad,
                    onSave: onSave,
                    onCancel: onCancel
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            } else {
                // Collapsed: Show compact action buttons
                CompactActionButtons(
                    isSubmitting: isSubmitting,
                    isValid: isValid,
                    isIPad: isIPad,
                    onSave: onSave,
                    onCancel: onCancel
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }
        }
        .padding(.horizontal, isIPad ? 40 : 24)
        .padding(.vertical, isCollapsed ? (isIPad ? 16 : 12) : (isIPad ? 32 : 16))
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                .ignoresSafeArea(.container, edges: .horizontal)
        )
        .animation(.easeInOut(duration: 0.3), value: isCollapsed)
    }
}

// MARK: - Collapsible Score Card

struct CollapsibleScoreCard: View {
    @Binding var myTeamScore: Int
    @Binding var opponentScore: Int
    let teamName: String
    let opponent: String
    let isCollapsed: Bool
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 24 : 16)) {
            if !isCollapsed {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(isIPad ? .system(size: 24) : .title3)
                        .foregroundColor(.orange)
                    
                    Text("Final Score")
                        .font(isIPad ? .system(size: 24, weight: .semibold) : .headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            HStack(spacing: isCollapsed ? (isIPad ? 30 : 20) : (isIPad ? 50 : 30)) {
                // My team score
                VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 8)) {
                    if !isCollapsed {
                        Text(teamName)
                            .font(isIPad ? .system(size: 16, weight: .medium) : .caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                    
                    CollapsibleScoreControl(
                        score: $myTeamScore,
                        isCollapsed: isCollapsed,
                        isIPad: isIPad
                    )
                    .foregroundColor(.blue)
                }
                
                Text("–")
                    .font(isCollapsed ?
                          (isIPad ? .system(size: 24, weight: .medium) : .title2) :
                          (isIPad ? .system(size: 36, weight: .medium) : .title)
                    )
                    .foregroundColor(.secondary)
                
                // Opponent score
                VStack(spacing: isCollapsed ? (isIPad ? 8 : 6) : (isIPad ? 16 : 8)) {
                    if !isCollapsed {
                        Text(opponent)
                            .font(isIPad ? .system(size: 16, weight: .medium) : .caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                    
                    CollapsibleScoreControl(
                        score: $opponentScore,
                        isCollapsed: isCollapsed,
                        isIPad: isIPad
                    )
                    .foregroundColor(.red)
                }
            }
        }
        .padding(isCollapsed ? (isIPad ? 16 : 12) : (isIPad ? 28 : 16))
        .background(Color(.systemGray6))
        .cornerRadius(isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 12))
        .animation(.easeInOut(duration: 0.3), value: isCollapsed)
    }
}

// MARK: - Collapsible Score Control

struct CollapsibleScoreControl: View {
    @Binding var score: Int
    let isCollapsed: Bool
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isCollapsed ? (isIPad ? 12 : 8) : (isIPad ? 20 : 12)) {
            Button("-") {
                if score > 0 { score -= 1 }
            }
            .buttonStyle(CollapsibleScoreButtonStyle(isCollapsed: isCollapsed, isIPad: isIPad))
            
            Text("\(score)")
                .font(isCollapsed ?
                      (isIPad ? .system(size: 28, weight: .bold) : .title2) :
                      (isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                )
                .fontWeight(.bold)
                .frame(minWidth: isCollapsed ? (isIPad ? 50 : 40) : (isIPad ? 70 : 50))
                .animation(.easeInOut(duration: 0.3), value: isCollapsed)
            
            Button("+") {
                score += 1
            }
            .buttonStyle(CollapsibleScoreButtonStyle(isCollapsed: isCollapsed, isIPad: isIPad))
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
        VStack(spacing: isIPad ? 24 : 16) { // MORE spacing on iPad
            HStack {
                Image(systemName: "trophy.fill")
                    .font(isIPad ? .system(size: 24) : .title3) // BIGGER on iPad
                    .foregroundColor(.orange)
                
                Text("Final Score")
                    .font(isIPad ? .system(size: 24, weight: .semibold) : .headline) // BIGGER on iPad
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: isIPad ? 50 : 30) { // MORE spacing on iPad
                // My team score
                VStack(spacing: isIPad ? 16 : 8) { // MORE spacing on iPad
                    Text(teamName)
                        .font(isIPad ? .system(size: 16, weight: .medium) : .caption) // BIGGER on iPad
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    PostGameScoreControl(score: $myTeamScore, isIPad: isIPad)
                        .foregroundColor(.blue)
                }
                
                Text("–")
                    .font(isIPad ? .system(size: 36, weight: .medium) : .title) // BIGGER on iPad
                    .foregroundColor(.secondary)
                
                // Opponent score
                VStack(spacing: isIPad ? 16 : 8) { // MORE spacing on iPad
                    Text(opponent)
                        .font(isIPad ? .system(size: 16, weight: .medium) : .caption) // BIGGER on iPad
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    PostGameScoreControl(score: $opponentScore, isIPad: isIPad)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(isIPad ? 28 : 16) // MORE padding on iPad
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 20 : 12) // BIGGER corner radius on iPad
    }
}



struct PostGameScoreControl: View {
    @Binding var score: Int
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 20 : 12) { // MORE spacing on iPad
            Button("-") {
                if score > 0 { score -= 1 }
            }
            .buttonStyle(PostGameScoreButtonStyle(isIPad: isIPad))
            
            Text("\(score)")
                .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle) // BIGGER on iPad
                .fontWeight(.bold)
                .frame(minWidth: isIPad ? 70 : 50) // BIGGER frame on iPad
            
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
        HStack(spacing: isIPad ? 24 : 16) { // MORE spacing on iPad
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
            VStack(alignment: .leading, spacing: isIPad ? 12 : 4) { // MORE spacing on iPad
                Text("Enter Game Stats")
                    .font(isIPad ? .system(size: 32, weight: .bold) : .title2) // BIGGER on iPad
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(config.teamName) vs \(config.opponent)")
                    .font(isIPad ? .system(size: 20, weight: .medium) : .body) // BIGGER on iPad
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: isIPad ? 8 : 4) { // MORE spacing on iPad
                Text(config.date, style: .date)
                    .font(isIPad ? .system(size: 18, weight: .medium) : .body) // BIGGER on iPad
                    .foregroundColor(.secondary)
                
                if !config.location.isEmpty {
                    Text(config.location)
                        .font(isIPad ? .system(size: 16, weight: .regular) : .caption) // BIGGER on iPad
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, isIPad ? 28 : 16) // MORE padding on iPad
        .padding(.vertical, isIPad ? 24 : 12) // MORE padding on iPad
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 20 : 12) // BIGGER corner radius on iPad
    }
}

// MARK: - Supporting Data Models

struct GameStatsData {
    var myTeamScore = 0
    var opponentScore = 0
    var playerStats = PlayerStats()
    
    // Calculated points based on shooting stats
    var calculatedPoints: Int {
        return (playerStats.fg2m * 2) + (playerStats.fg3m * 3) + playerStats.ftm
    }
    
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
