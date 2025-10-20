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
        // Side-by-side buttons with no header
        HStack(spacing: isIPad ? 20 : 12) {
            // Multi-device option (with video)
            setupModeCard(
                icon1: "chart.bar.fill",
                icon2: "video.fill",
                color1: .blue,
                color2: .red,
                title: "Stats + Recording",
                subtitle: "Two devices",
                borderColor: .orange,
                backgroundColor: Color.orange.opacity(0.05),
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
                subtitle: "One device",
                borderColor: .blue,
                backgroundColor: Color.blue.opacity(0.05),
                showConnectionArrows: false,
                action: onSelectSingleDevice
            )
        }
        .padding(.horizontal, isIPad ? 24 : 16)
    }

    @ViewBuilder
    private func setupModeCard(
        icon1: String,
        icon2: String,
        color1: Color,
        color2: Color,
        title: String,
        subtitle: String,
        borderColor: Color,
        backgroundColor: Color,
        showConnectionArrows: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: isIPad ? 16 : 10) {
                if showConnectionArrows {
                    // Multi-device: Two devices side by side with connection
                    HStack(spacing: isIPad ? 12 : 6) {
                        // Stats device
                        ZStack {
                            RoundedRectangle(cornerRadius: isIPad ? 8 : 6)
                                .fill(color1.opacity(0.2))
                                .frame(width: isIPad ? 50 : 35, height: isIPad ? 65 : 45)
                            Image(systemName: icon1)
                                .font(isIPad ? .title2 : .body)
                                .foregroundColor(color1)
                        }

                        // Connection arrows
                        Image(systemName: "arrow.left.arrow.right")
                            .font(isIPad ? .title3 : .caption)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)

                        // Video device
                        ZStack {
                            RoundedRectangle(cornerRadius: isIPad ? 8 : 6)
                                .fill(color2.opacity(0.2))
                                .frame(width: isIPad ? 50 : 35, height: isIPad ? 65 : 45)
                            Image(systemName: icon2)
                                .font(isIPad ? .title2 : .body)
                                .foregroundColor(color2)
                        }
                    }
                    .frame(height: isIPad ? 75 : 55)
                } else {
                    // Single device: iPad with chart
                    ZStack {
                        RoundedRectangle(cornerRadius: isIPad ? 10 : 8)
                            .fill(color1.opacity(0.2))
                            .frame(width: isIPad ? 70 : 50, height: isIPad ? 90 : 65)

                        VStack(spacing: isIPad ? 8 : 6) {
                            Image(systemName: icon1)
                                .font(isIPad ? .system(size: 35) : .title2)
                                .foregroundColor(color1)
                            Image(systemName: icon2)
                                .font(isIPad ? .title3 : .caption)
                                .foregroundColor(color2)
                        }
                    }
                    .frame(height: isIPad ? 90 : 65)
                }

                VStack(spacing: isIPad ? 4 : 2) {
                    Text(title)
                        .font(isIPad ? .headline : .subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 24 : 16)
            .padding(.horizontal, isIPad ? 16 : 10)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                            .stroke(borderColor, lineWidth: isIPad ? 3 : 2.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    GameSetupModeSelectionView(
        onSelectMultiDevice: { print("Multi-device selected") },
        onSelectSingleDevice: { print("Single-device selected") }
    )
}
