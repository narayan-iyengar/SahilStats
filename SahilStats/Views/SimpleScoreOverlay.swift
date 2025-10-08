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
    @State private var borderPulse = false
    
    private var isLandscape: Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
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
        switch orientation {
        case .landscapeLeft: return 90
        case .landscapeRight: return -90
        default: return 0
        }
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
        .onChange(of: orientation) { _, _ in
            // Stop animation when orientation changes
            if isLandscape {
                rotationAnimation = false
            }
        }
    }
    
    // MARK: - Compact Landscape Overlay
    private var landscapeOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Position based on specific landscape orientation
                if orientation == .landscapeRight {
                    // Camera on left (dynamic island side), overlay bottom center
                    VStack {
                        Spacer()
                        scoreboardContent
                            .padding(.bottom, 40)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else if orientation == .landscapeLeft {
                    // Camera on right, overlay bottom center
                    VStack {
                        Spacer()
                        scoreboardContent
                            .padding(.bottom, 40)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
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
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isRecording ? Color.red : Color.white.opacity(0.2),
                        lineWidth: isRecording ? 3 : 1
                    )
                    .opacity(isRecording ? (borderPulse ? 1.0 : 0.4) : 1.0)
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
        .onAppear {
            if isRecording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    borderPulse = true
                }
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    borderPulse = true
                }
            } else {
                borderPulse = false
            }
        }
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
                Image(systemName: "iphone")  // Changed to iPhone icon for better portrait representation
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotationAnimation ? 90 : 0))
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: rotationAnimation)
                    .onAppear { rotationAnimation = true }
                    .onDisappear { rotationAnimation = false }  // FIXED: Stop animation when view disappears
                
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
