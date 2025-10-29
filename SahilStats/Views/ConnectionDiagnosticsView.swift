//
//  ConnectionDiagnosticsView.swift
//  SahilStats
//
//  Connection diagnostics for troubleshooting Bluetooth/MultipeerConnectivity issues
//

import SwiftUI
import MultipeerConnectivity

struct ConnectionDiagnosticsView: View {
    @ObservedObject private var multipeer = MultipeerConnectivityManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private func forceReconnect() {
        // Stop current session and restart with saved role
        let trustedDevices = TrustedDevicesManager.shared
        let roleManager = DeviceRoleManager.shared

        // Stop current attempt
        multipeer.stopSession()

        // Wait briefly, then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Get the saved role for the first trusted peer
            if let firstTrustedPeer = trustedDevices.allTrustedPeers.first {
                let peerID = MCPeerID(displayName: firstTrustedPeer.id)
                let role = trustedDevices.getMyRole(for: peerID) ?? roleManager.preferredRole
                let effectiveRole = role != .none ? role : .controller

                print("🔄 Force reconnect: Restarting as \(effectiveRole.displayName)")
                multipeer.startSession(role: effectiveRole)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                // Connection Status (connected or not)
                Section {
                    VStack(spacing: 20) {
                        if multipeer.connectionState.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("Connected")
                                .font(.title2)
                                .fontWeight(.semibold)

                            if let peer = multipeer.connectedPeers.first {
                                Text(peer.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("Not Connected")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text("Go to Settings → Device Pairing to connect")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Connection Status")
                }

                // Discovery Status (browsing/advertising)
                if !multipeer.connectionState.isConnected {
                    Section {
                        VStack(spacing: 12) {
                            DiagnosticRow(
                                label: "Browsing for Peers",
                                value: multipeer.isBrowsingActive ? "Active" : "Inactive",
                                icon: "magnifyingglass",
                                color: multipeer.isBrowsingActive ? .green : .gray
                            )

                            DiagnosticRow(
                                label: "Advertising Presence",
                                value: multipeer.isAdvertisingActive ? "Active" : "Inactive",
                                icon: "dot.radiowaves.right",
                                color: multipeer.isAdvertisingActive ? .green : .gray
                            )

                            // Force Reconnect Button (for gym troubleshooting)
                            if multipeer.isBrowsingActive || multipeer.isAdvertisingActive {
                                Button(action: {
                                    forceReconnect()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Force Reconnect")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Discovery Status")
                    } footer: {
                        if !multipeer.isBrowsingActive && !multipeer.isAdvertisingActive {
                            Text("Discovery is inactive. Go to Settings → Device Pairing to start searching.")
                        } else {
                            Text("Both devices must be browsing AND advertising to find each other. Use Force Reconnect if discovery is taking too long.")
                        }
                    }
                }

                // Interference Section
                Section {
                    VStack(spacing: 16) {
                        // Nearby Devices
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nearby Devices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(multipeer.nearbyDeviceCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            InterferenceIndicator(deviceCount: multipeer.nearbyDeviceCount)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        if multipeer.nearbyDeviceCount > 5 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("High interference detected. This may affect connection quality.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Interference")
                }

                // Connection Stability (only when connected)
                if multipeer.connectionState.isConnected {
                    Section {
                    VStack(spacing: 12) {
                        DiagnosticRow(
                            label: "Reconnections This Session",
                            value: "\(multipeer.reconnectionCount)",
                            icon: "arrow.triangle.2.circlepath",
                            color: multipeer.reconnectionCount == 0 ? .green : (multipeer.reconnectionCount <= 2 ? .orange : .red)
                        )
                    }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Connection Stability")
                    } footer: {
                        if multipeer.reconnectionCount == 0 {
                            Text("Connection has been stable with no disconnections")
                        } else {
                            Text("Connection dropped \(multipeer.reconnectionCount) time(s). This may indicate interference or weak signal.")
                        }
                    }
                }

                // Troubleshooting Tips
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if multipeer.nearbyDeviceCount > 10 {
                            RecommendationRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "Very high interference! \(multipeer.nearbyDeviceCount) nearby devices detected.",
                                color: .red
                            )
                            RecommendationRow(
                                icon: "location.fill",
                                text: "Move to a less crowded area (away from other people's devices)",
                                color: .orange
                            )
                            RecommendationRow(
                                icon: "wifi.slash",
                                text: "Try: Turn OFF WiFi on both devices, use Bluetooth only",
                                color: .blue
                            )
                        } else if multipeer.nearbyDeviceCount > 5 {
                            RecommendationRow(
                                icon: "antenna.radiowaves.left.and.right",
                                text: "Moderate interference detected (\(multipeer.nearbyDeviceCount) devices)",
                                color: .orange
                            )
                            RecommendationRow(
                                icon: "arrow.up.arrow.down",
                                text: "Keep devices within 10 feet of each other",
                                color: .blue
                            )
                        }

                        if multipeer.reconnectionCount > 2 {
                            RecommendationRow(
                                icon: "arrow.clockwise",
                                text: "Unstable connection. Try: Restart both devices, then reconnect",
                                color: .orange
                            )
                        }

                        if multipeer.nearbyDeviceCount <= 5 && multipeer.reconnectionCount == 0 {
                            RecommendationRow(
                                icon: "checkmark.circle.fill",
                                text: "Low interference, stable connection. Conditions are good!",
                                color: .green
                            )
                        }

                        // Always show general troubleshooting
                        RecommendationRow(
                            icon: "info.circle.fill",
                            text: "Tip: Bluetooth works better than WiFi in crowded gyms",
                            color: .blue
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Troubleshooting")
                } footer: {
                    Text("At gyms: Many phones/watches cause interference. Turn off WiFi and use Bluetooth only for better results.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Connection Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InterferenceIndicator: View {
    let deviceCount: Int

    private var interferenceLevel: (color: Color, label: String) {
        switch deviceCount {
        case 0...2:
            return (.green, "Minimal")
        case 3...5:
            return (.blue, "Moderate")
        case 6...10:
            return (.orange, "High")
        default:
            return (.red, "Very High")
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index < min(deviceCount / 3, 3) ? interferenceLevel.color : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            Text(interferenceLevel.label)
                .font(.caption)
                .foregroundColor(interferenceLevel.color)
        }
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RecommendationRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ConnectionDiagnosticsView()
}
