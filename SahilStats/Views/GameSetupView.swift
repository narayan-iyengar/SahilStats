// File: SahilStats/Views/GameSetupView.swift (Fixed Form closure issue)

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth
import CoreLocation


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
    
    
    @State private var enableMultiDevice = false
    @State private var deviceRole: DeviceRoleManager.DeviceRole = .none
    @StateObject private var roleManager = DeviceRoleManager.shared
    
    
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
                }
                .buttonStyle(PillButtonStyle(isIPad: isIPad))
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
        
        // REMOVED: Live game status indicator banner
        // No more green banner here
        
        Spacer()
        
        // Setup options with enhanced live game tracking
        VStack(spacing: 16) {
            // Post-Game Stats Entry
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
            
            // ENHANCED: Live Game Tracking with prominent status
            SubtleLiveGameTrackingCard(
                hasLiveGame: firebaseService.hasLiveGame
            ) {
                if firebaseService.hasLiveGame {
                    // Navigate directly to live game view
                    showingLiveGameView = true
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
                
                // Opponent suggestions - simplified for Form compatibility
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
                Button(action: {
                    setupMode = .selection
                    deviceRole = .none
                    gameId = ""
                }) {
                    Text("Back")
                        .fixedSize() // Prevents text from being clipped
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
        locationManager.requestLocation()
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
                        // Set the created game and show the live view
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
#Preview {
    struct PreviewWrapper: View {
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        private var isIPad: Bool {
            horizontalSizeClass == .regular
        }
        var body: some View {
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
    }
    return PreviewWrapper()
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


// MARK: - Live Game Badge Component
struct LiveGameBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .opacity(isAnimating ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
            
            Text("LIVE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red.opacity(0.1))
        .clipShape(Capsule())
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Alternative: Subtle Animation Version
struct SubtleLiveGameTrackingCard: View {
    let hasLiveGame: Bool
    let action: () -> Void
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with subtle pulse when live
                Image(systemName: "stopwatch.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(hasLiveGame ? Color.red : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(hasLiveGame ? pulseScale : 1.0)
                    .animation(
                        hasLiveGame ?
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                        .default,
                        value: pulseScale
                    )
                
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
                         "Track stats and score during the game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(hasLiveGame ? "Tap to join and control" : "Start new live game")
                        .font(.caption2)
                        .foregroundColor(hasLiveGame ? .red : .blue)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                hasLiveGame ?
                Color.red.opacity(0.1) :
                Color(.systemGray6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        hasLiveGame ? Color.red.opacity(0.3) : Color.clear,
                        lineWidth: hasLiveGame ? 1 : 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onAppear {
            if hasLiveGame {
                pulseScale = 1.05
            }
        }
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
