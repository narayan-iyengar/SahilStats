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
    @State private var isViewingTrends = false
    @State private var selectedGame: Game?
    @State private var showingDeleteAlert = false
    @State private var gameToDelete: Game?
    @State private var deleteErrorMessage = ""
    @State private var showingDeleteError = false
    @State private var hoveredGameId: String?

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

    // Show top 20 recent games
    private var recentGames: [Game] {
        Array(sortedGames.prefix(20))
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
        .onAppear {
            firebaseService.startListening()
        }
        .onDisappear {
            firebaseService.stopListening()
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
                Text("Recent Games")
                    .font(isIPad ? .largeTitle : .title2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, isIPad ? 32 : 20)

                Spacer()

                if recentGames.count < sortedGames.count {
                    Text("Showing \(recentGames.count) of \(sortedGames.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, isIPad ? 32 : 20)
                }
            }

            // Games list
            VStack(spacing: 0) {
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
                    .padding(.horizontal, isIPad ? 32 : 20)

                    if game.id != recentGames.last?.id {
                        Divider()
                            .padding(.horizontal, isIPad ? 32 : 20)
                    }
                }
            }

            // "View All Games" link if there are more
            if recentGames.count < sortedGames.count {
                Button(action: {
                    // Could navigate to full games list or expand inline
                }) {
                    HStack {
                        Spacer()
                        Text("View All \(sortedGames.count) Games")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Image(systemName: "chevron.right")
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
}

#Preview {
    HistoryView()
        .environmentObject(AuthService())
}
