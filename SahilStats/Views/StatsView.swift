//
//  StatsView.swift
//  SahilStats
//
//  Dedicated tab for career statistics and trends
//

import SwiftUI

struct StatsView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var isViewingTrends = false
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

    var body: some View {
        NavigationView {
            ScrollView {
                if firebaseService.isLoading {
                    LoadingView()
                } else if sortedGames.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        ModernCareerDashboard(
                            stats: firebaseService.getCareerStats(),
                            games: sortedGames,
                            isViewingTrends: $isViewingTrends,
                            isIPad: isIPad
                        )
                        .padding(.top, -35)
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
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

            Text("No Stats Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Play some games to see your career stats and trends")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    StatsView()
}
