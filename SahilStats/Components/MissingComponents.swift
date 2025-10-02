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
                    .buttonStyle(ToolbarPillButtonStyle(isIPad: isIPad))
                }
            }
        }
    }
}


struct GameDetailView: View {
    @State var game: Game
    
    var body: some View {
        // Corrected: Use the existing and complete detail view
        CompleteGameDetailView(game: game)
    }
}





struct GameDetailTimeCard: View {
    let title: String
    let time: Double
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7) // Allow text to scale down
            
            Text(formatTime(time))
                .font(isIPad ? .largeTitle : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6) // Allow value to scale down
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 120 : 80, maxHeight: isIPad ? 120 : 80) // Fixed height
        .padding(isIPad ? 20 : 16)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    
    private func formatTime(_ minutes: Double) -> String {
        // 🔍 DEBUG: Print the formatting process
        print("🔍 formatTime called with minutes: \(minutes)")
        
        if minutes == 0 {
            print("🔍 formatTime returning '0m' (minutes was 0)")
            return "0m"
        }
        
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        let result: String
        if hours > 0 {
            result = "\(hours)h \(mins)m"
        } else {
            result = "\(mins)m"
        }
        
        print("🔍 formatTime returning: '\(result)'")
        return result
    }
}

struct InlineConnectionStatusBadge: View {
    let status: String
    let isConnecting: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isConnecting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Text(status)
                .font(.caption)
                .foregroundColor(isConnecting ? .secondary : .green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isConnecting ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(8)
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
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7) // Allow text to scale down to 70% if needed
            
            Text(value)
                .font(isIPad ? .largeTitle : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6) // Allow value to scale down more aggressively
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 120 : 80, maxHeight: isIPad ? 120 : 80) // Fixed height
        .padding(isIPad ? 20 : 16)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Shooting Percentage Card
struct ShootingPercentageCard: View {
    let title: String
    let percentage: String
    let fraction: String
    let color: Color
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7) // Allow text to scale down
            
            Text(percentage)
                .font(isIPad ? .largeTitle : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6) // Allow percentage to scale down
            
            Text(fraction)
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8) // Allow fraction to scale down slightly
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 120 : 80, maxHeight: isIPad ? 120 : 80) // Fixed height
        .padding(isIPad ? 20 : 16)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
}
