//
//  ScoreboardRenderer.swift
//  SahilStats
//
//  Shared scoreboard rendering for preview (SwiftUI) and video (bitmap)
//  Ensures perfect visual consistency between preview and final video
//

import UIKit
import SwiftUI

/// Shared data structure for scoreboard rendering
struct ScoreboardData {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    let clockTime: String
    let quarter: Int
    let gameFormat: GameFormat
    let zoomLevel: CGFloat?  // Optional zoom indicator
}

/// Renders scoreboard as bitmap image with glassmorphism effect
/// Used by both SwiftUI preview and video post-processing
class ScoreboardRenderer {

    /// Render scoreboard as UIImage with glassmorphism effect
    /// - Parameters:
    ///   - data: Scoreboard data to render
    ///   - size: Render size (e.g., 1920×1080 or 3840×2160)
    ///   - isRecording: Whether to show recording indicator
    /// - Returns: Rendered scoreboard image with transparent background
    static func renderScoreboard(
        data: ScoreboardData,
        size: CGSize,
        isRecording: Bool = false
    ) -> UIImage? {

        let scaleFactor = size.height / 375.0

        // IMPORTANT: Use transparent format to preserve glassmorphism
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1  // Use 1x scale for exact pixel control

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let cgContext = context.cgContext

            // Clear to transparent background
            cgContext.clear(CGRect(origin: .zero, size: size))

            // Draw REC indicator if recording (top-right corner)
            if isRecording {
                drawRecIndicator(
                    in: cgContext,
                    size: size,
                    scaleFactor: scaleFactor
                )
            }

            // Draw zoom indicator if present
            if let zoomLevel = data.zoomLevel, zoomLevel != 1.0 {
                drawZoomIndicator(
                    zoomLevel: zoomLevel,
                    in: cgContext,
                    size: size,
                    scaleFactor: scaleFactor
                )
            }

            // Draw scoreboard
            drawScoreboard(
                data: data,
                in: cgContext,
                size: size,
                scaleFactor: scaleFactor,
                isRecording: isRecording
            )
        }
    }

    // MARK: - REC Indicator

    private static func drawRecIndicator(
        in context: CGContext,
        size: CGSize,
        scaleFactor: CGFloat
    ) {
        // Match SimpleScoreOverlay exactly:
        // - Red circle (8pt diameter)
        // - "REC" text
        // - Black background (0.6 opacity)
        // - 8pt corner radius
        // - Padding: 8pt inside, 20pt from top-right

        let padding: CGFloat = 8 * scaleFactor
        let topMargin: CGFloat = 20 * scaleFactor
        let trailingMargin: CGFloat = 20 * scaleFactor
        let circleSize: CGFloat = 8 * scaleFactor
        let cornerRadius: CGFloat = 8 * scaleFactor

        // Text setup
        let text = "REC"
        let fontSize: CGFloat = 12 * scaleFactor  // caption font
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        // Calculate container size
        let spacing: CGFloat = 6 * scaleFactor
        let containerWidth = padding + circleSize + spacing + textSize.width + padding
        let containerHeight = padding + max(circleSize, textSize.height) + padding

        // Position at top-right
        let containerRect = CGRect(
            x: size.width - containerWidth - trailingMargin,
            y: topMargin,
            width: containerWidth,
            height: containerHeight
        )

        // Draw background
        let path = UIBezierPath(roundedRect: containerRect, cornerRadius: cornerRadius)
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        // Draw red circle
        let circleX = containerRect.minX + padding + circleSize / 2
        let circleY = containerRect.minY + containerHeight / 2
        context.setFillColor(UIColor.red.cgColor)
        context.fillEllipse(in: CGRect(
            x: circleX - circleSize / 2,
            y: circleY - circleSize / 2,
            width: circleSize,
            height: circleSize
        ))

        // Draw text
        let textX = circleX + circleSize / 2 + spacing
        let textY = containerRect.minY + (containerHeight - textSize.height) / 2
        attributedString.draw(at: CGPoint(x: textX, y: textY))
    }

    // MARK: - Zoom Indicator

    private static func drawZoomIndicator(
        zoomLevel: CGFloat,
        in context: CGContext,
        size: CGSize,
        scaleFactor: CGFloat
    ) {
        let text = String(format: "%.1f×", zoomLevel)
        let fontSize: CGFloat = 14 * scaleFactor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // iOS Camera yellow
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        // Position at top center
        let x = (size.width - textSize.width) / 2
        let y: CGFloat = 20 * scaleFactor

        // Draw shadow first
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.5).cgColor)
        attributedString.draw(at: CGPoint(x: x, y: y))
        context.restoreGState()
    }

    // MARK: - Scoreboard Drawing

    private static func drawScoreboard(
        data: ScoreboardData,
        in context: CGContext,
        size: CGSize,
        scaleFactor: CGFloat,
        isRecording: Bool
    ) {
        // Scoreboard dimensions (match SimpleScoreOverlay exactly)
        let scoreboardWidth: CGFloat = 246 * scaleFactor
        let scoreboardHeight: CGFloat = 56 * scaleFactor

        // Position at bottom center
        let scoreboardRect = CGRect(
            x: (size.width - scoreboardWidth) / 2,
            y: size.height - scoreboardHeight - (40 * scaleFactor),
            width: scoreboardWidth,
            height: scoreboardHeight
        )

        // OPAQUE GLASSMORPHISM BACKGROUND
        // Match SwiftUI .ultraThinMaterial appearance for video clarity
        // We use a more opaque background so the overlay is clearly visible in final video
        let cornerRadius = 14 * scaleFactor
        let path = UIBezierPath(roundedRect: scoreboardRect, cornerRadius: cornerRadius)

        context.saveGState()

        // First: Draw shadow BEFORE filling (so shadow appears behind the background)
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 10, color: UIColor.black.withAlphaComponent(0.3).cgColor)

        // Opaque dark background (much more visible than preview's glassmorphism)
        // This ensures scoreboard is clearly readable in final video
        context.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        // Clear shadow for border drawing
        context.setShadow(offset: .zero, blur: 0, color: nil)

        // Subtle white highlight for depth
        context.setFillColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        // Border for definition
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.addPath(path.cgPath)
        context.strokePath()

        context.restoreGState()

        // Layout constants
        let columnWidth: CGFloat = 50 * scaleFactor
        let centerWidth: CGFloat = 70 * scaleFactor
        let spacing: CGFloat = 12 * scaleFactor
        let padding: CGFloat = 14 * scaleFactor

        var xOffset = scoreboardRect.minX + padding

        // HOME TEAM SECTION (left)
        drawTeamSection(
            teamName: formatTeamName(data.homeTeam, maxLength: 4),
            score: data.homeScore,
            at: CGPoint(x: xOffset, y: scoreboardRect.minY),
            width: columnWidth,
            scaleFactor: scaleFactor,
            in: context
        )

        xOffset += columnWidth + spacing

        // First separator
        drawSeparator(
            at: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + 13 * scaleFactor),
            height: 30 * scaleFactor,
            scaleFactor: scaleFactor,
            in: context
        )

        // CENTER SECTION (clock & period)
        drawCenterSection(
            periodText: formatPeriod(quarter: data.quarter, gameFormat: data.gameFormat),
            clockTime: data.clockTime,
            at: CGPoint(x: xOffset, y: scoreboardRect.minY),
            width: centerWidth,
            scaleFactor: scaleFactor,
            in: context
        )

        xOffset += centerWidth + spacing

        // Second separator
        drawSeparator(
            at: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + 13 * scaleFactor),
            height: 30 * scaleFactor,
            scaleFactor: scaleFactor,
            in: context
        )

        // AWAY TEAM SECTION (right)
        drawTeamSection(
            teamName: formatTeamName(data.awayTeam, maxLength: 4),
            score: data.awayScore,
            at: CGPoint(x: xOffset, y: scoreboardRect.minY),
            width: columnWidth,
            scaleFactor: scaleFactor,
            in: context
        )
    }

    // MARK: - Helper Drawing Methods

    private static func drawTeamSection(
        teamName: String,
        score: Int,
        at origin: CGPoint,
        width: CGFloat,
        scaleFactor: CGFloat,
        in context: CGContext
    ) {
        // Team name
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10 * scaleFactor, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]

        let nameString = NSAttributedString(string: teamName, attributes: nameAttributes)
        let nameSize = nameString.size()
        let nameX = origin.x + (width - nameSize.width) / 2
        let nameY = origin.y + 8 * scaleFactor

        nameString.draw(at: CGPoint(x: nameX, y: nameY))

        // Score
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20 * scaleFactor, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let scoreString = NSAttributedString(string: "\(score)", attributes: scoreAttributes)
        let scoreSize = scoreString.size()
        let scoreX = origin.x + (width - scoreSize.width) / 2
        let scoreY = origin.y + 22 * scaleFactor

        scoreString.draw(at: CGPoint(x: scoreX, y: scoreY))
    }

    private static func drawCenterSection(
        periodText: String,
        clockTime: String,
        at origin: CGPoint,
        width: CGFloat,
        scaleFactor: CGFloat,
        in context: CGContext
    ) {
        // Period text
        let periodAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9 * scaleFactor, weight: .semibold),
            .foregroundColor: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95)  // Orange
        ]

        let periodString = NSAttributedString(string: periodText, attributes: periodAttributes)
        let periodSize = periodString.size()
        let periodX = origin.x + (width - periodSize.width) / 2
        let periodY = origin.y + 8 * scaleFactor

        periodString.draw(at: CGPoint(x: periodX, y: periodY))

        // Clock time
        let clockAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16 * scaleFactor, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let clockString = NSAttributedString(string: clockTime, attributes: clockAttributes)
        let clockSize = clockString.size()
        let clockX = origin.x + (width - clockSize.width) / 2
        let clockY = origin.y + 22 * scaleFactor

        clockString.draw(at: CGPoint(x: clockX, y: clockY))
    }

    private static func drawSeparator(
        at origin: CGPoint,
        height: CGFloat,
        scaleFactor: CGFloat,
        in context: CGContext
    ) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1 * scaleFactor)  // Scale line width for 4K resolution
        context.move(to: origin)
        context.addLine(to: CGPoint(x: origin.x, y: origin.y + height))
        context.strokePath()
    }

    // MARK: - Formatting Helpers

    private static func formatTeamName(_ teamName: String, maxLength: Int) -> String {
        if teamName.count <= maxLength {
            return teamName.uppercased()
        }
        let words = teamName.components(separatedBy: " ")
        if words.count > 1 {
            let firstWord = words[0]
            if firstWord.count <= maxLength {
                return firstWord.uppercased()
            }
        }
        return String(teamName.prefix(maxLength)).uppercased()
    }

    private static func formatPeriod(quarter: Int, gameFormat: GameFormat) -> String {
        let periodName = gameFormat == .halves ? "HALF" : "QTR"
        let ordinal = getOrdinalSuffix(quarter)
        return "\(quarter)\(ordinal) \(periodName)"
    }

    private static func getOrdinalSuffix(_ number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100

        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "th"
        }

        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
