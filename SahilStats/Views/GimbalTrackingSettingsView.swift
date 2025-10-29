//
//  GimbalTrackingSettingsView.swift
//  SahilStats
//
//  Settings for DockKit gimbal tracking (Insta360 Flow 2 Pro)
//

import SwiftUI

struct GimbalTrackingSettingsView: View {
    @ObservedObject private var gimbalManager = GimbalTrackingManager.shared
    @State private var isEnabled: Bool = false
    @State private var selectedMode: GimbalTrackingManager.TrackingMode = .multiObject

    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    Image(systemName: trackingInfo.statusIcon)
                        .foregroundColor(trackingInfo.statusColor)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("DockKit Status")
                            .font(.headline)

                        Text(gimbalManager.getTrackingStatus())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                if let error = trackingInfo.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            } header: {
                Text("Status")
            }

            // Camera Configuration Warning
            if gimbalManager.isDockKitAvailable {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            Text("Back Camera Setup")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("To use the back camera for basketball recording:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("1.")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("Open iPhone Settings app")
                                    .font(.caption)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("2.")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("Search for 'DockKit'")
                                    .font(.caption)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("3.")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("Turn OFF 'DockKit in background mode'")
                                    .font(.caption)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("4.")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("Return to this app and test tracking")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } header: {
                    Text("Camera Configuration")
                } footer: {
                    Text("The 'DockKit in background mode' setting makes iOS use the front camera automatically. Turn it off so the app can control gimbal tracking with the back camera during game recording.")
                }
            }

            // Enable/Disable Section
            Section {
                Toggle("Enable Gimbal Tracking", isOn: $isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .disabled(!gimbalManager.isDockKitAvailable)
                    .onChange(of: isEnabled) {
                        gimbalManager.setEnabled(isEnabled)
                    }

                if !gimbalManager.isDockKitAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connect Your Gimbal")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Mount your iPhone on the Insta360 Flow Pro 2 and turn it on. DockKit will automatically detect the gimbal via Bluetooth.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            } header: {
                Text("Gimbal Tracking")
            } footer: {
                Text("Automatically track players during recording. The gimbal will start tracking when you begin recording a game. Works with Insta360 Flow 2 Pro and other DockKit-compatible gimbals.")
            }

            // Tracking Mode Selection
            if isEnabled {
                Section {
                    Picker("Tracking Mode", selection: $selectedMode) {
                        ForEach(GimbalTrackingManager.TrackingMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.displayName)

                                // Show "Recommended" badge for multi-object
                                if mode.isRecommendedForBasketball {
                                    Spacer()
                                    Text("RECOMMENDED")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .cornerRadius(4)
                                }
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedMode) {
                        gimbalManager.setTrackingMode(selectedMode)
                    }

                    // Mode Description
                    HStack(spacing: 8) {
                        Image(systemName: selectedMode.isRecommendedForBasketball ? "star.fill" : "info.circle")
                            .foregroundColor(selectedMode.isRecommendedForBasketball ? .orange : .blue)
                        Text(selectedMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    // Multi-object specific info
                    if selectedMode == .multiObject {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "basketball.fill")
                                    .foregroundColor(.orange)
                                Text("BASKETBALL MODE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }

                            Text("• Tracks up to 9 players independently")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Automatically keeps all players in frame")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Perfect for 5-on-5 games (10 players total)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Intelligent framing adjusts as players move")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                } header: {
                    Text("Tracking Mode")
                } footer: {
                    Text("Multi-Object tracking uses the Flow Pro 2's advanced AI to track each player individually. This provides the best coverage for basketball games.")
                }
            }

            // How It Works Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "person.3.sequence.fill",
                        title: "Multi-Object Tracking",
                        description: "Tracks up to 9 players individually, perfect for 5v5 basketball"
                    )

                    FeatureRow(
                        icon: "viewfinder",
                        title: "Intelligent Framing",
                        description: "Automatically adjusts zoom and pan to keep all tracked players visible"
                    )

                    FeatureRow(
                        icon: "arrow.left.and.right",
                        title: "Smart Panning",
                        description: "Follows the action smoothly as players move around the court"
                    )

                    FeatureRow(
                        icon: "hand.tap.fill",
                        title: "Tap to Add/Remove",
                        description: "Tap on screen to manually add/remove players from tracking"
                    )

                    FeatureRow(
                        icon: "eye.fill",
                        title: "Auto-Detection",
                        description: "Automatically detects and tracks visible players without manual selection"
                    )

                    FeatureRow(
                        icon: "iphone",
                        title: "Works Offline",
                        description: "No internet required - all processing happens on-device"
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("How It Works")
            }

            // Basketball Tips Section
            if selectedMode == .multiObject || !isEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(
                            icon: "location.fill",
                            title: "Position Behind Baseline",
                            description: "Place gimbal behind the basket for best full-court view"
                        )

                        TipRow(
                            icon: "arrow.up.backward.and.arrow.down.forward",
                            title: "Elevated Position",
                            description: "Mount 6-8 feet high for optimal player tracking"
                        )

                        TipRow(
                            icon: "light.max",
                            title: "Good Lighting",
                            description: "Tracking works best with consistent gym lighting"
                        )

                        TipRow(
                            icon: "figure.basketball",
                            title: "Let It Auto-Detect",
                            description: "Flow Pro 2 automatically finds and tracks all players - no manual selection needed!"
                        )
                    }
                } header: {
                    Text("Basketball Tips")
                } footer: {
                    Text("The Flow Pro 2's AI is trained to recognize basketball scenarios and will automatically track players as they enter/exit the frame.")
                }
            }

            // Compatibility Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    CompatibilityRow(
                        device: "Insta360 Flow 2 Pro",
                        status: .supported
                    )

                    CompatibilityRow(
                        device: "Other DockKit Gimbals",
                        status: .supported
                    )

                    CompatibilityRow(
                        device: "DJI OSMO (older models)",
                        status: .notSupported
                    )
                }
            } header: {
                Text("Compatible Hardware")
            } footer: {
                Text("DockKit is Apple's official gimbal API, available on iOS 17+. Multi-object tracking requires hardware support (Flow Pro 2 confirmed).")
            }
        }
        .navigationTitle("Gimbal Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnabled = gimbalManager.isTrackingEnabled()
            selectedMode = gimbalManager.trackingMode
        }
    }

    private var trackingInfo: GimbalTrackingManager.TrackingInfo {
        gimbalManager.getTrackingInfo()
    }
}

// MARK: - Supporting Views

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CompatibilityRow: View {
    enum Status {
        case supported
        case notSupported
        case unknown

        var icon: String {
            switch self {
            case .supported: return "checkmark.circle.fill"
            case .notSupported: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .supported: return .green
            case .notSupported: return .red
            case .unknown: return .gray
            }
        }

        var label: String {
            switch self {
            case .supported: return "Supported"
            case .notSupported: return "Not Supported"
            case .unknown: return "Unknown"
            }
        }
    }

    let device: String
    let status: Status

    var body: some View {
        HStack {
            Text(device)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                Text(status.label)
                    .font(.caption)
                    .foregroundColor(status.color)
            }
        }
    }
}

#Preview {
    NavigationView {
        GimbalTrackingSettingsView()
    }
}
