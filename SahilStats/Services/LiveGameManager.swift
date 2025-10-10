// SahilStats/Services/LiveGameManager.swift

import Foundation
import Combine
import SwiftUI
import MultipeerConnectivity

@MainActor
class LiveGameManager: ObservableObject {
    static let shared = LiveGameManager()

    @Published var liveGame: LiveGame?

    private var cancellables = Set<AnyCancellable>()
    private let multipeer = MultipeerConnectivityManager.shared
    private let firebase = FirebaseService.shared

    private init() {
        // Listen for incoming multipeer messages for game logic
        multipeer.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleGameMessage(message)
            }
            .store(in: &cancellables)
            
        // Keep the local liveGame object in sync with Firebase
        firebase.$liveGames
            .receive(on: DispatchQueue.main)
            .sink { [weak self] games in
                self?.liveGame = games.first
            }
            .store(in: &cancellables)
    }

    // This function now simply starts the connection process.
    // The UI will be responsible for observing the connection state directly.
    func startMultiDeviceSession(role: DeviceRoleManager.DeviceRole) {
        print("🚀 LiveGameManager: Kicking off multi-device session for role: \(role)")

        multipeer.stopSession() // Ensure a clean slate

        // Add a small delay to let services fully stop before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if role == .controller {
                self.multipeer.startBrowsing()
            } else {
                self.multipeer.startAdvertising(as: "recorder")
            }
        }
    }

    private func handleGameMessage(_ message: MultipeerConnectivityManager.Message) {
        // This function no longer handles connection state, only game logic
        switch message.type {
        case .gameStarting:
             if let gameId = message.payload?["gameId"] {
                print("🎬 LiveGameManager received gameStarting signal for gameId: \(gameId)")
                // The NavigationCoordinator will handle the UI transition
            }
        default:
            break
        }
    }
    
    func reset() {
        liveGame = nil
        multipeer.stopSession()
    }
}
