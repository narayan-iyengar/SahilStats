//
//  TeamSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//

import SwiftUI
import PhotosUI

struct TeamsSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var logoUploadManager = LogoUploadManager.shared
    @State private var newTeamName = ""
    @State private var showingDeleteAlert = false
    @State private var teamToDelete: Team?
    @State private var editingTeam: Team?
    @State private var editingTeamName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var teamForLogoUpload: Team?
    
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Team logo (if available)
                                if let logoURL = team.logoURL {
                                    AsyncImage(url: URL(string: logoURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .cornerRadius(8)
                                        case .failure(_):
                                            Image(systemName: "photo.circle.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 40, height: 40)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "photo.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.3))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    if editingTeam?.id == team.id {
                                        TextField("Team name", text: $editingTeamName)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        Text(team.name)
                                            .font(.headline)
                                    }

                                    // Logo upload button
                                    if editingTeam?.id != team.id {
                                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                            HStack(spacing: 4) {
                                                Image(systemName: team.logoURL == nil ? "photo.badge.plus" : "photo.badge.arrow.down")
                                                    .font(.caption2)
                                                Text(team.logoURL == nil ? "Add Logo" : "Change Logo")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.orange)
                                        }
                                        .onChange(of: selectedPhotoItem) { _, newValue in
                                            if newValue != nil {
                                                teamForLogoUpload = team
                                                Task {
                                                    await handleLogoSelection()
                                                }
                                            }
                                        }
                                    }
                                }

                                Spacer()

                            if editingTeam?.id == team.id {
                                Button("Save") {
                                    saveTeamEdit(team)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .controlSize(.small)
                                .disabled(editingTeamName.isEmpty)

                                Button("Cancel") {
                                    cancelEdit()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                HStack(spacing: 16) {
                                    Button(action: {
                                        startEditing(team)
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .controlSize(.small)

                                    Button(action: {
                                        teamToDelete = team
                                        showingDeleteAlert = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .controlSize(.small)
                                }
                            }
                            }

                            // Upload progress indicator
                            if logoUploadManager.isUploading && teamForLogoUpload?.id == team.id {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: logoUploadManager.uploadProgress)
                                        .progressViewStyle(.linear)
                                    Text("Uploading logo... \(Int(logoUploadManager.uploadProgress * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 48) // Align with team name
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
                debugPrint("Failed to add team: \(error)")
            }
        }
    }
    
    private func deleteTeam(_ team: Team) {
        Task {
            do {
                try await firebaseService.deleteTeam(team.id ?? "")
            } catch {
                debugPrint("Failed to delete team: \(error)")
            }
        }
    }

    private func startEditing(_ team: Team) {
        editingTeam = team
        editingTeamName = team.name
    }

    private func cancelEdit() {
        editingTeam = nil
        editingTeamName = ""
    }

    private func saveTeamEdit(_ team: Team) {
        guard !editingTeamName.isEmpty else { return }
        var updatedTeam = team
        updatedTeam.name = editingTeamName

        Task {
            do {
                try await firebaseService.updateTeam(updatedTeam)
                editingTeam = nil
                editingTeamName = ""
            } catch {
                debugPrint("Failed to update team: \(error)")
            }
        }
    }

    private func handleLogoSelection() async {
        guard let photoItem = selectedPhotoItem,
              let team = teamForLogoUpload,
              let teamId = team.id else {
            return
        }

        do {
            // Load image from PhotosPicker
            guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                debugPrint("❌ Failed to load image from photo picker")
                return
            }

            debugPrint("📸 Image selected, uploading for team: \(team.name)")

            // Upload to Firebase Storage
            let downloadURL = try await logoUploadManager.uploadTeamLogo(image, teamId: teamId)

            // Update team with logo URL
            var updatedTeam = team
            updatedTeam.logoURL = downloadURL

            try await firebaseService.updateTeam(updatedTeam)

            debugPrint("✅ Team logo updated successfully")

            // Reset state
            selectedPhotoItem = nil
            teamForLogoUpload = nil

        } catch {
            debugPrint("❌ Logo upload failed: \(error.localizedDescription)")
            // Reset state even on error
            selectedPhotoItem = nil
            teamForLogoUpload = nil
        }
    }
}
