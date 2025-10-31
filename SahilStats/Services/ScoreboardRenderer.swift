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
    let numQuarter: Int  // Total regular periods (for OT detection)
    let zoomLevel: CGFloat?  // Optional zoom indicator
    let homeLogoURL: String?  // Optional home team logo
    let awayLogoURL: String?  // Optional away team logo
}

/// Renders scoreboard as bitmap image with glassmorphism effect
/// Used by both SwiftUI preview and video post-processing
class ScoreboardRenderer {

    /// Render scoreboard as UIImage with glassmorphism effect
    /// - Parameters:
    ///   - data: Scoreboard data to render
    ///   - size: Render size (e.g., 1920×1080 or 3840×2160)
    ///   - isRecording: Whether to show recording indicator
    ///   - forVideo: Use enhanced layout for final video (larger, full team names)
    /// - Returns: Rendered scoreboard image with transparent background
    static func renderScoreboard(
        data: ScoreboardData,
        size: CGSize,
        isRecording: Bool = false,
        forVideo: Bool = false
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
            // NOTE: This is never shown in final videos since isRecording=false in compositor
            if isRecording {
                drawRecIndicator(
                    in: cgContext,
                    size: size,
                    scaleFactor: scaleFactor
                )
            }

            // NOTE: Zoom indicator removed from final videos
            // It only shows during live recording preview, not in rendered videos

            // Draw scoreboard
            drawScoreboard(
                data: data,
                in: cgContext,
                size: size,
                scaleFactor: scaleFactor,
                isRecording: isRecording,
                forVideo: forVideo
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
        isRecording: Bool,
        forVideo: Bool
    ) {
        // Scoreboard dimensions
        // For video: Larger, more prominent overlay with full team names
        // For live: Compact overlay (match SimpleScoreOverlay exactly)
        let scoreboardWidth: CGFloat = forVideo ? 450 * scaleFactor : 246 * scaleFactor
        let scoreboardHeight: CGFloat = forVideo ? 80 * scaleFactor : 56 * scaleFactor

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

        // Layout constants - adjusted for video vs live
        let columnWidth: CGFloat = forVideo ? 120 * scaleFactor : 50 * scaleFactor
        let centerWidth: CGFloat = forVideo ? 100 * scaleFactor : 70 * scaleFactor
        let spacing: CGFloat = forVideo ? 20 * scaleFactor : 12 * scaleFactor
        let padding: CGFloat = forVideo ? 20 * scaleFactor : 14 * scaleFactor
        let logoSize: CGFloat = forVideo ? 40 * scaleFactor : 18 * scaleFactor

        // Load logos from cache (if URLs provided and cached)
        // Note: Logos should be pre-cached during game setup/live preview
        let homeLogo = loadImageFromURLSync(data.homeLogoURL)
        let awayLogo = loadImageFromURLSync(data.awayLogoURL)

        var xOffset = scoreboardRect.minX + padding

        // HOME TEAM SECTION (left)
        drawTeamSection(
            teamName: forVideo ? data.homeTeam : formatTeamName(data.homeTeam, maxLength: 4),
            score: data.homeScore,
            at: CGPoint(x: xOffset, y: scoreboardRect.minY),
            width: columnWidth,
            scaleFactor: scaleFactor,
            logoImage: homeLogo,
            logoSize: logoSize,
            forVideo: forVideo,
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
            periodText: data.gameFormat.formatPeriodDisplay(currentPeriod: data.quarter, totalRegularPeriods: data.numQuarter),
            clockTime: data.clockTime,
            at: CGPoint(x: xOffset, y: scoreboardRect.minY),
            width: centerWidth,
            scaleFactor: scaleFactor,
            forVideo: forVideo,
            in: context
        )

        xOffset += centerWidth + spacing

        // Second separator
        drawSeparator(
            at: CGPoint(x: xOffset - spacing / 2, y: scoreboardRect.minY + (forVideo ? 18 : 13) * scaleFactor),
            height: forVideo ? 44 * scaleFactor : 30 * scaleFactor,
            scaleFactor: scaleFactor,
            in: context
        )

        // AWAY TEAM SECTION (right)
        drawTeamSection(
            teamName: forVideo ? data.awayTeam : formatTeamName(data.awayTeam, maxLength: 4),
            score: data.awayScore,
            at: CGPoint(x: xOffset, y: scoreboardRect.minY),
            width: columnWidth,
            scaleFactor: scaleFactor,
            logoImage: awayLogo,
            logoSize: logoSize,
            forVideo: forVideo,
            in: context
        )
    }

    /// Load image from URL asynchronously using URLSession
    /// This version uses async/await to avoid blocking the main thread
    private static func loadImageFromURL(_ urlString: String?) async -> UIImage? {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            debugPrint("⚠️ Failed to load logo from \(urlString): \(error)")
            return nil
        }
    }

