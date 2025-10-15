//
//  SahilStatsLogo.swift
//  SahilStats
//
//  App logo: Clean, minimalist flat basketball icon
//  Simple and modern app icon aesthetic
//

import SwiftUI

struct SahilStatsLogo: View {
    var size: CGFloat = 200
    var backgroundColor: Color = Color.orange
    var seamColor: Color = Color.white.opacity(0.9)
    var showShadow: Bool = true

    var body: some View {
        ZStack {
            // Basketball circle - flat design
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)

            // Basketball seams - clean lines
            basketballSeams
                .stroke(seamColor, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        }
        .shadow(color: showShadow ? Color.black.opacity(0.2) : Color.clear, radius: size * 0.05, x: 0, y: size * 0.03)
    }

    // MARK: - Basketball Seams

    private var basketballSeams: some Shape {
        BasketballSeams(size: size)
    }
}

// MARK: - Basketball Seams Shape

struct BasketballSeams: Shape {
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Vertical center line
        path.move(to: CGPoint(x: center.x, y: center.y - radius * 0.85))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.85))

        // Top horizontal curve (curves upward like a smile)
        path.move(to: CGPoint(x: center.x - radius * 0.65, y: center.y - radius * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: center.x + radius * 0.65, y: center.y - radius * 0.15),
            control: CGPoint(x: center.x, y: center.y - radius * 0.55)
        )

        // Bottom horizontal curve (curves downward like a frown)
        path.move(to: CGPoint(x: center.x - radius * 0.65, y: center.y + radius * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: center.x + radius * 0.65, y: center.y + radius * 0.15),
            control: CGPoint(x: center.x, y: center.y + radius * 0.55)
        )

        return path
    }
}

// MARK: - Preview and Export Helper

struct SahilStatsLogoPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Main logo showcase
                VStack(spacing: 20) {
                    Text("Flat Basketball Icon")
                        .font(.system(.title, design: .rounded, weight: .bold))

                    SahilStatsLogo(size: 300)

                    Text("Minimalist • Clean • Professional")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(40)

                Divider()

                // Color Variations
                VStack(spacing: 30) {
                    Text("Color Variations")
                        .font(.headline)

                    HStack(spacing: 30) {
                        VStack {
                            SahilStatsLogo(size: 120, backgroundColor: .orange)
                            Text("Classic Orange")
                                .font(.caption)
                        }
                        VStack {
                            SahilStatsLogo(size: 120, backgroundColor: .black, seamColor: .white.opacity(0.4))
                            Text("Dark Mode")
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
                            SahilStatsLogo(size: 120, showShadow: false)
                            Text("180×180")
                                .font(.caption)
                        }
                        VStack {
                            SahilStatsLogo(size: 80, showShadow: false)
                            Text("120×120")
                                .font(.caption)
                        }
                        VStack {
                            SahilStatsLogo(size: 60, showShadow: false)
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

#Preview("Flat Basketball Icon") {
    ZStack {
        Color(UIColor.systemBackground)

        VStack(spacing: 50) {
            // Main icon
            VStack(spacing: 20) {
                SahilStatsLogo(size: 300)
                Text("Clean • Simple • Modern")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(width: 300)

            // Different color variations
            VStack(spacing: 20) {
                Text("Color Options")
                    .font(.headline)

                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        SahilStatsLogo(
                            size: 100,
                            backgroundColor: .orange,
                            seamColor: .white.opacity(0.9),
                            showShadow: false
                        )
                        Text("Orange")
                            .font(.caption)
                    }

                    VStack(spacing: 8) {
                        SahilStatsLogo(
                            size: 100,
                            backgroundColor: Color(red: 0.95, green: 0.45, blue: 0.18),
                            seamColor: .white.opacity(0.9),
                            showShadow: false
                        )
                        Text("Dark Orange")
                            .font(.caption)
                    }

                    VStack(spacing: 8) {
                        SahilStatsLogo(
                            size: 100,
                            backgroundColor: .black,
                            seamColor: .white.opacity(0.3),
                            showShadow: false
                        )
                        Text("Black")
                            .font(.caption)
                    }
                }
            }

            // On different backgrounds
            VStack(spacing: 20) {
                Text("On Different Backgrounds")
                    .font(.headline)

                HStack(spacing: 20) {
                    ZStack {
                        Color.white
                        SahilStatsLogo(size: 80, showShadow: true)
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)

                    ZStack {
                        Color.black
                        SahilStatsLogo(size: 80, showShadow: true)
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)

                    ZStack {
                        Color.blue
                        SahilStatsLogo(size: 80, showShadow: true)
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                }
            }
        }
        .padding(40)
    }
    .ignoresSafeArea()
}

#Preview("Full Preview") {
    SahilStatsLogoPreview()
}
