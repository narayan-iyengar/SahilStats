// SahilStats/Views/GameSetupView.swift

import SwiftUI

struct GameSetupView: View {
    @State private var setupMode: SetupMode = .selection
    @State private var showingConnectionWaitingRoom = false
    @State private var gameConfig = GameConfiguration() // Your existing game config model
    @State private var createdLiveGame: LiveGame?
    @State private var showingLiveGameView = false
    @State private var showingPostGameEntry = false
    @State private var isMultiDevice = false
    @State private var useCustomTeamName = false
    @State private var showLocationPermissionAlert = false

    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    enum SetupMode {
        case selection, gameForm, postGameForm
    }
    
    var body: some View {
        VStack {
            if setupMode == .selection {
                gameModeSelection
            } else if setupMode == .postGameForm {
                postGameConfigurationForm
            } else {
                gameConfigurationForm
            }
        }
        .navigationTitle("Game Setup")
        .sheet(isPresented: $showingConnectionWaitingRoom) {
            ConnectionWaitingRoomView()
        }
        .fullScreenCover(isPresented: $showingLiveGameView) {
            if let game = createdLiveGame {
                LiveGameView() // Your existing live game view
            }
        }
        .fullScreenCover(isPresented: $showingPostGameEntry) {
            PostGameStatsView(gameConfig: gameConfig)
        }
        .onChange(of: showingConnectionWaitingRoom) { wasShowing, isShowing in
            if wasShowing && !isShowing { // When the waiting room is dismissed
                if case .connected = multipeer.connectionState {
                    // Handshake complete for Controller, proceed to game form
                    print("✅ Handshake complete. Proceeding to create game.")
                    setupMode = .gameForm
                }
            }
        }
    }

