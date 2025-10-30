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
    @State private var selectedMode: GimbalTrackingManager.TrackingMode = .intelligentCourt

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

            // Intelligent Tracking Explanation
            if gimbalManager.isDockKitAvailable {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Intelligent Tracking")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("iOS 18+ ML-Powered Basketball Tracking")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("🏀")
                                Text("Automatically follows game action on court")
                                    .font(.caption)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("🧠")
                                Text("AI selects most relevant player using ML")
                                    .font(.caption)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("📊")
                                Text("Analyzes body pose, attention, and activity")
                                    .font(.caption)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("📍")
                                Text("Stays focused on court area (won't follow benched players)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                } header: {
                    Text("How It Works")
                } footer: {
                    Text("The gimbal uses Apple's DockKit ML model to intelligently track basketball action. No manual control needed during games.")
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

                    // Intelligent Court specific info
                    if selectedMode == .intelligentCourt {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.fill")
                                    .foregroundColor(.purple)
                                Text("AI-POWERED TRACKING")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }

                            Text("• ML model selects most relevant player")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Analyzes body pose and player activity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Automatically switches between players during action")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Keeps focus on court area (ignores benched players)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                } header: {
                    Text("Tracking Mode")
                } footer: {
                    Text("Intelligent Court uses iOS 18+ machine learning to automatically follow basketball action. The gimbal will pan, tilt, and frame to keep the most active player in view.")
                }

                // Court Region Setup
                if selectedMode == .intelligentCourt || selectedMode == .courtZone {
                    Section {
                        NavigationLink(destination: CourtRegionSetupView()) {
                            HStack {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(.green)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Align Court Region")
                                        .font(.body)
                                    Text("Define the basketball court area for tracking")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Court Setup")
                    } footer: {
                        Text("Use the visual alignment tool to frame your basketball court. The gimbal will only track players within this region.")
                    }
                }
            }

            // How It Works Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "brain.fill",
                        title: "ML-Based Selection",
                        description: "Advanced machine learning analyzes players to select who to follow"
                    )

                    FeatureRow(
                        icon: "figure.basketball",
                        title: "Court Region Tracking",
                        description: "Focuses on basketball court area, ignores benched players"
                    )

                    FeatureRow(
                        icon: "arrow.left.and.right",
                        title: "Automatic Following",
                        description: "Smoothly follows game action as it moves between players"
                    )

                    FeatureRow(
                        icon: "wand.and.stars",
                        title: "Zero Manual Control",
                        description: "Completely hands-free - just start recording and let AI handle the rest"
                    )

                    FeatureRow(
                        icon: "eye.fill",
                        title: "Action Recognition",
                        description: "Detects player activity, body pose, and attention to follow the action"
                    )

                    FeatureRow(
                        icon: "iphone",
                        title: "Works Offline",
                        description: "All ML processing happens on-device, no internet needed"
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("How It Works")
            }

            // Basketball Tips Section
            if isEnabled {
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
