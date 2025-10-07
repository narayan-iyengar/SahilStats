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
                self?.liveGame = games.first
                // If the game is deleted from Firebase, reset our state
                if games.isEmpty, let currentState = self?.gameState {
                    if case .inProgress = currentState {
                        print("🔴 Live Game was removed from Firebase. Resetting state.")
                        self?.reset()
                    }
                }
            }
            .store(in: &cancellables)
            
        // Monitor multipeer connection state
        multipeer.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                switch self.gameState {
                case .connecting(let role):
                    if isConnected {
                        self.gameState = .connected(role: role)
                    }
                case .connected(let role):
                    if !isConnected {
                        // Connection was dropped, go back to connecting state
                        self.gameState = .connecting(role: role)
                    }
                case .inProgress(let role):
                     if !isConnected {
                        // Connection dropped during a game, attempt to reconnect
                        self.gameState = .connecting(role: role)
                        self.startMultiDeviceSession(role: role) // Re-initiate advertising/browsing
                    }
                case .idle:
                    break
                }
            }
            .store(in: &cancellables)
    }

    func startMultiDeviceSession(role: DeviceRoleManager.DeviceRole) {
        gameState = .connecting(role: role)
        if role == .controller {
            multipeer.startBrowsing()
        } else {
            // Typo fixed here: multipeer, not multipear
            multipeer.startAdvertising(as: "recorder")
        }
    }

    private func handleMessage(_ message: MultipeerConnectivityManager.Message) {
        switch message.type {
        case .gameStarting:
            if let gameId = message.payload?["gameId"] {
                print("LiveGameManager handling gameStarting signal for gameId: \(gameId)")
                if case .connected(let role) = gameState, role == .recorder {
                     gameState = .inProgress(role: .recorder)
                }
            }
        
        // ... handle other messages like start/stop recording here in the future ...
        default:
            break
        }
    }
    
    func reset() {
        gameState = .idle
        multipeer.stopAll()
    }
}
