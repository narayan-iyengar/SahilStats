// SahilStats/Services/LiveGameManager.swift

import Foundation
import Combine
import SwiftUI
import MultipeerConnectivity

@MainActor
class LiveGameManager: ObservableObject {
    static let shared = LiveGameManager()

    @Published var liveGame: LiveGame? {
        didSet {
            // Update Live Activity whenever game state changes
            LiveActivityManager.shared.updateGameState(liveGame: liveGame)
        }
    }

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
    func startMultiDeviceSession(role: DeviceRole) {
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

                // Set the recorder's device role when they receive the game starting message
                let roleManager = DeviceRoleManager.shared
                print("🔍 Current preferredRole: \(roleManager.preferredRole.displayName)")
                print("🔍 Current deviceRole: \(roleManager.deviceRole.displayName)")

                if roleManager.preferredRole == .recorder {
                    print("🎯 Recorder setting deviceRole to .recorder for game \(gameId)")
                    Task {
                        do {
                            try await roleManager.setDeviceRole(.recorder, for: gameId)
                            print("✅ Recorder deviceRole set successfully")
                            print("🔍 After setting - deviceRole: \(roleManager.deviceRole.displayName)")

                            // Note: No Live Activity for recorder - device is on tripod
                        } catch {
                            print("❌ Failed to set recorder deviceRole: \(error)")
                        }
                    }
                } else {
                    print("⚠️ Not recorder, skipping deviceRole set (preferredRole: \(roleManager.preferredRole.displayName))")
                }

                // The NavigationCoordinator will handle the UI transition
            }
        default:
            break
        }
    }
    
    func reset() {
        print("🔄 LiveGameManager: Resetting game state (keeping connection alive)")
        liveGame = nil
        // Don't stop the session - keep connection alive for next game
        // Connection will only be stopped when app terminates or user explicitly disconnects
    }
}
