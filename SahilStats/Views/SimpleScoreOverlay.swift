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
                        Text(String(overlayData.awayTeam.prefix(5)).uppercased())
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
                    .rotationEffect(.degrees(-90))
                    
                    // Divider
                    Rectangle()
                        .fill(.orange.opacity(0.5))
                        .frame(height: 2)
                        .padding(.horizontal, 12)
                    
                    // Game info section
                    VStack(spacing: 8) {
                        Text(formatShortPeriod())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                        
                        Text(overlayData.clockTime)
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        if overlayData.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .rotationEffect(.degrees(-90))
                    
                    // Divider
                    Rectangle()
                        .fill(.orange.opacity(0.5))
                        .frame(height: 2)
                        .padding(.horizontal, 12)
                    
                    // Home team section
                    VStack(spacing: 8) {
                        Text(String(overlayData.homeTeam.prefix(5)).uppercased())
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
                    .rotationEffect(.degrees(-90))
                }
                .frame(width: 100)
                .background(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black.opacity(0.95), location: 0.0),
                            .init(color: .black.opacity(0.85), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
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
        }
    }
}
