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
        let _ = print("🔵 LandscapeVideoRecordingView: body called")
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
        let _ = print("🔴 ESPNStyleScoreboard: body called")
        // Full-width bottom bar - ESPN style
        HStack(spacing: 0) {
            // Left side - Away team
            awayTeamSection
            
            // Center - Game info
            gameInfoSection
            
            // Right side - Home team
            homeTeamSection
        }
        .frame(height: 110) // Increased height from 100 to 110 for separated center content
        .background(
            ZStack {
                // Enhanced base gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black.opacity(0.95), location: 0.0),
                        .init(color: .black.opacity(0.85), location: 0.5),
                        .init(color: .black.opacity(0.9), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle texture overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.08),
                        .clear,
                        .white.opacity(0.05)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            // Enhanced top border with glow
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 3)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .orange.opacity(0.9),
                                .orange,
                                .orange.opacity(0.9)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 0)
                
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: -4)
    }
    
    @ViewBuilder
    private var awayTeamSection: some View {
        HStack(spacing: 18) { // Increased spacing
            VStack(alignment: .leading, spacing: 6) { // Increased spacing
                Text(formatTeamName(liveGame.opponent))
                    .font(.system(size: 20, weight: .bold, design: .rounded)) // Increased from 16 to 20
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                Text("AWAY")
                    .font(.system(size: 12, weight: .medium, design: .rounded)) // Increased from 10 to 12
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            Text("\(liveGame.awayScore)")
                .font(.system(size: 48, weight: .black, design: .rounded)) // Increased from 40 to 48
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 3) // Enhanced shadow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 28) // Increased padding
    }
    
    @ViewBuilder
    private var gameInfoSection: some View {
        VStack(spacing: 8) { // Reduced spacing for tighter layout
            // Quarter info - more compact
            VStack(spacing: 2) {
                Text("\(liveGame.quarter)\(getOrdinalSuffix(liveGame.quarter))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                
                Text(liveGame.gameFormat == .halves ? "HALF" : "QUARTER")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.orange.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // Game clock with proper separation
            Text(liveGame.currentClockDisplay)
                .font(.system(size: 28, weight: .black, design: .rounded)) // Slightly smaller to fit better
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 3)
                .padding(.vertical, 4) // Add vertical padding for breathing room
            
            // Recording indicator (smaller, integrated)
            if isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [.red, .red.opacity(0.8)]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 3
                            )
                        )
                        .frame(width: 6, height: 6)
                        .shadow(color: .red.opacity(0.5), radius: 2, x: 0, y: 1)
                    Text("REC \(formatRecordingTime(recordingDuration))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, 28) // Increased padding
        .padding(.vertical, 14) // Increased padding
        .background(
            ZStack {
                // Enhanced glass-like background
                RoundedRectangle(cornerRadius: 15) // Increased corner radius
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .black.opacity(0.4),
                                .black.opacity(0.2),
                                .black.opacity(0.4)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3) // Enhanced shadow
                
                // Subtle highlight
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .orange.opacity(0.6),
                                .orange.opacity(0.3),
                                .orange.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2 // Increased stroke width
                    )
            }
        )
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var homeTeamSection: some View {
        HStack(spacing: 18) { // Increased spacing
            Text("\(liveGame.homeScore)")
                .font(.system(size: 48, weight: .black, design: .rounded)) // Increased from 40 to 48
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 3) // Enhanced shadow
            
            VStack(alignment: .trailing, spacing: 6) { // Increased spacing
                Text(formatTeamName(liveGame.teamName))
                    .font(.system(size: 20, weight: .bold, design: .rounded)) // Increased from 16 to 20
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                Text("HOME")
                    .font(.system(size: 12, weight: .medium, design: .rounded)) // Increased from 10 to 12
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 28) // Increased padding
    }
    
    // Helper function to format team names intelligently for landscape
    private func formatTeamName(_ teamName: String) -> String {
        // Allow much longer team names in landscape - we have more space
        if teamName.count <= 18 { // Increased from 12 to 18
            return teamName.uppercased()
        }
        // Try to find a good break point
        let words = teamName.components(separatedBy: " ")
        if words.count > 1 {
            let firstWord = words[0]
            if firstWord.count <= 18 { // Increased from 12 to 18
                return firstWord.uppercased()
            }
        }
        return String(teamName.prefix(18)).uppercased() // Increased from 12 to 18
    }
    
    // Helper function to get ordinal suffix (1st, 2nd, 3rd, 4th, etc.)
    private func getOrdinalSuffix(_ number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "TH"
        }
        
        switch lastDigit {
        case 1: return "ST"
        case 2: return "ND" 
        case 3: return "RD"
        default: return "TH"
        }
    }
    
    private func formatQuarter(_ quarter: Int, format: GameFormat) -> String {
        let quarterName = format == .halves ? "HALF" : "QTR"
        return "\(quarter)\(getOrdinalSuffix(quarter)) \(quarterName)"
    }
    
    private func formatQuarterLong(_ quarter: Int, format: GameFormat) -> String {
        let quarterName = format == .halves ? "Half" : "Quarter"
        return "\(quarter)\(getOrdinalSuffix(quarter)) \(quarterName)"
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
            let _ = print("🟢 VideoRecordingView: Using LandscapeVideoRecordingView")
            LandscapeVideoRecordingView(liveGame: liveGame)
        } else {
            // Show rotation prompt
            let _ = print("🟡 VideoRecordingView: Using RotationPromptView")
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
                    
                    Text("\(formatQuarterLong(liveGame.quarter, format: liveGame.gameFormat)) • \(liveGame.currentClockDisplay)")
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
    
    private func formatQuarterLong(_ quarter: Int, format: GameFormat) -> String {
        let quarterName = format == .halves ? "Half" : "Quarter"
        return "\(quarter)\(getOrdinalSuffix(quarter)) \(quarterName)"
    }
    
    private func getOrdinalSuffix(_ number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100
        
        // Handle special cases for 11th, 12th, 13th
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
}
