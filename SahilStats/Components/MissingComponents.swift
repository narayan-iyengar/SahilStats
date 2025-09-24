// File: SahilStats/Views/Components/MissingComponents.swift
// Temporary scaffolding for missing components

// File: SahilStats/Views/Components/MissingComponents.swift
// Temporary scaffolding for missing components

import SwiftUI
import Charts
import Combine
import Foundation

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}



/*
// MARK: - Live Game Indicator View
struct LiveGameIndicatorView: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Game in Progress")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("Tap to view")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.red)
            }
            //.padding()
            //.background(Color.red.opacity(0.1))
            //.cornerRadius(12)
            //.contentShape(Rectangle()) // ⭐ THIS IS THE KEY FIX
        }
        .buttonStyle(.plain)
    }
}
 */

// MARK: - Game Filters Sheet
struct GameFiltersSheet: View {
    @ObservedObject var filterManager: GameFilterManager
    let availableTeams: [String]
    let availableOpponents: [String]
    let isIPad: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Filters")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Search
                TextField("Search games...", text: $filterManager.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Team filter
                Picker("Team", selection: $filterManager.selectedTeamFilter) {
                    ForEach(availableTeams, id: \.self) { team in
                        Text(team).tag(team)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                // Opponent filter
                Picker("Opponent", selection: $filterManager.selectedOpponentFilter) {
                    ForEach(availableOpponents, id: \.self) { opponent in
                        Text(opponent).tag(opponent)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                Button("Clear All Filters") {
                    filterManager.clearAllFilters()
                }
                .foregroundColor(.orange)
            }
            .padding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle(isIPad: isIPad))
                }
            }
        }
    }
}