    private var gameModeSelection: some View {
        VStack(spacing: 24) {
            Text("How do you want to enter stats?")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                // Option 1: Post-game stat entry (for games that already happened)
                Button(action: {
                    setupMode = .postGameForm
                }) {
                    HStack {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.title2)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enter Past Game Stats")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("For games that already happened")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Option 2: Live game tracking (single device)
                Button(action: {
                    isMultiDevice = false
                    setupMode = .gameForm
                }) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.title2)
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Track Live Game")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Track stats as the game happens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Option 3: Multi-device session with video
                Button(action: {
                    isMultiDevice = true
                    let role = roleManager.roleForAutoConnection
                    multipeer.startSession(role: role)
                    showingConnectionWaitingRoom = true
                }) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                            .font(.title2)
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Multi-Device with Video")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Record game with multiple devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Show current role preference for multi-device
            Text("Multi-device role: \(roleManager.preferredRole.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var postGameConfigurationForm: some View {
        Form {
            Section("Game Details") {
                // Team Name Picker or TextField
                if firebaseService.teams.isEmpty {
                    TextField("Team Name", text: $gameConfig.teamName)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if useCustomTeamName {
                            HStack {
                                TextField("Team Name", text: $gameConfig.teamName)
                                Button("Use Saved") {
                                    useCustomTeamName = false
                                    if let firstTeam = firebaseService.teams.first {
                                        gameConfig.teamName = firstTeam.name
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        } else {
                            Picker("Sahil's Team", selection: $gameConfig.teamName) {
                                ForEach(firebaseService.teams, id: \.name) { team in
                                    Text(team.name).tag(team.name)
                                }
                            }
                            .onChange(of: firebaseService.teams) { oldValue, newValue in
                                // Set default team if not already set
                                if gameConfig.teamName.isEmpty, let firstTeam = newValue.first {
                                    gameConfig.teamName = firstTeam.name
                                }
                            }

                            Button("Use Custom Name") {
                                useCustomTeamName = true
                                gameConfig.teamName = ""
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }
                }

                TextField("Opponent", text: $gameConfig.opponent)

                HStack {
                    TextField("Location", text: $gameConfig.location)

                    Button(action: {
                        locationManager.requestLocation()
                    }) {
                        if locationManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(locationManager.isLoading)
                }

                DatePicker("Game Date", selection: $gameConfig.date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Game Format") {
                Picker("Format", selection: $gameConfig.gameFormat) {
                    ForEach(GameFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Stepper("\(gameConfig.gameFormat.quarterName) Length: \(gameConfig.quarterLength) min",
                        value: $gameConfig.quarterLength, in: 1...30)
            }

            Section {
                Button("Continue to Stats Entry") {
                    showingPostGameEntry = true
                }
                .disabled(gameConfig.teamName.isEmpty || gameConfig.opponent.isEmpty)

                Button("Back") {
                    setupMode = .selection
                }
            }
        }
        .navigationTitle("Past Game Setup")
        .alert("Location Access Required", isPresented: $showLocationPermissionAlert) {
            Button("Open Settings") {
                locationManager.openLocationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(locationManager.error?.localizedDescription ?? "Please enable location access in Settings to use this feature.")
        }
        .onChange(of: locationManager.locationName) { oldValue, newValue in
            if !newValue.isEmpty {
                gameConfig.location = newValue
            }
        }
        .onChange(of: locationManager.error) { oldValue, newValue in
            if newValue != nil {
                showLocationPermissionAlert = true
            }
        }
        .onAppear {
            // Set default team when form appears
            if gameConfig.teamName.isEmpty, let firstTeam = firebaseService.teams.first {
                gameConfig.teamName = firstTeam.name
            }
            // Load game format and quarter length from settings
            gameConfig.gameFormat = settingsManager.gameFormat
            gameConfig.quarterLength = settingsManager.quarterLength
            gameConfig.numQuarter = settingsManager.gameFormat.quarterCount
        }
    }

    private var gameConfigurationForm: some View {
        Form {
            Section("Game Details") {
                // Team Name Picker or TextField
                if firebaseService.teams.isEmpty {
                    TextField("Team Name", text: $gameConfig.teamName)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if useCustomTeamName {
                            HStack {
                                TextField("Team Name", text: $gameConfig.teamName)
                                Button("Use Saved") {
                                    useCustomTeamName = false
                                    if let firstTeam = firebaseService.teams.first {
                                        gameConfig.teamName = firstTeam.name
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        } else {
                            Picker("Sahil's Team", selection: $gameConfig.teamName) {
                                ForEach(firebaseService.teams, id: \.name) { team in
                                    Text(team.name).tag(team.name)
                                }
                            }
                            .onChange(of: firebaseService.teams) { oldValue, newValue in
                                // Set default team if not already set
                                if gameConfig.teamName.isEmpty, let firstTeam = newValue.first {
                                    gameConfig.teamName = firstTeam.name
                                }
                            }

                            Button("Use Custom Name") {
                                useCustomTeamName = true
                                gameConfig.teamName = ""
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }
                }

                TextField("Opponent", text: $gameConfig.opponent)

                HStack {
                    TextField("Location", text: $gameConfig.location)

                    Button(action: {
                        locationManager.requestLocation()
                    }) {
                        if locationManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(locationManager.isLoading)
                }

                DatePicker("Game Date", selection: $gameConfig.date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Game Format") {
                Picker("Format", selection: $gameConfig.gameFormat) {
                    ForEach(GameFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .onChange(of: gameConfig.gameFormat) { oldValue, newValue in
                    // Update number of quarters when format changes
                    gameConfig.numQuarter = newValue == .halves ? 2 : 4
                }

                Stepper("\(gameConfig.gameFormat.quarterName) Length: \(gameConfig.quarterLength) min",
                        value: $gameConfig.quarterLength, in: 1...30)
            }

            Section {
                Button("Start Live Game") {
                    handleSubmit()
                }
                .disabled(gameConfig.teamName.isEmpty || gameConfig.opponent.isEmpty)

                Button("Back") {
                    setupMode = .selection
                }
            }
        }
        .navigationTitle("Live Game Setup")
        .alert("Location Access Required", isPresented: $showLocationPermissionAlert) {
            Button("Open Settings") {
                locationManager.openLocationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(locationManager.error?.localizedDescription ?? "Please enable location access in Settings to use this feature.")
        }
        .onChange(of: locationManager.locationName) { oldValue, newValue in
            if !newValue.isEmpty {
                gameConfig.location = newValue
            }
        }
        .onChange(of: locationManager.error) { oldValue, newValue in
            if newValue != nil {
                showLocationPermissionAlert = true
            }
        }
        .onAppear {
            // Set default team when form appears
            if gameConfig.teamName.isEmpty, let firstTeam = firebaseService.teams.first {
                gameConfig.teamName = firstTeam.name
            }
            // Load game format and quarter length from settings
            gameConfig.gameFormat = settingsManager.gameFormat
            gameConfig.quarterLength = settingsManager.quarterLength
            gameConfig.numQuarter = settingsManager.gameFormat.quarterCount
        }
    }

    private func handleSubmit() {
        Task {
            // Check connection only if multi-device mode
            if isMultiDevice {
                guard case .connected = multipeer.connectionState else {
                    print("❌ Cannot start game, not connected.")
                    return
                }
            }

            let liveGame = try await createLiveGame()
            createdLiveGame = liveGame

            // Send game starting message to connected device if multi-device
            if isMultiDevice, let gameId = liveGame.id {
                multipeer.sendGameStarting(gameId: gameId)
            }

            showingLiveGameView = true
        }
    }
    
    private func createLiveGame() async throws -> LiveGame {
        // Create live game with full configuration
        let newGame = LiveGame(
            teamName: gameConfig.teamName,
            opponent: gameConfig.opponent,
            location: gameConfig.location.isEmpty ? nil : gameConfig.location,
            gameFormat: gameConfig.gameFormat,
            quarterLength: gameConfig.quarterLength,
            isMultiDeviceSetup: isMultiDevice
        )
        let id = try await FirebaseService.shared.createLiveGame(newGame)
        var gameWithId = newGame; gameWithId.id = id
        return gameWithId
    }
}
