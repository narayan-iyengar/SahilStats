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
    
    // MARK: - App Startup Protection
    private var appStartTime = Date()
    private var hasUserInteractedWithApp = false
    private let startupGracePeriod: TimeInterval = 3.0 // 3 seconds after app start
    
    enum AppFlow: Equatable {
        case dashboard
        case liveGame(LiveGame)
        case gameSetup
        case recording(LiveGame)
        case waitingToRecord(LiveGame) // NEW: Recorder detected game but waiting for manual start
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
        markUserInteraction()
        userExplicitlyJoinedGame = true
        currentFlow = .gameSetup
    }
    
    func resumeLiveGame() {
        print("🎯 Resuming live game")
        markUserInteraction()
        userExplicitlyJoinedGame = true
        
        if let liveGame = liveGameManager.liveGame {
            navigateToGameFlow(liveGame)
        } else {
            currentFlow = .gameSetup
        }
    }
    
    func selectRole(_ role: DeviceRoleManager.DeviceRole) {
        print("🎯 Role selected: \(role)")
        markUserInteraction()
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
        
        markUserInteraction()
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
        hasUserInteractedWithApp = false  // Reset interaction state
        DeviceRoleManager.shared.deviceRole = .none
        
        // Disconnect but keep background scanning
        connectionManager.disconnect()
        liveGameManager.reset()
        
        // Reset startup time to current time (for multiple app sessions)
        appStartTime = Date()
    }
    
    func forceTransitionToRecording() {
        print("🎬 Force transition to recording view")
        
        if let liveGame = liveGameManager.liveGame {
            currentFlow = .recording(liveGame)
        } else {
            print("⚠️ Cannot force transition to recording - no live game available")
        }
    }
    
    // MARK: - Public Method for UI Components
    
    /// Call this when user performs any UI interaction to allow subsequent auto-navigation
    func markUserHasInteracted() {
        print("👤 User interaction marked")
        hasUserInteractedWithApp = true
    }
    
    /// NEW: Manual recording control for controller
    func startRecording() {
        print("🎬 Manual recording start requested")
        markUserInteraction()
        
        // Send signal to recorder device via MultipeerConnectivity
        MultipeerConnectivityManager.shared.sendStartRecording()
    }
    
    /// NEW: Manual stop recording from controller  
    func stopRecording() {
        print("🎬 Manual recording stop requested")
        markUserInteraction()
        
        // Send signal to recorder device via MultipeerConnectivity
        MultipeerConnectivityManager.shared.sendStopRecording()
    }
    

    

    
    // MARK: - Simplified Private Logic
    
    private func markUserInteraction() {
        hasUserInteractedWithApp = true
    }
    
    private var shouldAllowAutoNavigation: Bool {
        // Only allow if user explicitly joined
        return userExplicitlyJoinedGame
    }
    
    private func handleLiveGameChange(_ liveGame: LiveGame?) {
        print("📱 handleLiveGameChange called")
        print("📱 Device: \(UIDevice.current.name)")
        print("📱 userExplicitlyJoinedGame: \(userExplicitlyJoinedGame)")
        print("📱 hasUserInteractedWithApp: \(hasUserInteractedWithApp)")
        print("📱 timeSinceStartup: \(Date().timeIntervalSince(appStartTime))s")
        print("📱 shouldAllowAutoNavigation: \(shouldAllowAutoNavigation)")
        
        // SPECIAL CASE: iPhone in "tripod mode" - allow auto-recording even without explicit user join
        if let game = liveGame, shouldAutoRecordOnGameStart(game) {
            print("📱 🎥 iPhone auto-recording mode - bypassing user interaction checks")
            navigateToGameFlow(game)
            return
        }
        
        // IMPROVED: Better logic for preventing unwanted auto-connections
        guard shouldAllowAutoNavigation else {
            if Date().timeIntervalSince(appStartTime) <= startupGracePeriod {
                print("📱 Ignoring live game change - app just started, preventing auto-connection")
            } else if !hasUserInteractedWithApp {
                print("📱 Ignoring live game change - no user interaction yet")
            } else {
                print("📱 Ignoring live game change - user hasn't explicitly joined")
            }
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
    
    // MARK: - Basketball Tripod Mode Detection
    
    private func shouldAutoRecordOnGameStart(_ liveGame: LiveGame) -> Bool {
        // Only for multi-device games
        guard liveGame.isMultiDeviceSetup == true else { return false }
        
        // Only for iPhones (better cameras for recording)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        
        // Only if game has a controller already (someone else is managing the game)
        guard hasExistingController(in: liveGame) else { return false }
        
        // Only if we haven't explicitly set a different role
        let currentRole = DeviceRoleManager.shared.deviceRole
        guard currentRole == .none || currentRole == .recorder else { return false }
        
        print("🎥 ✅ iPhone tripod mode detected - auto-recording enabled")
        return true
    }
    
    private func navigateToGameFlow(_ liveGame: LiveGame) {
        let currentRole = DeviceRoleManager.shared.deviceRole
        print("🎯 navigateToGameFlow called with role: \(currentRole), gameId: \(liveGame.id ?? "nil")")
        
        // IMPROVED: Smart auto-role assignment for real-world usage
        let assignedRole = determineOptimalRole(currentRole: currentRole, liveGame: liveGame)
        
        // Set the role if it's not already set
        if currentRole == .none && assignedRole != .none {
            Task {
                do {
                    try await DeviceRoleManager.shared.setDeviceRole(assignedRole, for: liveGame.id ?? "")
                    print("🎯 Auto-assigned role: \(assignedRole.displayName)")
                } catch {
                    print("❌ Failed to auto-assign role: \(error)")
                }
            }
        }
        
        switch assignedRole {
        case .recorder:
            // IMPROVED: Don't auto-start recording - go to "Ready to Record" state
            print("🎬 Recorder detected game - showing READY state (waiting for manual start)")
            currentFlow = .waitingToRecord(liveGame)
            
        case .controller, .viewer:
            print("🎮 Navigating to live game view")
            currentFlow = .liveGame(liveGame)
            
        case .none:
            print("❓ No role determined, staying in game setup")
            currentFlow = .gameSetup
        }
    }
    
    // MARK: - Smart Role Assignment
    
    private func determineOptimalRole(currentRole: DeviceRoleManager.DeviceRole, liveGame: LiveGame) -> DeviceRoleManager.DeviceRole {
        // If role already set, keep it
        if currentRole != .none {
            return currentRole
        }
        
        print("🤔 Determining optimal role for device...")
        
        // Check if this is a multi-device game
        guard liveGame.isMultiDeviceSetup == true else {
            print("📱 Single device game - assigning controller role")
            return .controller
        }
        
        // For multi-device games, use device characteristics to determine role
        let deviceType = UIDevice.current.userInterfaceIdiom
        let deviceName = UIDevice.current.name.lowercased()
        
        // Logic: iPad = Controller (better for stats), iPhone = Recorder (better camera)
        let preferredRole: DeviceRoleManager.DeviceRole = {
            if deviceType == .pad {
                return .controller // iPads are better for managing stats
            } else {
                // iPhone - check if there's already a controller
                if hasExistingController(in: liveGame) {
                    return .recorder // Join as recorder if controller exists
                } else {
                    // First iPhone joins as controller if no controller exists
                    return .controller
                }
            }
        }()
        
        print("🎯 Device type: \(deviceType), name: \(deviceName)")
        print("🎯 Optimal role determined: \(preferredRole.displayName)")
        
        return preferredRole
    }
    
    private func hasExistingController(in liveGame: LiveGame) -> Bool {
        // Check if someone is already controlling the game
        return liveGame.controllingDeviceId != nil && liveGame.controllingUserEmail != nil
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
            
        case .startRecording:
            print("🎬 Start recording signal received")
            // Transition recorder from waitingToRecord to recording
            if case .waitingToRecord(let liveGame) = currentFlow {
                print("🎬 Transitioning from ready state to recording")
                currentFlow = .recording(liveGame)
            } else {
                print("⚠️ Received start recording but not in ready state. Current: \(currentFlow)")
            }
            
        case .stopRecording:
            print("🛑 Stop recording signal received")
            // This will be handled by the recording view itself
            
        case .gameEnded:
            print("🏁 Game ended signal received")
            returnToDashboard()
            
        default:
            print("📨 Received message: \(message.type)")
        }
    }
}

