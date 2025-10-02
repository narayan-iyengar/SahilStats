// File: SahilStats/Views/GameSetupView.swift (Fixed Version)

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth
import CoreLocation
import UIKit
import FirebaseCore
import MultipeerConnectivity

// MARK: - Connection Method Enum (Move outside the view)


struct GameSetupView: View  {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var multipeer = MultipeerConnectivityManager.shared // ADD THIS
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var setupMode: SetupMode = .selection
    @State private var deviceRole: DeviceRoleManager.DeviceRole = .none
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
    
    // Connection method state
    @State private var connectionMethod: ConnectionMethod = .bluetooth
    @State private var showingBluetoothConnection = false
    @State private var bluetoothConnectionRequired = false
    @State private var showingConnectionWaitingRoom = false
    
    @State private var opponentSuggestions: [String] = []
    @State private var isLoadingSuggestions = false
    
    @State private var isAutoConnecting = false
    @State private var autoConnectStatus = ""
    @State private var showManualConnection = false
    
    

    
    
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

    
    enum ConnectionMethod {
        case bluetooth
        case firebase
        
        var displayName: String {
            switch self {
            case .bluetooth: return "Bluetooth (Direct)"
            case .firebase: return "WiFi/Internet"
            }
        }
        
        var description: String {
            switch self {
            case .bluetooth: return "Direct device-to-device connection (no WiFi required)"
            case .firebase: return "Requires internet connection"
            }
        }
        
