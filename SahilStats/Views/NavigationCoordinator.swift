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
        case waitingToRecord(LiveGame)
    }

    private let liveGameManager = LiveGameManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("📱 NavigationCoordinator: Initializing")
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
        print("🎯 Resuming live game")
        markUserHasInteracted()
        userExplicitlyJoinedGame = true
        if let liveGame = liveGameManager.liveGame {
            navigateToGameFlow(liveGame)
        } else {
            currentFlow = .gameSetup
        }
    }

    func returnToDashboard() {
        print("🏠 Returning to dashboard")
        currentFlow = .dashboard
        userExplicitlyJoinedGame = false
        hasUserInteractedWithApp = false
        DeviceRoleManager.shared.deviceRole = .none
        liveGameManager.reset()
        appStartTime = Date()
    }

    func markUserHasInteracted() {
        if !hasUserInteractedWithApp {
            print("👤 User interaction marked")
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
        print("📱 handleLiveGameChange called. Should allow auto-nav: \(shouldAllowAutoNavigation)")

        // This guard is now the single point of control. It prevents any navigation
        // until the user has taken an explicit action to join or start a game.
        guard shouldAllowAutoNavigation else {
            if Date().timeIntervalSince(appStartTime) <= startupGracePeriod {
                print("📱 Ignoring live game change - app just started.")
            } else {
                print("📱 Ignoring live game change - user has not explicitly joined a game.")
            }
            return
        }

        if let game = liveGame {
            print("🎮 Live game is active: \(game.id ?? "unknown"). Navigating.")
            navigateToGameFlow(game)
        } else {
            print("🎮 Live game ended. Returning to dashboard.")
            returnToDashboard()
        }
    }
    
    private func navigateToGameFlow(_ liveGame: LiveGame) {
        let currentRole = DeviceRoleManager.shared.deviceRole
        print("🎯 navigateToGameFlow called with role: \(currentRole)")

        switch currentRole {
        case .recorder:
            print("🎬 Role is Recorder. Showing READY state.")
            currentFlow = .waitingToRecord(liveGame)
        case .controller, .viewer:
            print("🎮 Role is Controller/Viewer. Navigating to live game view.")
            currentFlow = .liveGame(liveGame)
        case .none:
            // If no role is set but a live game exists, prompt the user to select one.
            // This happens when a user opens the app and a game is already in progress.
            print("❓ No role set for existing game. Staying in dashboard/setup.")
            // The UI (e.g., GameListView) will show a "Join Live Game" button.
        }
    }
}
