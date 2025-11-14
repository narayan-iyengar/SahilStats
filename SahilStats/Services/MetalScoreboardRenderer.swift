//
//  MetalScoreboardRenderer.swift
//  SahilStats
//
//  Metal-based scoreboard renderer with professional visual effects
//

import Metal
import MetalKit
import CoreImage
import UIKit
import CoreText

class MetalScoreboardRenderer {

    // MARK: - Metal Setup

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            debugPrint("❌ Failed to create Metal device or command queue")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)

        debugPrint("✅ Metal scoreboard renderer initialized")
    }

    // MARK: - Render Scoreboard

    /// Renders a scoreboard with Metal effects
    /// - Parameters:
    ///   - data: Scoreboard data
    ///   - size: Output size
    ///   - scaleFactor: Scale for retina/4K
    /// - Returns: Rendered scoreboard image
    func renderScoreboard(
        data: ScoreboardData,
        size: CGSize,
        scaleFactor: CGFloat = 1.0
    ) -> UIImage? {

        // Step 1: Create base scoreboard with Core Graphics (text, logos, gradient background)
        guard let baseImage = createBaseScoreboard(data: data, size: size, scaleFactor: scaleFactor) else {
            return nil
        }

        // Step 2: Apply Metal effects (glow and subtle blur for polish)
        guard let enhancedImage = applyMetalEffects(to: baseImage) else {
            return baseImage // Fallback to base if effects fail
        }

        return enhancedImage
    }

    // MARK: - Base Scoreboard (Core Graphics)

    private func createBaseScoreboard(
        data: ScoreboardData,
        size: CGSize,
        scaleFactor: CGFloat
    ) -> UIImage? {

        // Calculate scoreboard dimensions
        let scoreboardWidth: CGFloat = 280 * scaleFactor
        let scoreboardHeight: CGFloat = 56 * scaleFactor

        let scoreboardRect = CGRect(
            x: (size.width - scoreboardWidth) / 2,
            y: size.height - scoreboardHeight - (40 * scaleFactor),
            width: scoreboardWidth,
            height: scoreboardHeight
        )

        // Create transparent image
        let format = UIGraphicsImageRendererFormat()
        format.scale = scaleFactor
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let ctx = context.cgContext

            // Draw text elements (team names, scores, clock)
            drawScoreboardContent(
                data: data,
                in: scoreboardRect,
                context: ctx,
                scaleFactor: scaleFactor
            )
        }
    }

    private func drawScoreboardContent(
        data: ScoreboardData,
        in rect: CGRect,
        context: CGContext,
        scaleFactor: CGFloat
    ) {

        // DRAW BACKGROUND FIRST
        let cornerRadius = 14 * scaleFactor
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        context.saveGState()

        // Shadow
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 10, color: UIColor.black.withAlphaComponent(0.3).cgColor)

        // Dark background with gradient (darker at bottom)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor.black.withAlphaComponent(0.85).cgColor,
            UIColor(white: 0.05, alpha: 0.9).cgColor
        ]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: []
            )
            context.restoreGState()
        }

        // Clear shadow for border
        context.setShadow(offset: .zero, blur: 0, color: nil)

        // Border
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.addPath(path.cgPath)
        context.strokePath()

        context.restoreGState()

        // NOW DRAW TEXT ON TOP
        // Layout constants
        let columnWidth: CGFloat = 90 * scaleFactor  // Increased from 75 to fit logos + names
        let centerWidth: CGFloat = 60 * scaleFactor  // Reduced from 70 to compensate
        let spacing: CGFloat = 8 * scaleFactor      // Slightly reduced spacing
        let padding: CGFloat = 8 * scaleFactor      // Reduced padding
        let logoSize: CGFloat = 18 * scaleFactor    // Slightly smaller logos (20 → 18)

        // Load logos from cache
        let homeLogo = loadImageFromURLSync(data.homeLogoURL)
        let awayLogo = loadImageFromURLSync(data.awayLogoURL)

        var xOffset = rect.minX + padding

        // HOME TEAM (logo on LEFT of score)
        drawTeamSection(
            teamName: formatTeamName(data.homeTeam, maxLength: 6),
            score: data.homeScore,
            at: CGPoint(x: xOffset, y: rect.minY),
            width: columnWidth,
            scaleFactor: scaleFactor,
            logoImage: homeLogo,
            logoSize: logoSize,
            logoOnLeft: true,
            context: context
        )

        xOffset += columnWidth + spacing

        // Separator
        drawSeparator(at: CGPoint(x: xOffset - spacing/2, y: rect.minY + 13 * scaleFactor),
                     height: 30 * scaleFactor, scaleFactor: scaleFactor, context: context)

        // CENTER (clock & period)
        let periodText = formatLongPeriodText(
            gameFormat: data.gameFormat,
            currentPeriod: data.quarter,
            totalRegularPeriods: data.numQuarter
        )

        drawCenterSection(
            periodText: periodText,
            clockTime: data.clockTime,
            at: CGPoint(x: xOffset, y: rect.minY),
            width: centerWidth,
            scaleFactor: scaleFactor,
            context: context
        )

        xOffset += centerWidth + spacing

        // Separator
        drawSeparator(at: CGPoint(x: xOffset - spacing/2, y: rect.minY + 13 * scaleFactor),
                     height: 30 * scaleFactor, scaleFactor: scaleFactor, context: context)

        // AWAY TEAM (logo on RIGHT of score)
        drawTeamSection(
            teamName: formatTeamName(data.awayTeam, maxLength: 6),
            score: data.awayScore,
            at: CGPoint(x: xOffset, y: rect.minY),
            width: columnWidth,
            scaleFactor: scaleFactor,
            logoImage: awayLogo,
            logoSize: logoSize,
            logoOnLeft: false,
            context: context
        )
    }

    // MARK: - Metal Effects

    private func applyMetalEffects(to image: UIImage) -> UIImage? {
        guard let inputCIImage = CIImage(image: image) else { return nil }

        var currentImage = inputCIImage

        // Skip gradient - already drawn in Core Graphics

        // 1. Add glow effect to text for better readability
        currentImage = addGlowEffect(to: currentImage)

        // 2. Add subtle blur (frosted glass effect)
        currentImage = addFrostedGlass(to: currentImage)

        // Render final image
        guard let cgImage = ciContext.createCGImage(currentImage, from: currentImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func addGradientBackground(to image: CIImage) -> CIImage {
        // Create gradient from dark at top to darker at bottom
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: image.extent.midX, y: image.extent.maxY), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: image.extent.midX, y: image.extent.minY), forKey: "inputPoint1")
        gradientFilter.setValue(CIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95), forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.95), forKey: "inputColor1")

        guard let gradient = gradientFilter.outputImage else { return image }

        // Blend gradient with original
        let blendFilter = CIFilter(name: "CISourceOverCompositing")!
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(gradient.cropped(to: image.extent), forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage ?? image
    }

    private func addGlowEffect(to image: CIImage) -> CIImage {
        // Create glow by blurring and brightening
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(2.0, forKey: kCIInputRadiusKey)

        guard let blurred = blurFilter.outputImage else { return image }

        // Brighten the blur
        let brightenFilter = CIFilter(name: "CIColorControls")!
        brightenFilter.setValue(blurred, forKey: kCIInputImageKey)
        brightenFilter.setValue(0.5, forKey: kCIInputBrightnessKey)

        guard let glow = brightenFilter.outputImage else { return image }

        // Blend glow behind original
        let blendFilter = CIFilter(name: "CISourceOverCompositing")!
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(glow.cropped(to: image.extent), forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage ?? image
    }

    private func addFrostedGlass(to image: CIImage) -> CIImage {
        // Create frosted glass effect with slight blur
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(1.0, forKey: kCIInputRadiusKey)

        return blurFilter.outputImage ?? image
    }

    // MARK: - Drawing Helpers

    private func drawTeamSection(
        teamName: String,
        score: Int,
        at origin: CGPoint,
        width: CGFloat,
        scaleFactor: CGFloat,
        logoImage: UIImage? = nil,
        logoSize: CGFloat,
        logoOnLeft: Bool,
        context: CGContext
    ) {
        let spacing: CGFloat = 6 * scaleFactor

        // TEAM NAME (top, centered, no logo)
        let nameFontSize: CGFloat = 10 * scaleFactor
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: nameFontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]

        let nameString = NSAttributedString(string: teamName, attributes: nameAttributes)
        let nameSize = nameString.size()
        let nameX = origin.x + (width - nameSize.width) / 2
        let nameY = origin.y + 6 * scaleFactor

        nameString.draw(at: CGPoint(x: nameX, y: nameY))

        // SCORE + LOGO (bottom row, NBA style)
        let scoreFontSize: CGFloat = 24 * scaleFactor
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: scoreFontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let scoreString = NSAttributedString(string: "\(score)", attributes: scoreAttributes)
        let scoreSize = scoreString.size()
        let scoreY = origin.y + 24 * scaleFactor

        // Calculate total width of logo + score
        let totalWidth = (logoImage != nil ? logoSize + spacing : 0) + scoreSize.width
        let startX = origin.x + (width - totalWidth) / 2

        if let logo = logoImage {
            if logoOnLeft {
                // Left team: [LOGO] SCORE
                let logoContainer = CGRect(
                    x: startX,
                    y: scoreY + (scoreSize.height - logoSize) / 2,  // Vertically center with score
                    width: logoSize,
                    height: logoSize
                )
                drawLogoAspectFit(logo, in: logoContainer, context: context)
                scoreString.draw(at: CGPoint(x: startX + logoSize + spacing, y: scoreY))
            } else {
                // Right team: SCORE [LOGO]
                scoreString.draw(at: CGPoint(x: startX, y: scoreY))
                let logoContainer = CGRect(
                    x: startX + scoreSize.width + spacing,
                    y: scoreY + (scoreSize.height - logoSize) / 2,  // Vertically center with score
                    width: logoSize,
                    height: logoSize
                )
                drawLogoAspectFit(logo, in: logoContainer, context: context)
            }
        } else {
            // No logo, just center the score
            let scoreX = origin.x + (width - scoreSize.width) / 2
            scoreString.draw(at: CGPoint(x: scoreX, y: scoreY))
        }
    }

    private func drawCenterSection(
        periodText: String,
        clockTime: String,
        at origin: CGPoint,
        width: CGFloat,
        scaleFactor: CGFloat,
        context: CGContext
    ) {
        let periodFontSize: CGFloat = 9 * scaleFactor
        let periodAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: periodFontSize, weight: .semibold),
            .foregroundColor: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95)
        ]

        let periodString = NSAttributedString(string: periodText, attributes: periodAttributes)
        let periodSize = periodString.size()
        let periodX = origin.x + (width - periodSize.width) / 2
        let periodY = origin.y + 8 * scaleFactor

        periodString.draw(at: CGPoint(x: periodX, y: periodY))

        // Clock
        let clockFontSize: CGFloat = 16 * scaleFactor
        let clockAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: clockFontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let clockString = NSAttributedString(string: clockTime, attributes: clockAttributes)
        let clockSize = clockString.size()
        let clockX = origin.x + (width - clockSize.width) / 2
        let clockY = origin.y + 22 * scaleFactor

        clockString.draw(at: CGPoint(x: clockX, y: clockY))
    }

    private func drawSeparator(
        at origin: CGPoint,
        height: CGFloat,
        scaleFactor: CGFloat,
        context: CGContext
    ) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1 * scaleFactor)
        context.move(to: origin)
        context.addLine(to: CGPoint(x: origin.x, y: origin.y + height))
        context.strokePath()
    }

    // MARK: - Image Loading Helpers

    /// Synchronous wrapper for loading logos (uses cache if available)
    private func loadImageFromURLSync(_ urlString: String?) -> UIImage? {
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
        print("⚠️ Logo not in cache, skipping: \(urlString)")
        return nil
    }

    /// Draws a logo image with aspect fit (no stretching) centered in the container
    private func drawLogoAspectFit(_ image: UIImage, in container: CGRect, context: CGContext) {
        let imageSize = image.size

        // Calculate aspect ratios
        let containerAspect = container.width / container.height
        let imageAspect = imageSize.width / imageSize.height

        var drawRect: CGRect

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let scaledHeight = container.width / imageAspect
            drawRect = CGRect(
                x: container.minX,
                y: container.minY + (container.height - scaledHeight) / 2,
                width: container.width,
                height: scaledHeight
            )
        } else {
            // Image is taller or square - fit to height
            let scaledWidth = container.height * imageAspect
            drawRect = CGRect(
                x: container.minX + (container.width - scaledWidth) / 2,
                y: container.minY,
                width: scaledWidth,
                height: container.height
            )
        }

        // Draw the image in the calculated rect
        image.draw(in: drawRect)
    }

    // MARK: - Formatting Helpers

    private func formatTeamName(_ teamName: String, maxLength: Int) -> String {
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

    private func formatLongPeriodText(gameFormat: GameFormat, currentPeriod: Int, totalRegularPeriods: Int) -> String {
        if currentPeriod <= totalRegularPeriods {
            let ordinalSuffixes = ["", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"]
            let suffix = currentPeriod <= 9 ? ordinalSuffixes[currentPeriod] : "th"

            switch gameFormat {
            case .quarters:
                return "\(currentPeriod)\(suffix) QTR"
            case .halves:
                return "\(currentPeriod)\(suffix) HALF"
            }
        } else {
            let otNumber = currentPeriod - totalRegularPeriods
            return otNumber == 1 ? "OT" : "\(otNumber)OT"
        }
    }
}

// Note: ScoreboardData is defined in ScoreboardRenderer.swift
