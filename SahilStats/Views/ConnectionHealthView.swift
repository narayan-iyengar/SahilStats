//
//  ConnectionHealthView.swift
//  SahilStats
//
//  Connection health indicator for gym use (no Xcode needed)
//

import SwiftUI
import Combine

struct ConnectionHealthView: View {
    @StateObject private var mpcManager = MultipeerConnectivityManager.shared
    @State private var stats: MultipeerConnectivityManager.ConnectionStats?

    // Timer to update stats periodically
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Connection")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let stats = stats {
                    // Signal strength bars (RSSI-style)
                    SignalStrengthBars(health: stats.keepAliveHealth)
                }
            }

            if let stats = stats {
                if stats.isConnected {
                    HStack(spacing: 8) {
                        // Session duration
                        Label(stats.sessionDurationFormatted, systemImage: "clock")
                            .font(.caption2)

                        // Connection quality percentage
                        Label(stats.keepAliveHealthPercent, systemImage: "checkmark.circle")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)

                    // Show warning if quality is poor
                    if stats.keepAliveHealth < 0.80 {
                        Text("⚠️ Poor connection quality")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    // Show disconnect count if any
                    if stats.totalDisconnections > 0 {
                        Text("Reconnects: \(stats.totalDisconnections)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Not connected")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            } else {
                Text("Loading...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .onAppear {
            updateStats()
        }
        .onReceive(timer) { _ in
            updateStats()
        }
    }

    private func updateStats() {
        stats = mpcManager.getConnectionStats()
    }
}

// MARK: - Compact Version (for embedding in existing views)

struct CompactConnectionHealth: View {
    @StateObject private var mpcManager = MultipeerConnectivityManager.shared
    @State private var stats: MultipeerConnectivityManager.ConnectionStats?

    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            if let stats = stats {
                // Signal strength bars
                SignalStrengthBars(health: stats.keepAliveHealth)

                if stats.isConnected {
                    Text(stats.sessionDurationFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if stats.totalDisconnections > 0 {
                        Text("(\(stats.totalDisconnections)x)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("No Connection")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            } else {
                SignalStrengthBars(health: 0.0)
                Text("...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(6)
        .onAppear {
            updateStats()
        }
        .onReceive(timer) { _ in
            updateStats()
        }
    }

    private func updateStats() {
        stats = mpcManager.getConnectionStats()
    }
}

// MARK: - Signal Strength Bars (RSSI-style)

struct SignalStrengthBars: View {
    let health: Double  // 0.0 to 1.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: CGFloat(4 + index * 2))
                    .opacity(barOpacity(for: index))
            }
        }
    }

    private func barOpacity(for index: Int) -> Double {
        let threshold = Double(index) / 4.0
        return health >= threshold ? 1.0 : 0.3
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Double(index) / 4.0
        if health < threshold {
            return .gray
        }

        // Color based on overall health
        if health >= 0.95 {
            return .green
        } else if health >= 0.80 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

struct ConnectionHealthView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ConnectionHealthView()
            CompactConnectionHealth()

            // Signal strength preview
            VStack(spacing: 12) {
                Text("Signal Strength Examples:")
                    .font(.caption)
                HStack(spacing: 20) {
                    VStack {
                        SignalStrengthBars(health: 1.0)
                        Text("100%")
                            .font(.caption2)
                    }
                    VStack {
                        SignalStrengthBars(health: 0.90)
                        Text("90%")
                            .font(.caption2)
                    }
                    VStack {
                        SignalStrengthBars(health: 0.75)
                        Text("75%")
                            .font(.caption2)
                    }
                    VStack {
                        SignalStrengthBars(health: 0.50)
                        Text("50%")
                            .font(.caption2)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
    }
}
