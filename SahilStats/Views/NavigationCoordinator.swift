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
    
    @Published var currentFlow: AppFlow = .dashboard {
        didSet {
        //    print("🔄 NavigationCoordinator: currentFlow changed from \(oldValue) to \(currentFlow)")
        }
    }
    @Published var connectionState: ConnectionFlow = .idle
    @Published var userExplicitlyJoinedGame = false
    
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
                    // FIXED: Only handle if user explicitly joined
                    if self?.userExplicitlyJoinedGame == true {
                        self?.handleLiveGameAvailable(game)
                    }
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
        userExplicitlyJoinedGame = true  // User is explicitly starting
        currentFlow = .gameSetup(.none)
    }
    
    func resumeLiveGame() {
        userExplicitlyJoinedGame = true  // User is explicitly resuming
        
        if let liveGame = liveGameManager.liveGame {
            let role = DeviceRoleManager.shared.deviceRole
            print("📱 NavigationCoordinator: resumeLiveGame - role: \(role)")
            
            if role != .none {
                // User has a role and explicitly wants to resume
                if case .idle = liveGameManager.gameState {
                    print("📱 NavigationCoordinator: Restarting multipeer session for role: \(role)")
                    liveGameManager.startMultiDeviceSession(role: role)
                }
                handleLiveGameAvailable(liveGame)
            } else {
                // Show role selection for existing game
                currentFlow = .gameSetup(.none)
            }
        } else {
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
        userExplicitlyJoinedGame = true  // User explicitly selected a role
        connectionState = .connecting(role)
        
        DeviceRoleManager.shared.deviceRole = role
        liveGameManager.startMultiDeviceSession(role: role)
    }
    
    func returnToDashboard() {
        currentFlow = .dashboard
        connectionState = .idle
        userExplicitlyJoinedGame = false  // Reset explicit join flag
        multipeer.stopAll()
        liveGameManager.reset()
        
        DeviceRoleManager.shared.deviceRole = .none
        print("📱 NavigationCoordinator: Cleared device role on return to dashboard")
    }
    
    // Manual method to force re-evaluation of the current state
    func forceStateEvaluation() {
        print("📱 NavigationCoordinator: Force evaluating state - currentFlow: \(currentFlow), gameState: \(liveGameManager.gameState)")
        print("📱 NavigationCoordinator: Device role: \(DeviceRoleManager.shared.deviceRole)")
        if let liveGame = liveGameManager.liveGame {
            print("📱 NavigationCoordinator: Force re-evaluating with liveGame: \(liveGame.id ?? "unknown")")
            handleLiveGameAvailable(liveGame)
        } else {
            print("📱 NavigationCoordinator: No liveGame available during force evaluation")
        }
    }
    
    // Direct method to force transition to recording view
    func forceTransitionToRecording() {
        print("📱 NavigationCoordinator: Force transitioning to recording view")
        print("📱 NavigationCoordinator: Current state - currentFlow: \(currentFlow), gameState: \(liveGameManager.gameState)")
        
        guard let liveGame = liveGameManager.liveGame else {
            print("❌ NavigationCoordinator: Cannot transition - no liveGame available")
            return
        }
        
        guard DeviceRoleManager.shared.deviceRole == .recorder else {
            print("❌ NavigationCoordinator: Cannot transition - device role is \(DeviceRoleManager.shared.deviceRole), not recorder")
            return
        }
        
        print("🎬 NavigationCoordinator: Force transitioning to recording view for game: \(liveGame.id ?? "unknown")")
        currentFlow = .recording(liveGame, .recorder)
        print("🎬 NavigationCoordinator: Force transition complete - new currentFlow: \(currentFlow)")
    }
    
    // MARK: - Private Event Handlers
    
    private func handleLiveGameAvailable(_ liveGame: LiveGame) {
        // FIXED: Only transition if user explicitly joined
        guard userExplicitlyJoinedGame else {
            print("📱 NavigationCoordinator: Ignoring live game - user didn't explicitly join")
            return
        }
        
        let role = DeviceRoleManager.shared.deviceRole
        print("📱 NavigationCoordinator: handleLiveGameAvailable - role=\(role)")
        
        guard role != .none else {
            print("📱 Not transitioning: device role is .none")
            return
        }
        
        // Check if this device should automatically transition based on game state
        let shouldAutoTransition: Bool
        switch currentFlow {
        case .dashboard:
            // Auto-transition from dashboard based on role and game state
            if role == .recorder {
                // Recorder should transition when connected or in progress
                if case .connected(.recorder) = liveGameManager.gameState {
                    shouldAutoTransition = true
                    print("🔄 Auto-transitioning from dashboard: recorder connected")
                } else if case .inProgress(.recorder) = liveGameManager.gameState {
                    shouldAutoTransition = true
                    print("🔄 Auto-transitioning from dashboard: recorder in progress")
                } else {
                    shouldAutoTransition = false
                    print("📱 Not auto-transitioning from dashboard: recorder gameState is \(liveGameManager.gameState)")
                }
            } else {
                // Controller and viewer should transition when game is in progress
                if case .inProgress = liveGameManager.gameState {
                    shouldAutoTransition = true
                    print("🔄 Auto-transitioning from dashboard due to game in progress state")
                } else {
                    shouldAutoTransition = false
                    print("📱 Not auto-transitioning from dashboard: gameState is \(liveGameManager.gameState)")
                }
            }
        case .gameSetup:
            // For gameSetup flow, transition based on the LiveGameManager state and role
            if role == .recorder {
                // Recorder should transition when connected or in progress
                if case .connected(.recorder) = liveGameManager.gameState {
                    shouldAutoTransition = true
                    print("🔄 Auto-transitioning from gameSetup: recorder connected")
                } else if case .inProgress(.recorder) = liveGameManager.gameState {
                    shouldAutoTransition = true
                    print("🔄 Auto-transitioning from gameSetup: recorder in progress")
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
        print("🎬 Before transition - currentFlow: \(currentFlow)")
        switch role {
        case .controller:
            currentFlow = .liveGame(liveGame)
            print("🎬 After transition - currentFlow set to: .liveGame(\(liveGame.id ?? "unknown"))")
        case .recorder:
            currentFlow = .recording(liveGame, .recorder)
            print("🎬 After transition - currentFlow set to: .recording(\(liveGame.id ?? "unknown"), .recorder)")
        case .viewer:
            currentFlow = .liveGame(liveGame)
            print("🎬 After transition - currentFlow set to: .liveGame(\(liveGame.id ?? "unknown"))")
        case .none:
            print("🎬 No transition - role is .none")
            break
        }
        print("🎬 Final currentFlow: \(currentFlow)")
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
