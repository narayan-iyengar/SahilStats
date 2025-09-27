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

struct SimpleScoreOverlay: View {
    let overlayData: SimpleScoreOverlayData
    
    var body: some View {
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
                            Text("REC \(overlayData.recordingDuration)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.red)
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
