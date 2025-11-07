//
//  HistoryView.swift
//  SahilStats
//
//  Combined view showing career stats and recent games
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @StateObject private var filterManager = GameFilterManager()

    @State private var isViewingTrends = false
    @State private var selectedGame: Game?
    @State private var showingDeleteAlert = false
    @State private var gameToDelete: Game?
    @State private var deleteErrorMessage = ""
    @State private var showingDeleteError = false
    @State private var hoveredGameId: String?
    @State private var showingFilters = false
    @State private var searchText = ""
    @State private var showAllGames = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var sortedGames: [Game] {
        firebaseService.games.sorted {
            let date1 = $0.timestamp ?? .distantPast
            let date2 = $1.timestamp ?? .distantPast
            return date1 > date2
        }
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
        var games = sortedGames

        // Apply search filter
        if !effectiveSearchText.isEmpty {
            games = games.filter { game in
                game.teamName.localizedCaseInsensitiveContains(effectiveSearchText) ||
                game.opponent.localizedCaseInsensitiveContains(effectiveSearchText) ||
                (game.location?.localizedCaseInsensitiveContains(effectiveSearchText) ?? false)
            }
        }

        // Apply other filters
        games = filterManager.applyFilters(to: games)

        return games
    }

    private var effectiveSearchText: String {
        !searchText.isEmpty ? searchText : filterManager.searchText
    }

    private var hasActiveFilters: Bool {
        !effectiveSearchText.isEmpty || filterManager.activeFiltersCount > 0
    }

    // Show top 20 recent games from filtered results (or all if expanded)
    private var recentGames: [Game] {
        showAllGames ? filteredGames : Array(filteredGames.prefix(20))
    }

    var body: some View {
        NavigationView {
            Group {
                if firebaseService.isLoading {
                    LoadingView()
                } else if sortedGames.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Stats Dashboard
                            ModernCareerDashboard(
                                stats: firebaseService.getCareerStats(),
                                games: sortedGames,
                                isViewingTrends: $isViewingTrends,
                                isIPad: isIPad
                            )
                            .padding(.top, -35)

                            // Recent Games Section
                            recentGamesSection
                                .padding(.top, 32)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Filter button with badge
                    Button(action: { showingFilters = true }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title3)
                                .foregroundColor(filterManager.activeFiltersCount > 0 ? .orange : .gray)

                            // Badge for active filters
                            if filterManager.activeFiltersCount > 0 {
                                Text("\(filterManager.activeFiltersCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            CompleteGameDetailView(game: game)
        }
        .alert("Delete Game", isPresented: $showingDeleteAlert) {
            GameDeleteAlert(
                gameToDelete: $gameToDelete,
                onDelete: deleteGame
            )
        }
        .alert("Deletion Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedTeamFilter: $filterManager.selectedTeamFilter,
                selectedOpponentFilter: $filterManager.selectedOpponentFilter,
                selectedOutcomeFilter: $filterManager.selectedOutcomeFilter,
                selectedDateRange: $filterManager.selectedDateRange,
                customStartDate: $filterManager.customStartDate,
                customEndDate: $filterManager.customEndDate,
                availableTeams: availableTeams,
                availableOpponents: availableOpponents,
                onClearAll: clearAllFilters,
                isIPad: isIPad
            )
        }
        .onAppear {
            firebaseService.startListening()
        }
        .onDisappear {
            firebaseService.stopListening()
        }
        .onChange(of: searchText) { _, _ in
            filterManager.searchText = searchText
            showAllGames = false  // Reset expansion when search changes
        }
        .onChange(of: filterManager.needsUpdate) { _, _ in
            // Trigger re-render when filters change
            showAllGames = false  // Reset expansion when filters change
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("No Games Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Play some games to see your career stats and game history")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(hasActiveFilters ? "Filtered Games" : "Recent Games")
                    .font(isIPad ? .largeTitle : .title2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, isIPad ? 32 : 20)

                Spacer()

                if hasActiveFilters {
                    Text("\(recentGames.count) of \(filteredGames.count) filtered")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, isIPad ? 32 : 20)
                } else if recentGames.count < sortedGames.count {
                    Text("Showing \(recentGames.count) of \(sortedGames.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, isIPad ? 32 : 20)
                }
            }

            // Active filters indicator
            if hasActiveFilters {
                Button(action: clearAllFilters) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear All Filters")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, isIPad ? 32 : 20)
                }
            }

            // Games list
            List {
                ForEach(recentGames) { game in
                    EditableGameRowView(
                        game: .constant(game),
                        isHovered: hoveredGameId == game.id,
                        canDelete: authService.canDeleteGames,
                        canEdit: authService.canEditGames,
                        onTap: {
                            NavigationCoordinator.shared.markUserHasInteracted()
                            selectedGame = game
                        },
                        onDelete: {
                            gameToDelete = game
                            showingDeleteAlert = true
                        },
                        onSave: saveGameChanges
                    )
                    .onHover { isHovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoveredGameId = isHovering ? game.id : nil
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: isIPad ? 32 : 20, bottom: 8, trailing: isIPad ? 32 : 20))
                }
            }
            .listStyle(.plain)
            .frame(height: CGFloat(recentGames.count) * 90) // Estimate ~90pt per row
            .animation(.easeInOut, value: recentGames.count)

            // "View All Games" / "Show Less" button if there are more than 20
            if filteredGames.count > 20 {
                Button(action: {
                    withAnimation {
                        showAllGames.toggle()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text(showAllGames ? "Show Less" : "View All \(filteredGames.count) Games")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Image(systemName: showAllGames ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, isIPad ? 32 : 20)
                .padding(.top, 8)
            }
        }
        .padding(.bottom, 32)
    }

    private func saveGameChanges(_ game: Game) {
        Task {
            do {
                try await firebaseService.updateGame(game)
            } catch {
                debugPrint("Failed to save game changes: \(error.localizedDescription)")
            }
        }
    }

    private func deleteGame(_ game: Game) {
        Task {
            do {
                try await firebaseService.deleteGame(game.id ?? "")
                forcePrint("✅ Game deleted successfully")
            } catch {
                debugPrint("Failed to delete game: \(error)")

                await MainActor.run {
                    deleteErrorMessage = "Failed to delete game: \(error.localizedDescription)"
                    showingDeleteError = true
                }
            }
        }
    }

    private func clearAllFilters() {
        searchText = ""
        filterManager.clearAllFilters()
    }
}

#Preview {
    HistoryView()
        .environmentObject(AuthService())
}
