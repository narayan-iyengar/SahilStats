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

// MARK: - COMPACT COMPONENTS FOR STICKY HEADER

// MARK: - Compact Device Control Status

struct CompactDeviceControlStatusCard: View {
    let hasControl: Bool
    let controllingUser: String?
    let canRequestControl: Bool
    let pendingRequest: String?
    let isIPad: Bool
    let onRequestControl: () -> Void
    
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
    let period: Int
    let clockTime: TimeInterval
    let isGameRunning: Bool
    let gameFormat: GameFormat // NEW: Add game format
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            // Period/Half with correct label
            VStack(spacing: 2) {
                Text(gameFormat.periodName) // "Period" or "Half"
                    .font(isIPad ? .caption : .caption2)
                    .foregroundColor(.secondary)
                Text("\(period)")
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
        .background(Color(.systemGray6))
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
            Text("Live Score")
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
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
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .stroke(Color.orange.opacity(0.4), lineWidth: 2)
        )
        .cornerRadius(isIPad ? 20 : 16)
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
            Text("Live Score")
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
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
        .background(Color(.systemGray6))
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
    let currentPeriod: Int
    let maxPeriods: Int
    let gameFormat: GameFormat
    let isGameRunning: Bool
    let isIPad: Bool
    let onStartPause: () -> Void
    let onAddMinute: () -> Void
    let onAdvancePeriod: () -> Void
    let onFinishGame: () -> Void
    
    private var startPauseText: String {
        isGameRunning ? "Pause" : "Start"
    }
    
    private var startPauseColor: Color {
        isGameRunning ? .orange : .green
    }
    
    private var advancePeriodText: String {
        if currentPeriod < maxPeriods {
            return "End \(gameFormat.periodName)" // "End Period" or "End Half"
        } else {
            return "End Game"
        }
    }
    
    private var advancePeriodColor: Color {
        currentPeriod < maxPeriods ? .blue : .red
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
                
                Button(advancePeriodText) {
                    if currentPeriod < maxPeriods {
                        onAdvancePeriod()
                    } else {
                        onFinishGame()
                    }
                }
                .buttonStyle(BiggerCompactControlButtonStyle(color: advancePeriodColor, isIPad: isIPad))
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(Color(.systemGray6))
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

struct LiveGameWatchView: View {
    let liveGame: LiveGame
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
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
                    period: liveGame.period,
                    clockTime: liveGame.getCurrentClock(),
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
                
                // Stats display (read-only)
                if !(liveGame.sahilOnBench ?? false) {
                    LiveStatsDisplayCard(
                        stats: liveGame.playerStats,
                        isIPad: isIPad,
                        isReadOnly: true
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.basketball")
                            .font(.system(size: isIPad ? 80 : 60))
                            .foregroundColor(.secondary)
                        
                        Text("Sahil is on the bench")
                            .font(isIPad ? .title : .title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Stats tracking is paused")
                            .font(isIPad ? .title3 : .body)
                            .foregroundColor(.secondary)
                    }
                    .padding(isIPad ? 32 : 24)
                    .background(Color(.systemGray6))
                    .cornerRadius(isIPad ? 16 : 12)
                }
            }
            .padding(isIPad ? 24 : 16)
        }
    }
}

// MARK: - No Live Game View

struct NoLiveGameView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
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
                
                Text("There's no live game currently in progress.")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: isIPad ? 20 : 16) {
                if authService.showAdminFeatures {
                    NavigationLink("Start New Live Game") {
                        GameSetupView()
                    }
                    .buttonStyle(CustomPrimaryButtonStyle(isIPad: isIPad))
                }
                
                // Back to Dashboard button
                Button("Back to Dashboard") {
                    dismiss()
                }
                .buttonStyle(CustomSecondaryButtonStyle(isIPad: isIPad))
            }
            .padding(.horizontal, isIPad ? 40 : 24)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Fixed Synchronized Clock Card

struct FixedSynchronizedClockCard: View {
    let period: Int
    let clockTime: TimeInterval
    let isGameRunning: Bool
    let gameFormat: GameFormat // NEW: Add game format
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("\(gameFormat.periodName) \(period)") // "Period 1" or "Half 1"
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
            Text("Live Score")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
            
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
            Text("Sahil:")
                .font(isIPad ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if hasControl {
                // INTERACTIVE: Only show buttons if user has control
                HStack(spacing: isIPad ? 8 : 6) {
                    Button("Court") {
                        sahilOnBench = false
                        onStatusChange()
                    }
                    .buttonStyle(CompactStatusButtonStyle(isSelected: !sahilOnBench, isIPad: isIPad))
                    
                    Button("Bench") {
                        sahilOnBench = true
                        onStatusChange()
                    }
                    .buttonStyle(CompactStatusButtonStyle(isSelected: sahilOnBench, isIPad: isIPad))
                }
            } else {
                // READ-ONLY: Just show the current status
                Text(sahilOnBench ? "On Bench" : "On Court")
                    .font(isIPad ? .body : .subheadline)
                    .fontWeight(.medium)
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
            Text("Sahil:")
                .font(isIPad ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
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
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
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
