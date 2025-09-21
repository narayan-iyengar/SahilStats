// File: SahilStats/Views/GameListView.swift

import SwiftUI
import Foundation
import Combine

struct GameListView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @StateObject private var filterManager = GameFilterManager()
    
    @State private var selectedGame: Game?
    @State private var hoveredGameId: String?
    @State private var showingDeleteAlert = false
    @State private var gameToDelete: Game?
    @State private var showingLiveGame = false
    @State private var isViewingTrends = false
    
    // iPad detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            contentView
        }
        .navigationTitle("Sahil's Basketball Stats")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                GameListToolbar(
                    activeFiltersCount: filterManager.activeFiltersCount,
                    hasLiveGame: firebaseService.hasLiveGame,
                    canCreateGames: authService.canCreateGames,
                    onShowFilters: { filterManager.showingFilters = true },
                    onShowLiveGame: { showingLiveGame = true }
                )
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                if authService.isSignedIn {
                    UserStatusIndicator()
                }
            }
        }
        .sheet(item: $selectedGame) { game in
            GameDetailView(game: game)
        }
        .sheet(isPresented: $filterManager.showingFilters) {
            GameFiltersSheet(
                filterManager: filterManager,
                availableTeams: availableTeams,
                availableOpponents: availableOpponents,
                isIPad: isIPad
            )
        }
        .fullScreenCover(isPresented: $showingLiveGame) {
            LiveGameFullScreenView {
                showingLiveGame = false
            }
            .environmentObject(authService)
        }
        .alert("Delete Game", isPresented: $showingDeleteAlert) {
            GameDeleteAlert(
                gameToDelete: $gameToDelete,
                onDelete: deleteGame
            )
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        .onAppear {
            firebaseService.startListening()
            filterManager.updateDisplayedGames(from: filteredGames)
        }
        .onDisappear {
            firebaseService.stopListening()
        }
        .onChange(of: firebaseService.games) { _, _ in
            filterManager.updateDisplayedGames(from: filteredGames)
        }
        .onChange(of: filterManager.needsUpdate) { _, _ in
            filterManager.updateDisplayedGames(from: filteredGames)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if firebaseService.isLoading {
            LoadingView()
        } else if sortedGames.isEmpty {
            EmptyStateView(canCreateGames: authService.canCreateGames)
        } else {
            GameListContent(
                sortedGames: sortedGames,
                filterManager: filterManager,
                firebaseService: firebaseService,
                authService: authService,
                isViewingTrends: $isViewingTrends,
                hoveredGameId: $hoveredGameId,
                onGameTap: { selectedGame = $0 },
                onGameDelete: {
                    gameToDelete = $0
                    showingDeleteAlert = true
                },
                onGameSave: saveGameChanges,
                onShowLiveGame: { showingLiveGame = true }
            )
        }
    }
}

// MARK: - Computed Properties
extension GameListView {
    private var sortedGames: [Game] {
        firebaseService.games.sorted { $0.timestamp > $1.timestamp }
    }
    
    private var availableTeams: [String] {
        let teamSet = Set(sortedGames.map(\.teamName))
        let sortedTeams = Array(teamSet).sorted()
        return ["All Teams"] + sortedTeams
    }
    
    private var availableOpponents: [String] {
        let opponentSet = Set(sortedGames.map(\.opponent))
        let sortedOpponents = Array(opponentSet).sorted()
        return ["All Opponents"] + sortedOpponents
    }
    
    private var filteredGames: [Game] {
        filterManager.applyFilters(to: sortedGames)
    }
}

// MARK: - Actions
extension GameListView {
    private func saveGameChanges(_ game: Game) {
        Task {
            do {
                try await firebaseService.updateGame(game)
                filterManager.updateGameInDisplayed(game)
            } catch {
                print("Failed to save game changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteGame(_ game: Game) {
        Task {
            do {
                try await firebaseService.deleteGame(game.id ?? "")
            } catch {
                print("Failed to delete game: \(error)")
            }
        }
    }
}

// MARK: - Date Range Enum (for FilterManager compatibility)
extension GameListView {
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case week = "Last Week"
        case month = "Last Month"
        case quarter = "Last 3 Months"
        case year = "Last Year"
        case custom = "Custom Range"
        
        func dateFilter(from startDate: Date, to endDate: Date) -> (Date, Date)? {
            let now = Date()
            switch self {
            case .all:
                return nil
            case .week:
                return (Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) ?? now, now)
            case .month:
                return (Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now, now)
            case .quarter:
                return (Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now, now)
            case .year:
                return (Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now, now)
            case .custom:
                return (startDate, endDate)
            }
        }
    }
}

#Preview {
    GameListView()
        .environmentObject(AuthService())
}


