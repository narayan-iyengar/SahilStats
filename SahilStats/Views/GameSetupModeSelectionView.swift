//
//  GameSetupModeSelectionView.swift
//  SahilStats
//
//  Reusable visual game setup mode selection
//

import SwiftUI

struct GameSetupModeSelectionView: View {
    let onSelectMultiDevice: () -> Void
    let onSelectSingleDevice: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(spacing: isIPad ? 32 : 20) {
            // Header
            VStack(spacing: isIPad ? 12 : 8) {
                Text("How do you want to set up?")
                    .font(isIPad ? .title : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Choose your setup mode")
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.secondary)
            }

            // Side-by-side buttons
            HStack(spacing: isIPad ? 24 : 16) {
                // Multi-device option (with video)
                setupModeCard(
                    icon1: "chart.bar.fill",
                    icon2: "video.fill",
                    color1: .blue,
                    color2: .red,
                    title: "Stats + Recording",
                    description: "Two devices",
                    borderColor: .orange,
                    showConnectionArrows: true,
                    action: onSelectMultiDevice
                )

                // Single device option (stats only)
                setupModeCard(
                    icon1: "ipad",
                    icon2: "chart.bar.fill",
                    color1: .blue,
                    color2: .blue,
                    title: "Stats Only",
                    description: "One device",
                    borderColor: .blue,
                    showConnectionArrows: false,
                    action: onSelectSingleDevice
                )
            }
        }
        .padding(isIPad ? 32 : 16)
    }

    @ViewBuilder
    private func setupModeCard(
        icon1: String,
        icon2: String,
        color1: Color,
        color2: Color,
        title: String,
        description: String,
        borderColor: Color,
        showConnectionArrows: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: isIPad ? 20 : 12) {
                if showConnectionArrows {
                    // Multi-device: Two devices side by side
                    HStack(spacing: isIPad ? 16 : 8) {
                        deviceIcon(icon1, color: color1, label: "Stats")

                        VStack(spacing: 2) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(isIPad ? .title3 : .caption)
                                .foregroundColor(.orange)
                        }

                        deviceIcon(icon2, color: color2, label: "Video")
                    }
                    .frame(height: isIPad ? 100 : 70)
                } else {
                    // Single device: Stacked icons
                    VStack(spacing: isIPad ? 12 : 8) {
                        Image(systemName: icon1)
                            .font(isIPad ? .system(size: 50) : .system(size: 35))
                            .foregroundColor(color1)
                        Image(systemName: icon2)
                            .font(isIPad ? .title : .title3)
                            .foregroundColor(color2)
                    }
                    .frame(height: isIPad ? 100 : 70)
                }

                VStack(spacing: isIPad ? 6 : 4) {
                    Text(title)
                        .font(isIPad ? .title2 : .body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 40 : 24)
            .padding(.horizontal, isIPad ? 24 : 12)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                            .stroke(borderColor, lineWidth: isIPad ? 4 : 3)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func deviceIcon(_ systemName: String, color: Color, label: String) -> some View {
        RoundedRectangle(cornerRadius: isIPad ? 10 : 8)
            .fill(color.opacity(0.15))
            .frame(width: isIPad ? 70 : 50, height: isIPad ? 90 : 65)
            .overlay(
                VStack(spacing: isIPad ? 6 : 4) {
                    Image(systemName: systemName)
                        .font(isIPad ? .title : .title3)
                        .foregroundColor(color)
                    Text(label)
                        .font(.system(size: isIPad ? 12 : 9))
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
            )
    }
}

#Preview {
    GameSetupModeSelectionView(
        onSelectMultiDevice: { print("Multi-device selected") },
        onSelectSingleDevice: { print("Single-device selected") }
    )
}
