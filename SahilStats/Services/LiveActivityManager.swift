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

    @Published var isActivityActive = false
    private var currentActivity: Activity<SahilStatsActivityAttributes>?

    private init() {}

    // MARK: - Start Activity

    func startActivity(deviceRole: DeviceRole) {
        print("🏝️ LiveActivityManager: startActivity() called for role: \(deviceRole.displayName)")

        // Don't start if already active
        guard !isActivityActive else {
            print("📱 Live Activity already active")
            return
        }

        // Check if Live Activities are supported
        let authInfo = ActivityAuthorizationInfo()
        print("🏝️ Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities are not enabled")
            print("   User needs to enable in Settings → SahilStats → Allow Live Activities")
            return
        }

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
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            isActivityActive = true
            print("✅ Live Activity started for role: \(deviceRole.displayName)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    func updateConnectionState(
        status: MultipeerConnectivityManager.ConnectionState,
        connectedPeers: [String]
    ) {
        guard let activity = currentActivity else { return }

        let connectionStatus: SahilStatsActivityAttributes.ContentState.ConnectionStatus
        let deviceName: String?

        switch status {
        case .connected:
            connectionStatus = .connected
            deviceName = connectedPeers.first
        case .connecting(let peerName):
            connectionStatus = .connecting
            deviceName = peerName
        case .disconnected:
            connectionStatus = .disconnected
            deviceName = nil
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
            print("🔄 Live Activity updated: connection = \(connectionStatus.displayText)")
        }
    }

    func updateGameState(liveGame: LiveGame?) {
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
            print("🔄 Live Activity updated: game state")
        }
    }

    func updateRecordingState(isRecording: Bool, duration: String? = nil) {
        guard let activity = currentActivity else { return }

        Task {
            var updatedState = activity.content.state
            updatedState.isRecording = isRecording
            updatedState.recordingDuration = duration

            await activity.update(
                .init(state: updatedState, staleDate: nil)
            )
            print("🔄 Live Activity updated: recording = \(isRecording)")
        }
    }

    // MARK: - Stop Activity

    func stopActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            isActivityActive = false
            print("⏹️ Live Activity stopped")
        }
    }
}
