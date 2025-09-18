//
//  GameSetupView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/18/25.
//

// File: SahilStats/Views/GameSetupView.swift

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth

struct GameSetupView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject var authService: AuthService
    @State private var setupMode: SetupMode = .selection
    @State private var deviceRole: DeviceRole = .none
    @State private var gameConfig = GameConfig()
    @State private var gameId = ""
    @State private var error = ""
    @State private var isGettingLocation = false
    @State private var newTeamName = ""
    @State private var showAddTeamInput = false
    
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
    }
    
    // MARK: - Setup Mode Selection
    
    private func SetupModeSelection() -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Game Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose how you want to set up today's game")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Live game status indicator
            if firebaseService.hasLiveGame {
                LiveGameStatusCard()
            }
            
            Spacer()
            
            // Setup options
            VStack(spacing: 16) {
                // Recording Setup Option
                SetupOptionCard(
                    title: "Recording Setup",
                    subtitle: "Multi-device recording with live score overlays",
                    icon: "video.fill",
                    color: .red,
                    status: firebaseService.hasLiveGame ? "Ready to join live game" : "Requires existing live game",
                    statusColor: firebaseService.hasLiveGame ? .green : .orange
                ) {
                    setupMode = .recording
                }
                
                // Traditional Scoring Setup
                SetupOptionCard(
                    title: "Scoring & Stats",
                    subtitle: "Live scoring or post-game stat entry",
                    icon: "chart.bar.fill",
                    color: .orange,
                    status: "Start new live game or enter final stats",
                    statusColor: .blue
                ) {
                    setupMode = .gameForm
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Recording Role Selection
    
    private func RecordingRoleSelection() -> some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "video.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Recording Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose this device's role")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            if !error.isEmpty {
                ErrorCard(message: error)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Recording Device Option
                DeviceRoleCard(
                    title: "Recording Device",
                    subtitle: "Record video with live score overlays",
                    icon: "camera.fill",
                    color: .red,
                    status: firebaseService.hasLiveGame ? "Live game available" : "No live game - need scoring device first",
                    statusColor: firebaseService.hasLiveGame ? .green : .orange
                ) {
                    handleDeviceRoleSelection(.recorder)
                }
                
                // Scoring Device Option
                DeviceRoleCard(
                    title: "Scoring Device",
                    subtitle: "Manage scoring and stats during the game",
                    icon: "gamecontroller.fill",
                    color: .green,
                    status: "Creates new live game for recording devices",
                    statusColor: .blue
                ) {
                    handleDeviceRoleSelection(.controller)
                }
            }
            
            // Setup instructions
            SetupInstructionsCard()
            
            Spacer()
            
            // Back button
            Button("Back to setup options") {
                setupMode = .selection
                error = ""
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Game Configuration Form
    
    private func GameConfigurationForm() -> some View {
        Form {
            // Game ID display for recording controller
            if deviceRole == .controller && !gameId.isEmpty {
                Section {
                    GameIdDisplayCard(gameId: gameId)
                }
            }
            
            // Date and Time
            Section {
                DatePicker("Date", selection: $gameConfig.date, displayedComponents: .date)
                DatePicker("Time", selection: $gameConfig.date, displayedComponents: .hourAndMinute)
            }
            
            // Teams
            Section("Teams") {
                // Sahil's Team
                if showAddTeamInput {
                    AddTeamInputRow()
                } else {
                    TeamSelectionRow()
                }
                
                // Opponent
                TextField("Opponent Team", text: $gameConfig.opponent)
                    .autocapitalization(.words)
                
                OpponentSuggestions()
            }
            
            // Location
            Section("Location") {
                HStack {
                    TextField("Location", text: $gameConfig.location)
                    
                    Button(action: getAutoLocation) {
                        Image(systemName: isGettingLocation ? "location.fill" : "location")
                            .foregroundColor(.blue)
                    }
                    .disabled(isGettingLocation)
                }
                
                LocationSuggestions()
            }
            
            // Game Actions
            Section {
                if deviceRole == .controller {
                    // Recording controller buttons
                    Button("Start Live Game & Recording") {
                        handleSubmit(mode: .liveRecording)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Enter Final Stats Only") {
                        handleSubmit(mode: .postGame)
                    }
                    .foregroundColor(.secondary)
                } else {
                    // Standard buttons
                    Button("Start Live Game") {
                        handleSubmit(mode: .live)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Enter Final Stats Only") {
                        handleSubmit(mode: .postGame)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    setupMode = .selection
                }
            }
        }
        .alert("Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
    }
    
    // MARK: - Connect to Game View
    
    private func ConnectToGameView() -> some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "link")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Connect to Live Game")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enter the game ID to join an existing live game")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 16) {
                TextField("Game ID (e.g., game-123456)", text: $gameId)
                    .textFieldStyle(.roundedBorder)
                    .font(.monospaced(.body)())
                
                Button("Connect to Game") {
                    connectToExistingGame()
                }
                .buttonStyle(.borderedProminent)
                .disabled(gameId.isEmpty)
            }
            .padding()
            
            InstructionCard(
                title: "When to use this:",
                instructions: [
                    "Someone else already started a live game",
                    "You want to view live stats on this device",
                    "Multiple people are tracking the same game",
                    "You're setting up a recording device"
                ]
            )
            
            Spacer()
            
            Button("Back to setup options") {
                setupMode = .selection
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadDefaultSettings() {
        let settings = settingsManager.getDefaultGameSettings()
        gameConfig.gameFormat = settings.format
        gameConfig.periodLength = settings.length
        
        // Set default team if available
        if let firstTeam = firebaseService.teams.first {
            gameConfig.teamName = firstTeam.name
        }
        
        // Generate game ID for controller role
        if deviceRole == .controller && gameId.isEmpty {
            gameId = generateGameId()
        }
    }
    
    private func generateGameId() -> String {
        let timestamp = Date().timeIntervalSince1970
        return "game-\(Int(timestamp).description.suffix(6))"
    }
    
    private func handleDeviceRoleSelection(_ role: DeviceRole) {
        deviceRole = role
        
        switch role {
        case .recorder:
            if firebaseService.hasLiveGame {
                // Navigate to recording view
                // TODO: Navigate to LiveGameRecordingView
                print("Navigate to recording view")
            } else {
                error = "No live game in progress. Someone needs to start a live game first using 'Scoring Device' option."
            }
            
        case .controller:
            gameId = generateGameId()
            setupMode = .gameForm
            
        case .none:
            break
        }
    }
    
    private func getAutoLocation() {
        isGettingLocation = true
        
        LocationManager.shared.requestLocation { location in
            DispatchQueue.main.async {
                gameConfig.location = location
                isGettingLocation = false
            }
        } onError: { error in
            DispatchQueue.main.async {
                self.error = "Unable to get location: \(error)"
                isGettingLocation = false
            }
        }
    }
    
    private func handleSubmit(mode: GameSubmissionMode) {
        guard !gameConfig.teamName.isEmpty && !gameConfig.opponent.isEmpty else {
            error = "Please enter team name and opponent"
            return
        }
        
        Task {
            do {
                switch mode {
                case .live:
                    try await createLiveGame()
                case .liveRecording:
                    try await createLiveGameWithRecording()
                case .postGame:
                    try await createPostGameEntry()
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func createLiveGame() async throws {
        let liveGame = LiveGame(
            teamName: gameConfig.teamName,
            opponent: gameConfig.opponent,
            location: gameConfig.location,
            gameFormat: gameConfig.gameFormat,
            periodLength: gameConfig.periodLength,
            createdBy: authService.currentUser?.email
        )
        
        let createdGameId = try await firebaseService.createLiveGame(liveGame)
        // TODO: Navigate to LiveGameAdminView with createdGameId
        print("Created live game: \(createdGameId)")
    }
    
    private func createLiveGameWithRecording() async throws {
        let liveGame = LiveGame(
            teamName: gameConfig.teamName,
            opponent: gameConfig.opponent,
            location: gameConfig.location,
            gameFormat: gameConfig.gameFormat,
            periodLength: gameConfig.periodLength,
            createdBy: authService.currentUser?.email
        )
        
        let createdGameId = try await firebaseService.createLiveGame(liveGame)
        // TODO: Navigate to LiveGameRecordingView with createdGameId
        print("Created live game with recording: \(createdGameId)")
    }
    
    private func createPostGameEntry() async throws {
        let game = Game(
            teamName: gameConfig.teamName,
            opponent: gameConfig.opponent,
            location: gameConfig.location,
            timestamp: gameConfig.date,
            gameFormat: gameConfig.gameFormat,
            periodLength: gameConfig.periodLength,
            adminName: authService.currentUser?.email
        )
        
        try await firebaseService.addGame(game)
        // TODO: Navigate to PostGameStatsView
        print("Created post-game entry")
    }
    
    private func connectToExistingGame() {
        // TODO: Connect to existing live game
        print("Connecting to game: \(gameId)")
    }
    
    private func addNewTeam() {
        guard !newTeamName.isEmpty else { return }
        
        Task {
            do {
                let team = Team(name: newTeamName)
                try await firebaseService.addTeam(team)
                gameConfig.teamName = newTeamName
                newTeamName = ""
                showAddTeamInput = false
            } catch {
                self.error = "Failed to add team: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Views

struct GameConfig {
    var teamName = ""
    var opponent = ""
    var location = ""
    var date = Date()
    var gameFormat = GameFormat.halves
    var periodLength = 20
}

enum GameSubmissionMode {
    case live, liveRecording, postGame
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
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct DeviceRoleCard: View {
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
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                
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
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LiveGameStatusCard: View {
    var body: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .opacity(0.8)
                .animation(.easeInOut(duration: 1).repeatForever(), value: true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Game In Progress")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text("You can join as a recording device or create a new game")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GameIdDisplayCard: View {
    let gameId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scoring Device Setup")
                .font(.headline)
                .foregroundColor(.green)
            
            Text("Share this Game ID with the recording device:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(gameId)
                    .font(.monospaced(.body)())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Copy") {
                    UIPasteboard.general.string = gameId
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SetupInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                Text("Setup Order:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. First device: Choose 'Scoring Device' to create live game")
                Text("2. Second device: Choose 'Recording Device' to join and record")
                Text("3. Score updates appear on recording automatically")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ErrorCard: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InstructionCard: View {
    let title: String
    let instructions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(instructions, id: \.self) { instruction in
                    Text("• \(instruction)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Form Helper Views

extension GameSetupView {
    private func TeamSelectionRow() -> some View {
        Group {
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
    }
    
    private func AddTeamInputRow() -> some View {
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
    }
    
    private func OpponentSuggestions() -> some View {
        Group {
            if !gameConfig.opponent.isEmpty {
                let suggestions = getOpponentSuggestions()
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    gameConfig.opponent = suggestion
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func LocationSuggestions() -> some View {
        Group {
            if !gameConfig.location.isEmpty {
                let suggestions = getLocationSuggestions()
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    gameConfig.location = suggestion
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func getOpponentSuggestions() -> [String] {
        let allOpponents = Set(firebaseService.games.compactMap { $0.opponent })
        return Array(allOpponents)
            .filter { $0.localizedCaseInsensitiveContains(gameConfig.opponent) }
            .prefix(3)
            .map { $0 }
    }
    
    private func getLocationSuggestions() -> [String] {
        let allLocations = Set(firebaseService.games.compactMap { $0.location })
        return Array(allLocations)
            .filter { $0.localizedCaseInsensitiveContains(gameConfig.location) }
            .prefix(3)
            .map { $0 }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private override init() {
        super.init()
    }
    
    func requestLocation(onSuccess: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        // TODO: Implement CoreLocation integration
        onError("Location services not yet implemented")
    }
}

#Preview {
    NavigationView {
        GameSetupView()
            .environmentObject(AuthService())
    }
}
