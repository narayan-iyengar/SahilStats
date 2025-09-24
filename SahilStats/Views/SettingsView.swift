//
//  SettingsView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/17/25.
//
// File: SahilStats/Views/SettingsView.swift (Enhanced)

import SwiftUI
import FirebaseAuth
import FirebaseCore
import Combine

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingAuth = false
    @State private var newTeamName = ""
    @State private var showingDeleteAlert = false
    @State private var teamToDelete: Team?
    @State private var showingDeleteLiveGamesAlert = false
    @State private var showingDeviceManager = false
    
    var body: some View {
        List {
            // Account Section
            Section("Account") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(authService.userRole.displayName)
                        .foregroundColor(.secondary)
                }
                
                if authService.isSignedIn && !authService.currentUser!.isAnonymous {
                    if let email = authService.currentUser?.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Sign Out") {
                        Task {
                            try? await authService.signOut()
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Sign In") {
                        showingAuth = true
                    }
                    .foregroundColor(.orange)
                }
            }
            
            // Teams Section (Admin only)
            if authService.showAdminFeatures {
                Section("Teams") {
                    // Add new team
                    HStack {
                        TextField("Add new team", text: $newTeamName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            addTeam()
                        }
                        .disabled(newTeamName.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    // List existing teams
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
            }
            
            // Game Format Section (Admin only)
            if authService.showAdminFeatures {
                Section("Game Format") {
                    // Format selection
                    Picker("Format", selection: $settingsManager.gameFormat) {
                        Text("Periods").tag(GameFormat.periods)
                        Text("Halves").tag(GameFormat.halves)
                    }
                    .pickerStyle(.segmented)
                    
                    // Period/Half length
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Length (minutes per \(settingsManager.gameFormat.periodName.lowercased()))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("Minutes", value: $settingsManager.periodLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                            
                            Text("minutes")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Live Games Management
                Section("Live Games") {
                    if firebaseService.hasLiveGame {
                        Text("There is currently a live game in progress")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No live games currently running")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Delete All Live Games") {
                        showingDeleteLiveGamesAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            if authService.showAdminFeatures {
                Section("Media & Recording") {
                    MediaAccessStatus()
                    
                    Button("Manage Connected Devices") {
                        // Show device manager if in live game
                        if firebaseService.hasLiveGame {
                            showingDeviceManager = true
                        }
                    }
                    .disabled(!firebaseService.hasLiveGame)
                    
                    Button("Clear Recording Cache") {
                        // Clear temporary video files
                        clearRecordingCache()
                    }
                    .foregroundColor(.orange)
                }
            }
            .sheet(isPresented: $showingDeviceManager) {
                    if let liveGame = firebaseService.getCurrentLiveGame() {
                        DeviceManagerView(liveGame: liveGame)
                    }
                }
            // App Info Section
            Section("App Info") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.1")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Player")
                    Spacer()
                    Text("Sahil")
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAuth) {
            AuthView()
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
        .alert("Delete Live Games", isPresented: $showingDeleteLiveGamesAlert) {
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
    
    // MARK: - Helper Methods
    
    private func clearRecordingCache() {
        // Implementation to clear video cache
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoFiles = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
        
        videoFiles?.forEach { url in
            if url.pathExtension == "mov" {
                try? FileManager.default.removeItem(at: url)
            }
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

// MARK: - Settings Manager for Persistent Settings

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var gameFormat: GameFormat {
        didSet {
            UserDefaults.standard.set(gameFormat.rawValue, forKey: "gameFormat")
        }
    }
    
    @Published var periodLength: Int {
        didSet {
            UserDefaults.standard.set(periodLength, forKey: "periodLength")
        }
    }
    @Published var enableMultiDevice: Bool {
        didSet {
            UserDefaults.standard.set(enableMultiDevice, forKey: "enableMultiDevice")
        }
    }
/*
    @Published var autoScreenshots: Bool {
        didSet {
            UserDefaults.standard.set(autoScreenshots, forKey: "autoScreenshots")
        }
    }
 */

    @Published var videoQuality: String {
        didSet {
            UserDefaults.standard.set(videoQuality, forKey: "videoQuality")
        }
    }
    
    private init() {
        // Load saved settings or use defaults
        if let savedFormat = UserDefaults.standard.string(forKey: "gameFormat"),
           let format = GameFormat(rawValue: savedFormat) {
            self.gameFormat = format
        } else {
            self.gameFormat = .halves // Default to halves
        }
        
        let savedLength = UserDefaults.standard.integer(forKey: "periodLength")
        self.periodLength = savedLength > 0 ? savedLength : 20 // Default to 20 minutes
    }
    
    // Helper method to get default game settings for new games
    func getDefaultGameSettings() -> (format: GameFormat, length: Int) {
        return (gameFormat, periodLength)
    }
}

// MARK: - Enhanced Team Model (if needed)

extension Team {
    var gamesPlayed: Int {
        // This would need to be calculated from games where this team was used
        // For now, return 0 as placeholder
        return 0
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AuthService())
    }
}
