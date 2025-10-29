//
//  TeamSettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 10/4/25.
//

import SwiftUI
import Combine

struct TeamsSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var logoUploadManager = LogoUploadManager.shared
    private let photoPickerCoordinator = PhotoPickerCoordinator()
    @State private var newTeamName = ""
    @State private var newOpponentName = ""
    @State private var showingDeleteAlert = false
    @State private var teamToDelete: Team?
    @State private var opponentToDelete: Opponent?
    @State private var editingTeam: Team?
    @State private var editingOpponent: Opponent?
    @State private var editingTeamName = ""
    @State private var editingOpponentName = ""
    @State private var teamForLogoUpload: Team?
    @State private var opponentForLogoUpload: Opponent?
    @State private var uploadError: String?
    @State private var showingUploadError = false
    @State private var isMigrating = false
    @State private var showingMigrationSuccess = false

    var body: some View {
        List {
            // Migration section (show if opponents are empty but games exist)
            if firebaseService.opponents.isEmpty && !firebaseService.games.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Opponents from Games")
                            .font(.headline)
                        Text("Automatically create opponent records from your existing games")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            migrateOpponents()
                        }) {
                            HStack {
                                if isMigrating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(isMigrating ? "Importing..." : "Import Opponents")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isMigrating)
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Quick Setup")
                }
            }

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
                Text("Add New Team (Sahil's Teams)")
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
                                                teamForLogoUpload = team

                                                photoPickerCoordinator.presentPicker { image in
                                                    guard let capturedTeam = teamForLogoUpload else {
                                                        debugPrint("⚠️ Team lost during photo selection")
                                                        return
                                                    }

                                                    Task {
                                                        await handleLogoSelection(
                                                            image: image,
                                                            teamId: capturedTeam.id ?? "",
                                                            teamName: capturedTeam.name
                                                        )
                                                    }
                                                }
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
                Text("Sahil's Teams")
            }

            // MARK: - Opponents Section

            Section {
                HStack {
                    TextField("Opponent name", text: $newOpponentName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addOpponent()
                    }
                    .disabled(newOpponentName.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }
            } header: {
                Text("Add New Opponent")
            }

            Section {
                if firebaseService.opponents.isEmpty {
                    Text("No opponents yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(firebaseService.opponents) { opponent in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Opponent logo (if available)
                                if let logoURL = opponent.logoURL {
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
                                    if editingOpponent?.id == opponent.id {
                                        TextField("Opponent name", text: $editingOpponentName)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        Text(opponent.name)
                                            .font(.headline)
                                    }

                                    // Logo upload/remove buttons
                                    if editingOpponent?.id != opponent.id {
                                        HStack(spacing: 8) {
                                            // Upload/Change logo button
                                            Button(action: {
                                                debugPrint("🎯 Logo button tapped for opponent: \(opponent.name)")
                                                opponentForLogoUpload = opponent

                                                photoPickerCoordinator.presentPicker { image in
                                                    guard let capturedOpponent = opponentForLogoUpload else {
                                                        debugPrint("⚠️ Opponent lost during photo selection")
                                                        return
                                                    }

                                                    Task {
                                                        await handleOpponentLogoSelection(
                                                            image: image,
                                                            opponentId: capturedOpponent.id ?? "",
                                                            opponentName: capturedOpponent.name
                                                        )
                                                    }
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: opponent.logoURL == nil ? "photo.badge.plus" : "photo.badge.arrow.down")
                                                        .font(.caption2)
                                                    Text(opponent.logoURL == nil ? "Add Logo" : "Change Logo")
                                                        .font(.caption)
                                                }
                                                .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)

                                            // Remove logo button (only show if logo exists)
                                            if opponent.logoURL != nil {
                                                Button(action: {
                                                    removeOpponentLogo(for: opponent)
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

                            if editingOpponent?.id == opponent.id {
                                Button("Save") {
                                    saveOpponentEdit(opponent)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .controlSize(.small)
                                .disabled(editingOpponentName.isEmpty)

                                Button("Cancel") {
                                    cancelOpponentEdit()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        startEditingOpponent(opponent)
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .controlSize(.small)

                                    Button(action: {
                                        opponentToDelete = opponent
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
                            if logoUploadManager.isUploading && opponentForLogoUpload?.id == opponent.id {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: logoUploadManager.uploadProgress)
                                        .progressViewStyle(.linear)
                                    Text("Uploading logo... \(Int(logoUploadManager.uploadProgress * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 48) // Align with opponent name
                            }
                        }
                    }
                }
            } header: {
                Text("Opponents")
            }
        }
        .navigationTitle("Teams & Opponents")
        .alert("Delete \(teamToDelete != nil ? "Team" : "Opponent")", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                teamToDelete = nil
                opponentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let team = teamToDelete {
                    deleteTeam(team)
                } else if let opponent = opponentToDelete {
                    deleteOpponent(opponent)
                }
                teamToDelete = nil
                opponentToDelete = nil
            }
        } message: {
            if let team = teamToDelete {
                Text("Are you sure you want to delete \(team.name)? This action cannot be undone.")
            } else if let opponent = opponentToDelete {
                Text("Are you sure you want to delete \(opponent.name)? This action cannot be undone.")
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
        .alert("Import Complete", isPresented: $showingMigrationSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Successfully imported \(firebaseService.opponents.count) opponents from your games. You can now upload logos for them!")
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

    private func handleLogoSelection(image: UIImage, teamId: String, teamName: String) async {
        do {
            debugPrint("📸 Starting logo upload for team: \(teamName) (id: \(teamId))")
            debugPrint("✅ UIImage: \(image.size.width)×\(image.size.height)")

            // Upload to Firebase Storage
            debugPrint("📤 Uploading to Firebase Storage...")
            let downloadURL = try await logoUploadManager.uploadTeamLogo(image, teamId: teamId)

            debugPrint("✅ Upload complete! URL: \(downloadURL)")

            // Find and update the team
            guard let team = firebaseService.teams.first(where: { $0.id == teamId }) else {
                throw NSError(domain: "TeamSettings", code: 3, userInfo: [NSLocalizedDescriptionKey: "Team not found in local cache"])
            }

            var updatedTeam = team
            updatedTeam.logoURL = downloadURL

            debugPrint("💾 Updating team in Firestore...")
            try await firebaseService.updateTeam(updatedTeam)

            debugPrint("✅ Team logo updated successfully in Firestore")

            // Clear selection
            teamForLogoUpload = nil

        } catch {
            debugPrint("❌ Logo upload failed: \(error)")
            debugPrint("   Error description: \(error.localizedDescription)")

            // Show error to user
            uploadError = "Failed to upload logo: \(error.localizedDescription)"
            showingUploadError = true

            // Clear selection even on error
            teamForLogoUpload = nil
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

    // MARK: - Opponent Functions

    private func addOpponent() {
        guard !newOpponentName.isEmpty else { return }
        let opponent = Opponent(name: newOpponentName)
        Task {
            do {
                try await firebaseService.addOpponent(opponent)
                newOpponentName = ""
            } catch {
                debugPrint("Failed to add opponent: \(error)")
            }
        }
    }

    private func deleteOpponent(_ opponent: Opponent) {
        Task {
            do {
                try await firebaseService.deleteOpponent(opponent.id ?? "")
            } catch {
                debugPrint("Failed to delete opponent: \(error)")
            }
        }
    }

    private func startEditingOpponent(_ opponent: Opponent) {
        editingOpponent = opponent
        editingOpponentName = opponent.name
    }

    private func cancelOpponentEdit() {
        editingOpponent = nil
        editingOpponentName = ""
    }

    private func saveOpponentEdit(_ opponent: Opponent) {
        guard !editingOpponentName.isEmpty else { return }
        var updatedOpponent = opponent
        updatedOpponent.name = editingOpponentName

        Task {
            do {
                try await firebaseService.updateOpponent(updatedOpponent)
                editingOpponent = nil
                editingOpponentName = ""
            } catch {
                debugPrint("Failed to update opponent: \(error)")
            }
        }
    }

    private func handleOpponentLogoSelection(image: UIImage, opponentId: String, opponentName: String) async {
        do {
            debugPrint("📸 Starting logo upload for opponent: \(opponentName) (id: \(opponentId))")
            debugPrint("✅ UIImage: \(image.size.width)×\(image.size.height)")

            // Upload to Firebase Storage (using same function as teams, just different ID)
            debugPrint("📤 Uploading to Firebase Storage...")
            let downloadURL = try await logoUploadManager.uploadTeamLogo(image, teamId: opponentId)

            debugPrint("✅ Upload complete! URL: \(downloadURL)")

            // Find and update the opponent
            guard let opponent = firebaseService.opponents.first(where: { $0.id == opponentId }) else {
                throw NSError(domain: "TeamSettings", code: 3, userInfo: [NSLocalizedDescriptionKey: "Opponent not found in local cache"])
            }

            var updatedOpponent = opponent
            updatedOpponent.logoURL = downloadURL

            debugPrint("💾 Updating opponent in Firestore...")
            try await firebaseService.updateOpponent(updatedOpponent)

            debugPrint("✅ Opponent logo updated successfully in Firestore")

            // Clear selection
            opponentForLogoUpload = nil

        } catch {
            debugPrint("❌ Logo upload failed: \(error)")
            debugPrint("   Error description: \(error.localizedDescription)")

            // Show error to user
            uploadError = "Failed to upload logo: \(error.localizedDescription)"
            showingUploadError = true

            // Clear selection even on error
            opponentForLogoUpload = nil
        }
    }

    private func removeOpponentLogo(for opponent: Opponent) {
        guard let opponentId = opponent.id else {
            debugPrint("❌ Missing opponent ID for logo removal")
            return
        }

        Task {
            do {
                debugPrint("🗑️ Removing logo for opponent: \(opponent.name) (id: \(opponentId))")

                // Delete from Firebase Storage
                try await logoUploadManager.deleteTeamLogo(teamId: opponentId)
                debugPrint("✅ Logo deleted from Firebase Storage")

                // Update opponent to remove logo URL
                var updatedOpponent = opponent
                updatedOpponent.logoURL = nil

                debugPrint("💾 Updating opponent in Firestore...")
                try await firebaseService.updateOpponent(updatedOpponent)

                debugPrint("✅ Opponent logo removed successfully")

            } catch {
                debugPrint("❌ Logo removal failed: \(error)")
                debugPrint("   Error description: \(error.localizedDescription)")

                // Show error to user
                uploadError = "Failed to remove logo: \(error.localizedDescription)"
                showingUploadError = true
            }
        }
    }

    // MARK: - Migration

    private func migrateOpponents() {
        isMigrating = true

        Task {
            do {
                try await firebaseService.migrateOpponentsFromGames()

                await MainActor.run {
                    isMigrating = false
                    showingMigrationSuccess = true
                }
            } catch {
                debugPrint("❌ Migration failed: \(error)")

                await MainActor.run {
                    isMigrating = false
                    uploadError = "Failed to import opponents: \(error.localizedDescription)"
                    showingUploadError = true
                }
            }
        }
    }
}
