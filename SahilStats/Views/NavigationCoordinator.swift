// SahilStats/Views/NavigationCoordinator.swift

import SwiftUI
import Combine

@MainActor
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()

    @Published var currentFlow: AppFlow = .dashboard
    @Published var userExplicitlyJoinedGame = false

    private var appStartTime = Date()
    private var hasUserInteractedWithApp = false
    private let startupGracePeriod: TimeInterval = 3.0

    enum AppFlow: Equatable {
        case dashboard
        case liveGame(LiveGame)
        case gameSetup
        case recording(LiveGame)
        case waitingToRecord(LiveGame?)  // Optional - recorder may not have game info yet
    }

    private let liveGameManager = LiveGameManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        debugPrint("📱 NavigationCoordinator: Initializing")
        setupObservers()
    }

    private func setupObservers() {
        liveGameManager.$liveGame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveGame in
                self?.handleLiveGameChange(liveGame)
            }
            .store(in: &cancellables)
    }

    func resumeLiveGame() {
        debugPrint("🎯 Resuming live game")
        markUserHasInteracted()
        userExplicitlyJoinedGame = true

        // Start Live Activity for all roles (shows connection status in Dynamic Island)
        let deviceRole = DeviceRoleManager.shared.deviceRole
        debugPrint("🏝️ Starting Live Activity for \(deviceRole.displayName)")
        LiveActivityManager.shared.startActivity(deviceRole: deviceRole)

        if let liveGame = liveGameManager.liveGame {
            navigateToGameFlow(liveGame)
        } else {
            currentFlow = .gameSetup
        }
    }

    func returnToDashboard() {
        debugPrint("🏠 Returning to dashboard")

        // Stop Live Activity when leaving game
        LiveActivityManager.shared.stopActivity()

        // Reset orientation lock to portrait for dashboard
        AppDelegate.orientationLock = .portrait
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        debugPrint("🔄 Reset orientation lock to portrait")

        currentFlow = .dashboard
        userExplicitlyJoinedGame = false
        hasUserInteractedWithApp = false
        DeviceRoleManager.shared.deviceRole = .none
        liveGameManager.reset()
        // Don't reset appStartTime - it should only be set once at app launch
    }

    func markUserHasInteracted() {
        if !hasUserInteractedWithApp {
            debugPrint("👤 User interaction marked")
            hasUserInteractedWithApp = true
        }
    }

    private var shouldAllowAutoNavigation: Bool {
        // --- FIX: Stricter check ---
        // Auto-navigation is only allowed if the user has explicitly joined a game flow.
        // The "tripod mode" will now set `userExplicitlyJoinedGame` to true when the user taps "Join".
        return userExplicitlyJoinedGame
    }

    private func handleLiveGameChange(_ liveGame: LiveGame?) {
        debugPrint("📱 handleLiveGameChange called. Should allow auto-nav: \(shouldAllowAutoNavigation)")

        // This guard is now the single point of control. It prevents any navigation
        // until the user has taken an explicit action to join or start a game.
        guard shouldAllowAutoNavigation else {
            if Date().timeIntervalSince(appStartTime) <= startupGracePeriod {
                debugPrint("📱 Ignoring live game change - app just started.")
            } else {
                debugPrint("📱 Ignoring live game change - user has not explicitly joined a game.")
            }
            return
        }

        if let game = liveGame {
            debugPrint("🎮 Live game is active: \(game.id ?? "unknown"). Navigating.")
            navigateToGameFlow(game)
        } else {
            debugPrint("🎮 Live game ended. Returning to dashboard.")
            returnToDashboard()
        }
    }
    
    private func navigateToGameFlow(_ liveGame: LiveGame) {
        let currentRole = DeviceRoleManager.shared.deviceRole
        debugPrint("🎯 navigateToGameFlow called with role: \(currentRole)")

        switch currentRole {
        case .recorder:
            debugPrint("🎬 Role is Recorder. Showing READY state.")
            currentFlow = .waitingToRecord(Optional(liveGame))
        case .controller, .viewer:
            debugPrint("🎮 Role is Controller/Viewer. Navigating to live game view.")
            currentFlow = .liveGame(liveGame)
        case .none:
            // If no role is set, stay in dashboard
            // The user will tap the Live pill which shows a role selection sheet
            debugPrint("❓ No role set for existing game. User should tap Live pill to select role.")
        }
    }
}
