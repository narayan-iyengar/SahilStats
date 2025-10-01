//
//  SimpleScoreOverlay.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/27/25.
//
// SimpleScoreOverlay.swift - Enhanced with full team names, better layout, and fancy graphics

import SwiftUI
import Combine
import Foundation
import UIKit

struct SimpleScoreOverlay: View {
    let overlayData: SimpleScoreOverlayData
    let orientation: UIDeviceOrientation
    let recordingDuration: String
    
    @State private var rotationAnimation = false
    
    private var isLandscape: Bool {
        let result = orientation == .landscapeLeft || orientation == .landscapeRight
        let _ = print("🟣 isLandscape check: orientation=\(orientation), landscapeLeft=\(UIDeviceOrientation.landscapeLeft), landscapeRight=\(UIDeviceOrientation.landscapeRight), result=\(result)")
        return result
    }
    
    // Helper function to get ordinal suffix (1st, 2nd, 3rd, 4th, etc.)
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
    
    // Helper function to format quarter/half display
    private func formatPeriod() -> String {
        let periodName = overlayData.gameFormat == .halves ? "HALF" : "QUARTER"
        let ordinal = "\(overlayData.quarter)\(getOrdinalSuffix(overlayData.quarter))"
        return "\(ordinal) \(periodName)"
    }
    
    // Helper function for short period display
    private func formatShortPeriod() -> String {
        let shortName = overlayData.gameFormat == .halves ? "HALF" : "QTR"
        return "\(overlayData.quarter)\(getOrdinalSuffix(overlayData.quarter)) \(shortName)"
    }
    
    // Helper function to keep text upright in landscape mode
    private func getTextRotation() -> Double {
        let rotation: Double
        switch orientation {
        case .landscapeLeft:
            rotation = 90  // Rotate text to stay upright
        case .landscapeRight:
            rotation = -90 // Rotate text to stay upright
        default:
            rotation = 0   // No rotation needed in portrait
        }
        let _ = print("🟣 getTextRotation: orientation=\(orientation), returning rotation=\(rotation)")
        return rotation
    }
    
    // Helper function to truncate team name smartly for landscape
    private func formatTeamName(_ teamName: String, maxLength: Int = 8) -> String {
        if teamName.count <= maxLength {
            return teamName.uppercased()
        }
        // Try to find a good break point
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
        if isLandscape {
            // FIXED: Landscape overlay - NO rotation, native vertical layout
            HStack {
                Spacer()
                
                // Vertical side scoreboard (naturally vertical, no rotation needed)
                VStack(spacing: 0) {
                    // Away team section
                    VStack(spacing: 8) {
                        Text(formatTeamName(overlayData.awayTeam, maxLength: 8))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(overlayData.awayScore)")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.top, 20)
                    .rotationEffect(.degrees(getTextRotation()))
                    
                    // Divider
                    Rectangle()
                        .fill(.orange.opacity(0.5))
                        .frame(height: 2)
                        .padding(.horizontal, 12)
                    
                    // Game info section
                    VStack(spacing: 6) {
                        Text(formatShortPeriod())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                        
                        Text(overlayData.clockTime)
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(maxHeight: .infinity)
                    .rotationEffect(.degrees(getTextRotation()))
                    
                    // Divider
                    Rectangle()
                        .fill(.orange.opacity(0.5))
                        .frame(height: 2)
                        .padding(.horizontal, 12)
                    
                    // Home team section
                    VStack(spacing: 8) {
                        Text(String(formatTeamName(overlayData.homeTeam)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(overlayData.homeScore)")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.top, 20)
                    .rotationEffect(.degrees(getTextRotation()))
                }
                .frame(width: 100)
                .overlay(
                    Rectangle()
                        .frame(width: 3)
                        .foregroundColor(.orange.opacity(0.6)),
                    alignment: .leading
                )
            }
            .ignoresSafeArea(.all)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        } else {
            // Portrait mode - show rotation prompt
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Animated rotation icon
                    Image(systemName: "rotate.right")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotationAnimation ? 90 : 0))
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: rotationAnimation)
                        .onAppear { rotationAnimation = true }
                    
                    VStack(spacing: 16) {
                        Text("Rotate to Landscape")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Professional video recording requires landscape orientation for the best scoreboard experience")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Game preview
                    VStack(spacing: 12) {
                        Text("\(overlayData.homeTeam) vs \(overlayData.awayTeam)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("\(overlayData.homeScore) - \(overlayData.awayScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("\(formatPeriod()) • \(overlayData.clockTime)")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 24)
                }
            }
        }
    }
}
