//
//  SimpleScoreOverlay.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/27/25.
//
// SimpleScoreOverlay.swift - Create this as a new file

import SwiftUI
import Combine
import Foundation
import UIKit

struct SimpleScoreOverlay: View {
    let overlayData: SimpleScoreOverlayData
    let orientation: UIDeviceOrientation
    
    private var isLandscape: Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
    }
    
    // Helper function to keep text upright in landscape mode
    private func getTextRotation() -> Double {
        switch orientation {
        case .landscapeLeft:
            return 90  // Rotate text to stay upright
        case .landscapeRight:
            return -90 // Rotate text to stay upright
        default:
            return 0   // No rotation needed in portrait
        }
    }
    
    var body: some View {
        if isLandscape {
            // Landscape overlay - positioned on the side
            HStack {
                Spacer()
                
                // Vertical overlay on the right side
                VStack(spacing: 0) {
                    // Away team (top)
                    VStack(spacing: 4) {
                        Text(String(overlayData.awayTeam.prefix(3)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(getTextRotation()))
                        
                        Text("\(overlayData.awayScore)")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .rotationEffect(.degrees(getTextRotation()))
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.top, 12)
                    
                    // Center info
                    VStack(spacing: 2) {
                        Text("P\(overlayData.period)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(getTextRotation()))
                        
                        Text(overlayData.clockTime)
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .rotationEffect(.degrees(getTextRotation()))
                        
                        if overlayData.isRecording {
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 4, height: 4)
                                // Removed "REC" text from scorecard overlay
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Home team (bottom)
                    VStack(spacing: 4) {
                        Text("\(overlayData.homeScore)")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .rotationEffect(.degrees(getTextRotation()))
                        
                        Text(String(overlayData.homeTeam.prefix(3)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(getTextRotation()))
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 12)
                }
                .frame(width: 80)
                .background(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black.opacity(0.9), location: 0.0),
                            .init(color: .black.opacity(0.7), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Rectangle()
                        .frame(width: 2)
                        .foregroundColor(.orange.opacity(0.8)),
                    alignment: .leading
                )
            }
            .ignoresSafeArea(.all)
            
        } else {
            // Portrait overlay - positioned at the bottom (original design)
            VStack {
                Spacer()
                
                // Bottom overlay bar
                HStack(spacing: 0) {
                    // Away team (left)
                    HStack(spacing: 8) {
                        Text(String(overlayData.awayTeam.prefix(3)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(overlayData.awayScore)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    
                    // Center info
                    VStack(spacing: 4) {
                        Text("PERIOD \(overlayData.period)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text(overlayData.clockTime)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        if overlayData.isRecording {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 4, height: 4)
                                // Only show dot, no "REC" text in scorecard
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Home team (right)
                    HStack(spacing: 8) {
                        Text("\(overlayData.homeScore)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        Text(String(overlayData.homeTeam.prefix(3)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                }
                .frame(height: 60)
                .background(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black.opacity(0.9), location: 0.0),
                            .init(color: .black.opacity(0.7), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.orange.opacity(0.8)),
                    alignment: .top
                )
            }
            .ignoresSafeArea(.all)
        }
    }
}
