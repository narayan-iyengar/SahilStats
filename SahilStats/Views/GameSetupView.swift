// File: SahilStats/Views/GameSetupView.swift (Fixed Auto-Connect)

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth
import CoreLocation
import UIKit
import FirebaseCore
import MultipeerConnectivity

struct GameSetupView: View  {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @StateObject private var trustedDevicesManager = TrustedDevicesManager.shared
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
    
    @State private var showingConnectionToast = false
    @State private var connectionToastMessage = ""
    @State private var connectionToastIcon = ""
    
    
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
                if let liveGame = firebaseService.getCurrentLiveGame() {
                    SeamlessConnectionFlow(
                        role: deviceRole,
                        liveGame: liveGame
                    )
                } else {
                    // Show loading animation while waiting for game to be created
                    WaitingForGameView(role: deviceRole) {
                        // Cancel button action
                        showingConnectionWaitingRoom = false
                        setupMode = .selection
                    }
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
                // CRITICAL: Never cleanup Bluetooth here - it needs to persist for live game
                print("🔵 GameSetupView disappearing - preserving Bluetooth connection")
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
            print("🎮 Controller proceeding to game form")
            showingConnectionWaitingRoom = false
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
                        // CRITICAL: Don't dismiss the waiting room - let it stay in the background
                        // This preserves the multipeer connection
                        showingLiveGameView = true
                        
                        // Dismiss the waiting room AFTER the live game view is showing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingConnectionWaitingRoom = false
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
            Section("When") {
                DatePicker("Date", selection: $gameConfig.date, displayedComponents: .date)
                DatePicker("Time", selection: $gameConfig.date, displayedComponents: .hourAndMinute)
            }
            
            Section("Teams") {
                if showAddTeamInput {
                    HStack {
                        TextField("New team name", text: $newTeamName)
                        Button("Add") { addNewTeam() }
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
                                Text(suggestion).foregroundColor(.primary)
                                Spacer()
                                Text("Use").font(.caption).foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
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
                        Text("min").foregroundColor(.secondary)
                    }
                    
                    Text("Each \(gameConfig.gameFormat.quarterName.lowercased()) will be \(gameConfig.quarterLength) minutes long")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
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
            
            // Check for trusted devices
            if trustedDevicesManager.hasTrustedDevices {
                // SEAMLESS MODE - Auto-connect in background
                VStack(spacing: 16) {
                    DeviceRoleCard(
                        role: .controller,
                        isSelected: deviceRole == .controller,
                        isIPad: isIPad
                    ) {
                        deviceRole = .controller
                        seamlessConnect(role: .controller)
                    }
                    
                    DeviceRoleCard(
                        role: .recorder,
                        isSelected: deviceRole == .recorder,
                        isIPad: isIPad
                    ) {
                        deviceRole = .recorder
                        seamlessConnect(role: .recorder)
                    }
                }
                
                Text("Trusted devices will auto-connect")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            } else {
                // NO TRUSTED DEVICES - Show pairing prompt
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("No Trusted Devices")
                        .font(.headline)
                    
                    Text("To use multi-device recording, you need to pair your devices first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Go to Settings to Pair") {
                        // Navigate to settings
                        setupMode = .selection
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                    .padding(.horizontal, 40)
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
    }
    
    private func seamlessConnect(role: DeviceRoleManager.DeviceRole) {
        print("🎯 Seamless connect for role: \(role)")
        
        // Set device role immediately
        Task.detached {
            try? await DeviceRoleManager.shared.setDeviceRole(role, for: "setup-pending")
        }
        
        // Start background connection
        if role == .controller {
            print("🎮 Controller: Starting browsing for auto-connect")
            multipeer.startBrowsing()
            // Proceed directly to game form
            setupMode = .gameForm
        } else {
            print("📹 Recorder: Starting advertising for auto-connect")
            multipeer.startAdvertising(as: "recorder")
            // Show seamless waiting view
            showingConnectionWaitingRoom = true
        }
        multipeer.onAutoConnectCompleted = {
            print("✅ Auto-connect completed!")
            DispatchQueue.main.async {
                if role == .controller {
                    print("🎮 Controller: Moving to game form")
                    self.setupMode = .gameForm
                }
            }
        }
        
        // Different behavior based on role
        if role == .controller {
            print("🎮 Controller: Proceeding to game form, connection in background")
            setupMode = .gameForm
        } else {
            print("📹 Recorder: Showing connection waiting room")
            showingConnectionWaitingRoom = true
        }

    }
    
    private func setupAutoConnect() {
        print("🔧 Setting up auto-connect callbacks in recordingRoleSelection")
        
        multipeer.onAutoConnectCompleted = {
            print("✅ Auto-connect completed in setupAutoConnect callback")
            DispatchQueue.main.async {
                self.handleAutoConnectCompleted()
            }
        }
        
        if multipeer.isConnected {
            print("🔧 Already connected during setup - checking auto-connect state")
            isAutoConnecting = false
        }
        
        print("🔧 Auto-connect callbacks set up successfully")
    }
    
    // NEW: Show connection success toast
    private func showConnectionSuccess(role: DeviceRoleManager.DeviceRole, peerName: String) {
        let otherRole = role == .controller ? "Recorder" : "Controller"
        connectionToastMessage = "Connected to \(otherRole)"
        connectionToastIcon = role == .controller ? "video.fill" : "gamecontroller.fill"
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingConnectionToast = true
        }
        
        // Auto-hide toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingConnectionToast = false
            }
        }
    }
    
    
    
    private func handleRoleSelection(_ role: DeviceRoleManager.DeviceRole) {
        print("🎯 handleRoleSelection called with role: \(role)")
        
        if connectionMethod == .bluetooth {
            print("🔵 Using Bluetooth connection method")
            
            // Check if already connected to trusted device
            if multipeer.isConnected {
                print("✅ Already connected to trusted device - proceeding immediately")
                showConnectionSuccess(role: role, peerName: multipeer.connectedPeers.first?.displayName ?? "Device")
                proceedWithConnectedDevice(role: role)
                return
            }
            
            // Start advertising/browsing
            Task.detached {
                try? await DeviceRoleManager.shared.setDeviceRole(role, for: "setup-pending")
            }
            
            if role == .controller {
                print("🔍 Controller starting to browse...")
                multipeer.startBrowsing()
            } else {
                print("📡 Recorder starting to advertise...")
                multipeer.startAdvertising(as: "recorder")
            }
            
            // 🎯 SEAMLESS AUTO-CONNECT: Wait for trusted device
            isAutoConnecting = true
            autoConnectStatus = "Looking for trusted devices..."
            
            // Set up auto-connect completion callback
            multipeer.onAutoConnectCompleted = {
                print("✅ Auto-connect completed!")
                DispatchQueue.main.async {
                    self.isAutoConnecting = false
                    
                    // 🎉 Show connection success toast
                    let peerName = self.multipeer.connectedPeers.first?.displayName ?? "Device"
                    self.showConnectionSuccess(role: role, peerName: peerName)
                    
                    // Small delay to let user see the toast, then proceed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.proceedWithConnectedDevice(role: role)
                    }
                }
            }
            
            // 3-second timeout for auto-connect
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if !self.multipeer.isConnected && self.isAutoConnecting {
                    // Auto-connect didn't happen - show waiting room for manual approval
                    print("⏰ Auto-connect timeout - showing waiting room for manual approval")
                    self.isAutoConnecting = false
                    self.showManualConnection = true
                    self.showingConnectionWaitingRoom = true
                }
            }
            
        } else {
            // Firebase mode - proceed as before
            print("🌐 Using Firebase connection method")
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


    private func proceedWithConnectedDevice(role: DeviceRoleManager.DeviceRole) {
        Task.detached {
            try? await DeviceRoleManager.shared.setDeviceRole(role, for: "setup-pending")
        }
        
        if role == .controller {
            print("🎮 Controller proceeding to game form")
            setupMode = .gameForm
        } else {
            print("🎬 Recorder checking for existing live game...")
            
            // 🔥 FIX: Check if there's already a live game
            if firebaseService.hasLiveGame {
                print("✅ Live game exists - joining as recorder")
                // Join the existing game directly
                Task {
                    do {
                        guard let liveGame = firebaseService.getCurrentLiveGame(),
                              let gameId = liveGame.id else {
                            await MainActor.run {
                                self.error = "No live game found"
                            }
                            return
                        }
                        
                        try await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                        
                        await MainActor.run {
                            print("🎬 Showing live game view for recorder")
                            self.showingLiveGameView = true
                        }
                    } catch {
                        await MainActor.run {
                            self.error = "Failed to join as recorder: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                print("⏳ No live game yet - showing waiting room")
                // No game started yet, show waiting room
                showingConnectionWaitingRoom = true
            }
        }
    }

    private func handleAutoConnectCompleted() {
        isAutoConnecting = false
        
        if deviceRole == .controller {
            setupMode = .gameForm
        } else if deviceRole == .recorder {
            // Recorder stays on role selection with connected status showing
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
                let roleAvailability = getRoleAvailability()
                
                ForEach(roleAvailability, id: \.role) { availability in
                    SmartJoinRoleCard(
                        role: availability.role,
                        isIPad: isIPad,
                        isAvailable: availability.isAvailable,
                        unavailableReason: availability.reason,
                        onSelect: {
                            if availability.isAvailable {
                                joinGameWithRole(availability.role)
                            }
                        }
                    )
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
    
 /*
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
  */
    private func getRoleAvailability() -> [RoleAvailability] {
        guard let liveGame = firebaseService.getCurrentLiveGame() else {
            // No live game, so all primary roles are available
            return [
                RoleAvailability(role: .controller, isAvailable: true, reason: nil),
                RoleAvailability(role: .recorder, isAvailable: true, reason: nil),
                RoleAvailability(role: .viewer, isAvailable: true, reason: nil)
            ]
        }
        
        // Get roles of devices currently connected to the game
        let connectedRoles = DeviceRoleManager.shared.connectedDevices.map { $0.role }
        var roleAvailability: [RoleAvailability] = []
        
        // Controller role - always available (someone needs to control scoring!)
        roleAvailability.append(RoleAvailability(role: .controller, isAvailable: true, reason: nil))
        
        // Recorder role
        if liveGame.isMultiDeviceSetup == true {
            if !connectedRoles.contains(.recorder) {
                roleAvailability.append(RoleAvailability(role: .recorder, isAvailable: true, reason: nil))
            } else {
                roleAvailability.append(RoleAvailability(role: .recorder, isAvailable: false, reason: "Recorder already connected"))
            }
        } else {
            roleAvailability.append(RoleAvailability(role: .recorder, isAvailable: false, reason: "Only available for multi-device games"))
        }
        
        // Viewer is always available
        roleAvailability.append(RoleAvailability(role: .viewer, isAvailable: true, reason: nil))
        
        return roleAvailability
    }
    
    // Keep the old function for backward compatibility, but now it uses the new logic
    private func getAvailableRoles() -> [DeviceRoleManager.DeviceRole] {
        return getRoleAvailability().compactMap { $0.isAvailable ? $0.role : nil }
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
                    let hasBluetoothConnection = multipeer.isConnected
                    let connectedPeerCount = multipeer.connectedPeers.count
                    
                    print("🎮 Creating live game - Bluetooth connected: \(hasBluetoothConnection), peers: \(connectedPeerCount)")
                    
                    let liveGame = try await createLiveGame(isMultiDevice: isMultiDevice)
                    
                    if let gameId = liveGame.id {
                        let selectedRole: DeviceRoleManager.DeviceRole = deviceRole == .controller ? .controller : .controller
                        try await DeviceRoleManager.shared.setDeviceRole(selectedRole, for: gameId)
                        
                        // CRITICAL FIX: Send game starting signal and WAIT for confirmation
                        if isMultiDevice && connectionMethod == .bluetooth && hasBluetoothConnection {
                            print("📤 Sending game starting signal via Bluetooth - gameId: \(gameId)")
                            multipeer.sendGameStarting(gameId: gameId)
                            
                            // LONGER DELAY to ensure recorder receives signal
                            try await Task.sleep(nanoseconds: 2_000_000_000) // 1 second
                            print("✅ Game starting signal sent, now transitioning to game view")
                            
                            // CRITICAL: Set a flag to prevent cleanup on view disappear
                            await MainActor.run {
                                // Don't dismiss GameSetupView - just show LiveGameView on top
                                createdLiveGame = liveGame
                                showingLiveGameView = true
                            }
                            
                            return // Don't dismiss the setup view
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

struct ConnectionToast: View {
    let message: String
    let icon: String
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 24 : 20))
                .foregroundColor(.white)
            
            Text(message)
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isIPad ? 24 : 20))
                .foregroundColor(.green)
        }
        .padding(.horizontal, isIPad ? 24 : 20)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}


struct SmartJoinRoleCard: View {
    let role: DeviceRoleManager.DeviceRole
    let isIPad: Bool
    let isAvailable: Bool
    let unavailableReason: String?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: role.icon)
                    .font(.title)
                    .foregroundColor(isAvailable ? .white : .gray)
                    .frame(width: 50, height: 50)
                    .background(isAvailable ? role.color : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Join as \(role.displayName)")
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .secondary)
                    
                    if let reason = unavailableReason, !isAvailable {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .lineLimit(2)
                    } else {
                        Text(contextualDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isAvailable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(isAvailable ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAvailable ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
    
    private var contextualDescription: String {
        switch role {
        case .controller:
            return "Control the scoreboard and game stats"
        case .recorder:
            return "Record video of the live game"
        case .viewer:
            return "Watch the game stats in real-time"
        case .none:
            return ""
        }
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


// Add this to GameSetupView.swift or create a new file

struct WaitingForGameView: View {
    let role: DeviceRoleManager.DeviceRole
    let onCancel: () -> Void
    
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    @State private var showConnectionNotification = false
    @State private var connectionStatus: ConnectionStatusNotification.ConnectionStatus = .searching
    @State private var hasStartedGame = false
    @State private var shouldTransitionToGame = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: isIPad ? 40 : 32) {
                    Spacer()
                    
                    // Lottie animation - waiting for game
                    LottieView(name: "connection-animation")
                        .frame(width: isIPad ? 250 : 180, height: isIPad ? 250 : 180)
                    
                    VStack(spacing: isIPad ? 20 : 16) {
                        Text("Waiting for Game")
                            .font(isIPad ? .system(size: 44, weight: .bold) : .largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text("Connected and ready to record")
                                .font(isIPad ? .title3 : .body)
                                .foregroundColor(.secondary)
                            
                            Text("The controller will start the game shortly")
                                .font(isIPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, isIPad ? 60 : 40)
                    }
                    
                    // Connection status indicator
                    if multipeer.isConnected, let peer = multipeer.connectedPeers.first {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected to Controller")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(peer.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    } else {
                        // Still connecting
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.orange)
                            
                            Text("Connecting to controller...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                    
                    // Cancel button
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                    .padding(.horizontal, isIPad ? 80 : 40)
                    
                    Spacer()
                }
                .padding()
                
                // Hidden NavigationLink for programmatic navigation
                NavigationLink(
                    destination: destinationView(),
                    isActive: $shouldTransitionToGame
                ) {
                    EmptyView()
                }
                .hidden()
                
                // Connection notification overlay (at top)
                ConnectionStatusNotification(
                    status: connectionStatus,
                    isShowing: $showConnectionNotification
                )
                .padding(.top, 8)
                .zIndex(1000)
            }
            .navigationBarHidden(true)
            .onAppear {
                print("View appeared")
                setupConnectionNotifications()
                setupGameCallbacks()
                
                // Check for existing game
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkForExistingGame()
                }
            }
            .onChange(of: firebaseService.hasLiveGame) { _, hasGame in
                print("Live game status changed: \(hasGame)")
                if hasGame && !hasStartedGame {
                    checkForExistingGame()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder
    private func destinationView() -> some View {
        if let liveGame = firebaseService.getCurrentLiveGame() {
            CleanVideoRecordingView(liveGame: liveGame)
        } else {
            NoLiveGameLottieView()
        }
    }
    
    private func setupGameCallbacks() {
        print("🎬 [WaitingForGame] Setting up game callbacks for recorder")
        
        multipeer.onGameStarting = { gameId in
            print("🎬 [WaitingForGame] onGameStarting callback fired for: \(gameId)")
            print("🎬 hasStartedGame before check: \(self.hasStartedGame)")
            
            guard !self.hasStartedGame else {
                print("⚠️ Already transitioning, ignoring")
                return
            }
            
            self.hasStartedGame = true
            print("🎬 Setting hasStartedGame = true")
            
            Task {
                try? await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                
                await MainActor.run {
                    print("🎬 About to set shouldTransitionToGame = true")
                    print("🎬 Live game exists: \(self.firebaseService.getCurrentLiveGame() != nil)")
                    self.shouldTransitionToGame = true
                    print("🎬 shouldTransitionToGame is now: \(self.shouldTransitionToGame)")
                }
            }
        }
        
        multipeer.onGameAlreadyStarted = { gameId in
            print("🎬 [WaitingForGame] onGameAlreadyStarted callback fired for: \(gameId)")
            print("🎬 hasStartedGame before check: \(self.hasStartedGame)")
            
            guard !self.hasStartedGame else {
                print("⚠️ Already transitioning, ignoring")
                return
            }
            
            self.hasStartedGame = true
            print("🎬 Setting hasStartedGame = true")
            
            Task {
                try? await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                
                await MainActor.run {
                    print("🎬 About to set shouldTransitionToGame = true (game already started)")
                    print("🎬 Live game exists: \(self.firebaseService.getCurrentLiveGame() != nil)")
                    self.shouldTransitionToGame = true
                    print("🎬 shouldTransitionToGame is now: \(self.shouldTransitionToGame)")
                }
            }
        }
    }
    
    private func checkForExistingGame() {
        print("🎬 [WaitingForGame] checkForExistingGame called")
        print("🎬 hasStartedGame: \(hasStartedGame)")
        print("🎬 Live game exists: \(firebaseService.getCurrentLiveGame() != nil)")
        
        if let liveGame = firebaseService.getCurrentLiveGame(),
           let gameId = liveGame.id,
           !hasStartedGame {
            
            print("🎬 [WaitingForGame] Found existing live game: \(gameId)")
            print("🎬 Requesting game state from controller...")
            
            // Ask the controller if the game has already started
            multipeer.sendMessage(MultipeerConnectivityManager.Message(
                type: .requestRecordingState
            ))
            
            // DON'T auto-transition - wait for controller to send gameStarting signal
            print("🎬 Waiting for controller to send gameStarting signal...")
        } else {
            print("🎬 No game to check or already started")
        }
    }
    
    private func setupConnectionNotifications() {
        connectionStatus = .searching
        showConnectionNotification = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if case .searching = connectionStatus {
                withAnimation {
                    showConnectionNotification = false
                }
            }
        }
        
        multipeer.onConnectionEstablished = {
            if let peer = multipeer.connectedPeers.first {
                print("✅ Connected to \(peer.displayName)")
                
                connectionStatus = .connected(
                    deviceName: peer.displayName,
                    role: .controller
                )
                showConnectionNotification = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showConnectionNotification = false
                    }
                }
            }
        }
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
                    onSelect: { showingRoleSelection = true }
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
                    NoLiveGameLottieView()
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
    let onSelect: () -> Void
    
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
                    onSelect()
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

struct RoleAvailability {
    let role: DeviceRoleManager.DeviceRole
    let isAvailable: Bool
    let reason: String?
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

// MARK: - DeviceRole Extensions



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
                Image(systemName: role.icon)
                    .font(.system(size: isIPad ? 40 : 32))
                    .foregroundColor(isSelected ? .white : role.color)
                
                // Title and description
                VStack(spacing: isIPad ? 8 : 6) {
                    Text(role.displayName)
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
                    .fill(isSelected ? role.color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                    .stroke(isSelected ? role.color : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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