    /// Synchronous wrapper for backwards compatibility (uses cache if available)
    private static func loadImageFromURLSync(_ urlString: String?) -> UIImage? {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            return nil
        }

        // Try to load from URL cache first
        let request = URLRequest(url: url)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            return image
        }

        // If not in cache, we can't load synchronously without blocking
        // Return nil and let the video render without logo
        debugPrint("⚠️ Logo not in cache, skipping: \(urlString)")
        return nil
    }

    // MARK: - Helper Drawing Methods

    private static func drawTeamSection(
        teamName: String,
        score: Int,
        at origin: CGPoint,
        width: CGFloat,
        scaleFactor: CGFloat,
        logoImage: UIImage? = nil,
        logoSize: CGFloat,
        forVideo: Bool,
        in context: CGContext
    ) {
        // Calculate layout with optional logo
        let spacing: CGFloat = forVideo ? 8 * scaleFactor : 4 * scaleFactor

        // Team name (with logo if available)
        // For video: Larger font, full team name
        // For live: Smaller font, abbreviated name
        let nameFontSize: CGFloat = forVideo ? 14 * scaleFactor : 10 * scaleFactor
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: nameFontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]

        let nameString = NSAttributedString(string: teamName, attributes: nameAttributes)
        let nameSize = nameString.size()

        // Calculate total width (logo + spacing + text)
        let totalWidth = (logoImage != nil ? logoSize + spacing : 0) + nameSize.width
        let startX = origin.x + (width - totalWidth) / 2
        let nameY = origin.y + (forVideo ? 12 : 8) * scaleFactor

        var currentX = startX

        // Draw logo if available
        if let logo = logoImage {
            let logoRect = CGRect(
                x: currentX,
                y: nameY - (forVideo ? 2 : 0) * scaleFactor,  // Slightly adjust logo position for larger size
                width: logoSize,
                height: logoSize
            )
            logo.draw(in: logoRect)
            currentX += logoSize + spacing
        }

        // Draw team name
        nameString.draw(at: CGPoint(x: currentX, y: nameY))

        // Score - larger for video
        let scoreFontSize: CGFloat = forVideo ? 32 * scaleFactor : 20 * scaleFactor
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: scoreFontSize, weight: .bold),
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
        forVideo: Bool,
        in context: CGContext
    ) {
        // Period text - larger for video
        let periodFontSize: CGFloat = forVideo ? 12 * scaleFactor : 9 * scaleFactor
        let periodAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: periodFontSize, weight: .semibold),
            .foregroundColor: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95)  // Orange
        ]

        let periodString = NSAttributedString(string: periodText, attributes: periodAttributes)
        let periodSize = periodString.size()
        let periodX = origin.x + (width - periodSize.width) / 2
        let periodY = origin.y + (forVideo ? 12 : 8) * scaleFactor

        periodString.draw(at: CGPoint(x: periodX, y: periodY))

        // Clock time - larger for video
        let clockFontSize: CGFloat = forVideo ? 24 * scaleFactor : 16 * scaleFactor
        let clockAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: clockFontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let clockString = NSAttributedString(string: clockTime, attributes: clockAttributes)
        let clockSize = clockString.size()
        let clockX = origin.x + (width - clockSize.width) / 2
        let clockY = origin.y + (forVideo ? 35 : 22) * scaleFactor

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

    // Note: Period formatting now uses GameFormat.formatPeriodDisplay()
    // which handles overtime display (OT, 2OT, etc.)
}
