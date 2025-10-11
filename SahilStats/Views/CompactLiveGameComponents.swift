//
//  CompactLiveGameComponents.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/19/25.
//
//
//  CompactLiveGameComponents.swift
//  SahilStats
//
//  Created by [Your Name] on [Date]
//

import SwiftUI
import FirebaseCore
import Firebase
import FirebaseAuth
import Combine




// MARK: - Compact Device Control Status - NEW

struct CompactDeviceControlStatusCard: View {
    let hasControl: Bool
    let controllingUser: String?
    let canRequestControl: Bool
    let pendingRequest: String?
    let isIPad: Bool
    let onRequestControl: () -> Void
    let showBluetoothStatus: Bool
    let isRecording: Bool?  // NEW: Optional recording state
    let onToggleRecording: (() -> Void)?  // NEW: Optional recording toggle
    
    init(hasControl: Bool, controllingUser: String?, canRequestControl: Bool, pendingRequest: String?, isIPad: Bool, onRequestControl: @escaping () -> Void, showBluetoothStatus: Bool, isRecording: Bool?, onToggleRecording: (() -> Void)?) {
        self.hasControl = hasControl
        self.controllingUser = controllingUser
        self.canRequestControl = canRequestControl
        self.pendingRequest = pendingRequest
        self.isIPad = isIPad
        self.onRequestControl = onRequestControl
        self.showBluetoothStatus = showBluetoothStatus
        self.isRecording = isRecording
        self.onToggleRecording = onToggleRecording
        
        // DEBUG: Print all the values when this view is created
        print("🔍 [DEBUG] CompactDeviceControlStatusCard init:")
        print("   hasControl: \(hasControl)")
        print("   showBluetoothStatus: \(showBluetoothStatus)")
        print("   isRecording: \(isRecording?.description ?? "nil")")
        print("   onToggleRecording: \(onToggleRecording != nil ? "provided" : "nil")")
        print("   Recording button will show: \(isRecording != nil && onToggleRecording != nil)")
    }
    
