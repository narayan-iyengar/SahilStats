//
//  SahilStatsLogo.swift
//  SahilStats
//
//  App logo: Hand-drawn basketball with sketchy, organic style
//  Can be used in-app or rendered to image for app icons
//
//  ANIMATION & BATTERY USAGE:
//  - Static version (isAnimated: false): Zero battery impact
//  - Animated version (isAnimated: true): Minimal battery impact (~0.1% per minute)
//  - Best practice: Only animate when visible (splash screen, loading)
//  - DON'T animate: In list cells, always-on displays
//  - SwiftUI animations are GPU-accelerated (efficient)
//

import SwiftUI

struct SahilStatsLogo: View {
    var size: CGFloat = 200
    var showShadow: Bool = true
    var showText: Bool = true
    var isAnimated: Bool = false

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Hand-drawn basketball
            ZStack {
                // Sketchy basketball circle
                sketchyBasketball
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.98, green: 0.58, blue: 0.28),  // Bright orange
                                Color(red: 0.95, green: 0.45, blue: 0.18)   // Darker orange
                            ],
                            center: .init(x: 0.45, y: 0.45),
                            startRadius: size * 0.1,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)

                // Sketchy outline stroke
                sketchyBasketball
                    .stroke(
                        Color(red: 0.3, green: 0.2, blue: 0.15),
                        style: StrokeStyle(lineWidth: size * 0.015, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size, height: size)

                // Basketball seams (hand-drawn style)
                handDrawnSeams
                    .stroke(
                        Color(red: 0.3, green: 0.2, blue: 0.15).opacity(0.8),
                        style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size, height: size)
            }
            .rotationEffect(.degrees(rotation))
            .onAppear {
                if isAnimated {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            }

            // Hand-drawn text (if enabled)
            if showText {
                VStack(spacing: size * 0.02) {
                    Spacer()

                    Text("SAHIL")
                        .font(.system(size: size * 0.16, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.20, blue: 0.18),
                                    Color(red: 0.35, green: 0.28, blue: 0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 0, x: -1, y: -1)
                        .offset(y: size * 0.52)

                    Text("STATS")
                        .font(.system(size: size * 0.12, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.18))
                        .shadow(color: .white.opacity(0.3), radius: 0, x: -1, y: -1)
                        .offset(y: size * 0.52)
                }
            }
        }
        .shadow(color: showShadow ? .black.opacity(0.15) : .clear, radius: size * 0.03, x: size * 0.01, y: size * 0.02)
    }

    // MARK: - Hand-Drawn Shapes

    /// Sketchy, imperfect basketball outline (wobbled circle)
    private var sketchyBasketball: some Shape {
        SketchyCircle(wobbleAmount: size * 0.01, segments: 60)
    }

    /// Hand-drawn basketball seams
    private var handDrawnSeams: some Shape {
        HandDrawnSeams(size: size)
    }
}

// MARK: - Custom Shapes for Hand-Drawn Effect

/// Creates an imperfect circle with slight wobbles (hand-drawn feel)
struct SketchyCircle: Shape {
    let wobbleAmount: CGFloat
    let segments: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Create points around circle with slight random wobble
        let angleStep = (2 * .pi) / CGFloat(segments)

        for i in 0...segments {
            let angle = CGFloat(i) * angleStep
            // Add deterministic "wobble" based on angle (not truly random, so it's reproducible)
            let wobble = sin(angle * 7) * wobbleAmount + cos(angle * 11) * wobbleAmount * 0.5
            let r = radius + wobble

            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

/// Hand-drawn basketball seams (wobbly curves)
struct HandDrawnSeams: Shape {
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let scale = min(rect.width, rect.height) / size

        // Vertical center seam (slightly wobbly)
        let seamHeight = size * 0.7 * scale
        let seamTop = center.y - seamHeight / 2
        let seamBottom = center.y + seamHeight / 2

        path.move(to: CGPoint(x: center.x + size * 0.005 * scale, y: seamTop))

        // Add slight curves for hand-drawn feel
        let controlPoints = 8
        let stepY = seamHeight / CGFloat(controlPoints)

        for i in 0...controlPoints {
            let y = seamTop + stepY * CGFloat(i)
            let wobble = sin(CGFloat(i) * 1.5) * size * 0.006 * scale
            path.addLine(to: CGPoint(x: center.x + wobble, y: y))
        }

        // Horizontal curved seams (top and bottom)
        let seamWidth = size * 0.55 * scale
        let seamCurve = size * 0.25 * scale

        // Top curve
        path.move(to: CGPoint(x: center.x - seamWidth, y: center.y - size * 0.15 * scale))
        path.addQuadCurve(
            to: CGPoint(x: center.x + seamWidth, y: center.y - size * 0.15 * scale + size * 0.01 * scale),
            control: CGPoint(x: center.x + size * 0.01 * scale, y: center.y - seamCurve)
        )

        // Bottom curve
        path.move(to: CGPoint(x: center.x - seamWidth, y: center.y + size * 0.15 * scale))
        path.addQuadCurve(
            to: CGPoint(x: center.x + seamWidth, y: center.y + size * 0.15 * scale - size * 0.01 * scale),
            control: CGPoint(x: center.x - size * 0.01 * scale, y: center.y + seamCurve)
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
                    Text("Hand-Drawn Basketball")
                        .font(.system(.title, design: .rounded, weight: .bold))

                    SahilStatsLogo(size: 300, isAnimated: true)

                    Text("Sketchy • Organic • Friendly")
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

#Preview("Hand-Drawn Logo") {
    ZStack {
        // Notebook paper background for hand-drawn feel
        Color(red: 0.98, green: 0.97, blue: 0.95)

        VStack(spacing: 50) {
            // Animated spinning version
            VStack(spacing: 15) {
                SahilStatsLogo(size: 280, showText: true, isAnimated: true)
                Text("✏️ Hand-Drawn Style • Spinning")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(width: 300)

            // Static versions
            VStack(spacing: 15) {
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        SahilStatsLogo(size: 130, showText: false, isAnimated: false)
                        Text("Icon Only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 8) {
                        SahilStatsLogo(size: 130, showText: true, isAnimated: false)
                        Text("With Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text("Static (No Animation)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
    }
    .ignoresSafeArea()
}

#Preview("Full Preview") {
    SahilStatsLogoPreview()
}
