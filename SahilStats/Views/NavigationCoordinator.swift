//
//  NavigationCoordinator.swift
//  SahilStats
//
//  Simplified navigation state management
//

import SwiftUI
import Combine

@MainActor
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    @Published var currentFlow: AppFlow = .dashboard
    @Published var connectionState: ConnectionFlow = .idle
    
    enum AppFlow: Equatable {
        case dashboard
        case liveGame(LiveGame)
        case gameSetup(DeviceRoleManager.DeviceRole)
        case recording(LiveGame, DeviceRoleManager.DeviceRole)
    }
    
    enum ConnectionFlow: Equatable {
        case idle
        case selectingRole
        case connecting(DeviceRoleManager.DeviceRole)
        case connected(DeviceRoleManager.DeviceRole)
        case failed(String)
    }
    
    private let multipeer = MultipeerConnectivityManager.shared
    private let liveGameManager = LiveGameManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        print("📱 NavigationCoordinator: Initializing with currentFlow=\(currentFlow)")
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe live game changes
        liveGameManager.$liveGame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveGame in
                if let game = liveGame {
                    print("📱 NavigationCoordinator: Live game available - \(game.id ?? "unknown")")
                    self?.handleLiveGameAvailable(game)
                } else {
                    print("📱 NavigationCoordinator: Live game ended")
                    self?.handleLiveGameEnded()
                }
            }
            .store(in: &cancellables)
        
        // Observe LiveGameManager game state changes
        liveGameManager.$gameState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gameState in
                print("📱 NavigationCoordinator: LiveGameManager state changed to \(gameState), currentFlow: \(self?.currentFlow ?? .dashboard)")
                
                // If LiveGameManager is idle but we have a saved role and active game, restart the session
                if case .idle = gameState,
                   DeviceRoleManager.shared.deviceRole != .none,
                   self?.liveGameManager.liveGame != nil {
                    print("📱 NavigationCoordinator: Auto-restarting session due to idle state with saved role")
                    self?.liveGameManager.startMultiDeviceSession(role: DeviceRoleManager.shared.deviceRole)
                }
                
                // Re-evaluate if we should transition when game state changes
                if let liveGame = self?.liveGameManager.liveGame {
                    print("📱 NavigationCoordinator: Re-evaluating transition for liveGame: \(liveGame.id ?? "unknown")")
                    self?.handleLiveGameAvailable(liveGame)
                } else {
                    print("📱 NavigationCoordinator: No liveGame available, skipping transition evaluation")
                }
            }
            .store(in: &cancellables)
        
        // Observe connection state
        multipeer.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                print("📱 NavigationCoordinator: Multipeer connection state - \(state)")
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)
        
        // Handle incoming messages
        multipeer.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                print("📱 NavigationCoordinator: Received message - \(message.type)")
                self?.handleMessage(message)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Navigation Methods
    
    func startLiveGame() {
        currentFlow = .gameSetup(.none) // Will show role selection
    }
    
    func resumeLiveGame() {
        // Check if there's an active live game and go directly to it
        if let liveGame = liveGameManager.liveGame {
            let role = DeviceRoleManager.shared.deviceRole
            print("📱 NavigationCoordinator: resumeLiveGame - role: \(role), gameState: \(liveGameManager.gameState)")
            
            if role != .none {
                // If we have a role but LiveGameManager is idle, restart the session
                if case .idle = liveGameManager.gameState {
                    print("📱 NavigationCoordinator: Restarting multipeer session for role: \(role)")
                    liveGameManager.startMultiDeviceSession(role: role)
                }
                
                // If we already have a role, go directly to the appropriate view
                handleLiveGameAvailable(liveGame)
            } else {
                // If no role is set, show role selection to join the existing game
                currentFlow = .gameSetup(.none)
            }
        } else {
            // No live game exists, start the setup flow
            startLiveGame()
        }
    }
    
    func viewLiveGame() {
        // Go directly to live game as a viewer, without setting up multipeer
        if let liveGame = liveGameManager.liveGame {
            currentFlow = .liveGame(liveGame)
        } else {
            // If no live game, fall back to starting one
            startLiveGame()
        }
    }
    
    func selectRole(_ role: DeviceRoleManager.DeviceRole) {
        print("🎯 NavigationCoordinator: selectRole(\(role)) called")
        connectionState = .connecting(role)
        
        // Set the role in DeviceRoleManager immediately for the multipeer connection
        DeviceRoleManager.shared.deviceRole = role
        
        liveGameManager.startMultiDeviceSession(role: role)
    }
    
    func returnToDashboard() {
        currentFlow = .dashboard
        connectionState = .idle
        multipeer.stopAll()
        liveGameManager.reset()
    }
    
    // MARK: - Private Event Handlers
    
    private func handleLiveGameAvailable(_ liveGame: LiveGame) {
        let role = DeviceRoleManager.shared.deviceRole
        print("📱 NavigationCoordinator: handleLiveGameAvailable - currentFlow=\(currentFlow), role=\(role), gameState=\(liveGameManager.gameState)")
        
        guard role != .none else { 
            print("📱 Not transitioning: device role is .none")
            return 
        }
        
        // Check if this device should automatically transition based on game state
        let shouldAutoTransition: Bool
        switch currentFlow {
        case .dashboard:
            // Only auto-transition from dashboard if the LiveGameManager indicates we're in progress
            // This handles the case where a recorder device receives a gameStarting signal
            if case .inProgress = liveGameManager.gameState {
                shouldAutoTransition = true
                print("🔄 Auto-transitioning from dashboard due to game in progress state")
            } else {
                shouldAutoTransition = false
                print("📱 Not auto-transitioning from dashboard: gameState is \(liveGameManager.gameState)")
            }
        case .gameSetup:
            // For gameSetup flow, transition based on the LiveGameManager state and role
            if role == .recorder {
                // Recorder should transition when game state is inProgress
                if case .inProgress = liveGameManager.gameState {
                    shouldAutoTransition = true
                    print("🔄 Auto-transitioning from gameSetup for recorder due to inProgress state")
                } else {
                    shouldAutoTransition = false
                    print("📱 Not auto-transitioning from gameSetup: recorder gameState is \(liveGameManager.gameState)")
                }
            } else {
                shouldAutoTransition = true
                print("🔄 Auto-transitioning from gameSetup for non-recorder role")
            }
        case .liveGame, .recording:
            // These flows should always transition automatically
            shouldAutoTransition = true
            print("🔄 Auto-transitioning from \(currentFlow)")
        }
        
        guard shouldAutoTransition else {
            print("📱 Not auto-transitioning: currentFlow=\(currentFlow), role=\(role), gameState=\(liveGameManager.gameState)")
            return
        }
        
        print("🎬 Transitioning to appropriate view for role: \(role)")
        switch role {
        case .controller:
            currentFlow = .liveGame(liveGame)
        case .recorder:
            currentFlow = .recording(liveGame, .recorder)
        case .viewer:
            currentFlow = .liveGame(liveGame)
        case .none:
            break
        }
    }
    
    private func handleLiveGameEnded() {
        if case .liveGame = currentFlow {
            returnToDashboard()
        }
    }
    
    private func handleConnectionStateChange(_ state: MultipeerConnectivityManager.ConnectionState) {
        print("📱 NavigationCoordinator: handleConnectionStateChange(\(state))")
        
        switch state {
        case .connected:
            if case .connecting(let role) = connectionState {
                print("📱 Connection established for role: \(role)")
                connectionState = .connected(role)
                
                // Ensure the DeviceRoleManager has the role set
                if DeviceRoleManager.shared.deviceRole != role {
                    print("📱 Setting DeviceRoleManager role to: \(role)")
                    DeviceRoleManager.shared.deviceRole = role
                }
            }
        case .disconnected:
            if case .connected(let role) = connectionState {
                print("📱 Connection lost, attempting to reconnect for role: \(role)")
                connectionState = .connecting(role) // Try to reconnect
            }
        case .connecting:
            break
        }
    }
    
    private func handleMessage(_ message: MultipeerConnectivityManager.Message) {
        switch message.type {
        case .gameStarting:
            if let gameId = message.payload?["gameId"],
               case .connected(.recorder) = connectionState {
                // Recorder automatically transitions to recording
                // The liveGame observer will handle the UI transition
            }
        default:
            break
        }
    }
}