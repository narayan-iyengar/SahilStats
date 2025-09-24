//
//  EnhancedGameDetailView.swift.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/24/25.
//

// File: SahilStats/Views/EnhancedGameDetailView.swift
// Complete Game Detail View with all stats using existing components

import SwiftUI
import FirebaseAuth

struct CompleteGameDetailView: View {
    @State var game: Game
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    
    // State for editing individual stats
    @State private var isEditingStat = false
    @State private var editingStatTitle = ""
    @State private var editingStatValue = ""
    @State private var statUpdateBinding: Binding<Int>?
    
    // State for editing score
    @State private var isEditingScore = false
    @State private var editingMyTeamScore = ""
    @State private var editingOpponentScore = ""
    
    // State for media features
    @State private var showingShareSheet = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: isIPad ? 32 : 24) {
                    // Header with game info
                    gameHeaderSection
                    
                    // Media/Share Section
                    mediaSection
                    
                    // Player Stats Section (comprehensive)
                    playerStatsSection
                    
                    // Playing Time Section (if available)
                    //if game.totalPlayingTimeMinutes > 0 || game.benchTimeMinutes > 0 {
                    playingTimeSection
                    //}
                    
                    // Shooting Percentages Section
                    shootingPercentagesSection
                    
                    // Advanced Analytics Section
                    advancedAnalyticsSection
                    
                    // Achievements Section
                    if !game.achievements.isEmpty {
                        achievementsSection
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(isIPad ? 24 : 16)
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingShareSheet = true }) {
                            Label("Share Game", systemImage: "square.and.arrow.up")
                        }
                        
                        if authService.canEditGames {
                            Button(action: { }) {
                                Label("Edit Game", systemImage: "pencil")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.orange)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle(isIPad: isIPad))
                }
            }
        }
        .alert("Edit \(editingStatTitle)", isPresented: $isEditingStat) {
            TextField("New Value", text: $editingStatValue)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveStatChange()
            }
        }
        .alert("Edit Final Score", isPresented: $isEditingScore) {
            TextField("My Team Score", text: $editingMyTeamScore)
                .keyboardType(.numberPad)
            TextField("Opponent Score", text: $editingOpponentScore)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveScoreChange()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareGameView(game: game)
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var gameHeaderSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
            // Game matchup and outcome
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(game.teamName) vs \(game.opponent)")
                        .font(isIPad ? .largeTitle : .title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(game.formattedDate)
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                    
                    if let location = game.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Outcome indicator
                if game.outcome == .win {
                    VStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(isIPad ? .largeTitle : .title)
                            .foregroundColor(.yellow)
                        Text("WIN")
                            .font(isIPad ? .body : .caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Score display with edit capability
            Button(action: {
                if authService.canEditGames {
                    editingMyTeamScore = "\(game.myTeamScore)"
                    editingOpponentScore = "\(game.opponentScore)"
                    isEditingScore = true
                }
            }) {
                HStack {
                    Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                        .font(isIPad ? .title : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(game.outcome == .win ? .green : (game.outcome == .loss ? .red : .orange))
                    
                    if authService.canEditGames {
                        Image(systemName: "pencil.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!authService.canEditGames)
        }
        .padding(isIPad ? 24 : 20)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 20 : 16)
    }
    
    // MARK: - Media Section
    
    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
            HStack {
                Text("Share & Media")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            HStack(spacing: isIPad ? 16 : 12) {
                Button(action: { showingShareSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(isIPad ? .body : .subheadline)
                        Text("Share Game")
                            .font(isIPad ? .body : .subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, isIPad ? 16 : 12)
                    .padding(.vertical, isIPad ? 12 : 8)
                    .background(Color.green)
                    .cornerRadius(isIPad ? 12 : 8)
                }
                
                Spacer()
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    // MARK: - Player Stats Section (Comprehensive)
    
    @ViewBuilder
    private var playerStatsSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Player Stats")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Main stats grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: isIPad ? 16 : 12) {
                // Scoring stats
                editableStatCard(for: "Points", value: $game.points, color: .purple)
                
                // Shooting stats
                editableStatCard(for: "2PT Made", value: $game.fg2m, color: .blue)
                editableStatCard(for: "2PT Att", value: $game.fg2a, color: .blue.opacity(0.7))
                editableStatCard(for: "3PT Made", value: $game.fg3m, color: .green)
                editableStatCard(for: "3PT Att", value: $game.fg3a, color: .green.opacity(0.7))
                editableStatCard(for: "FT Made", value: $game.ftm, color: .orange)
                editableStatCard(for: "FT Att", value: $game.fta, color: .orange.opacity(0.7))
                
                // Other stats
                editableStatCard(for: "Rebounds", value: $game.rebounds, color: .mint)
                editableStatCard(for: "Assists", value: $game.assists, color: .cyan)
                editableStatCard(for: "Steals", value: $game.steals, color: .yellow)
                editableStatCard(for: "Blocks", value: $game.blocks, color: .red)
                editableStatCard(for: "Fouls", value: $game.fouls, color: .pink)
                editableStatCard(for: "Turnovers", value: $game.turnovers, color: .pink.opacity(0.7))
                
                // Calculated stats (non-editable)
                DetailStatCard(title: "A/T Ratio", value: String(format: "%.2f", game.assistTurnoverRatio), color: .indigo)
            }
        }
    }
    
    // MARK: - Playing Time Section
    
    @ViewBuilder
    private var playingTimeSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Playing Time")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.teal)
            
            if game.totalPlayingTimeMinutes > 0 || game.benchTimeMinutes > 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                    GameDetailTimeCard(
                        title: "Minutes Played",
                        time: game.totalPlayingTimeMinutes,
                        color: .green,
                        isIPad: isIPad
                    )
                    GameDetailTimeCard(
                        title: "Bench Time",
                        time: game.benchTimeMinutes,
                        color: .orange,
                        isIPad: isIPad
                    )
                    DetailStatCard(
                        title: "Court Time %",
                        value: "\(Int(game.playingTimePercentage))%",
                        color: .teal
                    )
                    DetailStatCard(
                        title: "Points/Min",
                        value: String(format: "%.1f", calculatePointsPerMinute()),
                        color: .red
                    )
                }
                
                // Playing time percentage bar
                PlayingTimePercentageBar(
                    playingTime: game.totalPlayingTimeMinutes,
                    totalTime: game.totalPlayingTimeMinutes + game.benchTimeMinutes,
                    isIPad: isIPad
                )
            } else {
                Text("Playing time data not available for this game")
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(isIPad ? 12 : 8)
            }
        }
    }
    
    // MARK: - Shooting Percentages Section
    
    @ViewBuilder
    private var shootingPercentagesSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Shooting Percentages")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                ShootingPercentageCard(
                    title: "Field Goal",
                    percentage: String(format: "%.0f%%", game.fieldGoalPercentage * 100),
                    fraction: "\(game.fg2m + game.fg3m)/\(game.fg2a + game.fg3a)",
                    color: .blue
                )
                ShootingPercentageCard(
                    title: "Two Point",
                    percentage: String(format: "%.0f%%", game.twoPointPercentage * 100),
                    fraction: "\(game.fg2m)/\(game.fg2a)",
                    color: .blue
                )
                ShootingPercentageCard(
                    title: "Three Point",
                    percentage: String(format: "%.0f%%", game.threePointPercentage * 100),
                    fraction: "\(game.fg3m)/\(game.fg3a)",
                    color: .green
                )
                ShootingPercentageCard(
                    title: "Free Throw",
                    percentage: String(format: "%.0f%%", game.freeThrowPercentage * 100),
                    fraction: "\(game.ftm)/\(game.fta)",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Advanced Analytics Section
    
    @ViewBuilder
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Advanced Analytics")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 16 : 12) {
                DetailStatCard(
                    title: "Game Score",
                    value: String(format: "%.1f", calculateGameScore()),
                    color: .purple
                )
                DetailStatCard(
                    title: "Usage Rate",
                    value: String(format: "%.1f%%", calculateUsageRate()),
                    color: .indigo
                )
                DetailStatCard(
                    title: "Efficiency",
                    value: String(format: "%.1f", calculateEfficiency()),
                    color: .mint
                )
                DetailStatCard(
                    title: "Impact Score",
                    value: String(format: "%.1f", calculateImpactScore()),
                    color: .cyan
                )
            }
        }
    }
    
    // MARK: - Achievements Section
    
    @ViewBuilder
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Achievements Earned")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: isIPad ? 12 : 8) {
                ForEach(game.achievements.prefix(6), id: \.id) { achievement in
                    HStack(spacing: isIPad ? 12 : 8) {
                        Text(achievement.emoji)
                            .font(isIPad ? .title2 : .title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.name)
                                .font(isIPad ? .body : .caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(achievement.description)
                                .font(isIPad ? .caption : .caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(isIPad ? 12 : 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(isIPad ? 12 : 8)
                }
            }
            
            if game.achievements.count > 6 {
                Text("+ \(game.achievements.count - 6) more achievements")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func editableStatCard(for title: String, value: Binding<Int>, color: Color) -> some View {
        DetailStatCard(title: title, value: "\(value.wrappedValue)", color: color)
            .onLongPressGesture {
                if authService.canEditGames {
                    editingStatTitle = title
                    editingStatValue = "\(value.wrappedValue)"
                    statUpdateBinding = value
                    isEditingStat = true
                }
            }
    }
    
    private func calculatePointsPerMinute() -> Double {
        guard game.totalPlayingTimeMinutes > 0 else { return 0.0 }
        return Double(game.points) / game.totalPlayingTimeMinutes
    }
    
    private func calculateGameScore() -> Double {
        // Simplified game score calculation
        let positiveActions = Double(game.points + game.rebounds + game.assists + game.steals + game.blocks)
        let negativeActions = Double(game.turnovers + game.fouls)
        let missedShots = Double((game.fg2a + game.fg3a) - (game.fg2m + game.fg3m))
        let missedFTs = Double(game.fta - game.ftm)
        
        return positiveActions - (negativeActions + missedShots * 0.5 + missedFTs * 0.5)
    }
    
    private func calculateUsageRate() -> Double {
        // Simplified usage rate - in a real app, you'd need team totals
        let fieldGoalAttempts = Double(game.fg2a + game.fg3a)
        let turnovers = Double(game.turnovers)
        let freeThrowFactor = Double(game.fta) * 0.44
        let possessions = fieldGoalAttempts + turnovers + freeThrowFactor
        return possessions > 0 ? (possessions / 100.0) * 100 : 0
    }
    
    private func calculateEfficiency() -> Double {
        let totalShots = game.fg2a + game.fg3a + game.fta
        return totalShots > 0 ? Double(game.points) / Double(totalShots) : 0
    }
    
    private func calculateImpactScore() -> Double {
        // Custom impact score combining various stats
        let offense = Double(game.points + game.assists * 2)
        let defense = Double(game.steals * 2 + game.blocks * 2 + game.rebounds)
        let negatives = Double(game.turnovers * 2 + game.fouls)
        
        return offense + defense - negatives
    }
    
    private func saveStatChange() {
        guard let newValue = Int(editingStatValue), let binding = statUpdateBinding else { return }
        
        binding.wrappedValue = newValue
        
        // Recalculate points if a shooting stat changed
        if ["2PT Made", "3PT Made", "FT Made"].contains(editingStatTitle) {
            game.points = (game.fg2m * 2) + (game.fg3m * 3) + game.ftm
        }
        
        // Update achievements
        game.achievements = Achievement.getEarnedAchievements(for: game)
        
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                print("Failed to save game changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveScoreChange() {
        guard let myScore = Int(editingMyTeamScore),
              let opponentScore = Int(editingOpponentScore) else { return }
        
        game.myTeamScore = myScore
        game.opponentScore = opponentScore
        
        // Recalculate outcome
        if myScore > opponentScore {
            game.outcome = .win
        } else if myScore < opponentScore {
            game.outcome = .loss
        } else {
            game.outcome = .tie
        }
        
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                print("Failed to save score change: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Share Game View

struct ShareGameView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Game Stats")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Game summary for sharing
                VStack(alignment: .leading, spacing: 12) {
                    Text("🏀 \(game.teamName) vs \(game.opponent)")
                        .font(.headline)
                    
                    Text("Final: \(game.myTeamScore) - \(game.opponentScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(game.outcome == .win ? .green : .red)
                    
                    Text("Sahil's Stats:")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        Text("📊 \(game.points) PTS • \(game.rebounds) REB • \(game.assists) AST")
                        Spacer()
                    }
                    
                    HStack {
                        Text("🎯 FG: \(String(format: "%.0f%%", game.fieldGoalPercentage * 100))")
                        if game.fg3a > 0 {
                            Text("• 3P: \(String(format: "%.0f%%", game.threePointPercentage * 100))")
                        }
                        Spacer()
                    }
                    
                    if !game.achievements.isEmpty {
                        HStack {
                            Text("🏆 ")
                            Text(game.achievements.map { $0.emoji }.joined(separator: " "))
                            Spacer()
                        }
                    }
                    
                    Text("#SahilStats #Basketball")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button("Share") {
                    shareGame()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: false))
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareGame() {
        let text = """
        🏀 \(game.teamName) vs \(game.opponent)
        Final: \(game.myTeamScore) - \(game.opponentScore)
        
        Sahil's Stats:
        📊 \(game.points) PTS • \(game.rebounds) REB • \(game.assists) AST
        🎯 FG: \(String(format: "%.0f%%", game.fieldGoalPercentage * 100))\(game.fg3a > 0 ? " • 3P: \(String(format: "%.0f%%", game.threePointPercentage * 100))" : "")
        
        #SahilStats #Basketball
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}


