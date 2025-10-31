//
//  SimpleScoreOverlay.swift
//  SahilStats
//

import SwiftUI
import Combine
import Foundation
import UIKit

struct SimpleScoreOverlay: View {
    let overlayData: SimpleScoreOverlayData
    let orientation: UIDeviceOrientation
    let recordingDuration: String
    let isRecording: Bool

    @State private var rotationAnimation = false
    @State private var showZoomIndicator = false
    @State private var cancellables = Set<AnyCancellable>()

    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    
    private var isLandscape: Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
    }
    
    // Camera is locked to landscapeRight, so we need to rotate content when device is landscapeLeft
    private var needsRotation: Bool {
        orientation == .landscapeLeft
    }
    
    // Note: Period formatting uses GameFormat.formatPeriodDisplay()
    // which handles overtime display (OT, 2OT, etc.)

    private func formatPeriod() -> String {
        // For portrait view (long form): "1st QUARTER" or "OT"
        let shortForm = overlayData.gameFormat.formatPeriodDisplay(
            currentPeriod: overlayData.quarter,
            totalRegularPeriods: overlayData.numQuarter
        )

        // Expand short form for portrait display
        if shortForm == "OT" {
            return "OVERTIME"
        } else if shortForm.hasSuffix("OT") {
            // "2OT" -> "2nd OVERTIME"
            return "\(shortForm.dropLast(2)) OVERTIME"
        }

        // Regular period: expand "Q1" to "1st QUARTER" or "1H" to "1st HALF"
        let periodName = overlayData.gameFormat == .halves ? "HALF" : "QUARTER"
        let ordinalSuffixes = ["", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"]
        let suffix = overlayData.quarter <= 9 ? ordinalSuffixes[overlayData.quarter] : "th"
        return "\(overlayData.quarter)\(suffix) \(periodName)"
    }

    private func formatShortPeriod() -> String {
        // For landscape scoreboard: "1st Half", "3rd Qtr", "OT", "2OT"
        let shortForm = overlayData.gameFormat.formatPeriodDisplay(
            currentPeriod: overlayData.quarter,
            totalRegularPeriods: overlayData.numQuarter
        )

        // Keep overtime as-is
        if shortForm == "OT" || shortForm.hasSuffix("OT") {
            return shortForm
        }

        // Regular period: "1st Half", "3rd Qtr", etc.
        let periodName = overlayData.gameFormat == .halves ? "Half" : "Qtr"
        let ordinalSuffixes = ["", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"]
        let suffix = overlayData.quarter <= 9 ? ordinalSuffixes[overlayData.quarter] : "th"
        return "\(overlayData.quarter)\(suffix) \(periodName)"
    }
    
    private func getTextRotation() -> Double {
        // Camera is locked to landscapeRight
        // When device is landscapeLeft, we need to rotate 180 degrees
        return needsRotation ? 180 : 0
    }
    
    private func formatTeamName(_ teamName: String, maxLength: Int = 8) -> String {
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
    
    var body: some View {
        Group {
            if isLandscape {
                landscapeOverlay
            } else {
                portraitPrompt
            }
        }
        .onAppear {
            debugPrint("📄 SimpleScoreOverlay appeared - orientation: \(orientation.debugDescription), isLandscape: \(isLandscape)")
        }
        .onChange(of: orientation) { oldValue, newValue in
            debugPrint("📄 SimpleScoreOverlay orientation changed: \(oldValue.debugDescription) -> \(newValue.debugDescription), isLandscape: \(isLandscape)")
            // Stop animation when orientation changes
            if isLandscape {
                rotationAnimation = false
            }
        }
        .onChange(of: recordingManager.currentZoomLevel) { oldValue, newValue in
            // Show zoom indicator when zoom changes
            if newValue != oldValue && newValue != 1.0 {
                withAnimation(.easeIn(duration: 0.2)) {
                    showZoomIndicator = true
                }

                // Cancel existing hide timer
                cancellables.removeAll()

                // Auto-hide after 1.5 seconds using Combine
                Just(())
                    .delay(for: .seconds(1.5), scheduler: RunLoop.main)
                    .sink { [self] _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            showZoomIndicator = false
                        }
                    }
                    .store(in: &cancellables)
            } else if newValue == 1.0 {
                // Hide immediately when returning to 1.0x
                withAnimation(.easeOut(duration: 0.2)) {
                    showZoomIndicator = false
                }
                cancellables.removeAll()
            }
        }
    }
    
    // MARK: - Compact Landscape Overlay
    private var landscapeOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // REC indicator at top-right when recording
                if isRecording {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("REC")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.top, geometry.safeAreaInsets.top + 12)
                            .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                }

                // Zoom indicator at top center (iOS Camera app style)
                if showZoomIndicator {
                    VStack {
                        Text(String(format: "%.1f×", recordingManager.currentZoomLevel))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))  // iOS Camera yellow
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .padding(.top, geometry.safeAreaInsets.top + 12)
                        Spacer()
                    }
                    .transition(.opacity)
                }

                // Scoreboard at bottom center
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        scoreboardContent
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var scoreboardContent: some View {
        HStack(spacing: 12) {
            // Home team
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    // Home team logo (if available)
                    if let logoURL = overlayData.homeLogoURL, !logoURL.isEmpty {
                        AsyncImage(url: URL(string: logoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .cornerRadius(3)
                                    .padding(1)
                                    .frame(width: 20, height: 20)
                                    .clipped()
                            case .failure(_):
                                // Fallback: Show team initial
                                Text(String(overlayData.homeTeam.prefix(1)))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.orange.opacity(0.7))
                                    .cornerRadius(3)
                            case .empty:
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    Text(formatTeamName(overlayData.homeTeam, maxLength: 4))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Text("\(overlayData.homeScore)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 65)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 30)

            // Clock & period
            VStack(spacing: 2) {
                Text(formatShortPeriod())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.95))
                Text(overlayData.clockTime)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 70)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 30)

            // Away team
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    // Away team logo (if available)
                    if let logoURL = overlayData.awayLogoURL, !logoURL.isEmpty {
                        AsyncImage(url: URL(string: logoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .cornerRadius(3)
                                    .padding(1)
                                    .frame(width: 20, height: 20)
                                    .clipped()
                            case .failure(_):
                                // Fallback: Show team initial
                                Text(String(overlayData.awayTeam.prefix(1)))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.blue.opacity(0.7))
                                    .cornerRadius(3)
                            case .empty:
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    Text(formatTeamName(overlayData.awayTeam, maxLength: 4))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Text("\(overlayData.awayScore)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 65)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // ORIGINAL: Nice glassmorphism effect
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Subtle border
                if !isRecording {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
    }

    // MARK: - Portrait Prompt
    
    private var portraitPrompt: some View {
        ZStack {
            // Dark background with slight blur
            Color.black
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Animated rotation icon with proper orientation
                Image(systemName: "iphone")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotationAnimation ? 90 : 0))
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: rotationAnimation)
                    .onAppear { rotationAnimation = true }
                    .onDisappear { rotationAnimation = false }
                
                VStack(spacing: 16) {
                    Text("Rotate to Landscape")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Professional video recording requires landscape orientation")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Glass preview card
                VStack(spacing: 16) {
                    Text("\(overlayData.homeTeam) vs \(overlayData.awayTeam)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 20) {
                        Text("\(overlayData.homeScore)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("—")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("\(overlayData.awayScore)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    Text("\(formatPeriod()) • \(overlayData.clockTime)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 40)
            }
        }
    }
}
