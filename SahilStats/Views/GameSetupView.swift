// File: SahilStats/Views/GameSetupView.swift (Fixed isIPad scope issue)

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth

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
        .sheet(isPresented: $showingPostGameView) {
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
        .fullScreenCover(isPresented: $showingPostGameView) {
            PostGameFullScreenWrapper(gameConfig: gameConfig) {
                showingPostGameView = false
            }
            .environmentObject(authService)
        }
    }

    struct PostGameFullScreenWrapper: View {
        let gameConfig: GameConfig
        let onDismiss: () -> Void
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        
        private var isIPad: Bool {
            horizontalSizeClass == .regular
        }
        
        var body: some View {
            ZStack {
                // FORCE: Full background coverage
                Color(.systemBackground)
                    .ignoresSafeArea(.all) // IMPORTANT: Ignore ALL safe areas
                
                VStack(spacing: 0) {
                    // Custom navigation bar (replaces system nav)
                    PostGameNavigationBar(onDismiss: onDismiss, isIPad: isIPad)
                    
                    // Main content
                    PostGameStatsView(gameConfig: gameConfig)
                        .navigationBarHidden(true) // FORCE: Hide any system nav
                }
            }
            .navigationBarHidden(true) // DOUBLE FORCE: Ensure nav is hidden
            .navigationViewStyle(StackNavigationViewStyle()) // FORCE: Stack style on iPad
        }
    }

    // MARK: - Enhanced Navigation Bar for iPad

    struct PostGameNavigationBar: View {
        let onDismiss: () -> Void
        let isIPad: Bool
        
        var body: some View {
            HStack {
                // Title section
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
                
                // Done button - ALWAYS visible and prominent
                Button(action: onDismiss) {
                    Text("Done")
                        .font(isIPad ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, isIPad ? 20 : 16)
                        .padding(.vertical, isIPad ? 12 : 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(isIPad ? 24 : 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isIPad ? 28 : 24)
            .padding(.top, isIPad ? 24 : 20)
            .padding(.bottom, isIPad ? 20 : 16)
            .background(
                Color(.systemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                    .ignoresSafeArea(.container, edges: .top) // EXTEND: To top edge
            )
        }
    }
    
    // MARK: - Alternative PostGameFullScreenView (FIXED)
    struct PostGameFullScreenView: View {
        let gameConfig: GameConfig
        let onDismiss: () -> Void
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        
        private var isIPad: Bool {
            horizontalSizeClass == .regular
        }
        
        var body: some View {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    PostGameNavigationBar(onDismiss: onDismiss, isIPad: isIPad)
                    PostGameStatsView(gameConfig: gameConfig)
                }
            }
        }
    }

    // MARK: - Full Screen Live Game View (FIXED)
    
    @ViewBuilder
    private func LiveGameFullScreenView(onDismiss: @escaping () -> Void) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                FullScreenNavigationBar(onDismiss: onDismiss)
                LiveGameView().environmentObject(authService)
            }
        }
    }
    
    @ViewBuilder
    private func FullScreenNavigationBar(onDismiss: @escaping () -> Void) -> some View {
        HStack {
            // Title
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
            
            // FIXED: Always show "Done" button, never "X"
            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
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
                // Post-Game Stats Entry
                SetupOptionCard(
                    title: "Enter Final Stats",
                    subtitle: "Game is over - enter final score and stats",
                    icon: "chart.bar.fill",
                    color: .green,
                    status: "Quick stat entry after the game",
                    statusColor: .blue
                ) {
                    setupMode = .gameForm
                    deviceRole = .none
                }
                
                // Live Game Scoring
                SetupOptionCard(
                    title: "Live Game Tracking",
                    subtitle: "Track stats and score during the game",
                    icon: "stopwatch.fill",
                    color: .orange,
                    status: firebaseService.hasLiveGame ? "Join existing live game" : "Start new live game",
                    statusColor: firebaseService.hasLiveGame ? .green : .blue
                ) {
                    if firebaseService.hasLiveGame {
                        // Navigate directly to live game view
                        if let currentLiveGame = firebaseService.getCurrentLiveGame() {
                            createdLiveGame = currentLiveGame
                            showingLiveGameView = true
                        }
                    } else {
                        setupMode = .gameForm
                        deviceRole = .controller
                    }
                }
                
                // Recording Setup (Future feature)
                SetupOptionCard(
                    title: "Video Recording",
                    subtitle: "Multi-device recording with live overlays",
                    icon: "video.fill",
                    color: .red,
                    status: "Coming Soon",
                    statusColor: .gray
                ) {
                    // setupMode = .recording
                    error = "Video recording feature coming soon!"
                }
            }
            
            Spacer()
        }
        .padding()
        .alert("Feature Info", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
    }
    
    // MARK: - Game Configuration Form
    
    private func GameConfigurationForm() -> some View {
        Form {
            // Game ID display for live game controller
            if deviceRole == .controller && !gameId.isEmpty {
                Section {
                    GameIdDisplayCard(gameId: gameId)
                }
            }
            
            // Date and Time
            Section("When") {
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
            Section("Where") {
                HStack {
                    TextField("Location (optional)", text: $gameConfig.location)
                    
                    Button(action: getAutoLocation) {
                        Image(systemName: isGettingLocation ? "location.fill" : "location")
                            .foregroundColor(.blue)
                    }
                    .disabled(isGettingLocation)
                }
                
                LocationSuggestions()
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
                        // DYNAMIC: Label changes based on format
                        Text("\(gameConfig.gameFormat.periodName) Length")
                        Spacer()
                        TextField("Minutes", value: $gameConfig.periodLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                    
                    // OPTIONAL: Add helpful context
                    Text("Each \(gameConfig.gameFormat.periodName.lowercased()) will be \(gameConfig.periodLength) minutes long")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Game Actions
            Section {
                if deviceRole == .controller {
                    // Live game controller
                    Button("Start Live Game") {
                        handleSubmit(mode: .live)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    // Post-game stats entry
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
                Button("Back") {
                    setupMode = .selection
                    deviceRole = .none
                    gameId = ""
                }
            }
        }
        .alert("Error", isPresented: .constant(!error.isEmpty)) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
    }
    
    // MARK: - Recording Role Selection (Future)
    
    private func RecordingRoleSelection() -> some View {
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
    
    // MARK: - Connect to Game View (Future)
    
    private func ConnectToGameView() -> some View {
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
    
    private func getAutoLocation() {
        isGettingLocation = true
        
        // Simulate getting location for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            gameConfig.location = "Home Court" // Placeholder
            isGettingLocation = false
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
    
    private func createLiveGame() async throws -> LiveGame {
        // Use the shared instance to get the device ID
        let deviceId = DeviceControlManager.shared.deviceId
        var liveGame = LiveGame(
            teamName: gameConfig.teamName,
            opponent: gameConfig.opponent,
            location: gameConfig.location.isEmpty ? nil : gameConfig.location,
            gameFormat: gameConfig.gameFormat,
            periodLength: gameConfig.periodLength,
            createdBy: authService.currentUser?.email,
            deviceId: deviceId // Pass the deviceId here
        )
        
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
}

// MARK: - Supporting Views and Extensions

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

// Reuse the setup option card from the previous implementation
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
                
                Text("You can join the current live game or create a new one")
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
            Text("Live Game Setup")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("This will create a live game that can be tracked in real-time:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Game ID: \(gameId)")
                    .font(.monospaced(.caption)())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Copy") {
                    UIPasteboard.general.string = gameId
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
