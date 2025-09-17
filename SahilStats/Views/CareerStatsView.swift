//
//  CareerStatsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/17/25.
//

import SwiftUI

struct GameListView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @State private var selectedGame: Game?
    
    var body: some View {
        NavigationView {
            Group {
                if firebaseService.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        Text("Loading games...")
                            .foregroundColor(.secondary)
                    }
                } else if firebaseService.games.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "basketball.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                        
                        Text("No games yet!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Start playing to see your stats here")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if authService.canCreateGames {
                            NavigationLink("Create Your First Game") {
                                GameSetupView()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding()
                } else {
                    List {
                        // Career stats summary at top
                        CareerStatsView(stats: firebaseService.getCareerStats())
                            .listRowBackground(Color.orange.opacity(0.1))
                        
                        // Live game indicator if present
                        if firebaseService.hasLiveGame {
                            LiveGameIndicatorView()
                                .listRowBackground(Color.red.opacity(0.1))
                        }
                        
                        // Games section
                        Section("Recent Games") {
                            ForEach(firebaseService.games) { game in
                                GameRowView(game: game)
                                    .onTapGesture {
                                        selectedGame = game
                                    }
                                    .contextMenu {
                                        if authService.canEditGames {
                                            Button("Edit Game") {
                                                // TODO: Navigate to edit
                                            }
                                        }
                                        
                                        if authService.canDeleteGames {
                                            Button("Delete Game", role: .destructive) {
                                                Task {
                                                    try? await firebaseService.deleteGame(game.id ?? "")
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Basketball Stats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Live game indicator in toolbar
                        if firebaseService.hasLiveGame {
                            NavigationLink(destination: LiveGameView()) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .opacity(0.8)
                                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                                    
                                    Text("LIVE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Add game button for admins
                        if authService.canCreateGames {
                            NavigationLink(destination: GameSetupView()) {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    // User status indicator
                    if authService.isSignedIn {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            
                            Text(authService.userRole.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game)
            }
            .refreshable {
                // Pull to refresh - Firebase auto-updates, but this provides feedback
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            }
        }
        .onAppear {
            firebaseService.startListening()
        }
        .onDisappear {
            firebaseService.stopListening()
        }
    }
}
