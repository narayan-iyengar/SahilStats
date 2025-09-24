// File: SahilStats/Views/GameListContent.swift

import SwiftUI

struct GameListContent: View {
    let sortedGames: [Game]
    @ObservedObject var filterManager: GameFilterManager
    @ObservedObject var firebaseService: FirebaseService
    @ObservedObject var authService: AuthService
    
    @Binding var isViewingTrends: Bool
    @Binding var hoveredGameId: String?
    
    let onGameTap: (Game) -> Void
    let onGameDelete: (Game) -> Void
    let onGameSave: (Game) -> Void
    let onShowLiveGame: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var filteredGames: [Game] {
        filterManager.applyFilters(to: sortedGames)
    }
    
    var body: some View {
        List {
            // Career stats section (only if not heavily filtered)
            if filterManager.activeFiltersCount <= 1 && filterManager.searchText.isEmpty {
                CareerStatsSection(
                    stats: firebaseService.getCareerStats(),
                    games: Array(sortedGames.prefix(10)),
                    isViewingTrends: $isViewingTrends,
                    isIPad: isIPad
                )
            }
            
            // Only show games section when not viewing trends
            if !isViewingTrends {
                GamesListSection(
                    filterManager: filterManager,
                    firebaseService: firebaseService,
                    authService: authService,
                    isIPad: isIPad,
                    filteredGames: filteredGames,
                    hoveredGameId: $hoveredGameId,
                    onGameTap: onGameTap,
                    onGameDelete: onGameDelete,
                    onGameSave: onGameSave,
                    onShowLiveGame: onShowLiveGame
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Career Stats Section
struct CareerStatsSection: View {
    let stats: CareerStats
    let games: [Game]
    @Binding var isViewingTrends: Bool
    let isIPad: Bool
    
    var body: some View {
        EnhancedCareerStatsView(
            stats: stats,
            games: games,
            isViewingTrends: $isViewingTrends,
            isIPad: isIPad
        )
        .listRowBackground(Color.blue.opacity(0.08))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Games List Section
struct GamesListSection: View {
    @ObservedObject var filterManager: GameFilterManager
    @ObservedObject var firebaseService: FirebaseService
    @ObservedObject var authService: AuthService
    let isIPad: Bool
    
    let filteredGames: [Game]
    @Binding var hoveredGameId: String?
    
    let onGameTap: (Game) -> Void
    let onGameDelete: (Game) -> Void
    let onGameSave: (Game) -> Void
    let onShowLiveGame: () -> Void
    
    var body: some View {
        Group {
            // Active filters display
            if filterManager.activeFiltersCount > 0 || !filterManager.searchText.isEmpty {
                ActiveFiltersSection(
                    filterManager: filterManager,
                    filteredCount: filteredGames.count,
                    totalCount: firebaseService.games.count
                )
            }
/*
            // Live game indicator if present
            if firebaseService.hasLiveGame {
                LiveGameSection(onTap: onShowLiveGame)
            }
*/
            // Games section with header
            Section {
                GameRowsSection(
                    displayedGames: filterManager.displayedGames,
                    authService: authService,
                    hoveredGameId: $hoveredGameId,
                    onGameTap: onGameTap,
                    onGameDelete: onGameDelete,
                    onGameSave: onGameSave
                )
            } header: {
                GamesSectionHeader(
                    filteredCount: filteredGames.count,
                    totalCount: firebaseService.games.count,
                    displayedCount: filterManager.displayedGames.count,
                    isIPad: isIPad
                )
            }
        }
    }
}

// MARK: - Active Filters Section
struct ActiveFiltersSection: View {
    @ObservedObject var filterManager: GameFilterManager
    let filteredCount: Int
    let totalCount: Int
    
    var body: some View {
        ActiveFiltersView(
            searchText: filterManager.searchText,
            selectedTeamFilter: filterManager.selectedTeamFilter,
            selectedOpponentFilter: filterManager.selectedOpponentFilter,
            selectedOutcomeFilter: filterManager.selectedOutcomeFilter,
            selectedDateRange: filterManager.selectedDateRange,
            filteredCount: filteredCount,
            totalCount: totalCount,
            onClearAll: filterManager.clearAllFilters
        )
        .listRowBackground(Color.orange.opacity(0.05))
        .listRowSeparator(.hidden)
    }
}

/*
// MARK: - Live Game Section
struct LiveGameSection: View {
    let onTap: () -> Void
    
    var body: some View {
        LiveGameIndicatorView(onTap: onTap)
            .listRowBackground(Color.red.opacity(0.1))
    }
}
*/


// MARK: - Game Rows Section
struct GameRowsSection: View {
    let displayedGames: [Game]
    @ObservedObject var authService: AuthService
    @Binding var hoveredGameId: String?
    
    let onGameTap: (Game) -> Void
    let onGameDelete: (Game) -> Void
    let onGameSave: (Game) -> Void
    
    var body: some View {
        ForEach(Array(displayedGames.enumerated()), id: \.element.id) { index, game in
            SimpleGameRow(game: game) {
                onGameTap(game)
            }
            .onHover { isHovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredGameId = isHovering ? game.id : nil
                }
            }
        }
    }
}

// MARK: - Simple Game Row
struct SimpleGameRow: View {
    let game: Game
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(outcomeColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(game.teamName) vs \(game.opponent)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(game.myTeamScore) - \(game.opponentScore)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(outcomeColor)
                    }
                    
                    HStack {
                        Text("\(game.points) PTS")
                        Text("•")
                        Text("\(game.rebounds) REB")
                        Text("•")
                        Text("\(game.assists) AST")
                        Spacer()
                        Text(formatDate(game.timestamp))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var outcomeColor: Color {
        switch game.outcome {
        case .win: return .green
        case .loss: return .red
        case .tie: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
