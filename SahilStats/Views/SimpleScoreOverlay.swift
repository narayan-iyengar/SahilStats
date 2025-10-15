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
    @State private var recordingProgress: CGFloat = 0
    @State private var progressTimer: Timer?
    @State private var showZoomIndicator = false
    @State private var zoomHideTimer: Timer?

    @ObservedObject private var recordingManager = VideoRecordingManager.shared
    
    private var isLandscape: Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
    }
    
    // Camera is locked to landscapeRight, so we need to rotate content when device is landscapeLeft
    private var needsRotation: Bool {
        orientation == .landscapeLeft
    }
    
    private func getOrdinalSuffix(_ number: Int) -> String {
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
    
    private func formatPeriod() -> String {
        let periodName = overlayData.gameFormat == .halves ? "HALF" : "QUARTER"
        let ordinal = "\(overlayData.quarter)\(getOrdinalSuffix(overlayData.quarter))"
        return "\(ordinal) \(periodName)"
    }
    
    private func formatShortPeriod() -> String {
        let periodName = overlayData.gameFormat == .halves ? "HALF" : "QTR"
        let ordinal = getOrdinalSuffix(overlayData.quarter)
        return "\(overlayData.quarter)\(ordinal) \(periodName)"
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
            print("📄 SimpleScoreOverlay appeared - orientation: \(orientation.debugDescription), isLandscape: \(isLandscape)")
        }
        .onChange(of: orientation) { oldValue, newValue in
            print("📄 SimpleScoreOverlay orientation changed: \(oldValue.debugDescription) -> \(newValue.debugDescription), isLandscape: \(isLandscape)")
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
                zoomHideTimer?.invalidate()

                // Auto-hide after 1.5 seconds
                zoomHideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        showZoomIndicator = false
                    }
                }
            } else if newValue == 1.0 {
                // Hide immediately when returning to 1.0x
                withAnimation(.easeOut(duration: 0.2)) {
                    showZoomIndicator = false
                }
                zoomHideTimer?.invalidate()
            }
        }
    }
    
    // MARK: - Compact Landscape Overlay
    private var landscapeOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Zoom indicator at top center (iOS Camera app style)
                if showZoomIndicator {
                    VStack {
                        Text(String(format: "%.1f×", recordingManager.currentZoomLevel))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))  // iOS Camera yellow
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .padding(.top, 20)
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
            // Away team
            VStack(spacing: 2) {
                Text(formatTeamName(overlayData.homeTeam, maxLength: 4))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(overlayData.homeScore)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 50)

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

            // Home team
            VStack(spacing: 2) {
                Text(formatTeamName(overlayData.awayTeam, maxLength: 4))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(overlayData.awayScore)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 50)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
        .shadow(color: isRecording ? Color.red.opacity(0.4 + (recordingProgress * 0.3)) : Color.clear, radius: isRecording ? 8 : 0, x: 0, y: 0)
        .onAppear {
            if isRecording {
                startProgressTimer()
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startProgressTimer()
            } else {
                stopProgressTimer()
            }
        }
        .onDisappear {
            stopProgressTimer()
        }
    }

    // MARK: - Progress Timer Methods

    private func startProgressTimer() {
        recordingProgress = 0
        progressTimer?.invalidate()

        // Update progress every 0.1 seconds for smooth animation
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Increment progress - complete circle every 60 seconds
            recordingProgress += 0.1 / 60.0

            // Loop back to 0 when complete
            if recordingProgress >= 1.0 {
                recordingProgress = 0
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        recordingProgress = 0
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
