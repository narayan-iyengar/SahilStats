//
//  LiveGameSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//

import SwiftUI

struct LiveGamesSettingsView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            Section {
                if firebaseService.hasLiveGame {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Live game in progress")
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text("No live games")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Status")
            }
            
            Section {
                Button("Delete All Live Games") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            } footer: {
                Text("This will permanently delete all live game sessions. Completed games will not be affected.")
            }
        }
        .navigationTitle("Live Games")
        .alert("Delete Live Games", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllLiveGames()
            }
        } message: {
            Text("Are you sure you want to delete all live games? This action cannot be undone.")
        }
        .onAppear {
            firebaseService.startListening()
        }
    }
    
    private func deleteAllLiveGames() {
        Task {
            do {
                try await firebaseService.deleteAllLiveGames()
            } catch {
                print("Failed to delete live games: \(error)")
            }
        }
    }
}
