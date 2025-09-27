// File: SahilStats/Views/GameSetupView.swift (Fixed Version)

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth
import CoreLocation
import UIKit

struct GameSetupView: View  {
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
    @State private var isCreatingMultiDeviceGame = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    @StateObject private var locationManager = LocationManager.shared
    
    enum SetupMode {
        case selection      // Choose setup type
        case recording      // Recording device role selection
        case gameForm       // Game configuration form
        case smartJoin      // Smart join existing game
    }
    
    enum DeviceRole {
        case none
        case recorder      // iPhone for recording
        case controller    // iPad for scoring/control
        case viewer
    }
    
    var body: some View {
        Group {
            switch setupMode {
            case .selection:
                setupModeSelection
            case .recording:
                recordingRoleSelection
            case .gameForm:
                gameConfigurationForm
            case .smartJoin:
                smartJoinGameView
            }
        }
        .navigationTitle("Game Setup")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            firebaseService.startListening()
            loadDefaultSettings()
        }
        .fullScreenCover(isPresented: $showingPostGameView) {
            PostGameFullScreenWrapper(gameConfig: gameConfig) {
                showingPostGameView = false
            }
        }
        .fullScreenCover(isPresented: $showingLiveGameView) {
            LiveGameFullScreenWrapper {
                showingLiveGameView = false
            }
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
    }
    
    
    @ViewBuilder
    private var gameConfigurationForm: some View {
        Form {
            // Date and Time
            Section("When") {
                DatePicker("Date", selection: $gameConfig.date, displayedComponents: .date)
                DatePicker("Time", selection: $gameConfig.date, displayedComponents: .hourAndMinute)
            }
            
            // Teams
            Section("Teams") {
                // Team name input
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
                
/*
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
 */
                
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
                        handleSubmit(mode: .live, isMultiDevice: isCreatingMultiDeviceGame)
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                } else {
                    Button("Enter Game Stats") {
                        handleSubmit(mode: .postGame, isMultiDevice: false)
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                }
                
                Button("Cancel") {
                    if setupMode == .gameForm {
                        setupMode = .selection
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            }
        }
        .navigationBarBackButtonHidden()
        .alert("Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
    }
    // MARK: - FIXED: Setup Mode Selection
    
    @ViewBuilder
    private var setupModeSelection: some View {
        VStack(spacing: 16) {
            // 1. Post-Game Stats
            SetupOptionCard(
                title: "Enter Final Stats",
                subtitle: "For games that are already complete",
                icon: "chart.bar.fill",
                color: .green,
                status: "Quick stat entry after the game",
                statusColor: .green
            ) {
                self.setupMode = .gameForm
                self.deviceRole = .none
                self.isCreatingMultiDeviceGame = false
            }

            // 2. Stats-Only Live Game
            SetupOptionCard(
                title: "Track Stats Live",
                subtitle: "Use this device to score the game",
                icon: "stopwatch.fill",
                color: .orange,
                status: "Single device, no recording",
                statusColor: .orange
            ) {
                self.isCreatingMultiDeviceGame = false
                self.setupMode = .gameForm
                self.deviceRole = .controller
            }

            // 3. FIXED: Multi-Device Recording Session
            SetupOptionCard(
                title: "Multi-Device Recording",
                subtitle: "Record video + control scoring separately",
                icon: "video.fill",
                color: .red,
                status: "Choose recorder or controller role",
                statusColor: .red
            ) {
                self.isCreatingMultiDeviceGame = true
                self.setupMode = .recording // Go to role selection first
                self.deviceRole = .none
            }

            // 4. FIXED: Smart Join Live Game
            if firebaseService.hasLiveGame {
                SetupOptionCard(
                    title: "Join Live Game",
                    subtitle: getCurrentLiveGameInfo(),
                    icon: "antenna.radiowaves.left.and.right",
                    color: .blue,
                    status: "A game is in progress!",
                    statusColor: .blue
                ) {
                    self.setupMode = .smartJoin // Go to smart join logic
                }
            }
        }
        .padding()
    }
    // MARK: - NEW: Smart Join Helper Methods
    
    private func getCurrentLiveGameInfo() -> String {
        guard let liveGame = firebaseService.getCurrentLiveGame() else {
            return "Connect to ongoing game"
        }
        return "\(liveGame.teamName) vs \(liveGame.opponent)"
    }
    
    private func getAvailableRoles() -> [DeviceRoleManager.DeviceRole] {
        guard let liveGame = firebaseService.getCurrentLiveGame() else {
            return []
        }
        
        var availableRoles: [DeviceRoleManager.DeviceRole] = []
        
        // Check if controller slot is available
        if liveGame.controllingDeviceId == nil || liveGame.controllingUserEmail == nil {
            availableRoles.append(.controller)
        }
        
        // Always allow viewers
        availableRoles.append(.viewer)
        
        // Check if this is a multi-device game that needs a recorder
        if liveGame.isMultiDeviceSetup == true {
            // Check if recorder slot is available (you'd need to track this in your LiveGame model)
            // For now, always allow recorder if it's multi-device
            availableRoles.append(.recorder)
        }
        
        return availableRoles
    }
    
    private func joinGameWithRole(_ role: DeviceRoleManager.DeviceRole) {
        Task {
            do {
                guard let liveGame = firebaseService.getCurrentLiveGame(),
                      let gameId = liveGame.id else {
                    throw LiveGameError.gameNotFound
                }
                
                try await DeviceRoleManager.shared.setDeviceRole(role, for: gameId)
                
                await MainActor.run {
                    showingLiveGameView = true
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to join game: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func joinAsRecorder() {
        Task {
            do {
                guard let liveGame = firebaseService.getCurrentLiveGame(),
                      let gameId = liveGame.id else {
                    throw LiveGameError.gameNotFound
                }
                
                try await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                
                await MainActor.run {
                    showingLiveGameView = true
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to join as recorder: \(error.localizedDescription)"
                }
            }
        }
    }
    // MARK: - FIXED: Multi-Device Role Selection
    
    @ViewBuilder
    private var recordingRoleSelection: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.title) // Match the font size to the text for alignment
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            
                        Text("Multi-Device Setup")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                
                Text("Choose your device's role for this multi-device recording session")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 16) {
                // Controller role - CREATE the game
                DeviceRoleCard(
                    role: .controller,
                    isSelected: deviceRole == .controller,
                    isIPad: isIPad
                ) {
                    deviceRole = .controller
                    setupMode = .gameForm // Go to game form to CREATE the game
                }
                
                // Recorder role - JOIN existing game
                DeviceRoleCard(
                    role: .recorder,
                    isSelected: deviceRole == .recorder,
                    isIPad: isIPad
                ) {
                    deviceRole = .recorder
                    // For recorder in multi-device setup, they need to wait for controller to create game
                    if firebaseService.hasLiveGame {
                        // Join existing game as recorder
                        joinAsRecorder()
                    } else {
                        error = "No live game found. Ask the controller to start the game first, then try joining as a recorder."
                    }
                }
            }
            
            Spacer()
            
            Button("Back to Setup Options") {
                setupMode = .selection
                deviceRole = .none
            }
            .buttonStyle(ToolbarPillButtonStyle(isIPad: isIPad))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - NEW: Smart Join Game View
    
    @ViewBuilder
    private var smartJoinGameView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Join Live Game")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let liveGame = firebaseService.getCurrentLiveGame() {
                    Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 40)
            
            // SMART: Show available roles based on what's already taken
            VStack(spacing: 16) {
                let availableRoles = getAvailableRoles()
                
                ForEach(availableRoles, id: \.self) { role in
                    SmartJoinRoleCard(
                        role: role,
                        isIPad: isIPad,
                        onSelect: {
                            joinGameWithRole(role)
                        }
                    )
                }
                
                if availableRoles.isEmpty {
                    Text("All roles are currently filled")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            
            Spacer()
            
            Button("Back to Setup Options") {
                setupMode = .selection
            }
            .buttonStyle(ToolbarPillButtonStyle(isIPad: isIPad))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadDefaultSettings() {
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
    
    private func generateGameId() -> String {
        let timestamp = Date().timeIntervalSince1970
        return "game-\(Int(timestamp).description.suffix(6))"
    }
    
    private func getAutoLocation() {
        locationManager.requestLocation()
    }
    
    // MARK: - 3. Update handleSubmit in GameSetupView.swift to support multi-device

    private func handleSubmit(mode: GameSubmissionMode, isMultiDevice: Bool) {
        guard !gameConfig.teamName.isEmpty && !gameConfig.opponent.isEmpty else {
            error = "Please enter team name and opponent"
            return
        }
        
        Task {
            do {
                switch mode {
                case .live:
                    let liveGame = try await createLiveGame(isMultiDevice: isMultiDevice)
                    if let gameId = liveGame.id {
                        // Set device role based on selection
                        let selectedRole: DeviceRoleManager.DeviceRole = deviceRole == .controller ? .controller : .controller
                        try await DeviceRoleManager.shared.setDeviceRole(selectedRole, for: gameId)
                    }
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
    
    private func createLiveGame(isMultiDevice: Bool) async throws -> LiveGame {
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
        
        liveGame.isMultiDeviceSetup = isMultiDevice
        
        let createdGameId = try await firebaseService.createLiveGame(liveGame)
        liveGame.id = createdGameId
        
        return liveGame
    }
    
    private func addNewTeam() {
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

//MARK: smart join role card
struct SmartJoinRoleCard: View {
    let role: DeviceRoleManager.DeviceRole
    let isIPad: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: role.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(role.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Join as \(role.displayName)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(role.joinDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
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

// MARK: - Supporting Views

struct PostGameFullScreenWrapper: View {
    let gameConfig: GameConfig
    let onDismiss: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                PostGameNavigationBar(onDismiss: onDismiss, isIPad: isIPad)
                PostGameStatsView(gameConfig: gameConfig)
                    .navigationBarHidden(true)
            }
        }
        .navigationBarHidden(true)
    }
}

struct PostGameNavigationBar: View {
    let onDismiss: () -> Void
    let isIPad: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(isIPad ? .title2 : .title3)
                    .foregroundColor(.orange)
                
                Text("Enter Game Stats")
                    .font(isIPad ? .largeTitle : .title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("Done")
            }
            .buttonStyle(PillButtonStyle(isIPad: isIPad))
        }
        .padding(.horizontal, isIPad ? 28 : 24)
        .padding(.top, isIPad ? 24 : 20)
        .padding(.bottom, isIPad ? 20 : 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                .ignoresSafeArea(.container, edges: .top)
        )
    }
}


struct LiveGameFullScreenWrapper: View {
    let onDismiss: () -> Void
    
    // 1. The wrapper now owns the state objects
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @State private var showingRoleSelection = false

    var body: some View {
        VStack(spacing: 0) {
            // 2. Only show navigation bar for non-recorder roles
            if roleManager.deviceRole != .recorder {
                LiveGameNavigationBar(
                    liveGame: firebaseService.getCurrentLiveGame(),
                    role: roleManager.deviceRole,
                    onDone: onDismiss,
                    onSelectRole: { showingRoleSelection = true }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).shadow(color: .black.opacity(0.1), radius: 2, y: 1))
            }

            // 3. The main view receives the data and a binding
            LiveGameView()
        }
        .navigationBarHidden(true)
        .statusBarHidden(roleManager.deviceRole == .recorder) // Hide status bar for recorder
        .ignoresSafeArea(.all, edges: .bottom)
        .sheet(isPresented: $showingRoleSelection) {
            if let liveGame = firebaseService.getCurrentLiveGame() {
                DeviceRoleSelectionView(liveGame: liveGame)
            }
        }
    }
}


// MARK: - Reusable Navigation Bar
struct LiveGameNavigationBar: View {
    // Properties to receive data
    let liveGame: LiveGame?
    let role: DeviceRoleManager.DeviceRole
    // Actions
    let onDone: () -> Void
    let onSelectRole: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(liveGame != nil ? "Live Game" : "Game Setup")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if let game = liveGame {
                    Text("\(game.teamName) vs \(game.opponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if role == .none {
                Button("Select Role") {
                    onSelectRole()
                }
                .buttonStyle(ToolbarPillButtonStyle(isIPad: isIPad))
            }

            Button("Done") {
                onDone()
            }
            .buttonStyle(ToolbarPillButtonStyle(isIPad: isIPad))
        }
    }
}


// MARK: - Supporting Models (keep these as they are)

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

// MARK: - Missing Views

struct DeviceRoleCard: View {
    let role: GameSetupView.DeviceRole
    let isSelected: Bool
    let isIPad: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isIPad ? 20 : 16) {
                // Icon
                Image(systemName: roleIcon)
                    .font(.system(size: isIPad ? 40 : 32))
                    .foregroundColor(isSelected ? .white : roleColor)
                
                // Title and description
                VStack(spacing: isIPad ? 8 : 6) {
                    Text(roleTitle)
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(roleDescription)
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
            }
            .frame(maxWidth: .infinity)
            .padding(isIPad ? 32 : 24)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                    .fill(isSelected ? roleColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                    .stroke(isSelected ? roleColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var roleIcon: String {
        switch role {
        case .controller: return "gamecontroller.fill"
        case .recorder: return "video.fill"
        case .viewer: return "eye.fill"
        case .none: return "questionmark"
        }
    }
    
    private var roleColor: Color {
        switch role {
        case .controller: return .blue
        case .recorder: return .red
        case .viewer: return .green
        case .none: return .gray
        }
    }
    
    private var roleTitle: String {
        switch role {
        case .controller: return "Controller"
        case .recorder: return "Recorder"
        case .viewer: return "Viewer"
        case .none: return "Unknown"
        }
    }
    
    private var roleDescription: String {
        switch role {
        case .controller: return "Control the scoreboard"
        case .recorder: return "Record video"
        case .viewer: return "View the game in real-time"
        case .none: return ""
        }
    }
    
    private var deviceRecommendation: String {
        switch role {
        case .controller: return "Recommended for iPad"
        case .recorder: return "Recommended for iPhone"
        case .viewer: return "Recommended for iPad"
        case .none: return ""
        }
    }
}



struct DeviceRoleSelectionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
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
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
