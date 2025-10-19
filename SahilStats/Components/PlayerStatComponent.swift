//
//  PlayerStatComponent.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/24/25.
//

import Combine
import SwiftUI

struct PlayerStatsSection: View {
    @Binding var game: Game
    let authService: AuthService
    let firebaseService: FirebaseService
    let isIPad: Bool
    
    // State for editing
    @State private var isEditingStat = false
    @State private var editingStatTitle = ""
    @State private var editingStatValue = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Player Stats")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Main stats grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: isIPad ? 16 : 12) {
                // Scoring stats
                statCard(title: "Points", value: game.points, color: .purple)
                
                // Shooting stats
                statCard(title: "2PT Made", value: game.fg2m, color: .blue)
                statCard(title: "2PT Att", value: game.fg2a, color: .blue.opacity(0.7))
                statCard(title: "3PT Made", value: game.fg3m, color: .green)
                statCard(title: "3PT Att", value: game.fg3a, color: .green.opacity(0.7))
                statCard(title: "FT Made", value: game.ftm, color: .orange)
                statCard(title: "FT Att", value: game.fta, color: .orange.opacity(0.7))
                
                // Other stats
                statCard(title: "Rebounds", value: game.rebounds, color: .mint)
                statCard(title: "Assists", value: game.assists, color: .cyan)
                statCard(title: "Steals", value: game.steals, color: .yellow)
                statCard(title: "Blocks", value: game.blocks, color: .red)
                statCard(title: "Fouls", value: game.fouls, color: .pink)
                statCard(title: "Turnovers", value: game.turnovers, color: .pink.opacity(0.7))
                
                // Calculated stats (always non-editable)
                DetailStatCard(title: "A/T Ratio", value: String(format: "%.2f", game.assistTurnoverRatio), color: .indigo)
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
    }
    
    // Helper function for stat cards
    @ViewBuilder
    func statCard(title: String, value: Int, color: Color) -> some View {
        if authService.canEditGames {
            // For admins: editable card with long press
            DetailStatCard(title: title, value: "\(value)", color: color)
                .onLongPressGesture {
                    editingStatTitle = title
                    editingStatValue = "\(value)"
                    isEditingStat = true
                }
        } else {
            // For regular users: read-only card
            DetailStatCard(title: title, value: "\(value)", color: color)
        }
    }
    
    // Save stat changes
    func saveStatChange() {
        guard let newValue = Int(editingStatValue) else { return }
        
        // Update the appropriate field in the game object
        switch editingStatTitle {
        case "Points":
            game.points = newValue
        case "2PT Made":
            game.fg2m = newValue
        case "2PT Att":
            game.fg2a = newValue
        case "3PT Made":
            game.fg3m = newValue
        case "3PT Att":
            game.fg3a = newValue
        case "FT Made":
            game.ftm = newValue
        case "FT Att":
            game.fta = newValue
        case "Rebounds":
            game.rebounds = newValue
        case "Assists":
            game.assists = newValue
        case "Steals":
            game.steals = newValue
        case "Blocks":
            game.blocks = newValue
        case "Fouls":
            game.fouls = newValue
        case "Turnovers":
            game.turnovers = newValue
        default:
            break
        }
        
        // Recalculate points if a shooting stat changed
        if ["2PT Made", "3PT Made", "FT Made"].contains(editingStatTitle) {
            game.points = (game.fg2m * 2) + (game.fg3m * 3) + game.ftm
        }
        
        // Update achievements
        game.achievements = Achievement.getEarnedAchievements(for: game)
        
        // Save to Firebase
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                debugPrint("Failed to save game changes: \(error.localizedDescription)")
            }
        }
    }
}