        var icon: String {
            switch self {
            case .bluetooth: return "antenna.radiowaves.left.and.right"
            case .firebase: return "wifi"
            }
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("Game Setup")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                firebaseService.startListening()
                loadDefaultSettings()
            }
            .sheet(isPresented: $showingBluetoothConnection) {
                BluetoothConnectionView()
            }
            .fullScreenCover(isPresented: $showingConnectionWaitingRoom) {
                ConnectionWaitingRoomView(role: deviceRole) {
                    handleWaitingRoomGameStart()
                }
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
            .onChange(of: showingBluetoothConnection) { _, isShowing in
                handleBluetoothConnectionChange(isShowing)
            }
            .onChange(of: gameConfig.opponent) { _, newValue in
                if !newValue.isEmpty && newValue.count > 2 {
                    Task {
                        opponentSuggestions = getOpponentSuggestions()
                    }
                } else {
                    opponentSuggestions = []
                }
            }
            .onDisappear {
                // DO NOT cleanup Multipeer connection here if going to live game
                if !showingLiveGameView {
                    // Only cleanup if we're actually leaving, not transitioning to game
                    print("🔵 GameSetupView disappearing - NOT in live game, safe to cleanup")
                } else {
                    print("🔵 GameSetupView disappearing - transitioning to live game, keeping connection alive")
                }
            }
            .alert("Bluetooth Connection Required", isPresented: $bluetoothConnectionRequired) {
                Button("Connect Now") {
                    showingBluetoothConnection = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You need to establish a Bluetooth connection with the recorder device before starting the game.")
            }
    }
    

    private var mainContent: some View {
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
    }
    
    

    
    private func handleWaitingRoomGameStart() {
        print("🎯 handleWaitingRoomGameStart called - role: \(deviceRole)")
        
        if deviceRole == .controller {
            // DON'T dismiss yet - keep connection alive
            print("🎮 Controller proceeding to game form")
            
            // Dismiss the waiting room
            showingConnectionWaitingRoom = false
            
            // Short delay before showing game form
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🎮 Controller switching to game form")
                setupMode = .gameForm
            }
        } else if deviceRole == .recorder {
            print("🎬 handleWaitingRoomGameStart - recorder path")
            
            Task {
                do {
                    guard let liveGame = firebaseService.getCurrentLiveGame(),
                          let gameId = liveGame.id else {
                        await MainActor.run {
                            print("❌ No live game found for recorder")
                            error = "No live game found"
                        }
                        return
                    }
                    
                    print("🎬 Setting recorder role for game: \(gameId)")
                    try await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                    
                    await MainActor.run {
                        print("🎬 Showing live game view for recorder")
                        // Dismiss sheet AFTER everything is ready
                        showingConnectionWaitingRoom = false
                        // Small delay to let sheet dismiss cleanly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showingLiveGameView = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.error = "Failed to join as recorder: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func handleBluetoothConnectionChange(_ isShowing: Bool) {
        if !isShowing && deviceRole == .recorder && multipeer.isConnected {
            Task {
                do {
                    guard let liveGame = firebaseService.getCurrentLiveGame(),
                          let gameId = liveGame.id else {
                        error = "No live game found"
                        return
                    }
                    
                    try await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                    showingLiveGameView = true
                } catch {
                    self.error = "Failed to join as recorder: \(error.localizedDescription)"
                }
            }
        }
    }
    
    
    // MARK: - Game Configuration Form
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
                
                TextField("Opponent Team", text: $gameConfig.opponent)
                    .autocapitalization(.words)
                
                if !opponentSuggestions.isEmpty {
                    ForEach(Array(opponentSuggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                        Button(action: {
                            gameConfig.opponent = suggestion
                            opponentSuggestions = []
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
                        Text("\(gameConfig.gameFormat.quarterName) Length")
                        Spacer()
                        TextField("Minutes", value: $gameConfig.quarterLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Each \(gameConfig.gameFormat.quarterName.lowercased()) will be \(gameConfig.quarterLength) minutes long")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Game Actions
            Section {
                if deviceRole == .controller {
                    Button("Start Live Game") {
                        // No Bluetooth check needed - connection already established in waiting room
                        handleSubmit(mode: .live, isMultiDevice: isCreatingMultiDeviceGame)
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                    }
                    else {
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
    
    // MARK: - Setup Mode Selection
    @ViewBuilder
    private var setupModeSelection: some View {
        VStack(spacing: 16) {
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

            SetupOptionCard(
                title: "Multi-Device Recording",
                subtitle: "Record video + control scoring separately",
                icon: "video.fill",
                color: .red,
                status: "Choose recorder or controller role",
                statusColor: .red
            ) {
                self.isCreatingMultiDeviceGame = true
                self.setupMode = .recording
                self.deviceRole = .none
            }

            if firebaseService.hasLiveGame {
                SetupOptionCard(
                    title: "Join Live Game",
                    subtitle: getCurrentLiveGameInfo(),
                    icon: "antenna.radiowaves.left.and.right",
                    color: .blue,
                    status: "A game is in progress!",
                    statusColor: .blue
                ) {
                    self.setupMode = .smartJoin
                }
            }
        }
        .padding()
    }
    
    // MARK: - Recording Role Selection
    @ViewBuilder
    private var recordingRoleSelection: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text("Multi-Device Setup")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Text("Choose your device's role")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Auto-connect status (if connecting in background)
            if isAutoConnecting {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text(autoConnectStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Connection Type")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ConnectionMethodCard(
                        method: .bluetooth,
                        isSelected: connectionMethod == .bluetooth,
                        isIPad: isIPad
                    ) {
                        connectionMethod = .bluetooth
                    }
                    
                    ConnectionMethodCard(
                        method: .firebase,
                        isSelected: connectionMethod == .firebase,
                        isIPad: isIPad
                    ) {
                        connectionMethod = .firebase
                    }
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                DeviceRoleCard(
                    role: .controller,
                    isSelected: deviceRole == .controller,
                    isIPad: isIPad
                ) {
                    deviceRole = .controller
                    handleRoleSelection(.controller)
                }
                
                DeviceRoleCard(
                    role: .recorder,
                    isSelected: deviceRole == .recorder,
                    isIPad: isIPad
                ) {
                    deviceRole = .recorder
                    handleRoleSelection(.recorder)
                }
            }
            
            Spacer()
            
            Button("Cancel") {
                setupMode = .selection
                deviceRole = .none
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            
            Spacer()
        }
        .padding()
        .onAppear {
            setupAutoConnect()
        }
    }
    
    // Add these new methods:
    private func setupAutoConnect() {
        print("🔧 Setting up auto-connect callbacks in recordingRoleSelection")
        
        // Set up auto-connect callback BEFORE any connection attempt
        multipeer.onAutoConnectCompleted = {
            print("✅ Auto-connect completed in setupAutoConnect callback")
            DispatchQueue.main.async {
                self.handleAutoConnectCompleted()
            }
        }
        
        // Don't set up onPendingInvitation here - let ConnectionWaitingRoomView handle it
        // when it appears
        
        // Check current connection state
        if multipeer.isConnected {
            print("🔧 Already connected during setup - checking auto-connect state")
            isAutoConnecting = false
        }
        
        print("🔧 Auto-connect callbacks set up successfully")
    }
    
    
    
    
    private func handleRoleSelection(_ role: DeviceRoleManager.DeviceRole) {
        print("🎯 handleRoleSelection called with role: \(role)")
        
        if connectionMethod == .bluetooth {
            print("🔵 Using Bluetooth connection method")
            
            // Set up auto-connect completion callback
            multipeer.onAutoConnectCompleted = {
                print("✅ onAutoConnectCompleted callback fired")
                DispatchQueue.main.async {
                    self.isAutoConnecting = false
                    self.proceedWithConnectedDevice(role: role)
                }
            }
            
            // Check if we should start auto-connecting
            isAutoConnecting = multipeer.isAutoConnecting
            autoConnectStatus = multipeer.autoConnectStatus
            
            // If already connected to trusted device, proceed immediately
            if multipeer.isConnected {
                print("✅ Already connected to trusted device")
                proceedWithConnectedDevice(role: role)
            } else {
                print("🔄 Starting new connection process")
                
                // Start advertising/browsing and wait for auto-connect
                Task.detached {
                    try? await DeviceRoleManager.shared.setDeviceRole(role, for: "setup-pending")
                }
                
                // Don't set up onPendingInvitation here - let ConnectionWaitingRoomView handle it
                // Show waiting room immediately for manual connections
                showingConnectionWaitingRoom = true
                
                if role == .controller {
                    print("🔍 Controller starting to browse...")
                    multipeer.startBrowsing()
                } else {
                    print("📡 Recorder starting to advertise...")
                    multipeer.startAdvertising(as: .recorder)
                }
                
                // Wait for auto-connect or timeout
                startAutoConnectTimeout(role: role)
            }
        } else {
            print("🌐 Using Firebase connection method")
            // Firebase mode - proceed as before
            if role == .controller {
                Task.detached {
                    try? await DeviceRoleManager.shared.setDeviceRole(.controller, for: "setup-pending")
                }
                setupMode = .gameForm
            } else {
                if firebaseService.hasLiveGame {
                    joinAsRecorder()
                } else {
                    error = "No live game found. The controller must start the game first."
                }
            }
        }
    }
 /*
    private func handleRoleSelection(_ role: DeviceRoleManager.DeviceRole) {
        if connectionMethod == .bluetooth {
            // Check if we should start auto-connecting
            isAutoConnecting = multipeer.isAutoConnecting
            autoConnectStatus = multipeer.autoConnectStatus
            
            // If already connected to trusted device, proceed immediately
            if multipeer.isConnected {
                proceedWithConnectedDevice(role: role)
            } else {
                // Start advertising/browsing and wait for auto-connect
                Task.detached {
                    try? await DeviceRoleManager.shared.setDeviceRole(role, for: "setup-pending")
                }
                
                if role == .controller {
                    multipeer.startBrowsing()
                } else {
                    multipeer.startAdvertising(as: .recorder)
                }
                
                // Wait for auto-connect or timeout
                startAutoConnectTimeout(role: role)
            }
        } else {
            // Firebase mode - proceed as before
            if role == .controller {
                Task.detached {
                    try? await DeviceRoleManager.shared.setDeviceRole(.controller, for: "setup-pending")
                }
                setupMode = .gameForm
            } else {
                if firebaseService.hasLiveGame {
                    joinAsRecorder()
                } else {
                    error = "No live game found. The controller must start the game first."
                }
            }
        }
    }
    */
    

    private func proceedWithConnectedDevice(role: DeviceRoleManager.DeviceRole) {
        Task.detached {
            try? await DeviceRoleManager.shared.setDeviceRole(role, for: "setup-pending")
        }
        
        if role == .controller {
            print("🎮 Controller proceeding to game form - already connected")
            // Controller can proceed to game form
            setupMode = .gameForm
        } else {
            print("🎬 Recorder proceeding to waiting room - already connected")
            // Recorder should wait in waiting room for controller to start game
            showingConnectionWaitingRoom = true
        }
    }

    private func startAutoConnectTimeout(role: DeviceRoleManager.DeviceRole) {
        // Wait 5 seconds for auto-connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if !multipeer.isConnected {
                // Auto-connect didn't happen, show waiting room for manual connection
                showManualConnection = true
                showingConnectionWaitingRoom = true
            }
        }
    }

    private func handleAutoConnectCompleted() {
        // Auto-connect succeeded
        isAutoConnecting = false
        
        if deviceRole == .controller {
            // Controller proceeds to game form
            setupMode = .gameForm
        } else if deviceRole == .recorder {
            // Recorder shows waiting room (or could auto-proceed if game already started)
            showingConnectionWaitingRoom = true
        }
    }

    
    
    
    // MARK: - Smart Join Game View
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
            
            Button("Cancel") {
                setupMode = .selection
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadDefaultSettings() {
        let settings = settingsManager.getDefaultGameSettings()
        gameConfig.gameFormat = settings.format
        gameConfig.quarterLength = settings.length
        
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
        
        if liveGame.controllingDeviceId == nil || liveGame.controllingUserEmail == nil {
            availableRoles.append(.controller)
        }
        
        availableRoles.append(.viewer)
        availableRoles.append(.recorder)
        
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
    
    private func handleSubmit(mode: GameSubmissionMode, isMultiDevice: Bool) {
        guard !gameConfig.teamName.isEmpty && !gameConfig.opponent.isEmpty else {
            error = "Please enter team name and opponent"
            return
        }
        
        Task {
            do {
                switch mode {
                case .live:
                    // CRITICAL: Keep connection info before creating game
                    let hasBluetoothConnection = multipeer.isConnected
                    let connectedPeerCount = multipeer.connectedPeers.count
                    
                    print("🎮 Creating live game - Bluetooth connected: \(hasBluetoothConnection), peers: \(connectedPeerCount)")
                    
                    let liveGame = try await createLiveGame(isMultiDevice: isMultiDevice)
                    
                    if let gameId = liveGame.id {
                        let selectedRole: DeviceRoleManager.DeviceRole = deviceRole == .controller ? .controller : .controller
                        try await DeviceRoleManager.shared.setDeviceRole(selectedRole, for: gameId)
                        
                        // CRITICAL FIX: Send Bluetooth signal ONLY if we have a stable connection
                        if isMultiDevice && connectionMethod == .bluetooth && hasBluetoothConnection {
                            print("📤 Sending game starting signal via Bluetooth - gameId: \(gameId)")
                            
                            // Give the signal time to send before transitioning
                            multipeer.sendGameStarting(gameId: gameId)
                            
                            // Wait for signal to be sent
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            print("✅ Game starting signal sent, now transitioning to game view")
                        }
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
            quarterLength: gameConfig.quarterLength,
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
    private func getLocationSuggestions() -> [String] {
        let allLocations = Set(firebaseService.games.compactMap { $0.location })
        return Array(allLocations)
            .filter { $0.localizedCaseInsensitiveContains(gameConfig.location) }
            .prefix(3)
            .map { $0 }
    }
    private func getOpponentSuggestions() -> [String] {
        let allOpponents = Set(firebaseService.games.compactMap { $0.opponent })
        return Array(allOpponents)
            .filter { $0.localizedCaseInsensitiveContains(gameConfig.opponent) }
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

    
struct ConnectionMethodCard: View {
        let method: GameSetupView.ConnectionMethod
        let isSelected: Bool
        let isIPad: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: method.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : (method == .bluetooth ? .blue : .orange))
                    
                    Text(method.displayName)
                        .font(isIPad ? .body : .caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? 20 : 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? (method == .bluetooth ? Color.blue : Color.orange) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
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
                    onDone: {
                        // Clear the device role when leaving so user can select role again next time
                        Task {
                            await roleManager.clearDeviceRole()
                        }
                        onDismiss()
                    },
                    onSelectRole: { showingRoleSelection = true }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).shadow(color: .black.opacity(0.1), radius: 2, y: 1))
            }

            if roleManager.deviceRole == .recorder {
                // Recorder goes straight to camera view
                if let liveGame = firebaseService.getCurrentLiveGame() {
                    CleanVideoRecordingView(liveGame: liveGame)
                } else {
                    // Fallback if no live game found
                    VStack {
                        Text("No live game found")
                            .foregroundColor(.secondary)
                        Button("Go Back") {
                            onDismiss()
                        }
                    }
                }
            } else {
                // Controller and viewer see the stats/scoring view
                LiveGameView()
            }
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
    var quarterLength = 20
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
    let role: DeviceRoleManager.DeviceRole
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


/*
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
 */


