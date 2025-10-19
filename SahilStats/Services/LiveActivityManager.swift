//
//  LiveActivityManager.swift
//  SahilStats
//
//  Manages Live Activity for Dynamic Island
//

import ActivityKit
import Foundation
import Combine

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    // FEATURE FLAG: Enable Live Activities for viewer role only
    // Viewers can glance at Dynamic Island to see live scores while watching the game
    // Not useful for recorder (on tripod) or controller (using full app)
    private static let isEnabled = true

    @Published var isActivityActive = false
    private var currentActivity: Activity<SahilStatsActivityAttributes>?

    private init() {}

    // MARK: - Start Activity

    func startActivity(deviceRole: DeviceRole) {
        // Feature flag check - skip if disabled
        guard Self.isEnabled else {
            debugPrint("🏝️ Live Activity disabled via feature flag")
            return
        }

        // Only enable for viewer role - not useful for recorder (on tripod) or controller (using full app)
        guard deviceRole == .viewer else {
            debugPrint("🏝️ Live Activity skipped for \(deviceRole.displayName) role (viewer only)")
            return
        }

        debugPrint("🏝️ LiveActivityManager: startActivity() called for role: \(deviceRole.displayName)")

        // Don't start if already active
        guard !isActivityActive else {
            debugPrint("📱 Live Activity already active")
            return
        }

        // Check if Live Activities are supported
        let authInfo = ActivityAuthorizationInfo()
        debugPrint("🏝️ Live Activities authorization status: \(authInfo.areActivitiesEnabled)")
        debugPrint("🏝️ Frequent pushes enabled: \(authInfo.frequentPushesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            debugPrint("⚠️ Live Activities are NOT enabled")
            debugPrint("   📱 User needs to enable in Settings → SahilStats → Allow Live Activities")
            debugPrint("   This is why you're seeing notification banners instead of Dynamic Island")
            return
        }

        debugPrint("✅ Live Activities ARE enabled - attempting to start...")

        let attributes = SahilStatsActivityAttributes(
            deviceRole: deviceRole.displayName
        )

        let initialState = SahilStatsActivityAttributes.ContentState(
            connectionStatus: .idle,
            connectedDeviceName: nil,
            isGameActive: false,
            homeTeam: nil,
            awayTeam: nil,
            homeScore: 0,
            awayScore: 0,
            clockTime: nil,
            quarter: 1,
            isRecording: false,
            recordingDuration: nil
        )

        do {
            debugPrint("🏝️ Requesting Live Activity with attributes: \(deviceRole.displayName)")
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            isActivityActive = true
            debugPrint("✅ Live Activity started successfully for role: \(deviceRole.displayName)")
            debugPrint("   Activity ID: \(currentActivity?.id ?? "unknown")")
        } catch {
            forcePrint("❌ Failed to start Live Activity: \(error.localizedDescription)")
            debugPrint("   Error details: \(error)")

            // Check if it's a common error
            if let activityError = error as? ActivityAuthorizationError {
                debugPrint("   Authorization error: \(activityError)")
            }
        }
    }

    // MARK: - Update Activity

    func updateConnectionState(
        status: MultipeerConnectivityManager.ConnectionState,
        connectedPeers: [String]
    ) {
        guard Self.isEnabled else { return }
        guard let activity = currentActivity else { return }

        let connectionStatus: SahilStatsActivityAttributes.ContentState.ConnectionStatus
        let deviceName: String?

        switch status {
        case .connected(let peerName):
            connectionStatus = .connected
            // Use friendly name from TrustedDevicesManager
            deviceName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
        case .connecting(let peerName):
            connectionStatus = .connecting
            // Use friendly name from TrustedDevicesManager
            deviceName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
        case .disconnected(let peerName):
            connectionStatus = .disconnected
            deviceName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
        case .searching:
            connectionStatus = .searching
            deviceName = nil
        case .idle:
            connectionStatus = .idle
            deviceName = nil
        }

        Task {
            var updatedState = activity.content.state
            updatedState.connectionStatus = connectionStatus
            updatedState.connectedDeviceName = deviceName

            await activity.update(
                .init(state: updatedState, staleDate: nil)
            )
            debugPrint("🔄 Live Activity updated: connection = \(connectionStatus.displayText), device = \(deviceName ?? "none")")
        }
    }

    func updateGameState(liveGame: LiveGame?) {
        guard Self.isEnabled else { return }
        guard let activity = currentActivity else { return }

        Task {
            var updatedState = activity.content.state

            if let game = liveGame {
                updatedState.isGameActive = true
                updatedState.homeTeam = game.teamName
                updatedState.awayTeam = game.opponent
                updatedState.homeScore = game.homeScore
                updatedState.awayScore = game.awayScore
                updatedState.clockTime = game.currentClockDisplay
                updatedState.quarter = game.quarter
            } else {
                updatedState.isGameActive = false
                updatedState.homeTeam = nil
                updatedState.awayTeam = nil
                updatedState.homeScore = 0
                updatedState.awayScore = 0
                updatedState.clockTime = nil
                updatedState.quarter = 1
            }

            await activity.update(
                .init(state: updatedState, staleDate: nil)
            )
            debugPrint("🔄 Live Activity updated: game state")
        }
    }

    func updateRecordingState(isRecording: Bool, duration: String? = nil) {
        guard Self.isEnabled else { return }
        guard let activity = currentActivity else { return }

        Task {
            var updatedState = activity.content.state
            updatedState.isRecording = isRecording
            updatedState.recordingDuration = duration

            await activity.update(
                .init(state: updatedState, staleDate: nil)
            )
            debugPrint("🔄 Live Activity updated: recording = \(isRecording)")
        }
    }

    // MARK: - Stop Activity

    func stopActivity() {
        guard Self.isEnabled else { return }
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            isActivityActive = false
            debugPrint("⏹️ Live Activity stopped")
        }
    }
}
