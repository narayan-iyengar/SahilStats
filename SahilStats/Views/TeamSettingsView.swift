//
//  TeamSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//

import SwiftUI

struct TeamsSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var newTeamName = ""
    @State private var showingDeleteAlert = false
    @State private var teamToDelete: Team?
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Team name", text: $newTeamName)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        addTeam()
                    }
                    .disabled(newTeamName.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            } header: {
                Text("Add New Team")
            }
            
            Section {
                if firebaseService.teams.isEmpty {
                    Text("No teams yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(firebaseService.teams) { team in
                        HStack {
                            Text(team.name)
                            Spacer()
                            Button(action: {
                                teamToDelete = team
                                showingDeleteAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            } header: {
                Text("Teams")
            }
        }
        .navigationTitle("Teams")
        .alert("Delete Team", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                teamToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let team = teamToDelete {
                    deleteTeam(team)
                }
                teamToDelete = nil
            }
        } message: {
            if let team = teamToDelete {
                Text("Are you sure you want to delete \(team.name)? This action cannot be undone.")
            }
        }
        .onAppear {
            firebaseService.startListening()
        }
    }
    
    private func addTeam() {
        guard !newTeamName.isEmpty else { return }
        let team = Team(name: newTeamName)
        Task {
            do {
                try await firebaseService.addTeam(team)
                newTeamName = ""
            } catch {
                print("Failed to add team: \(error)")
            }
        }
    }
    
    private func deleteTeam(_ team: Team) {
        Task {
            do {
                try await firebaseService.deleteTeam(team.id ?? "")
            } catch {
                print("Failed to delete team: \(error)")
            }
        }
    }
}
