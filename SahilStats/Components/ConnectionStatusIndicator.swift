//
//  ConnectionStatusIndicator.swift
//  SahilStats
//
//  Persistent connection status indicator shown during games
//

import SwiftUI

struct ConnectionStatusIndicator: View {
    @ObservedObject var multipeer = MultipeerConnectivityManager.shared
    let deviceRole: DeviceRole

    private var statusColor: Color {
        switch multipeer.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .searching:
            return .yellow
        case .disconnected:
            return .red
        case .idle:
            return .gray
        }
    }

    private var statusText: String {
        switch multipeer.connectionState {
        case .connected(let peerName):
            let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
            return friendlyName
        case .connecting(let peerName):
            let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
            return "Connecting to \(friendlyName)"
        case .searching:
            return "Searching..."
        case .disconnected(let peerName):
            let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
            return "Disconnected from \(friendlyName)"
        case .idle:
            return "No connection"
        }
    }

    private var statusIcon: String {
        switch multipeer.connectionState {
        case .connected:
            return "wifi"
        case .connecting, .searching:
            return "wifi.exclamationmark"
        case .disconnected:
            return "wifi.slash"
        case .idle:
            return "wifi.slash"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Connection status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Connection icon
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundColor(statusColor)

            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)

            // Device role badge
            Text(deviceRole.displayName)
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                )

            // Recording indicator (if recorder)
            if deviceRole == .recorder {
                let isRecording = multipeer.isRemoteRecording ?? VideoRecordingManager.shared.isRecording
                if isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("REC")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// Compact version for smaller screens or minimal UI
struct CompactConnectionStatusIndicator: View {
    @ObservedObject var multipeer = MultipeerConnectivityManager.shared

    private var statusColor: Color {
        switch multipeer.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .searching:
            return .yellow
        case .disconnected:
            return .red
        case .idle:
            return .gray
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if case .connected(let peerName) = multipeer.connectionState {
                let friendlyName = MultipeerConnectivityManager.ConnectionState.getFriendlyName(for: peerName)
                Text(friendlyName)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
        )
    }
}

// Preview
#Preview {
    VStack(spacing: 20) {
        ConnectionStatusIndicator(deviceRole: .controller)
        ConnectionStatusIndicator(deviceRole: .recorder)
        CompactConnectionStatusIndicator()
    }
    .padding()
    .background(Color.gray)
}
