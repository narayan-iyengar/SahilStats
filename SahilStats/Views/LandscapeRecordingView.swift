//
//  LandscapeRecordingView.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/27/25.
//

// Completely redesigned landscape-native video recording with ESPN-style overlay

import SwiftUI
import AVFoundation
import Combine

// MARK: - Force Landscape Video Recording View

struct LandscapeVideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var recordingManager = VideoRecordingManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var screenSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview fills entire screen
                CameraPreviewView()
                    .ignoresSafeArea(.all)
                
                // Force landscape layout regardless of orientation
                landscapeInterfaceOverlay
                    .frame(width: max(geometry.size.width, geometry.size.height),
                           height: min(geometry.size.width, geometry.size.height))
            }
            .onAppear {
                screenSize = geometry.size
                recordingManager.startCameraSession()
                
                // Force landscape orientation
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.all)
        .onDisappear {
            recordingManager.stopCameraSession()
        }
    }
    
    @ViewBuilder
    private var landscapeInterfaceOverlay: some View {
        VStack(spacing: 0) {
            // Top controls
            topControlsBar
            
            Spacer()
            
            // Bottom ESPN-style scoreboard
            ESPNStyleScoreboard(
                liveGame: liveGame,
                recordingDuration: recordingManager.recordingDuration,
                isRecording: recordingManager.isRecording
            )
        }
    }
    
    @ViewBuilder
    private var topControlsBar: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Spacer()
            
            // Recording indicator
            if recordingManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recordingManager.isRecording)
                    
                    Text("REC")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text(recordingManager.recordingTimeString)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            Spacer()
            
            // Record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(recordingManager.isRecording ? .red : .white)
                        .frame(width: recordingManager.isRecording ? 30 : 60)
                        .scaleEffect(recordingManager.isRecording ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: recordingManager.isRecording)
                    
                    if recordingManager.isRecording {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private func toggleRecording() {
        if recordingManager.isRecording {
            Task { await recordingManager.stopRecording() }
        } else {
            Task { await recordingManager.startRecording() }
        }
    }
}

// MARK: - ESPN-Style Scoreboard Overlay

struct ESPNStyleScoreboard: View {
    let liveGame: LiveGame
    let recordingDuration: TimeInterval
    let isRecording: Bool
    
    var body: some View {
        // Full-width bottom bar - ESPN style
        HStack(spacing: 0) {
            // Left side - Away team
            awayTeamSection
            
            // Center - Game info
            gameInfoSection
            
            // Right side - Home team
            homeTeamSection
        }
        .frame(height: 80)
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
    
    @ViewBuilder
    private var awayTeamSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(liveGame.opponent.prefix(3)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("AWAY")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text("\(liveGame.awayScore)")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24)
    }
    
    @ViewBuilder
    private var gameInfoSection: some View {
        VStack(spacing: 6) {
            // Period
            Text(formatPeriod(liveGame.period, format: liveGame.gameFormat))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
            
            // Game clock
            Text(liveGame.currentClockDisplay)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Recording indicator (smaller, integrated)
            if isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("REC \(formatRecordingTime(recordingDuration))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.orange.opacity(0.5), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var homeTeamSection: some View {
        HStack(spacing: 16) {
            Text("\(liveGame.homeScore)")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
                .monospacedDigit()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(liveGame.teamName.prefix(3)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("HOME")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 24)
    }
    
    private func formatPeriod(_ period: Int, format: GameFormat) -> String {
        let periodName = format == .halves ? "HALF" : "QTR"
        return "\(period)\(getOrdinalSuffix(period)) \(periodName)"
    }
    
    private func getOrdinalSuffix(_ number: Int) -> String {
        switch number {
        case 1: return "ST"
        case 2: return "ND"
        case 3: return "RD"
        default: return "TH"
        }
    }
    
    private func formatRecordingTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Updated VideoRecordingView to use the new landscape version

struct VideoRecordingView: View {
    let liveGame: LiveGame
    @StateObject private var orientationManager = OrientationManager()
    
    var body: some View {
        if orientationManager.isLandscape {
            // Use the new landscape-native view
            LandscapeVideoRecordingView(liveGame: liveGame)
        } else {
            // Show rotation prompt
            RotationPromptView(liveGame: liveGame)
        }
    }
}

// MARK: - Rotation Prompt View

struct RotationPromptView: View {
    let liveGame: LiveGame
    @Environment(\.dismiss) private var dismiss
    @State private var rotationAnimation = false
    
    var body: some View {
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
                    Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("\(liveGame.homeScore) - \(liveGame.awayScore)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Period \(liveGame.period) • \(liveGame.currentClockDisplay)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 24)
                
                Button("Cancel Recording") {
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
                .padding(.top, 32)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
    }
}
