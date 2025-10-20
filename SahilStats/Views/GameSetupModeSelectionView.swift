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

            // Multi-device option (with video)
            Button(action: onSelectMultiDevice) {
                VStack(spacing: isIPad ? 16 : 12) {
                    // Visual representation: Two devices with connection
                    ZStack {
                        // iPad (stats device)
                        RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: isIPad ? 90 : 60, height: isIPad ? 120 : 80)
                            .overlay(
                                VStack(spacing: isIPad ? 8 : 4) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(isIPad ? .largeTitle : .title3)
                                        .foregroundColor(.blue)
                                    Text("Stats")
                                        .font(.system(size: isIPad ? 14 : 8))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            )
                            .offset(x: isIPad ? -60 : -40)

                        // Connection indicator (bidirectional arrows)
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(isIPad ? .title2 : .caption)
                                .foregroundColor(.orange)
                            Text("Synced")
                                .font(.system(size: isIPad ? 10 : 7))
                                .foregroundColor(.orange)
                        }

                        // iPhone (camera device)
                        RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                            .fill(Color.red.opacity(0.15))
                            .frame(width: isIPad ? 90 : 60, height: isIPad ? 120 : 80)
                            .overlay(
                                VStack(spacing: isIPad ? 8 : 4) {
                                    Image(systemName: "video.fill")
                                        .font(isIPad ? .largeTitle : .title3)
                                        .foregroundColor(.red)
                                    Text("Video")
                                        .font(.system(size: isIPad ? 14 : 8))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                            )
                            .offset(x: isIPad ? 60 : 40)
                    }
                    .frame(height: isIPad ? 140 : 100)

                    VStack(spacing: isIPad ? 8 : 4) {
                        Text("Stats + Recording")
                            .font(isIPad ? .title2 : .headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Use two devices for video capture")
                            .font(isIPad ? .body : .caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? 32 : 20)
                .padding(.horizontal, isIPad ? 24 : 16)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: isIPad ? 20 : 12)
                                .stroke(Color.orange, lineWidth: isIPad ? 3 : 2)
                        )
                )
            }
            .buttonStyle(.plain)

            // Single device option (stats only)
            Button(action: onSelectSingleDevice) {
                VStack(spacing: isIPad ? 16 : 12) {
                    // Visual representation: Single device
                    RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: isIPad ? 120 : 80, height: isIPad ? 140 : 100)
                        .overlay(
                            VStack(spacing: isIPad ? 12 : 8) {
                                Image(systemName: "ipad")
                                    .font(isIPad ? .system(size: 60) : .largeTitle)
                                    .foregroundColor(.blue)
                                Image(systemName: "chart.bar.fill")
                                    .font(isIPad ? .title : .title3)
                                    .foregroundColor(.blue)
                            }
                        )

                    VStack(spacing: isIPad ? 8 : 4) {
                        Text("Stats Only")
                            .font(isIPad ? .title2 : .headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("One device, no video recording")
                            .font(isIPad ? .body : .caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? 32 : 20)
                .padding(.horizontal, isIPad ? 24 : 16)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: isIPad ? 20 : 12)
                                .stroke(Color.blue, lineWidth: isIPad ? 3 : 2)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(isIPad ? 32 : 16)
    }
}

#Preview {
    GameSetupModeSelectionView(
        onSelectMultiDevice: { print("Multi-device selected") },
        onSelectSingleDevice: { print("Single-device selected") }
    )
}