    var body: some View {
        HStack(spacing: isIPad ? 12 : 8) {
            // Status indicator
            Image(systemName: hasControl ? "gamecontroller.fill" : "eye.fill")
                .foregroundColor(hasControl ? .green : .blue)
                .font(isIPad ? .body : .caption)
            
            // Status text
            Text(hasControl ? "Controlling" : "Viewing")
                .font(isIPad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(hasControl ? .green : .blue)
            
            Spacer()
            // ADD: Recording button (compact) - only if Bluetooth connected and controller
            if showBluetoothStatus, let toggleRecording = onToggleRecording {
                Button(action: toggleRecording) {
                    HStack(spacing: 4) {
                        Image(systemName: (isRecording ?? false) ? "stop.circle.fill" : "record.circle")
                            .font(.caption)
                        Text((isRecording ?? false) ? "Stop" : "Rec")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isRecording ?? false) ? Color.red : Color.red.opacity(0.8))
                    .cornerRadius(6)
                }
                .disabled(isRecording == nil) // Disable if no recording state (not connected)
                .opacity(isRecording == nil ? 0.5 : 1.0) // Grey out if not connected
            }
            
            // ADD: Bluetooth status indicator
            if showBluetoothStatus {
                BluetoothStatusIndicator()
           }
            
            // Request control button (compact)
            if !hasControl {
                if let pendingUser = pendingRequest {
                    Text("Pending...")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                } else if canRequestControl {
                    Button("Request") {
                        onRequestControl()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(hasControl ? Color.green.opacity(0.08) : Color.blue.opacity(0.08))
        .cornerRadius(isIPad ? 12 : 8)
    }
}
// MARK: - Compact Clock Card

struct CompactClockCard: View {
    let quarter: Int
    let clockTime: TimeInterval
    let isGameRunning: Bool
    let gameFormat: GameFormat // NEW: Add game format
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            // quarter/Half with correct label
            VStack(spacing: 2) {
                Text(gameFormat.quarterName) // "quarter" or "Half"
                    .font(isIPad ? .caption : .caption2)
                    .foregroundColor(.secondary)
                Text("\(quarter)")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Clock
            VStack(spacing: 2) {
                Text("Time")
                    .font(isIPad ? .caption : .caption2)
                    .foregroundColor(.secondary)
                Text(formatClockTime(clockTime))
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(isGameRunning ? .red : .primary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(isGameRunning ? Color.red : Color.gray)
                    .frame(width: isIPad ? 8 : 6, height: isIPad ? 8 : 6)
                    .opacity(isGameRunning ? 0.8 : 0.5)
                    .animation(isGameRunning ? .easeInOut(duration: 1).repeatForever() : .default, value: isGameRunning)
                
                Text(isGameRunning ? "LIVE" : "PAUSED")
                    .font(isIPad ? .caption : .caption2)
                    .fontWeight(.bold)
                    .foregroundColor(isGameRunning ? .red : .gray)
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 12 : 8)
    }
    
    private func formatClockTime(_ time: TimeInterval) -> String {
        if time <= 59 {
            return String(format: "%.1f", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Compact Live Score Card (Interactive)

struct CompactLiveScoreCard: View {
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    let onScoreChange: () -> Void
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Title
            //Text("Live Score")
             //   .font(isIPad ? .title2 : .title3)
             //   .fontWeight(.bold)
             //   .foregroundColor(.primary)
            
            HStack(spacing: isIPad ? 32 : 24) { // Much more spacing between teams
                // Home team
                VStack(spacing: isIPad ? 16 : 12) {
                    Text(teamName)
                        .font(isIPad ? .title3 : .body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    VStack(spacing: isIPad ? 16 : 12) { // Much more spacing between score and buttons
                        // HUGE score display
                        Text("\(homeScore)")
                            .font(isIPad ? .system(size: 64, weight: .heavy) : .system(size: 56, weight: .heavy))
                            .foregroundColor(.blue)
                            .frame(minWidth: isIPad ? 80 : 70)
                            .frame(minHeight: isIPad ? 70 : 60) // Ensure tall touch target
                        
                        // MUCH BIGGER buttons with more spacing
                        HStack(spacing: isIPad ? 20 : 16) { // Way more spacing between buttons
                            Button("-") {
                                if homeScore > 0 {
                                    homeScore -= 1
                                    onScoreChange()
                                }
                            }
                            .buttonStyle(FatFingerProofButtonStyle(isIPad: isIPad))
                            
                            Button("+") {
                                homeScore += 1
                                onScoreChange()
                            }
                            .buttonStyle(FatFingerProofButtonStyle(isIPad: isIPad))
                        }
                    }
                }
                
                // Bigger separator
                Text("–")
                    .font(isIPad ? .system(size: 40, weight: .medium) : .system(size: 36, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Away team
                VStack(spacing: isIPad ? 16 : 12) {
                    Text(opponent)
                        .font(isIPad ? .title3 : .body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    VStack(spacing: isIPad ? 16 : 12) {
                        // HUGE score display
                        Text("\(awayScore)")
                            .font(isIPad ? .system(size: 64, weight: .heavy) : .system(size: 56, weight: .heavy))
                            .foregroundColor(.red)
                            .frame(minWidth: isIPad ? 80 : 70)
                            .frame(minHeight: isIPad ? 70 : 60)
                        
                        // MUCH BIGGER buttons with more spacing
                        HStack(spacing: isIPad ? 20 : 16) {
                            Button("-") {
                                if awayScore > 0 {
                                    awayScore -= 1
                                    onScoreChange()
                                }
                            }
                            .buttonStyle(FatFingerProofButtonStyle(isIPad: isIPad))
                            
                            Button("+") {
                                awayScore += 1
                                onScoreChange()
                            }
                            .buttonStyle(FatFingerProofButtonStyle(isIPad: isIPad))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, isIPad ? 28 : 24) // More padding all around
        .padding(.vertical, isIPad ? 28 : 24)
        .background(Color(.systemBackground))
        //.overlay(
        //    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
        //        .stroke(Color.orange.opacity(0.4), lineWidth: 2)
        //)
        //.cornerRadius(isIPad ? 20 : 16)
    }
}

// MARK: - Fat-Finger Proof Button Style

struct FatFingerProofButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .system(size: 28, weight: .bold) : .system(size: 24, weight: .bold)) // MUCH bigger text
            .foregroundColor(.white)
            .frame(width: isIPad ? 56 : 48, height: isIPad ? 56 : 48) // MUCH bigger buttons
            .background(
                Circle()
                    .fill(Color.orange)
                    .shadow(color: .orange.opacity(0.3), radius: configuration.isPressed ? 2 : 4, x: 0, y: configuration.isPressed ? 1 : 2)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0) // Less dramatic scale for better feedback
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Also update the read-only version for consistency

struct CompactLiveScoreDisplayCard: View {
    let homeScore: Int
    let awayScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            //Text("Live Score")
            //    .font(isIPad ? .title2 : .title3)
            //    .fontWeight(.bold)
            //    .foregroundColor(.primary)
            
            HStack(spacing: isIPad ? 40 : 32) { // More spacing for read-only too
                VStack(spacing: isIPad ? 16 : 12) {
                    Text(teamName)
                        .font(isIPad ? .title3 : .body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // MASSIVE scores for read-only (even bigger since no buttons)
                    Text("\(homeScore)")
                        .font(isIPad ? .system(size: 72, weight: .heavy) : .system(size: 64, weight: .heavy))
                        .foregroundColor(.blue)
                        .frame(minWidth: isIPad ? 90 : 80)
                        .frame(minHeight: isIPad ? 80 : 70)
                }
                
                // Bigger separator for read-only
                Text("–")
                    .font(isIPad ? .system(size: 44, weight: .medium) : .system(size: 40, weight: .medium))
                    .foregroundColor(.secondary)
                
                VStack(spacing: isIPad ? 16 : 12) {
                    Text(opponent)
                        .font(isIPad ? .title3 : .body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // MASSIVE scores for read-only
                    Text("\(awayScore)")
                        .font(isIPad ? .system(size: 72, weight: .heavy) : .system(size: 64, weight: .heavy))
                        .foregroundColor(.red)
                        .frame(minWidth: isIPad ? 90 : 80)
                        .frame(minHeight: isIPad ? 80 : 70)
                }
            }
        }
        .padding(.horizontal, isIPad ? 28 : 24)
        .padding(.vertical, isIPad ? 28 : 24)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 20 : 16)
    }
}

// MARK: - Smaller, More Subtle Score Button Style

struct SmallerScoreButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .body : .subheadline) // SMALLER: Reduced font size
            .fontWeight(.semibold) // SMALLER: Less bold
            .foregroundColor(.white)
            .frame(width: isIPad ? 32 : 28, height: isIPad ? 32 : 28) // SMALLER: Reduced button size
            .background(Color.orange.opacity(0.8)) // SMALLER: Less prominent with opacity
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


// MARK: - Compact Game Controls

struct CompactGameControlsCard: View {
    let currentQuarter: Int
    let maxQuarter: Int
    let gameFormat: GameFormat
    let isGameRunning: Bool
    let isIPad: Bool
    let onStartPause: () -> Void
    let onAddMinute: () -> Void
    let onAdvanceQuarter: () -> Void
    let onFinishGame: () -> Void
    
    private var startPauseText: String {
        isGameRunning ? "Pause" : "Start"
    }
    
    private var startPauseColor: Color {
        isGameRunning ? .orange : .green
    }
    
    private var advanceQuarterText: String {
        if currentQuarter < maxQuarter {
            return "End \(gameFormat.quarterName)" // "End quarter" or "End Half"
        } else {
            return "End Game"
        }
    }
    
    private var advanceQuarterColor: Color {
        currentQuarter < maxQuarter ? .blue : .red
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("Game Controls")
                .font(isIPad ? .body : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: isIPad ? 12 : 8) {
                Button(startPauseText) {
                    onStartPause()
                }
                .buttonStyle(BiggerCompactControlButtonStyle(color: startPauseColor, isIPad: isIPad))
                
                Button("+1m") {
                    onAddMinute()
                }
                .buttonStyle(BiggerCompactControlButtonStyle(color: .purple, isIPad: isIPad))
                
                Button(advanceQuarterText) {
                    if currentQuarter < maxQuarter {
                        onAdvanceQuarter()
                    } else {
                        onFinishGame()
                    }
                }
                .buttonStyle(BiggerCompactControlButtonStyle(color: advanceQuarterColor, isIPad: isIPad))
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

// MARK: - Compact Button Styles

struct CompactScoreButtonStyle: ButtonStyle {
    let isIPad: Bool
    
    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title3 : .body)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 36 : 30, height: isIPad ? 36 : 30)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactControlButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool

    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .caption : .caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, isIPad ? 8 : 6)
            .padding(.horizontal, isIPad ? 12 : 8)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(isIPad ? 8 : 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}




// MARK: - On Bench Message
struct OnBenchMessage: View {
    let isIPad: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            LottieView(name: "bench-animation2")

            Text("Sahil is on the bench")
                .font(isIPad ? .title : .title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("Stats tracking is paused")
                .font(isIPad ? .title3 : .body)
                .foregroundColor(.secondary)
        }
        .padding(isIPad ? 32 : 24)
        .background(Color.white)
        .cornerRadius(isIPad ? 16 : 12)
    }
}


struct LiveGameWatchView: View {
    let liveGame: LiveGame
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var localClockTime: TimeInterval = 0
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Watch-only header
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                        
                        Text("WATCHING LIVE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    
                    Text("You're watching in real-time. Only admins can control the game.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                // Game info (read-only)
                FixedSynchronizedClockCard(
                    quarter: liveGame.quarter,
                    clockTime: localClockTime,
                    isGameRunning: liveGame.isRunning,
                    gameFormat: liveGame.gameFormat, // ADD THIS
                    isIPad: isIPad
                )
                
                // Score display (read-only)
                LiveScoreDisplayCard(
                    homeScore: liveGame.homeScore,
                    awayScore: liveGame.awayScore,
                    teamName: liveGame.teamName,
                    opponent: liveGame.opponent,
                    isIPad: isIPad
                )
                
                if !(liveGame.sahilOnBench ?? false) {
                    PlayerStatsSection(
                        game: .constant(Game(
                            teamName: liveGame.teamName,
                            opponent: liveGame.opponent,
                            myTeamScore: liveGame.homeScore,
                            opponentScore: liveGame.awayScore,
                            fg2m: liveGame.playerStats.fg2m,
                            fg2a: liveGame.playerStats.fg2a,
                            fg3m: liveGame.playerStats.fg3m,
                            fg3a: liveGame.playerStats.fg3a,
                            ftm: liveGame.playerStats.ftm,
                            fta: liveGame.playerStats.fta,
                            rebounds: liveGame.playerStats.rebounds,
                            assists: liveGame.playerStats.assists,
                            steals: liveGame.playerStats.steals,
                            blocks: liveGame.playerStats.blocks,
                            fouls: liveGame.playerStats.fouls,
                            turnovers: liveGame.playerStats.turnovers
                        )),
                        authService: authService,  // Viewers won't be able to edit
                        firebaseService: firebaseService,
                        isIPad: isIPad
                    )
                } else {
                    OnBenchMessage(isIPad: isIPad)
                }
            }
            .padding(isIPad ? 24 : 16)
        }
        .onAppear {
            // Set the initial clock time when the view appears
            localClockTime = liveGame.getCurrentClock()
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Update the local clock time continuously
            localClockTime = firebaseService.getCurrentLiveGame()?.getCurrentClock() ?? localClockTime
        }
    }
}


// MARK: - No Live Game View

/*
struct NoLiveGameView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // NEW: Add this to track where we came from
    @Environment(\.presentationMode) var presentationMode
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 32 : 24) {
            Spacer()
            
            // Icon and message
            VStack(spacing: isIPad ? 24 : 20) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: isIPad ? 100 : 80))
                    .foregroundColor(.orange.opacity(0.6))
                
                Text("No Live Game")
                    .font(isIPad ? .largeTitle : .title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("The live game has ended or is no longer available.")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: isIPad ? 20 : 16) {
                // FIXED: Back to Dashboard button - dismiss ALL presented views
                Button("Back to Dashboard") {
                    // Dismiss all the way back to root
                    dismissToRoot()
                }
                .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
            }
            .padding(.horizontal, isIPad ? 40 : 24)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - NEW: Helper to dismiss all presented views
    private func dismissToRoot() {
        // Get the key window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            // Fallback to simple dismiss
            dismiss()
            return
        }
        
        // Dismiss all presented view controllers
        var currentVC = rootViewController
        while let presented = currentVC.presentedViewController {
            currentVC = presented
        }
        
        // Dismiss from the topmost presented view controller
        currentVC.dismiss(animated: true)
    }
}
 */
struct NoLiveGameView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.presentationMode) var presentationMode
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)
            .ignoresSafeArea()
            
            VStack(spacing: isIPad ? 40 : 32) {
                Spacer()
                
                // UPDATED: Lottie animation instead of static icon
                LottieView(name: "no-game-animation")
                    .frame(width: isIPad ? 300 : 200, height: isIPad ? 300 : 200)
                
                // Icon and message
                VStack(spacing: isIPad ? 24 : 20) {
                    Text("No Live Game")
                        .font(isIPad ? .largeTitle : .title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("The live game has ended or is no longer available.")
                        .font(isIPad ? .title3 : .body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: isIPad ? 20 : 16) {
                    Button("Back to Dashboard") {
                        dismissToRoot()
                    }
                    .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
                }
                .padding(.horizontal, isIPad ? 40 : 24)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Helper to dismiss all presented views
    private func dismissToRoot() {
        // Get the key window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            // Fallback to simple dismiss
            dismiss()
            return
        }
        
        // Dismiss all presented view controllers
        var currentVC = rootViewController
        while let presented = currentVC.presentedViewController {
            currentVC = presented
        }
        
        // Dismiss from the topmost presented view controller
        currentVC.dismiss(animated: true)
    }
}


struct PlayingTimeCard: View {
    let liveGame: LiveGame
    let isIPad: Bool
    
    // Calculate current segment duration if active
    private var currentSegmentDuration: Double {
        guard let current = liveGame.currentTimeSegment, current.endTime == nil else { return 0 }
        return Date().timeIntervalSince(current.startTime) / 60.0
    }
    
    // Use the computed properties from LiveGame that include active segments
    private var totalPlayingTime: Double {
        return liveGame.totalPlayingTime // This now includes active segment time!
    }
    
    private var totalBenchTime: Double {
        return liveGame.totalBenchTime // This now includes active segment time!
    }
    
    private var totalTime: Double {
        return totalPlayingTime + totalBenchTime
    }
    
    private var playingPercentage: Double {
        totalTime > 0 ? (totalPlayingTime / totalTime) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("Playing Time")
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: isIPad ? 20 : 16) {
                TimeStatItem(
                    title: "On Court",
                    time: totalPlayingTime,
                    color: .green,
                    isIPad: isIPad
                )
                
                TimeStatItem(
                    title: "On Bench",
                    time: totalBenchTime,
                    color: .orange,
                    isIPad: isIPad
                )
            }
            
            // Playing time percentage bar
            if totalTime > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Court Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(playingPercentage))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * (playingPercentage / 100), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            
            // Optional: Show active segment info
            if let current = liveGame.currentTimeSegment, current.endTime == nil {
                HStack {
                    Circle()
                        .fill(current.isOnCourt ? .green : .orange)
                        .frame(width: 6, height: 6)
                    
                    Text("Currently \(current.isOnCourt ? "on court" : "on bench") • \(String(format: "%.1f", currentSegmentDuration))m")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct TimeStatItem: View {
    let title: String
    let time: Double
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Text(formatTime(time))
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatTime(_ minutes: Double) -> String {
        if minutes < 1.0 {
            // Show seconds for values under 1 minute
            let seconds = Int(minutes * 60)
            return "\(seconds)s"
        } else {
            let totalMinutes = Int(minutes)
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            
            if hours > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(mins)m"
            }
        }
    }
}


// MARK: - Fixed Synchronized Clock Card

struct FixedSynchronizedClockCard: View {
    let quarter: Int
    let clockTime: TimeInterval
    let isGameRunning: Bool
    let gameFormat: GameFormat // NEW: Add game format
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text(formatPeriodWithOrdinal(quarter, gameFormat: gameFormat)) // "1st Quarter" or "1st Half"
                .font(isIPad ? .title2 : .headline)
                .foregroundColor(.secondary)
            
            Text(formatClockTime(clockTime))
                .font(isIPad ? .system(size: 48, weight: .bold) : .largeTitle)
                .fontWeight(.bold)
                .foregroundColor(isGameRunning ? .red : .primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    private func formatClockTime(_ time: TimeInterval) -> String {
        if time <= 59 {
            return String(format: "%.1f", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatPeriodWithOrdinal(_ quarter: Int, gameFormat: GameFormat) -> String {
        let periodName = gameFormat == .halves ? "Half" : "Quarter"
        return "\(quarter)\(getOrdinalSuffix(quarter)) \(periodName)"
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

// MARK: - Live Score Display Card (Read-only)

struct LiveScoreDisplayCard: View {
    let homeScore: Int
    let awayScore: Int
    let teamName: String
    let opponent: String
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            //Text("Live Score")
            //    .font(isIPad ? .title2 : .headline)
             //   .fontWeight(.bold)
            
            HStack(spacing: isIPad ? 40 : 30) {
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(teamName)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(homeScore)")
                        .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .frame(minWidth: isIPad ? 80 : 60)
                }
                
                Text("–")
                    .font(isIPad ? .largeTitle : .title)
                    .foregroundColor(.secondary)
                
                VStack(spacing: isIPad ? 12 : 8) {
                    Text(opponent)
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(awayScore)")
                        .font(isIPad ? .system(size: 40, weight: .bold) : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(minWidth: isIPad ? 80 : 60)
                }
            }
        }
        .padding(isIPad ? 28 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Player Status Card

// MARK: - FIXED Player Status Card - Controller Only

// MARK: - Interactive Player Status Card (Controller Only)

struct PlayerStatusCard: View {
    @Binding var sahilOnBench: Bool
    let isIPad: Bool
    let hasControl: Bool // NEW: Add control check
    let onStatusChange: () -> Void
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            
            //Spacer()
            
            if hasControl {
                // INTERACTIVE: Only show buttons if user has control
                HStack(spacing: isIPad ? 8 : 6) {
                    // --- REPLACEMENT FOR "Court" BUTTON ---
                    Button(action: {
                        sahilOnBench = false
                        onStatusChange()
                    }) {
                        Image(systemName: "figure.basketball") // <-- Icon instead of text
                    }
                    .buttonStyle(CompactStatusButtonStyle(isSelected: !sahilOnBench, isIPad: isIPad))
                    
                    // --- REPLACEMENT FOR "Bench" BUTTON ---
                    Button(action: {
                        sahilOnBench = true
                        onStatusChange()
                    }) {
                        Image(systemName: "pause.circle") // <-- Icon instead of text
                    }
                    .buttonStyle(CompactStatusButtonStyle(isSelected: sahilOnBench, isIPad: isIPad))
                }
            } else {
                // READ-ONLY: Just show the current status
                Text(sahilOnBench ? "On The Bench" : "On The Court")
                    .font(isIPad ? .body : .subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(sahilOnBench ? .orange : .green)
                    .padding(.horizontal, isIPad ? 12 : 10)
                    .padding(.vertical, isIPad ? 6 : 5)
                    .background((sahilOnBench ? Color.orange : Color.green).opacity(0.1))
                    .cornerRadius(isIPad ? 8 : 6)
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 10)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

struct PlayerStatusDisplayCard: View {
    let sahilOnBench: Bool
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            
            //Spacer()
            
            // READ-ONLY status display
            Text(sahilOnBench ? "On Bench" : "On Court")
                .font(isIPad ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(sahilOnBench ? .orange : .green)
                .padding(.horizontal, isIPad ? 12 : 10)
                .padding(.vertical, isIPad ? 6 : 5)
                .background((sahilOnBench ? Color.orange : Color.green).opacity(0.1))
                .cornerRadius(isIPad ? 8 : 6)
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 10)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 12 : 8)
    }
}



// MARK: - Live Stats Display Card

struct LiveStatsDisplayCard: View {
    let stats: PlayerStats
    let isIPad: Bool
    let isReadOnly: Bool
    
    init(stats: PlayerStats, isIPad: Bool = false, isReadOnly: Bool = false) {
        self.stats = stats
        self.isIPad = isIPad
        self.isReadOnly = isReadOnly
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            Text(isReadOnly ? "Current Stats" : "Live Stats")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: isIPad ? 16 : 12) {
                LiveStatDisplayCard(title: "PTS", value: stats.points, color: .purple, isIPad: isIPad)
                LiveStatDisplayCard(title: "REB", value: stats.rebounds, color: .mint, isIPad: isIPad)
                LiveStatDisplayCard(title: "AST", value: stats.assists, color: .cyan, isIPad: isIPad)
                LiveStatDisplayCard(title: "STL", value: stats.steals, color: .yellow, isIPad: isIPad)
                LiveStatDisplayCard(title: "BLK", value: stats.blocks, color: .red, isIPad: isIPad)
                LiveStatDisplayCard(title: "TO", value: stats.turnovers, color: .pink, isIPad: isIPad)
            }
            
            // Shooting percentages
            if stats.fg2a > 0 || stats.fg3a > 0 || stats.fta > 0 {
                Divider()
                
                HStack(spacing: isIPad ? 24 : 20) {
                    if stats.fg2a > 0 {
                        ShootingStatCard(
                            title: "FG%",
                            made: stats.fg2m + stats.fg3m,
                            attempted: stats.fg2a + stats.fg3a,
                            isIPad: isIPad
                        )
                    }
                    
                    if stats.fg3a > 0 {
                        ShootingStatCard(
                            title: "3P%",
                            made: stats.fg3m,
                            attempted: stats.fg3a,
                            isIPad: isIPad
                        )
                    }
                    
                    if stats.fta > 0 {
                        ShootingStatCard(
                            title: "FT%",
                            made: stats.ftm,
                            attempted: stats.fta,
                            isIPad: isIPad
                        )
                    }
                }
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct LiveStatDisplayCard: View {
    let title: String
    let value: Int
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text("\(value)")
                .font(isIPad ? .title : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, isIPad ? 16 : 12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

struct ShootingStatCard: View {
    let title: String
    let made: Int
    let attempted: Int
    let isIPad: Bool
    
    private var percentage: Double {
        return attempted > 0 ? Double(made) / Double(attempted) : 0.0
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(percentage * 100))%")
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("\(made)/\(attempted)")
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, isIPad ? 12 : 8)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(isIPad ? 8 : 6)
    }
}

// MARK: - Enhanced Points Summary for Live Games
struct EnhancedLivePointsSummaryCard: View {
    let stats: PlayerStats
    let teamScore: Int
    let isIPad: Bool
    
    private var sahilPoints: Int {
        return (stats.fg2m * 2) + (stats.fg3m * 3) + stats.ftm
    }
    
    private var sahilContribution: Double {
        return teamScore > 0 ? Double(sahilPoints) / Double(teamScore) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            // Header with live indicators
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    
                    Text("Live Points")
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sahilPoints) / \(teamScore)")
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    if sahilContribution > 0 {
                        Text("\(Int(sahilContribution))% of team")
                            .font(isIPad ? .caption : .caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Points breakdown
            HStack(spacing: isIPad ? 24 : 20) {
                LivePointBreakdownItem(
                    title: "2PT",
                    made: stats.fg2m,
                    points: stats.fg2m * 2,
                    color: .blue,
                    isIPad: isIPad
                )
                
                LivePointBreakdownItem(
                    title: "3PT",
                    made: stats.fg3m,
                    points: stats.fg3m * 3,
                    color: .green,
                    isIPad: isIPad
                )
                
                LivePointBreakdownItem(
                    title: "FT",
                    made: stats.ftm,
                    points: stats.ftm,
                    color: .orange,
                    isIPad: isIPad
                )
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.red.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
        )
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: SmartShootingStatCard

struct SmartShootingStatCard: View {
    let title: String
    let shotType: ShotType
    @Binding var made: Int
    @Binding var attempted: Int
    var liveScore: Binding<Int>? = nil // Optional live score binding for live games
    let isIPad: Bool
    let onStatChange: () -> Void
    
    enum ShotType {
        case twoPoint
        case threePoint
        case freeThrow
        
        var pointValue: Int {
            switch self {
            case .twoPoint: return 2
            case .threePoint: return 3
            case .freeThrow: return 1
            }
        }
        
        var madeTitle: String {
            switch self {
            case .twoPoint: return "2PT Made"
            case .threePoint: return "3PT Made"
            case .freeThrow: return "FT Made"
            }
        }
        
        var attemptedTitle: String {
            switch self {
            case .twoPoint: return "2PT Att"
            case .threePoint: return "3PT Att"
            case .freeThrow: return "FT Att"
            }
        }
        
        var shotEmoji: String {
            switch self {
            case .twoPoint: return "🏀"
            case .threePoint: return "🎯"
            case .freeThrow: return "🎪"
            }
        }
    }
    
    // Computed property to check if this is a live game
    private var isLiveGame: Bool {
        liveScore != nil
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 12) {
            // Clean header - just the title
            Text(title)
                .font(isIPad ? .title3 : .subheadline)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
            
            // Made shots section
            VStack(spacing: isIPad ? 12 : 8) {
                Text(shotType.madeTitle)
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                HStack(spacing: isIPad ? 16 : 12) {
                    Button("-") {
                        decrementMade()
                    }
                    .buttonStyle(LiveStatButtonStyle(color: .red, isIPad: isIPad))
                    .disabled(made <= 0)
                    
                    Text("\(made)")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                        .frame(minWidth: isIPad ? 40 : 35)
                        .foregroundColor(.primary)
                    
                    Button("+") {
                        incrementMade()
                    }
                    .buttonStyle(LiveStatButtonStyle(color: .green, isIPad: isIPad))
                }
            }
            
            // Attempted shots section
            VStack(spacing: isIPad ? 12 : 8) {
                Text(shotType.attemptedTitle)
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                HStack(spacing: isIPad ? 16 : 12) {
                    Button("-") {
                        decrementAttempted()
                    }
                    .buttonStyle(LiveStatButtonStyle(color: .red, isIPad: isIPad))
                    .disabled(attempted <= made)
                    
                    Text("\(attempted)")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                        .frame(minWidth: isIPad ? 40 : 35)
                        .foregroundColor(.primary)
                    
                    Button("+") {
                        incrementAttempted()
                    }
                    .buttonStyle(LiveStatButtonStyle(color: .orange, isIPad: isIPad))
                }
            }
            
            // Clean bottom section - just percentage and points
            HStack {
                if attempted > 0 {
                    let percentage = Double(made) / Double(attempted) * 100
                    Text("\(Int(percentage))%")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if made > 0 {
                    let totalPoints = made * shotType.pointValue
                    Text("\(totalPoints) pts")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(shotType == .twoPoint ? .blue : (shotType == .threePoint ? .green : .orange))
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
    
    // MARK: - Enhanced Smart Logic Methods with Live Score Integration
    
    private func incrementMade() {
        // When making a shot in a live game:
        // 1. Increment both made and attempted
        // 2. Add points to live score
        made += 1
        attempted += 1
        
        // Add points to live score if this is a live game
        if let liveScoreBinding = liveScore {
            liveScoreBinding.wrappedValue += shotType.pointValue
        }
        
        onStatChange()
    }
    
    private func decrementMade() {
        // When removing a made shot:
        // 1. Decrement made
        // 2. Subtract points from live score (if live game)
        if made > 0 {
            made -= 1
            
            // Subtract points from live score if this is a live game
            if let liveScoreBinding = liveScore {
                liveScoreBinding.wrappedValue = max(0, liveScoreBinding.wrappedValue - shotType.pointValue)
            }
            
            onStatChange()
        }
    }
    
    private func incrementAttempted() {
        // When adding a missed shot: increment only attempted
        // No score change since it's a miss
        attempted += 1
        onStatChange()
    }
    
    private func decrementAttempted() {
        // When removing an attempt: decrement attempted (but not below made)
        // No score change since we're just removing a miss
        if attempted > made {
            attempted -= 1
            onStatChange()
        }
    }
}


// MARK: - Points Summary Card

struct PointsSummaryCard: View {
    let gameStats: GameStatsData
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            HStack {
                Text("Points Breakdown")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Spacer()
                // Use calculated points instead of binding
                Text("\(gameStats.calculatedPoints) Total")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            
            HStack(spacing: isIPad ? 24 : 20) {
                PointBreakdownItem(
                    title: "2PT",
                    made: gameStats.playerStats.fg2m,
                    points: gameStats.playerStats.fg2m * 2,
                    color: .blue,
                    isIPad: isIPad
                )
                
                PointBreakdownItem(
                    title: "3PT",
                    made: gameStats.playerStats.fg3m,
                    points: gameStats.playerStats.fg3m * 3,
                    color: .green,
                    isIPad: isIPad
                )
                
                PointBreakdownItem(
                    title: "FT",
                    made: gameStats.playerStats.ftm,
                    points: gameStats.playerStats.ftm,
                    color: .orange,
                    isIPad: isIPad
                )
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct PointBreakdownItem: View {
    let title: String
    let made: Int
    let points: Int
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            Text(title)
                .font(isIPad ? .body : .caption)
                .foregroundColor(color)
                .fontWeight(.medium)
            
            Text("\(made) × \(title == "3PT" ? 3 : (title == "2PT" ? 2 : 1))")
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
            
            Text("\(points)")
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(color.opacity(0.1))
        .cornerRadius(isIPad ? 12 : 8)
    }
}

// MARK: Regular Stat Card
struct RegularStatCard: View {
    let title: String
    @Binding var value: Int
    let min: Int
    let max: Int?
    let isIPad: Bool
    let onStatChange: () -> Void
    
    init(title: String, value: Binding<Int>, min: Int = 0, max: Int? = nil, isIPad: Bool, onStatChange: @escaping () -> Void) {
        self.title = title
        self._value = value
        self.min = min
        self.max = max
        self.isIPad = isIPad
        self.onStatChange = onStatChange
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 10) {
            Text(title)
                .font(isIPad ? .title3 : .subheadline)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            HStack(spacing: isIPad ? 16 : 12) {
                Button("-") {
                    if value > min {
                        value -= 1
                        onStatChange()
                    }
                }
                .buttonStyle(CleanStatButtonStyle(color: .red, isIPad: isIPad))
                .disabled(value <= min)
                
                Text("\(value)")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .frame(minWidth: isIPad ? 40 : 35)
                    .foregroundColor(.primary)
                
                Button("+") {
                    if let max = max, value >= max {
                        // Don't increment if at max
                    } else {
                        value += 1
                        onStatChange()
                    }
                }
                .buttonStyle(CleanStatButtonStyle(color: .green, isIPad: isIPad))
                .disabled(max != nil && value >= max!)
            }
        }
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Clean Stat Card for Detailed Stats Entry

struct CleanStatCard: View {
    let title: String
    @Binding var value: Int
    let min: Int
    let max: Int?
    let isIPad: Bool
    let onStatChange: () -> Void
    
    init(title: String, value: Binding<Int>, min: Int = 0, max: Int? = nil, isIPad: Bool, onStatChange: @escaping () -> Void) {
        self.title = title
        self._value = value
        self.min = min
        self.max = max
        self.isIPad = isIPad
        self.onStatChange = onStatChange
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 10) {
            Text(title)
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            HStack(spacing: isIPad ? 16 : 12) {
                Button("-") {
                    if value > min {
                        value -= 1
                        onStatChange()
                    }
                }
                .buttonStyle(CleanStatButtonStyle(color: .red, isIPad: isIPad))
                .disabled(value <= min)
                
                Text("\(value)")
                    .font(isIPad ? .title2 : .title3)
                    .fontWeight(.bold)
                    .frame(minWidth: isIPad ? 40 : 35)
                    .foregroundColor(.primary)
                
                Button("+") {
                    if let max = max, value >= max {
                        // Don't increment if at max
                    } else {
                        value += 1
                        onStatChange()
                    }
                }
                .buttonStyle(CleanStatButtonStyle(color: .green, isIPad: isIPad))
                .disabled(max != nil && value >= max!)
            }
        }
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct CleanStatButtonStyle: ButtonStyle {
    let color: Color
    let isIPad: Bool

    init(color: Color, isIPad: Bool = false) {
        self.color = color
        self.isIPad = isIPad
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isIPad ? .title2 : .title3)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: isIPad ? 44 : 36, height: isIPad ? 44 : 36)
            .background(color)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
