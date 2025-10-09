//
//  NavigationCoordinator.swift
//  SahilStats
//
//  Simplified navigation state management - COMPLETELY REFACTORED
//

import SwiftUI
import Combine

@MainActor
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    // MARK: - Simplified State (Single Source of Truth)
    @Published var currentFlow: AppFlow = .dashboard
    @Published var userExplicitlyJoinedGame = false
    
    enum AppFlow: Equatable {
        case dashboard
        case liveGame(LiveGame)
        case gameSetup
        case recording(LiveGame)
    }
    
    // MARK: - Dependencies (Single Connection Manager)
    private let connectionManager = UnifiedConnectionManager.shared
    private let liveGameManager = LiveGameManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        print("📱 NavigationCoordinator: Initializing with simplified state")
        setupObservers()
    }
    
    private func setupObservers() {
        // Single observer for live game changes
        liveGameManager.$liveGame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveGame in
                self?.handleLiveGameChange(liveGame)
            }
            .store(in: &cancellables)
        
        // Single observer for connection messages
        connectionManager.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleConnectionMessage(message)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Simplified Public Interface
    
    func startLiveGame() {
        print("🎯 Starting live game")
        userExplicitlyJoinedGame = true
        currentFlow = .gameSetup
    }
    
    func resumeLiveGame() {
        print("🎯 Resuming live game")
        userExplicitlyJoinedGame = true
        
        if let liveGame = liveGameManager.liveGame {
            navigateToGameFlow(liveGame)
        } else {
            currentFlow = .gameSetup
        }
    }
    
    func selectRole(_ role: DeviceRoleManager.DeviceRole) {
        print("🎯 Role selected: \(role)")
        userExplicitlyJoinedGame = true
        
        // Set role immediately
        DeviceRoleManager.shared.deviceRole = role
        
        // Start connection (instant or traditional based on availability)
        if connectionManager.connectionStatus.canUseMultiDevice {
            print("⚡ Using instant connection")
        } else {
            print("🔧 Starting traditional connection")
            liveGameManager.startMultiDeviceSession(role: role)
        }
        
        // Navigate based on role and game state
        if let liveGame = liveGameManager.liveGame {
            navigateToGameFlow(liveGame)
        }
    }
    
    func navigateForRole(_ role: DeviceRoleManager.DeviceRole) {
        print("🎯 Navigating for role: \(role)")
        print("🎯 Current DeviceRoleManager role: \(DeviceRoleManager.shared.deviceRole)")
        print("🎯 LiveGameManager has game: \(liveGameManager.liveGame != nil)")
        if let game = liveGameManager.liveGame {
            print("🎯 LiveGame ID: \(game.id ?? "nil")")
        }
        
        userExplicitlyJoinedGame = true
        
        // Navigate based on role and game state
        // Try LiveGameManager first, then fallback to FirebaseService
        var liveGame = liveGameManager.liveGame
        if liveGame == nil {
            print("🎯 LiveGameManager.liveGame is nil, trying FirebaseService")
            liveGame = FirebaseService.shared.getCurrentLiveGame()
            if let game = liveGame {
                print("🎯 Found game in FirebaseService: \(game.id ?? "nil")")
            }
        }
        
        if let game = liveGame {
            navigateToGameFlow(game)
        } else {
            print("⚠️ No live game found in either manager, staying in setup")
            currentFlow = .gameSetup
        }
    }
    
    func returnToDashboard() {
        print("🏠 Returning to dashboard")
        
        // Clean up everything
        currentFlow = .dashboard
        userExplicitlyJoinedGame = false
        DeviceRoleManager.shared.deviceRole = .none
        
        // Disconnect but keep background scanning
        connectionManager.disconnect()
        liveGameManager.reset()
    }
    
    func forceTransitionToRecording() {
        print("🎬 Force transition to recording view")
        
        if let liveGame = liveGameManager.liveGame {
            currentFlow = .recording(liveGame)
        } else {
            print("⚠️ Cannot force transition to recording - no live game available")
        }
    }
    
    // MARK: - Simplified Private Logic
    
    private func handleLiveGameChange(_ liveGame: LiveGame?) {
        guard userExplicitlyJoinedGame else {
            print("📱 Ignoring live game change - user didn't explicitly join")
            return
        }
        
        if let game = liveGame {
            print("🎮 Live game available: \(game.id ?? "unknown")")
            navigateToGameFlow(game)
        } else {
            print("🎮 Live game ended")
            returnToDashboard()
        }
    }
    
    private func navigateToGameFlow(_ liveGame: LiveGame) {
        let role = DeviceRoleManager.shared.deviceRole
        print("🎯 navigateToGameFlow called with role: \(role), gameId: \(liveGame.id ?? "nil")")
        
        switch role {
        case .recorder:
            print("🎬 Setting currentFlow to recording view")
            currentFlow = .recording(liveGame)
            print("🎬 currentFlow is now: \(currentFlow)")
            
        case .controller, .viewer:
            print("🎮 Navigating to live game view")
            currentFlow = .liveGame(liveGame)
            
        case .none:
            print("❓ No role set, staying in game setup")
            currentFlow = .gameSetup
        }
    }
    
    private func handleConnectionMessage(_ message: UnifiedConnectionManager.GameMessage) {
        switch message.type {
        case .gameStarting:
            print("🚀 Game starting signal received")
            if let gameId = message.payload?["gameId"] {
                // Game is starting, ensure we transition appropriately
                if let liveGame = liveGameManager.liveGame {
                    navigateToGameFlow(liveGame)
                }
            }
            
        case .gameEnded:
            print("🏁 Game ended signal received")
            returnToDashboard()
            
        default:
            print("📨 Received message: \(message.type)")
        }
    }
}
