//
//  RootNavigationView.swift
//  SahilStats
//
//  Single source of truth for app navigation
//

import SwiftUI
import Combine

struct RootNavigationView: View {
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @EnvironmentObject var authService: AuthService
    @StateObject private var firebaseService = FirebaseService.shared

    var body: some View {
        Group {
            if authService.isLoading {
                SplashView()
            } else {
                // Logic is now driven entirely by the navigation flow state
                switch navigation.currentFlow {
                case .dashboard:
                    MainTabView()
                        .onAppear {
                            // Always re-enable idle timer when returning to dashboard
                            UIApplication.shared.isIdleTimerDisabled = false
                            debugPrint("🌙 Dashboard: Idle timer enabled - screen can now sleep")
                        }
                case .gameSetup:
                    // This case is handled within MainTabView's navigation
                    GameSetupView()
                        .onAppear {
                            // Ensure idle timer is enabled during game setup
                            UIApplication.shared.isIdleTimerDisabled = false
                            debugPrint("🌙 GameSetup: Idle timer enabled - screen can now sleep")
                        }
                case .liveGame(let liveGame):
                    LiveGameView()
                        .onAppear {
                            // Only keep screen awake for multi-device games
                            // Single-device stats-only games can sleep normally
                            let isMultiDevice = liveGame.isMultiDeviceSetup ?? false
                            UIApplication.shared.isIdleTimerDisabled = isMultiDevice

                            if isMultiDevice {
                                debugPrint("🔥 LiveGame (Multi-device): Idle timer disabled - screen stays awake")
                            } else {
                                debugPrint("🌙 LiveGame (Single-device): Idle timer enabled - screen can sleep")
                            }
                        }
                        .onDisappear {
                            // Re-enable idle timer when leaving live game
                            UIApplication.shared.isIdleTimerDisabled = false
                            debugPrint("🌙 LiveGame: Idle timer enabled - screen can sleep")
                        }
                case .recording(let liveGame):
                    CleanVideoRecordingView(liveGame: liveGame)
                case .waitingToRecord(let liveGame):
                    // This correctly uses your existing RecorderReadyView.swift file
                    RecorderReadyView(liveGame: liveGame)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: navigation.currentFlow)
        .onAppear {
            debugPrint("🏠 RootNavigationView: Appeared with currentFlow: \(navigation.currentFlow)")
            // On fresh launch, if a game exists but the user hasn't joined,
            // ensure we stay on the dashboard to allow connections to establish.
            if firebaseService.hasLiveGame && !navigation.userExplicitlyJoinedGame {
                navigation.currentFlow = .dashboard
            }
        }
    }
}


// MARK: - Splash View

struct SplashView: View {
    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            scale = 1.1
                        }
                    }

                Text("Sahil's Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAuth = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                // Schedule Tab (upcoming games from calendar)
                NavigationView {
                    ScheduleView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }

                // History Tab (career stats and recent games)
                HistoryView()
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text("History")
                    }

                // Settings Tab
                NavigationView {
                    SettingsView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
            }
            .environment(\.horizontalSizeClass, .compact)
            .accentColor(.orange)
            .sheet(isPresented: $showingAuth) {
                AuthView()
            }
            .onAppear {
                // Mark user interaction when they see the main app interface
                NavigationCoordinator.shared.markUserHasInteracted()
            }
        }
    }
}


// MARK: - Simplified Role Selection

struct RoleSelectionView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Choose Your Role")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select how you want to participate in this game")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                RoleButton(
                    title: "Controller",
                    subtitle: "Control the game and manage stats",
                    icon: "gamecontroller.fill",
                    color: .blue,
                    action: {
                        DeviceRoleManager.shared.deviceRole = DeviceRole.controller
                        NavigationCoordinator.shared.resumeLiveGame()
                    }
                )

                RoleButton(
                    title: "Recorder",
                    subtitle: "Record video and capture highlights",
                    icon: "video.fill",
                    color: .red,
                    action: {
                        DeviceRoleManager.shared.deviceRole = DeviceRole.recorder
                        NavigationCoordinator.shared.resumeLiveGame()
                    }
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Cancel") {
                NavigationCoordinator.shared.returnToDashboard()
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct RoleButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
