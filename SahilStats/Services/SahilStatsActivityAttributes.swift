//
//  SahilStatsActivityAttributes.swift
//  SahilStats
//
//  Live Activity attributes for Dynamic Island
//

import ActivityKit
import Foundation

struct SahilStatsActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Connection state
        var connectionStatus: ConnectionStatus
        var connectedDeviceName: String?

        // Game state
        var isGameActive: Bool
        var homeTeam: String?
        var awayTeam: String?
        var homeScore: Int
        var awayScore: Int
        var clockTime: String?
        var quarter: Int

        // Recording state
        var isRecording: Bool
        var recordingDuration: String?

        enum ConnectionStatus: String, Codable, Hashable {
            case connected
            case connecting
            case disconnected
            case searching
            case idle

            var displayText: String {
                switch self {
                case .connected: return "Connected"
                case .connecting: return "Connecting..."
                case .disconnected: return "Disconnected"
                case .searching: return "Searching..."
                case .idle: return "Ready"
                }
            }

            var emoji: String {
                switch self {
                case .connected: return "✅"
                case .connecting: return "🔄"
                case .disconnected: return "⚠️"
                case .searching: return "🔍"
                case .idle: return "📱"
                }
            }
        }
    }

    // Static data (doesn't change during the activity)
    var deviceRole: String // "Controller", "Recorder", or "Viewer"
}
