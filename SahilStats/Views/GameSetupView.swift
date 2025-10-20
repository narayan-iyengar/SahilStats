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
            if createdLiveGame != nil {
                LiveGameView() // Your existing live game view
            }
        }
        .fullScreenCover(isPresented: $showingPostGameEntry) {
            PostGameStatsView(gameConfig: gameConfig)
        }
        .onChange(of: showingConnectionWaitingRoom) { wasShowing, isShowing in
            if wasShowing && !isShowing { // When the waiting room is dismissed
                if case .connected = multipeer.connectionState {
                    // Only controller proceeds to game form
                    // Recorder goes to waiting room until controller creates game
                    if roleManager.preferredRole == .controller {
                        debugPrint("✅ Handshake complete. Controller proceeding to create game.")
                        setupMode = .gameForm
                    } else {
                        debugPrint("✅ Recorder connected. Navigating to waiting room...")
                        NavigationCoordinator.shared.currentFlow = .waitingToRecord(nil)
                    }
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
                            .foregroundColor(.purple)

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

                Divider()
                    .padding(.vertical, 8)

                // Live game setup - Use new visual component
                Text("Track Live Game")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GameSetupModeSelectionView(
                    onSelectMultiDevice: {
                        isMultiDevice = true
                        NavigationCoordinator.shared.userExplicitlyJoinedGame = true
                        NavigationCoordinator.shared.markUserHasInteracted()

                        // Check if already connected
                        if multipeer.connectionState.isConnected {
                            debugPrint("✅ Already connected, skipping waiting room")
                            if roleManager.preferredRole == .controller {
                                setupMode = .gameForm
                            } else {
                                debugPrint("✅ Recorder ready. Navigating to waiting room...")
                                NavigationCoordinator.shared.currentFlow = .waitingToRecord(nil)
                            }
                        } else {
                            debugPrint("🔍 Not connected, starting connection process")
                            let role = roleManager.roleForAutoConnection
                            multipeer.startSession(role: role)
                            showingConnectionWaitingRoom = true
                        }
                    },
                    onSelectSingleDevice: {
                        isMultiDevice = false
                        setupMode = .gameForm
                    }
                )
            }
            .padding(.horizontal)
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
                    forcePrint("❌ Cannot start game, not connected.")
                    return
                }
            }

            let liveGame = try await createLiveGame()
            createdLiveGame = liveGame

            // Set device role for multi-device games
            if isMultiDevice, let gameId = liveGame.id {
                // Set the device role based on preferred role
                debugPrint("🎯 Controller setting deviceRole to \(roleManager.preferredRole.displayName) for game \(gameId)")
                try await DeviceRoleManager.shared.setDeviceRole(roleManager.preferredRole, for: gameId)
                debugPrint("✅ Controller deviceRole set successfully")

                // Send game starting message to connected device
                debugPrint("📤 Sending gameStarting message to recorder")
                multipeer.sendGameStarting(gameId: gameId)

                // Give the recorder a moment to receive the message and set their role
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Send start recording command to transition recorder to recording view
                debugPrint("📤 Sending startRecording command to recorder")
                multipeer.sendStartRecording()
            }

            debugPrint("🎬 Controller transitioning to live game view")
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
