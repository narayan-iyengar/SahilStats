//
//  SahilStatsLiveActivity.swift
//  SahilStats
//
//  Dynamic Island and Live Activity UI
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SahilStatsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SahilStatsActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - shown when user taps on Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    ConnectionStatusView(
                        status: context.state.connectionStatus,
                        deviceName: context.state.connectedDeviceName
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isRecording {
                        RecordingIndicatorView(duration: context.state.recordingDuration)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.isGameActive {
                        GameScoreView(
                            homeTeam: context.state.homeTeam ?? "Home",
                            awayTeam: context.state.awayTeam ?? "Away",
                            homeScore: context.state.homeScore,
                            awayScore: context.state.awayScore,
                            clockTime: context.state.clockTime,
                            quarter: context.state.quarter
                        )
                    } else {
                        VStack(spacing: 4) {
                            Text("🏀 SahilStats")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Waiting for game to start...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isGameActive {
                        HStack {
                            Image(systemName: "basketball.fill")
                                .foregroundColor(.orange)
                            Text("Q\(context.state.quarter)")
                                .font(.caption)
                            if let clockTime = context.state.clockTime {
                                Text(clockTime)
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            } compactLeading: {
                // Compact leading - connection status
                ConnectionDotView(status: context.state.connectionStatus)
            } compactTrailing: {
                // Compact trailing - always show something meaningful
                if context.state.isGameActive {
                    // Show score prominently
                    HStack(spacing: 2) {
                        Text("\(context.state.homeScore)")
                            .font(.caption)
                            .bold()
                            .monospacedDigit()
                        Text("-")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(context.state.awayScore)")
                            .font(.caption)
                            .bold()
                            .monospacedDigit()
                    }
                } else {
                    // Show appropriate icon based on role when waiting
                    let icon = context.attributes.deviceRole.contains("Control") ? "gamecontroller.fill" :
                               context.attributes.deviceRole.contains("Viewer") ? "eye.fill" : "basketball.fill"
                    Image(systemName: icon)
                        .foregroundColor(.orange)
                        .font(.caption2)
                }
            } minimal: {
                // Minimal - just a dot showing connection/recording status
                if context.state.isRecording {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                } else {
                    ConnectionDotView(status: context.state.connectionStatus)
                }
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<SahilStatsActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Connection status
            HStack {
                Text(context.state.connectionStatus.emoji)
                Text(context.state.connectionStatus.displayText)
                    .font(.caption)

                if let deviceName = context.state.connectedDeviceName {
                    Text("• \(deviceName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(context.attributes.deviceRole)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if context.state.isGameActive {
                // Game score
                HStack(spacing: 20) {
                    VStack {
                        Text(context.state.homeTeam ?? "Home")
                            .font(.caption)
                            .lineLimit(1)
                        Text("\(context.state.homeScore)")
                            .font(.title2)
                            .bold()
                    }

                    VStack {
                        if let clockTime = context.state.clockTime {
                            Text(clockTime)
                                .font(.caption)
                                .monospacedDigit()
                        }
                        Text("Q\(context.state.quarter)")
                            .font(.caption2)
                    }

                    VStack {
                        Text(context.state.awayTeam ?? "Away")
                            .font(.caption)
                            .lineLimit(1)
                        Text("\(context.state.awayScore)")
                            .font(.title2)
                            .bold()
                    }
                }
            }

            if context.state.isRecording {
                HStack {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                    Text("Recording")
                        .font(.caption)
                    if let duration = context.state.recordingDuration {
                        Text(duration)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Subviews

struct ConnectionStatusView: View {
    let status: SahilStatsActivityAttributes.ContentState.ConnectionStatus
    let deviceName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(status.emoji)
                    .font(.caption)
                Text(status.displayText)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }

            if let name = deviceName {
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct ConnectionDotView: View {
    let status: SahilStatsActivityAttributes.ContentState.ConnectionStatus

    var dotColor: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        case .searching: return .yellow
        case .idle: return .gray
        }
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
    }
}

struct GameScoreView: View {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    let clockTime: String?
    let quarter: Int

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(homeTeam)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(homeScore)")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
            }
            .frame(minWidth: 50)

            VStack(spacing: 2) {
                if let time = clockTime {
                    Text(time)
                        .font(.caption)
                        .monospacedDigit()
                }
                Text("Q\(quarter)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            VStack(spacing: 2) {
                Text(awayTeam)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(awayScore)")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
            }
            .frame(minWidth: 50)
        }
    }
}

struct RecordingIndicatorView: View {
    let duration: String?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "record.circle.fill")
                .foregroundColor(.red)
                .font(.title3)

            if let duration = duration {
                Text(duration)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }
}
