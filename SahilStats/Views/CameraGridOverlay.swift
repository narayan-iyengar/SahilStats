//
//  CameraGridOverlay.swift
//  SahilStats
//
//  Reusable grid overlay for camera framing assistance
//  Shows rule of thirds lines and center crosshairs
//

import SwiftUI

struct CameraGridOverlay: View {
    var gridColor: Color = .white
    var opacity: Double = 0.3
    var lineWidth: CGFloat = 1.0
    var showCenterCross: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Rule of Thirds - Vertical Lines
                Path { path in
                    let oneThirdX = geometry.size.width / 3
                    let twoThirdsX = geometry.size.width * 2 / 3

                    // Left vertical line
                    path.move(to: CGPoint(x: oneThirdX, y: 0))
                    path.addLine(to: CGPoint(x: oneThirdX, y: geometry.size.height))

                    // Right vertical line
                    path.move(to: CGPoint(x: twoThirdsX, y: 0))
                    path.addLine(to: CGPoint(x: twoThirdsX, y: geometry.size.height))
                }
                .stroke(gridColor.opacity(opacity), lineWidth: lineWidth)

                // Rule of Thirds - Horizontal Lines
                Path { path in
                    let oneThirdY = geometry.size.height / 3
                    let twoThirdsY = geometry.size.height * 2 / 3

                    // Top horizontal line
                    path.move(to: CGPoint(x: 0, y: oneThirdY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: oneThirdY))

                    // Bottom horizontal line
                    path.move(to: CGPoint(x: 0, y: twoThirdsY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: twoThirdsY))
                }
                .stroke(gridColor.opacity(opacity), lineWidth: lineWidth)

                // Center Crosshairs (optional)
                if showCenterCross {
                    let centerX = geometry.size.width / 2
                    let centerY = geometry.size.height / 2
                    let crossSize: CGFloat = 40

                    Path { path in
                        // Horizontal line
                        path.move(to: CGPoint(x: centerX - crossSize, y: centerY))
                        path.addLine(to: CGPoint(x: centerX + crossSize, y: centerY))

                        // Vertical line
                        path.move(to: CGPoint(x: centerX, y: centerY - crossSize))
                        path.addLine(to: CGPoint(x: centerX, y: centerY + crossSize))
                    }
                    .stroke(gridColor.opacity(opacity * 1.5), lineWidth: lineWidth * 2)

                    // Center dot
                    Circle()
                        .fill(gridColor.opacity(opacity * 2))
                        .frame(width: 6, height: 6)
                        .position(x: centerX, y: centerY)
                }

                // Corner Brackets (professional look)
                cornerBrackets(in: geometry.size)
            }
        }
    }

    private func cornerBrackets(in size: CGSize) -> some View {
        let bracketLength: CGFloat = 30
        let margin: CGFloat = 20

        return ZStack {
            // Top-Left
            Path { path in
                path.move(to: CGPoint(x: margin + bracketLength, y: margin))
                path.addLine(to: CGPoint(x: margin, y: margin))
                path.addLine(to: CGPoint(x: margin, y: margin + bracketLength))
            }
            .stroke(gridColor.opacity(opacity * 2), lineWidth: lineWidth * 2)

            // Top-Right
            Path { path in
                path.move(to: CGPoint(x: size.width - margin - bracketLength, y: margin))
                path.addLine(to: CGPoint(x: size.width - margin, y: margin))
                path.addLine(to: CGPoint(x: size.width - margin, y: margin + bracketLength))
            }
            .stroke(gridColor.opacity(opacity * 2), lineWidth: lineWidth * 2)

            // Bottom-Left
            Path { path in
                path.move(to: CGPoint(x: margin, y: size.height - margin - bracketLength))
                path.addLine(to: CGPoint(x: margin, y: size.height - margin))
                path.addLine(to: CGPoint(x: margin + bracketLength, y: size.height - margin))
            }
            .stroke(gridColor.opacity(opacity * 2), lineWidth: lineWidth * 2)

            // Bottom-Right
            Path { path in
                path.move(to: CGPoint(x: size.width - margin, y: size.height - margin - bracketLength))
                path.addLine(to: CGPoint(x: size.width - margin, y: size.height - margin))
                path.addLine(to: CGPoint(x: size.width - margin - bracketLength, y: size.height - margin))
            }
            .stroke(gridColor.opacity(opacity * 2), lineWidth: lineWidth * 2)
        }
    }
}

// MARK: - Preview

#Preview("Default Grid") {
    ZStack {
        Color.black.ignoresSafeArea()

        // Simulated camera view
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .green.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()

        CameraGridOverlay()
    }
}

#Preview("Orange Grid") {
    ZStack {
        Color.black.ignoresSafeArea()

        CameraGridOverlay(
            gridColor: .orange,
            opacity: 0.5,
            lineWidth: 2.0
        )
    }
}

#Preview("No Center Cross") {
    ZStack {
        Color.black.ignoresSafeArea()

        CameraGridOverlay(
            showCenterCross: false
        )
    }
}
