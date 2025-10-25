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
    let quarter: Int
    let clockTime: String
    let gameFormat: GameFormat
    let isRecording: Bool
    let recordingDuration: String
    let homeLogoURL: String? // Optional team logo
    let awayLogoURL: String? // Optional opponent logo
    
    // Create from LiveGame - Fixed initializer
    init(from liveGame: LiveGame, isRecording: Bool = false, recordingDuration: String = "00:00", homeLogoURL: String? = nil, awayLogoURL: String? = nil) {
        self.homeTeam = liveGame.teamName
        self.awayTeam = liveGame.opponent
        self.homeScore = liveGame.homeScore
        self.awayScore = liveGame.awayScore
        self.quarter = liveGame.quarter
        self.clockTime = liveGame.currentClockDisplay
        self.gameFormat = liveGame.gameFormat
        self.isRecording = isRecording
        self.recordingDuration = recordingDuration
        self.homeLogoURL = homeLogoURL
        self.awayLogoURL = awayLogoURL
    }

    // Manual initializer for custom data
    init(homeTeam: String, awayTeam: String, homeScore: Int, awayScore: Int, quarter: Int, clockTime: String, gameFormat: GameFormat = .halves, isRecording: Bool = false, recordingDuration: String = "00:00", homeLogoURL: String? = nil, awayLogoURL: String? = nil) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.quarter = quarter
        self.clockTime = clockTime
        self.gameFormat = gameFormat
        self.isRecording = isRecording
        self.recordingDuration = recordingDuration
        self.homeLogoURL = homeLogoURL
        self.awayLogoURL = awayLogoURL
    }
    
    // Default/empty state
    static var empty: SimpleScoreOverlayData {
        SimpleScoreOverlayData(
            homeTeam: "HOME",
            awayTeam: "AWAY",
            homeScore: 0,
            awayScore: 0,
            quarter: 1,
            clockTime: "20:00",
            gameFormat: .halves,
            isRecording: false,
            recordingDuration: "00:00"
        )
    }
}
