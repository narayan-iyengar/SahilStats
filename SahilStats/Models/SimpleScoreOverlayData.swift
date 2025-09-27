// SimpleScoreOverlayData.swift - Fixed version

import Foundation
import Combine
import SwiftUI

// Simple data structure to hold score overlay information
struct SimpleScoreOverlayData {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    let period: Int
    let clockTime: String
    let isRecording: Bool
    let recordingDuration: String
    
    // Create from LiveGame - Fixed initializer
    init(from liveGame: LiveGame, isRecording: Bool = false, recordingDuration: String = "00:00") {
        self.homeTeam = liveGame.teamName
        self.awayTeam = liveGame.opponent
        self.homeScore = liveGame.homeScore
        self.awayScore = liveGame.awayScore
        self.period = liveGame.period
        self.clockTime = liveGame.currentClockDisplay
        self.isRecording = isRecording
        self.recordingDuration = recordingDuration
    }
    
    // Manual initializer for custom data
    init(homeTeam: String, awayTeam: String, homeScore: Int, awayScore: Int, period: Int, clockTime: String, isRecording: Bool = false, recordingDuration: String = "00:00") {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.period = period
        self.clockTime = clockTime
        self.isRecording = isRecording
        self.recordingDuration = recordingDuration
    }
    
    // Default/empty state
    static var empty: SimpleScoreOverlayData {
        SimpleScoreOverlayData(
            homeTeam: "HOME",
            awayTeam: "AWAY",
            homeScore: 0,
            awayScore: 0,
            period: 1,
            clockTime: "20:00",
            isRecording: false,
            recordingDuration: "00:00"
        )
    }
}