// MARK: - Enhanced Game Detail View with Playing Time
//OLD
/*
struct GameDetailView: View {
    @State var game: Game
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    
    // State for editing individual stats
    @State private var isEditingStat = false
    @State private var editingStatTitle = ""
    @State private var editingStatValue = ""
    @State private var statUpdateBinding: Binding<Int>?
    
    // State for editing score
    @State private var isEditingScore = false
    @State private var editingMyTeamScore = ""
    @State private var editingOpponentScore = ""
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerView
                    
                    // Player Stats Section (now includes playing time if available)
                    playerStatsSection
                    
                    // Shooting Percentages Section
                    shootingPercentagesSection
                }
                .padding()
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
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
        }
    }
    
    // MARK: - Child Views for GameDetailView
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.teamName) vs \(game.opponent)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                if game.outcome == .win {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.title)
                }
            }
            
            Button(action: {
                editingMyTeamScore = "\(game.myTeamScore)"
                editingOpponentScore = "\(game.opponentScore)"
                isEditingScore = true
            }) {
                HStack {
                    Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                        .font(.title2)
                        .foregroundColor(game.outcome.color == "green" ? .green : .red)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            HStack {
                Text(game.formattedDate)
                if let location = game.location, !location.isEmpty {
                    Text("• \(location)")
                }
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var playerStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Player Stats")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                statCard(for: "Points", value: $game.points, color: .purple)
                statCard(for: "2PT Made", value: $game.fg2m, color: .blue)
                statCard(for: "2PT Att", value: $game.fg2a, color: .blue.opacity(0.7))
                
                statCard(for: "3PT Made", value: $game.fg3m, color: .green)
                statCard(for: "3PT Att", value: $game.fg3a, color: .green.opacity(0.7))
                statCard(for: "FT Made", value: $game.ftm, color: .orange)
                
                statCard(for: "FT Att", value: $game.fta, color: .orange.opacity(0.7))
                statCard(for: "Rebounds", value: $game.rebounds, color: .mint)
                statCard(for: "Assists", value: $game.assists, color: .cyan)
                
                statCard(for: "Steals", value: $game.steals, color: .yellow)
                statCard(for: "Blocks", value: $game.blocks, color: .red)
                statCard(for: "Fouls", value: $game.fouls, color: .pink)
                
                statCard(for: "Turnovers", value: $game.turnovers, color: .pink.opacity(0.7))
                DetailStatCard(title: "A/T Ratio", value: String(format: "%.2f", game.assistTurnoverRatio), color: .indigo)
                
                // Playing Time Stats (always show for consistent layout)
                if game.totalPlayingTimeMinutes > 0 || game.benchTimeMinutes > 0 {
                    DetailStatCard(
                        title: "Minutes Played",
                        value: formatPlayingTime(game.totalPlayingTimeMinutes),
                        color: .green
                    )
                    DetailStatCard(
                        title: "Court Time %",
                        value: "\(Int(game.playingTimePercentage))%",
                        color: .teal
                    )
                    DetailStatCard(
                        title: "Bench Time",
                        value: formatPlayingTime(game.benchTimeMinutes),
                        color: .orange
                    )
                    DetailStatCard(
                        title: "Points/Min",
                        value: String(format: "%.1f", calculatePointsPerMinute()),
                        color: .red
                    )
                    DetailStatCard(
                        title: "Efficiency",
                        value: String(format: "%.1f", calculateEfficiencyRating()),
                        color: .purple
                    )
                } else {
                    // Placeholder cards for manual games
                    DetailStatCard(
                        title: "Minutes Played",
                        value: "Not tracked",
                        color: .gray
                    )
                    DetailStatCard(
                        title: "Court Time %",
                        value: "Not tracked",
                        color: .gray
                    )
                    DetailStatCard(
                        title: "Bench Time",
                        value: "Not tracked",
                        color: .gray
                    )
                    DetailStatCard(
                        title: "Points/Min",
                        value: "Not tracked",
                        color: .gray
                    )
                    DetailStatCard(
                        title: "Efficiency",
                        value: "Not tracked",
                        color: .gray
                    )
                }
                
                // Game Time Played (total game duration)
                if game.totalPlayingTimeMinutes > 0 || game.benchTimeMinutes > 0 {
                    DetailStatCard(
                        title: "Game Duration",
                        value: formatPlayingTime(game.totalPlayingTimeMinutes + game.benchTimeMinutes),
                        color: .purple
                    )
                } else {
                    DetailStatCard(
                        title: "Game Duration",
                        value: "Not tracked",
                        color: .gray
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatPlayingTime(_ minutes: Double) -> String {
        if minutes == 0 {
            return "0m"
        }
        
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h\(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private var shootingPercentagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shooting Percentages")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
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
    
    // MARK: - Editing Logic
    
    private func statCard(for title: String, value: Binding<Int>, color: Color) -> some View {
        DetailStatCard(title: title, value: "\(value.wrappedValue)", color: color)
            .onLongPressGesture {
                editingStatTitle = title
                editingStatValue = "\(value.wrappedValue)"
                statUpdateBinding = value
                isEditingStat = true
            }
    }
    
    private func saveStatChange() {
        guard let newValue = Int(editingStatValue), let binding = statUpdateBinding else { return }
        
        binding.wrappedValue = newValue
        
        // Recalculate points if a shooting stat changed
        if ["2PT Made", "3PT Made", "FT Made"].contains(editingStatTitle) {
            game.points = (game.fg2m * 2) + (game.fg3m * 3) + game.ftm
        }
        
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                // Handle error appropriately, e.g., show an alert
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
    
    private func calculatePointsPerMinute() -> Double {
        guard game.totalPlayingTimeMinutes > 0 else { return 0.0 }
        return Double(game.points) / game.totalPlayingTimeMinutes
    }
    
    private func calculateEfficiencyRating() -> Double {
        guard game.totalPlayingTimeMinutes > 0 else { return 0.0 }
        
        // Basketball efficiency formula: (Points + Rebounds + Assists + Steals + Blocks - Turnovers - Missed FG - Missed FT) / Minutes
        let positiveStats = game.points + game.rebounds + game.assists + game.steals + game.blocks
        let negativeStats = game.turnovers + (game.fg2a + game.fg3a - game.fg2m - game.fg3m) + (game.fta - game.ftm)
        let efficiency = Double(positiveStats - negativeStats) / game.totalPlayingTimeMinutes
        
        return efficiency
    }
}
*/

struct GameDetailView: View {
    @State var game: Game
    
    var body: some View {
        EnhancedGameDetailView(game: game)
    }
}


struct GameDetailTimeCard: View {
    let title: String
    let time: Double
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text(formatTime(time))
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(color.opacity(0.08))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    private func formatTime(_ minutes: Double) -> String {
        if minutes == 0 {
            return "0m"
        }
        
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct PlayingTimePercentageBar: View {
    let playingTime: Double
    let totalTime: Double
    let isIPad: Bool
    
    private var playingPercentage: Double {
        totalTime > 0 ? (playingTime / totalTime) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            HStack {
                Text("Court Time Percentage")
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(playingPercentage))%")
                    .font(isIPad ? .body : .caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: isIPad ? 12 : 8)
                        .cornerRadius(isIPad ? 6 : 4)
                    
                    // Progress bar
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * (playingPercentage / 100),
                            height: isIPad ? 12 : 8
                        )
                        .cornerRadius(isIPad ? 6 : 4)
                        .animation(.easeInOut(duration: 0.5), value: playingPercentage)
                }
            }
            .frame(height: isIPad ? 12 : 8)
            
            // Additional info
            if totalTime > 0 {
                HStack {
                    Text("On court: \(formatMinutes(playingTime))")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text("On bench: \(formatMinutes(totalTime - playingTime))")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(isIPad ? 16 : 12)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 12 : 8)
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
// MARK: - Detail Stat Card
struct DetailStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Shooting Percentage Card
struct ShootingPercentageCard: View {
    let title: String
    let percentage: String
    let fraction: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(percentage)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(fraction)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
