import SwiftUI

struct GameListView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var selectedGame: Game?
    
    var body: some View {
        NavigationView {
            Group {
                if firebaseService.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading games...")
                            .foregroundColor(.secondary)
                    }
                } else if firebaseService.games.isEmpty {
                    VStack {
                        Text("🏀")
                            .font(.system(size: 80))
                        Text("No games yet!")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Start playing to see your stats here")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // Career stats summary at top
                        CareerStatsView(games: firebaseService.games)
                            .listRowBackground(Color.orange.opacity(0.1))
                        
                        // Games section
                        Section("Recent Games") {
                            ForEach(firebaseService.games) { game in
                                GameRowView(game: game)
                                    .onTapGesture {
                                        selectedGame = game
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Basketball Stats")
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game)
            }
            .refreshable {
                // Pull to refresh - Firebase auto-updates, but this provides feedback
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            }
        }
    }
}

struct CareerStatsView: View {
    let games: [Game]
    
    private var totalPoints: Int {
        games.reduce(0) { $0 + $1.points }
    }
    
    private var totalGames: Int {
        games.count
    }
    
    private var averagePoints: Double {
        totalGames > 0 ? Double(totalPoints) / Double(totalGames) : 0.0
    }
    
    private var wins: Int {
        games.filter { $0.outcome == .win }.count
    }
    
    private var winPercentage: Double {
        totalGames > 0 ? Double(wins) / Double(totalGames) : 0.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🏀 Career Stats")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatBox(title: "Games", value: "\(totalGames)")
                StatBox(title: "Points", value: "\(totalPoints)")
                StatBox(title: "Avg", value: String(format: "%.1f", averagePoints))
                StatBox(title: "Win %", value: String(format: "%.0f%%", winPercentage * 100))
            }
        }
        .padding()
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GameRowView: View {
    let game: Game
    
    var body: some View {
        HStack(spacing: 12) {
            // Game outcome indicator
            Circle()
                .fill(outcomeColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                // Teams and score
                HStack {
                    Text("\(game.teamName) vs \(game.opponent)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(game.myTeamScore) - \(game.opponentScore)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                // Key stats
                HStack(spacing: 16) {
                    StatPill(label: "PTS", value: "\(game.points)")
                    StatPill(label: "REB", value: "\(game.rebounds)")
                    StatPill(label: "AST", value: "\(game.assists)")
                    
                    Spacer()
                }
                
                // Date and location
                HStack {
                    if let location = game.location {
                        Text("📍 \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(game.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Achievements
                if !game.achievements.isEmpty {
                    HStack {
                        ForEach(Array(game.achievements.prefix(3)), id: \.self) { achievement in
                            Text(achievement.emoji)
                                .font(.caption)
                        }
                        if game.achievements.count > 3 {
                            Text("+\(game.achievements.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var outcomeColor: Color {
        switch game.outcome {
        case .win: return .green
        case .loss: return .red
        case .tie: return .gray
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(4)
    }
}

struct GameDetailView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(game.teamName) vs \(game.opponent)")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text(game.outcome.emoji)
                                .font(.title)
                        }
                        
                        HStack {
                            Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                                .font(.title2)
                                .foregroundColor(game.outcome == .win ? .green : .red)
                            
                            Spacer()
                        }
                        
                        Text(game.formattedDate)
                            .foregroundColor(.secondary)
                        
                        if let location = game.location {
                            Text("📍 \(location)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Stats breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Player Stats")
                            .font(.headline)
                        
                        // Key stats
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                            StatCard(title: "Points", value: "\(game.points)", color: .orange)
                            StatCard(title: "Rebounds", value: "\(game.rebounds)", color: .blue)
                            StatCard(title: "Assists", value: "\(game.assists)", color: .green)
                            StatCard(title: "Steals", value: "\(game.steals)", color: .purple)
                            StatCard(title: "Blocks", value: "\(game.blocks)", color: .red)
                            StatCard(title: "Fouls", value: "\(game.fouls)", color: .orange)
                        }
                        
                        // Shooting stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Shooting")
                                .font(.headline)
                            
                            ShootingStatRow(title: "2-Pointers", made: game.fg2m, attempted: game.fg2a)
                            ShootingStatRow(title: "3-Pointers", made: game.fg3m, attempted: game.fg3a)
                            ShootingStatRow(title: "Free Throws", made: game.ftm, attempted: game.fta)
                        }
                        
                        // Achievements
                        if !game.achievements.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Achievements")
                                    .font(.headline)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                    ForEach(game.achievements, id: \.self) { achievement in
                                        AchievementBadge(achievement: achievement)
                                    }
                                }
                            }
                        }
                    }
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
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ShootingStatRow: View {
    let title: String
    let made: Int
    let attempted: Int
    
    private var percentage: Double {
        attempted > 0 ? Double(made) / Double(attempted) : 0.0
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(made)/\(attempted)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("(\(Int(percentage * 100))%)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 8) {
            Text(achievement.emoji)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
}

#Preview {
    GameListView()
}
