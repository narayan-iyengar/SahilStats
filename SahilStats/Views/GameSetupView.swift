// SahilStats/Views/GameSetupView.swift

import SwiftUI

struct GameSetupView: View {
    @State private var setupMode: SetupMode = .selection
    @State private var showingConnectionWaitingRoom = false
    @State private var gameConfig = GameConfiguration() // Your existing game config model
    @State private var createdLiveGame: LiveGame?
    @State private var showingLiveGameView = false
    
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    
    enum SetupMode {
        case selection, gameForm
    }
    
    var body: some View {
        VStack {
            if setupMode == .selection {
                gameModeSelection
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
        VStack(spacing: 20) {
            // Simplified for clarity
            Button("Track Stats (Single Device)") {
                setupMode = .gameForm
            }
            .buttonStyle(.borderedProminent)
            
            Button("Multi-Device Session") {
                // This is the entry point for the Controller
                multipeer.startSession(role: .controller)
                showingConnectionWaitingRoom = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var gameConfigurationForm: some View {
        Form {
            Section("Game Details") {
                TextField("Team Name", text: $gameConfig.teamName)
                TextField("Opponent", text: $gameConfig.opponent)
            }
            Button("Start Live Game") {
                handleSubmit()
            }
        }
    }
    
    private func handleSubmit() {
        Task {
            // The isConnected check is now reliable because the UI waited
            guard case .connected = multipeer.connectionState else {
                print("❌ Cannot start game, not connected.")
                return
            }

            let liveGame = try await createLiveGame()
            createdLiveGame = liveGame
            
            if let gameId = liveGame.id {
                multipeer.sendGameStarting(gameId: gameId)
            }
            showingLiveGameView = true
        }
    }
    
    private func createLiveGame() async throws -> LiveGame {
        // Your existing game creation logic...
        let newGame = LiveGame(teamName: gameConfig.teamName, opponent: gameConfig.opponent, isMultiDeviceSetup: true)
        let id = try await FirebaseService.shared.createLiveGame(newGame)
        var gameWithId = newGame; gameWithId.id = id
        return gameWithId
    }
}
