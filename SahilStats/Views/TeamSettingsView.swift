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
    @State private var selectedPhotoItems: [String: PhotosPickerItem] = [:]  // One PhotosPickerItem per team
    @State private var showPickerForTeamId: String?  // Which team's picker to show
    @State private var uploadError: String?
    @State private var showingUploadError = false
    
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

                                    // Logo upload/remove buttons
                                    if editingTeam?.id != team.id {
                                        HStack(spacing: 8) {
                                            // Upload/Change logo button
                                            Button(action: {
                                                debugPrint("🎯 Logo button tapped for team: \(team.name) (id: \(team.id ?? "nil"))")
                                                showPickerForTeamId = team.id
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: team.logoURL == nil ? "photo.badge.plus" : "photo.badge.arrow.down")
                                                        .font(.caption2)
                                                    Text(team.logoURL == nil ? "Add Logo" : "Change Logo")
                                                        .font(.caption)
                                                }
                                                .foregroundColor(.orange)
                                            }
                                            .buttonStyle(.plain)
                                            .photosPicker(
                                                isPresented: Binding(
                                                    get: { showPickerForTeamId == team.id },
                                                    set: { isPresented in
                                                        if !isPresented {
                                                            debugPrint("🔚 Photo picker dismissed for team: \(team.name)")
                                                            showPickerForTeamId = nil
                                                        }
                                                    }
                                                ),
                                                selection: Binding(
                                                    get: { selectedPhotoItems[team.id ?? ""] },
                                                    set: { newItem in
                                                        if let teamId = team.id {
                                                            selectedPhotoItems[teamId] = newItem
                                                            debugPrint("📸 Photo selected for team: \(team.name) - item: \(newItem != nil ? "YES" : "NO")")
                                                        }
                                                    }
                                                ),
                                                matching: .images
                                            )

                                            // Remove logo button (only show if logo exists)
                                            if team.logoURL != nil {
                                                Button(action: {
                                                    removeLogo(for: team)
                                                }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "trash")
                                                            .font(.caption2)
                                                        Text("Remove")
                                                            .font(.caption)
                                                    }
                                                    .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
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
                                HStack(spacing: 8) {
                                    Button(action: {
                                        startEditing(team)
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .controlSize(.small)

                                    Button(action: {
                                        teamToDelete = team
                                        showingDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .controlSize(.small)
                                }
                            }
                            }

                            // Upload progress indicator
                            if logoUploadManager.isUploading && showPickerForTeamId == team.id {
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
        .onChange(of: selectedPhotoItems) { oldValue, newValue in
            // Find which team had a new photo selected
            for (teamId, photoItem) in newValue {
                // Check if this is a new selection (wasn't in old value)
                if oldValue[teamId] == nil && photoItem != nil {
                    // Find the team
                    if let team = firebaseService.teams.first(where: { $0.id == teamId }) {
                        debugPrint("🎯 Uploading photo for team: \(team.name) (id: \(teamId))")
                        Task {
                            await handleLogoSelection(for: team, photoItem: photoItem, teamId: teamId)
                        }
                    }
                    break
                }
            }
        }
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
        .alert("Upload Failed", isPresented: $showingUploadError) {
            Button("OK", role: .cancel) {
                uploadError = nil
            }
        } message: {
            if let error = uploadError {
                Text(error)
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

    private func handleLogoSelection(for team: Team, photoItem: PhotosPickerItem, teamId: String) async {
        do {
            debugPrint("📸 Starting logo upload for team: \(team.name) (id: \(teamId))")

            // Load image from PhotosPicker
            guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                throw NSError(domain: "TeamSettings", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data from photo picker"])
            }

            debugPrint("✅ Image data loaded: \(imageData.count) bytes")

            guard let image = UIImage(data: imageData) else {
                throw NSError(domain: "TeamSettings", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create UIImage from data"])
            }

            debugPrint("✅ UIImage created: \(image.size.width)×\(image.size.height)")

            // Upload to Firebase Storage
            debugPrint("📤 Uploading to Firebase Storage...")
            let downloadURL = try await logoUploadManager.uploadTeamLogo(image, teamId: teamId)

            debugPrint("✅ Upload complete! URL: \(downloadURL)")

            // Update team with logo URL
            var updatedTeam = team
            updatedTeam.logoURL = downloadURL

            debugPrint("💾 Updating team in Firestore...")
            try await firebaseService.updateTeam(updatedTeam)

            debugPrint("✅ Team logo updated successfully in Firestore")

            // Clear this team's selection
            selectedPhotoItems[teamId] = nil
            showPickerForTeamId = nil

        } catch {
            debugPrint("❌ Logo upload failed: \(error)")
            debugPrint("   Error description: \(error.localizedDescription)")

            // Show error to user
            uploadError = "Failed to upload logo: \(error.localizedDescription)"
            showingUploadError = true

            // Clear selection even on error
            selectedPhotoItems[teamId] = nil
            showPickerForTeamId = nil
        }
    }

    private func removeLogo(for team: Team) {
        guard let teamId = team.id else {
            debugPrint("❌ Missing team ID for logo removal")
            return
        }

        Task {
            do {
                debugPrint("🗑️ Removing logo for team: \(team.name) (id: \(teamId))")

                // Delete from Firebase Storage
                try await logoUploadManager.deleteTeamLogo(teamId: teamId)
                debugPrint("✅ Logo deleted from Firebase Storage")

                // Update team to remove logo URL
                var updatedTeam = team
                updatedTeam.logoURL = nil

                debugPrint("💾 Updating team in Firestore...")
                try await firebaseService.updateTeam(updatedTeam)

                debugPrint("✅ Team logo removed successfully")

            } catch {
                debugPrint("❌ Logo removal failed: \(error)")
                debugPrint("   Error description: \(error.localizedDescription)")

                // Show error to user
                uploadError = "Failed to remove logo: \(error.localizedDescription)"
                showingUploadError = true
            }
        }
    }
}
