// File: SahilStats/Views/GameSetupView.swift (Fixed private function issues)

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth
import CoreLocation
import UIKit

struct GameSetupView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var setupMode: SetupMode = .selection
    @State private var deviceRole: DeviceRole = .none
    @State private var gameConfig = GameConfig()
    @State private var gameId = ""
    @State private var error = ""
    @State private var isGettingLocation = false
    @State private var newTeamName = ""
    @State private var showAddTeamInput = false
    @State private var showingPostGameView = false
    @State private var showingLiveGameView = false
    @State private var createdLiveGame: LiveGame?
    @State private var showingRoleSelection = false
    @State private var enableMultiDevice = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    @StateObject private var locationManager = LocationManager.shared
    
    enum SetupMode {
        case selection      // Choose setup type
        case recording      // Recording device role selection
        case gameForm      // Game configuration form
        case connecting    // Connecting to existing game
    }
    
    enum DeviceRole {
        case none
        case recorder      // iPhone for recording
        case controller    // iPad for scoring/control
    }
    
    var body: some View {
        Group {
            switch setupMode {
            case .selection:
                SetupModeSelection()
            case .recording:
                RecordingRoleSelection()
            case .gameForm:
                GameConfigurationForm()
            case .connecting:
                ConnectToGameView()
            }
        }
        .navigationTitle("Game Setup")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            firebaseService.startListening()
            loadDefaultSettings()
        }

        .fullScreenCover(isPresented: $showingPostGameView) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    PostGameStatsView(gameConfig: gameConfig)
                }
            } else {
                NavigationView {
                    PostGameStatsView(gameConfig: gameConfig)
                        .navigationViewStyle(StackNavigationViewStyle())
                }
            }
        }
 

        .fullScreenCover(isPresented: $showingLiveGameView) {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Navigation bar
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(0.8)
                                .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                            
                            Text("Live Game")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            showingLiveGameView = false
                        }
                        .buttonStyle(PillButtonStyle(isIPad: isIPad))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .background(
                        Color(.systemBackground)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    )
                    
                    // Main content
                    LiveGameView()
                        .environmentObject(authService)
                }
            }
            .navigationBarHidden(true)
        }
 
        .onChange(of: locationManager.locationName) { _, newLocation in
            if !newLocation.isEmpty {
                gameConfig.location = newLocation
            }
        }
        .onChange(of: locationManager.error) { _, error in
            if let error = error {
                self.error = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingRoleSelection) {
            if let liveGame = firebaseService.getCurrentLiveGame() {
                DeviceRoleSelectionView(liveGame: liveGame)
            }
        }
    }
    
    // MARK: - Setup Mode Selection
    
    func SetupModeSelection() -> some View {
        VStack(spacing: 16) {
            // Post-Game Stats Entry (existing)
            SetupOptionCard(
                title: "Enter Final Stats",
                subtitle: "Enter final score and stats",
                icon: "chart.bar.fill",
                color: .green,
                status: "Quick stat entry after the game",
                statusColor: .blue
            ) {
                setupMode = .gameForm
                deviceRole = .none
            }
            
            // Multi-Device Live Game
            MultiDeviceLiveGameCard(
                hasLiveGame: firebaseService.hasLiveGame,
                enableMultiDevice: $enableMultiDevice
            ) {
                if firebaseService.hasLiveGame {
                    showingLiveGameView = true
                } else {
                    setupMode = .gameForm
                    deviceRole = .controller
                }
            }
            
            // Join Existing Live Game
            if firebaseService.hasLiveGame {
                SetupOptionCard(
                    title: "Join Live Game",
                    subtitle: "Connect as recording or viewing device",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .blue,
                    status: "Multi-device support",
                    statusColor: .green
                ) {
                    showingRoleSelection = true
                }
            }
        }
    }
    
    // MARK: - Game Configuration Form
    
    func GameConfigurationForm() -> some View {
        Form {
            // Date and Time
            Section("When") {
                DatePicker("Date", selection: $gameConfig.date, displayedComponents: .date)
                DatePicker("Time", selection: $gameConfig.date, displayedComponents: .hourAndMinute)
            }
            
            // Teams
            Section("Teams") {
                // Sahil's Team
                if showAddTeamInput {
                    HStack {
                        TextField("New team name", text: $newTeamName)
                        
                        Button("Add") {
                            addNewTeam()
                        }
                        .disabled(newTeamName.isEmpty)
                        
                        Button("Cancel") {
                            showAddTeamInput = false
                            newTeamName = ""
                        }
                    }
                } else {
                    if firebaseService.teams.isEmpty {
                        TextField("Sahil's Team", text: $gameConfig.teamName)
                            .autocapitalization(.words)
                    } else {
                        Picker("Sahil's Team", selection: $gameConfig.teamName) {
                            ForEach(firebaseService.teams) { team in
                                Text(team.name).tag(team.name)
                            }
                            Text("Add New Team...").tag("__ADD_NEW__")
                        }
                        .onChange(of: gameConfig.teamName) { oldValue, newValue in
                            if newValue == "__ADD_NEW__" {
                                gameConfig.teamName = oldValue
                                showAddTeamInput = true
                            }
                        }
                    }
                }
                
                // Opponent
                TextField("Opponent Team", text: $gameConfig.opponent)
                    .autocapitalization(.words)
                
                // Opponent suggestions
                if !gameConfig.opponent.isEmpty {
                    let suggestions = getOpponentSuggestions()
                    ForEach(Array(suggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                        Button(action: {
                            gameConfig.opponent = suggestion
                        }) {
                            HStack {
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Use")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            // Location
            Section("Where") {
                HStack {
                    TextField("Location (optional)", text: $gameConfig.location)
                        .autocapitalization(.words)
                    
                    Button(action: getAutoLocation) {
                        if locationManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: locationManager.canRequestLocation ? "location.fill" : "location.slash")
                                .foregroundColor(locationManager.canRequestLocation ? .blue : .gray)
                        }
                    }
                    .disabled(locationManager.isLoading || !locationManager.canRequestLocation)
                }
                
                // Location suggestions
                if !gameConfig.location.isEmpty {
                    let suggestions = getLocationSuggestions()
                    ForEach(Array(suggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                        Button(action: {
                            gameConfig.location = suggestion
                        }) {
                            HStack {
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Use")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Show location status/error if needed
                if let error = locationManager.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        if locationManager.shouldShowSettingsAlert {
                            Button("Settings") {
                                locationManager.openLocationSettings()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Game Format (for live games only)
            if deviceRole == .controller {
                Section("Game Format") {
                    Picker("Format", selection: $gameConfig.gameFormat) {
                        ForEach(GameFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("\(gameConfig.gameFormat.periodName) Length")
                        Spacer()
                        TextField("Minutes", value: $gameConfig.periodLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Each \(gameConfig.gameFormat.periodName.lowercased()) will be \(gameConfig.periodLength) minutes long")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Game Actions
            Section {
                if deviceRole == .controller {
                    Button("Start Live Game") {
                        handleSubmit(mode: .live)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Enter Game Stats") {
                        handleSubmit(mode: .postGame)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Button("Cancel") {
                    if setupMode == .gameForm {
                        setupMode = .selection
                    } else {
                        dismiss()
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    setupMode = .selection
                    deviceRole = .none
                    gameId = ""
                }) {
                    Text("Back")
                        .fixedSize()
                }
                .buttonStyle(PillButtonStyle(isIPad: isIPad))
            }
        }
        .alert("Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
    }
    
    // MARK: - Recording Role Selection
    
    func RecordingRoleSelection() -> some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "video.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Recording Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Video recording with live overlays coming soon!")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            Spacer()
            
            Button("Back to Setup Options") {
                setupMode = .selection
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Connect to Game View
    
    func ConnectToGameView() -> some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "link")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Connect to Live Game")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Multi-device connection coming soon!")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            Spacer()
            
            Button("Back to Setup Options") {
                setupMode = .selection
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    func loadDefaultSettings() {
        let settings = settingsManager.getDefaultGameSettings()
        gameConfig.gameFormat = settings.format
        gameConfig.periodLength = settings.length
        
        if let firstTeam = firebaseService.teams.first {
            gameConfig.teamName = firstTeam.name
        }
        
        if deviceRole == .controller && gameId.isEmpty {
            gameId = generateGameId()
        }
    }
    
    func generateGameId() -> String {
        let timestamp = Date().timeIntervalSince1970
        return "game-\(Int(timestamp).description.suffix(6))"
    }
    
    func getAutoLocation() {
        locationManager.requestLocation()
    }
    
    func handleSubmit(mode: GameSubmissionMode) {
        guard !gameConfig.teamName.isEmpty && !gameConfig.opponent.isEmpty else {
            error = "Please enter team name and opponent"
            return
        }
        
        Task {
            do {
                switch mode {
                case .live:
                    let liveGame = try await createLiveGame()
                    await MainActor.run {
                        createdLiveGame = liveGame
                        showingLiveGameView = true
                    }
                case .postGame:
                    await MainActor.run {
                        showingPostGameView = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    func createLiveGame() async throws -> LiveGame {
        let deviceId = DeviceControlManager.shared.deviceId
        var liveGame = LiveGame(
            teamName: gameConfig.teamName,
            opponent: gameConfig.opponent,
            location: gameConfig.location.isEmpty ? nil : gameConfig.location,
            gameFormat: gameConfig.gameFormat,
            periodLength: gameConfig.periodLength,
            createdBy: authService.currentUser?.email,
            deviceId: deviceId
        )
        
        let createdGameId = try await firebaseService.createLiveGame(liveGame)
        liveGame.id = createdGameId
        
        return liveGame
    }
    
    func addNewTeam() {
        guard !newTeamName.isEmpty else { return }
        
        Task {
            do {
                let team = Team(name: newTeamName)
                try await firebaseService.addTeam(team)
                await MainActor.run {
                    gameConfig.teamName = newTeamName
                    newTeamName = ""
                    showAddTeamInput = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to add team: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func getOpponentSuggestions() -> [String] {
        let allOpponents = Set(firebaseService.games.compactMap { $0.opponent })
        return Array(allOpponents)
            .filter { $0.localizedCaseInsensitiveContains(gameConfig.opponent) }
            .prefix(3)
            .map { $0 }
    }
    
    func getLocationSuggestions() -> [String] {
        let allLocations = Set(firebaseService.games.compactMap { $0.location })
        return Array(allLocations)
            .filter { $0.localizedCaseInsensitiveContains(gameConfig.location) }
            .prefix(3)
            .map { $0 }
    }
}

// MARK: - Supporting Models and Views

struct GameConfig {
    var teamName = ""
    var opponent = ""
    var location = ""
    var date = Date()
    var gameFormat = GameFormat.halves
    var periodLength = 20
}

enum GameSubmissionMode {
    case live, postGame
}

// Multi-Device Live Game Card
struct MultiDeviceLiveGameCard: View {
    let hasLiveGame: Bool
    @Binding var enableMultiDevice: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "stopwatch.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(hasLiveGame ? Color.red : Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Live Game Tracking")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if hasLiveGame {
                                Text("• ACTIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text(hasLiveGame ?
                             "Join the current live game session" :
                             "Start live scoring with video recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Toggle("Enable multi-device recording", isOn: $enableMultiDevice)
                    .font(.caption)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct SetupOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let status: String
    let statusColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(status)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            GameSetupView()
                .environmentObject(AuthService())
        }
    } else {
        NavigationView {
            GameSetupView()
                .environmentObject(AuthService())
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
