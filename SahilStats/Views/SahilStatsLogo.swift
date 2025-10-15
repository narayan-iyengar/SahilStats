//
//  SahilStatsLogo.swift
//  SahilStats
//
//  App logo: Basketball with rising graph lines
//  Can be used in-app or rendered to image for app icons
//

import SwiftUI

struct SahilStatsLogo: View {
    var size: CGFloat = 200
    var showShadow: Bool = true

    var body: some View {
        ZStack {
            // Basketball
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.3),  // Lighter orange center
                            Color(red: 1.0, green: 0.42, blue: 0.21)  // Basketball orange
                        ],
                        center: .topLeading,
                        startRadius: size * 0.1,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            // Basketball seams/lines
            basketballSeams

            // Rising bar chart overlay
            statsOverlay
        }
        .shadow(color: showShadow ? .black.opacity(0.3) : .clear, radius: size * 0.05, x: 0, y: size * 0.02)
    }

    private var basketballSeams: some View {
        ZStack {
            // Vertical center line
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(width: size * 0.015, height: size * 0.7)

            // Horizontal curved lines (basketball seams)
            Path { path in
                // Top curve
                path.move(to: CGPoint(x: -size * 0.35, y: -size * 0.15))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.35, y: -size * 0.15),
                    control: CGPoint(x: 0, y: -size * 0.4)
                )

                // Bottom curve
                path.move(to: CGPoint(x: -size * 0.35, y: size * 0.15))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.35, y: size * 0.15),
                    control: CGPoint(x: 0, y: size * 0.4)
                )
            }
            .stroke(Color.black.opacity(0.15), lineWidth: size * 0.015)
        }
        .frame(width: size, height: size)
    }

    private var statsOverlay: some View {
        HStack(spacing: size * 0.05) {
            // Bar 1 (shortest)
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(Color.white)
                .frame(width: size * 0.12, height: size * 0.25)
                .offset(y: size * 0.1)

            // Bar 2 (medium)
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(Color.white)
                .frame(width: size * 0.12, height: size * 0.38)
                .offset(y: size * 0.035)

            // Bar 3 (tallest) - with highlight
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.12, height: size * 0.5)
                .overlay(
                    // Shine effect on tallest bar
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .offset(y: -size * 0.025)
        }
        .shadow(color: .black.opacity(0.2), radius: size * 0.02, x: 0, y: size * 0.01)
    }
}

// MARK: - Preview and Export Helper

struct SahilStatsLogoPreview: View {
    var body: some View {
        ZStack {
            // Preview on different backgrounds
            VStack(spacing: 40) {
                // Light background
                VStack(spacing: 20) {
                    Text("Light Background")
                        .font(.headline)
                    HStack(spacing: 30) {
                        SahilStatsLogo(size: 120)
                        SahilStatsLogo(size: 80)
                        SahilStatsLogo(size: 50)
                    }
                }
                .padding(40)
                .background(Color.white)
                .cornerRadius(20)

                // Dark background
                VStack(spacing: 20) {
                    Text("Dark Background")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 30) {
                        SahilStatsLogo(size: 120)
                        SahilStatsLogo(size: 80)
                        SahilStatsLogo(size: 50)
                    }
                }
                .padding(40)
                .background(Color(red: 0.1, green: 0.12, blue: 0.18))
                .cornerRadius(20)

                // App icon sizes
                VStack(spacing: 20) {
                    Text("iOS App Icon Sizes")
                        .font(.headline)
                    HStack(spacing: 20) {
                        VStack {
                            SahilStatsLogo(size: 180, showShadow: false)
                            Text("1024×1024")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            SahilStatsLogo(size: 120, showShadow: false)
                            Text("180×180")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            SahilStatsLogo(size: 80, showShadow: false)
                            Text("120×120")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            SahilStatsLogo(size: 60, showShadow: false)
                            Text("60×60")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - App Icon Generator View

struct AppIconGeneratorView: View {
    @State private var showingExportSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Large preview
                    SahilStatsLogo(size: 300, showShadow: true)
                        .padding(40)

                    Text("SahilStats Logo")
                        .font(.title.bold())

                    Text("Basketball with rising graph lines")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.horizontal)

                    // Export instructions
                    VStack(alignment: .leading, spacing: 15) {
                        Text("How to Export App Icons")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 10) {
                            ExportStep(number: 1, text: "Take screenshots of the logo at different sizes below")
                            ExportStep(number: 2, text: "Use an app icon generator like appicon.co or makeappicon.com")
                            ExportStep(number: 3, text: "Upload the 1024×1024 version")
                            ExportStep(number: 4, text: "Download the generated icon set")
                            ExportStep(number: 5, text: "Replace contents in Assets.xcassets/AppIcon.appiconset")
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Recommended export sizes
                    VStack(spacing: 20) {
                        Text("Recommended Export Size")
                            .font(.headline)

                        SahilStatsLogo(size: 512, showShadow: false)
                            .background(Color.white)
                            .cornerRadius(512 * 0.2237) // iOS icon corner radius ratio

                        Text("1024×1024 (iOS App Icon)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("📸 Take a screenshot of this logo for your app icon")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                .padding(.vertical, 40)
            }
            .navigationTitle("App Icon Generator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ExportStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Logo Sizes") {
    SahilStatsLogoPreview()
}

#Preview("App Icon Generator") {
    AppIconGeneratorView()
}

#Preview("Single Logo") {
    ZStack {
        Color.gray.opacity(0.2)
        SahilStatsLogo(size: 300)
    }
}
