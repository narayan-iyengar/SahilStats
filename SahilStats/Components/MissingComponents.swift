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
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

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

// MARK: - Game Detail View (Now with Editing)
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerView
                    
                    // Player Stats Section
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
            }
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
