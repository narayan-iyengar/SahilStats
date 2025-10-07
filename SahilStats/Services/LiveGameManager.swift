// SahilStats/Services/LiveGameManager.swift

import Foundation
import Combine
import SwiftUI

@MainActor
class LiveGameManager: ObservableObject {
    static let shared = LiveGameManager()

    @Published var gameState: GameState = .idle
    @Published var liveGame: LiveGame?
    
    private var cancellables = Set<AnyCancellable>()
    private let multipeer = MultipeerConnectivityManager.shared
    private let firebase = FirebaseService.shared

    // Add Equatable conformance here
    enum GameState: Equatable {
        case idle
        case connecting(role: DeviceRoleManager.DeviceRole)
        case connected(role: DeviceRoleManager.DeviceRole)
        case inProgress(role: DeviceRoleManager.DeviceRole)
    }
    
    private init() {
        // Listen for incoming multipeer messages
        multipeer.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMessage(message)
            }
            .store(in: &cancellables)
            
        // Keep the local liveGame object in sync with Firebase
        firebase.$liveGames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] games in
                guard let self = self else { return }
                
                self.liveGame = games.first
                
                // If the game is deleted from Firebase, reset our state
                if games.isEmpty {
                    if case .inProgress = self.gameState {
                        print("🔴 Live Game was removed from Firebase. Resetting state.")
                        self.reset()
                    }
                    return
                }
                
                // If we have a live game and device has a recorder role, but we're idle, start connecting
                if let liveGame = games.first,
                   case .idle = self.gameState,
                   DeviceRoleManager.shared.deviceRole == .recorder {
                    print("🎬 Firebase: Live game available and we're a recorder in idle state. Starting connection.")
                    self.startMultiDeviceSession(role: .recorder)
                }
                
                // If we have a live game and we're a recorder in connected state,
                // check if the game is already running and should transition to inProgress
                if let liveGame = games.first,
                   liveGame.isRunning,
                   case .connected(let role) = self.gameState,
                   role == .recorder {
                    print("🎬 Firebase: Game is running and we're connected as recorder. Transitioning to inProgress")
                    self.gameState = .inProgress(role: .recorder)
                }
            }
            .store(in: &cancellables)
            
        // Monitor multipeer connection state
        multipeer.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionState in
                guard let self = self else { return }
                
                let isConnected = connectionState.isConnected
                print("🔗 LiveGameManager: Multipeer connection state changed to \(connectionState), isConnected: \(isConnected), current gameState: \(self.gameState)")
                
                switch self.gameState {
                case .connecting(let role):
                    if isConnected {
                        print("🔗 LiveGameManager: Transitioning from connecting to connected for role: \(role)")
                        self.gameState = .connected(role: role)
                    }
                case .connected(let role):
                    if !isConnected {
                        // Connection was dropped, go back to connecting state
                        print("🔗 LiveGameManager: Connection lost, transitioning to connecting for role: \(role)")
                        self.gameState = .connecting(role: role)
                        self.startMultiDeviceSession(role: role) // Re-initiate advertising/browsing
                    }
                case .inProgress(let role):
                     if !isConnected {
                        // Connection dropped during a game, attempt to reconnect
                        print("🔗 LiveGameManager: Connection lost during game, transitioning to connecting for role: \(role)")
                        self.gameState = .connecting(role: role)
                        self.startMultiDeviceSession(role: role) // Re-initiate advertising/browsing
                    }
                case .idle:
                    if isConnected && DeviceRoleManager.shared.deviceRole != .none {
                        print("🔗 LiveGameManager: Connection established while idle, transitioning to connected for role: \(DeviceRoleManager.shared.deviceRole)")
                        self.gameState = .connected(role: DeviceRoleManager.shared.deviceRole)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func startMultiDeviceSession(role: DeviceRoleManager.DeviceRole) {
        print("🚀 LiveGameManager: Starting multi-device session for role: \(role), current state: \(gameState)")
        gameState = .connecting(role: role)
        if role == .controller {
            multipeer.startBrowsing()
        } else {
            // Typo fixed here: multipeer, not multipear
            multipeer.startAdvertising(as: "recorder")
        }
        print("🚀 LiveGameManager: Multi-device session started, new state: \(gameState)")
    }

    private func handleMessage(_ message: MultipeerConnectivityManager.Message) {
        print("🎬 LiveGameManager received message: \(message.type), current state: \(gameState)")
        switch message.type {
        case .gameStarting:
            if let gameId = message.payload?["gameId"] {
                print("🎬 LiveGameManager handling gameStarting signal for gameId: \(gameId)")
                
                // Be more flexible about the state - if we're a recorder, transition regardless of current state
                switch gameState {
                case .connected(let role) where role == .recorder:
                    print("🎬 Transitioning LiveGameManager from connected to inProgress state for recorder")
                    gameState = .inProgress(role: .recorder)
                case .idle, .connecting(.recorder):
                    print("🎬 Transitioning LiveGameManager from \(gameState) directly to inProgress state for recorder")
                    gameState = .inProgress(role: .recorder)
                default:
                    print("⚠️ LiveGameManager: gameStarting received but current state is \(gameState), not transitioning")
                }
                
                // Ensure DeviceRoleManager has the correct role set
                Task { @MainActor in
                    if DeviceRoleManager.shared.deviceRole != .recorder {
                        print("🔄 Setting DeviceRoleManager role to recorder")
                        try? await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                    }
                }
            }
            
        case .gameAlreadyStarted:
            if let gameId = message.payload?["gameId"] {
                print("🎬 LiveGameManager handling gameAlreadyStarted signal for gameId: \(gameId)")
                
                // If we join a game that's already in progress, transition to inProgress immediately
                if case .connected(let role) = gameState, role == .recorder {
                    print("🎬 Game already started! Transitioning recorder from connected to inProgress")
                    gameState = .inProgress(role: .recorder)
                    
                    // Ensure DeviceRoleManager has the correct role set
                    Task { @MainActor in
                        if DeviceRoleManager.shared.deviceRole != .recorder {
                            print("🔄 Setting DeviceRoleManager role to recorder")
                            try? await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                        }
                    }
                }
            }
        
        // Handle other message types for debugging
        case .requestRecordingState:
            print("🎬 LiveGameManager: Received requestRecordingState")
            // If we get this message, it means controller wants us to be ready to record
            if DeviceRoleManager.shared.deviceRole == .recorder, case .idle = gameState {
                print("🎬 Auto-transitioning to connecting state for recorder due to requestRecordingState")
                gameState = .connecting(role: .recorder)
            }
        
        case .gameStateUpdate:
            print("🎬 LiveGameManager: Received gameStateUpdate with payload: \(message.payload ?? [:])")
            // Handle game state synchronization from controller
            // Check if this gameStateUpdate indicates the game has started
            if let payload = message.payload,
               let isRunningString = payload["isRunning"] as? String,
               let isRunning = Bool(isRunningString),
               let gameId = payload["gameId"] {
                print("🎬 GameStateUpdate - isRunning: \(isRunning), gameId: \(gameId)")
                
                // If game is running and we're a recorder in connected state, transition to inProgress
                if isRunning , case .connected(let role) = gameState, role == .recorder {
                    print("🎬 Game is running! Transitioning recorder from connected to inProgress")
                    gameState = .inProgress(role: .recorder)
                    
                    // Ensure DeviceRoleManager has the correct role set
                    Task { @MainActor in
                        if DeviceRoleManager.shared.deviceRole != .recorder {
                            print("🔄 Setting DeviceRoleManager role to recorder")
                            try? await DeviceRoleManager.shared.setDeviceRole(.recorder, for: gameId)
                        }
                    }
                }
            }
            
        case .ping:
            print("🎬 LiveGameManager: Received ping (keep-alive)")
            // Ping messages are handled by MultipeerConnectivityManager for keep-alive
            // No additional action needed here
            
        case .pong:
            print("🎬 LiveGameManager: Received pong (keep-alive response)")
            // Pong messages are handled by MultipeerConnectivityManager for keep-alive
            // No additional action needed here
        
        // ... handle other messages like start/stop recording here in the future ...
        default:
            print("🎬 LiveGameManager: Unhandled message type: \(message.type)")
            break
        }
    }
    
    func reset() {
        gameState = .idle
        multipeer.stopAll()
    }
}
