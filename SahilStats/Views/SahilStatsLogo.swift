//
//  SahilStatsLogo.swift
//  SahilStats
//
//  App logo: Retro basketball badge with professional style
//  Can be used in-app or rendered to image for app icons
//

import SwiftUI

struct SahilStatsLogo: View {
    var size: CGFloat = 200
    var showShadow: Bool = true
    var showText: Bool = true

    var body: some View {
        ZStack {
            // Outer badge circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.18, blue: 0.25),  // Dark navy
                            Color(red: 0.10, green: 0.12, blue: 0.18)   // Darker navy
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)

            // Inner decorative ring
            Circle()
                .strokeBorder(
                    Color(red: 0.85, green: 0.65, blue: 0.35),  // Vintage gold
                    lineWidth: size * 0.015
                )
                .frame(width: size * 0.92, height: size * 0.92)

            // Second inner ring
            Circle()
                .strokeBorder(
                    Color(red: 0.85, green: 0.65, blue: 0.35).opacity(0.5),
                    lineWidth: size * 0.008
                )
                .frame(width: size * 0.88, height: size * 0.88)

            // Basketball center
            ZStack {
                // Basketball
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.95, green: 0.52, blue: 0.25),  // Bright center
                                Color(red: 0.85, green: 0.42, blue: 0.18)   // Darker edges
                            ],
                            center: .init(x: 0.4, y: 0.4),
                            startRadius: size * 0.05,
                            endRadius: size * 0.25
                        )
                    )
                    .frame(width: size * 0.50, height: size * 0.50)

                // Basketball seams
                basketballSeams
                    .frame(width: size * 0.50, height: size * 0.50)
            }

            // Text overlay (if enabled)
            if showText {
                VStack(spacing: 0) {
                    Spacer()

                    Text("SAHIL")
                        .font(.system(size: size * 0.11, weight: .black, design: .rounded))
                        .tracking(size * 0.02)
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.35))
                        .offset(y: size * 0.38)

                    Text("STATS")
                        .font(.system(size: size * 0.09, weight: .bold, design: .rounded))
                        .tracking(size * 0.025)
                        .foregroundColor(.white.opacity(0.9))
                        .offset(y: size * 0.40)
                }
            }
        }
        .shadow(color: showShadow ? .black.opacity(0.4) : .clear, radius: size * 0.08, x: 0, y: size * 0.04)
    }

    private var basketballSeams: some View {
        ZStack {
            // Vertical center line
            Capsule()
                .fill(Color.black.opacity(0.25))
                .frame(width: size * 0.012, height: size * 0.35)

            // Horizontal curved lines (basketball seams)
            Path { path in
                let seamWidth = size * 0.25

                // Top curve
                path.move(to: CGPoint(x: -seamWidth, y: -size * 0.08))
                path.addQuadCurve(
                    to: CGPoint(x: seamWidth, y: -size * 0.08),
                    control: CGPoint(x: 0, y: -size * 0.20)
                )

                // Bottom curve
                path.move(to: CGPoint(x: -seamWidth, y: size * 0.08))
                path.addQuadCurve(
                    to: CGPoint(x: seamWidth, y: size * 0.08),
                    control: CGPoint(x: 0, y: size * 0.20)
                )
            }
            .stroke(Color.black.opacity(0.25), style: StrokeStyle(lineWidth: size * 0.012, lineCap: .round))
        }
    }
}

// MARK: - Preview and Export Helper

struct SahilStatsLogoPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Main logo showcase
                VStack(spacing: 20) {
                    Text("Retro Basketball Badge")
                        .font(.title.bold())

                    SahilStatsLogo(size: 300)

                    Text("Professional • Classic • Clean")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(40)

                Divider()

                // Variations
                VStack(spacing: 30) {
                    Text("Logo Variations")
                        .font(.headline)

                    // With and without text
                    HStack(spacing: 40) {
                        VStack {
                            SahilStatsLogo(size: 150, showText: true)
                            Text("With Text")
                                .font(.caption)
                        }
                        VStack {
                            SahilStatsLogo(size: 150, showText: false)
                            Text("Icon Only")
                                .font(.caption)
                        }
                    }
                }
                .padding(40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(20)

                // Different backgrounds
                VStack(spacing: 30) {
                    Text("On Different Backgrounds")
                        .font(.headline)

                    HStack(spacing: 30) {
                        VStack {
                            ZStack {
                                Color.white
                                SahilStatsLogo(size: 120, showShadow: false)
                            }
                            .frame(width: 140, height: 140)
                            .cornerRadius(12)
                            Text("Light")
                                .font(.caption)
                        }

                        VStack {
                            ZStack {
                                Color.black
                                SahilStatsLogo(size: 120, showShadow: false)
                            }
                            .frame(width: 140, height: 140)
                            .cornerRadius(12)
                            Text("Dark")
                                .font(.caption)
                        }

                        VStack {
                            ZStack {
                                Color.orange.opacity(0.2)
                                SahilStatsLogo(size: 120, showShadow: false)
                            }
                            .frame(width: 140, height: 140)
                            .cornerRadius(12)
                            Text("Color")
                                .font(.caption)
                        }
                    }
                }
                .padding(40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(20)

                // App icon sizes
                VStack(spacing: 20) {
                    Text("iOS App Icon Sizes")
                        .font(.headline)

                    HStack(spacing: 20) {
                        VStack {
                            SahilStatsLogo(size: 120, showShadow: false, showText: false)
                            Text("180×180")
                                .font(.caption)
                        }
                        VStack {
                            SahilStatsLogo(size: 80, showShadow: false, showText: false)
                            Text("120×120")
                                .font(.caption)
                        }
                        VStack {
                            SahilStatsLogo(size: 60, showShadow: false, showText: false)
                            Text("60×60")
                                .font(.caption)
                        }
                    }

                    Text("💡 Use icon-only version for app icons (no text)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(40)
                .background(Color.blue.opacity(0.05))
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

#Preview("Badge Logo") {
    ZStack {
        Color(red: 0.95, green: 0.95, blue: 0.97)
        VStack(spacing: 40) {
            SahilStatsLogo(size: 300, showText: true)

            HStack(spacing: 30) {
                SahilStatsLogo(size: 150, showText: false)
                SahilStatsLogo(size: 150, showText: true)
            }
        }
    }
    .ignoresSafeArea()
}

#Preview("Full Preview") {
    SahilStatsLogoPreview()
}
