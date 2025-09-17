//
//  LiveGame.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/17/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Live Game Model (Firebase Compatible)
struct LiveGame: Identifiable, Codable {
    let id: String
    let teamName: String
    let opponent: String
    let location: String?
    
    // Real-time scores
    var homeScore: Int
    var awayScore: Int
    
    // Game state
    var period: Int
    var clock: TimeInterval
    var isRunning: Bool
    var clockStartTime: Date?
    var clockAtStart: TimeInterval
    
    // Settings
    let gameFormat: GameFormat
    let periodLength: Int
    
    var numPeriods: Int {
        gameFormat == .halves ? 2 : 4
    }
    
    var maxPeriod: Int {
        numPeriods
    }
    
    var periodName: String {
        gameFormat == .halves ? "Half" : "Period"
    }
    
    // Player stats (real-time)
    var playerStats: PlayerStats
    var sahilOnBench: Bool
    
    // Metadata
    let createdBy: String?
    let createdAt: Date
    
    enum GameFormat: String, CaseIterable, Codable {
        case halves = "halves"
        case periods = "periods"
        
        var displayName: String {
            switch self {
            case .halves: return "2 Halves"
            case .periods: return "4 Periods"
            }
        }
    }
    
    // Game state computed properties
    var isGameOver: Bool {
        period >= maxPeriod && clock <= 0 && !isRunning
    }
    
    var currentClockDisplay: String {
        if clock <= 59 {
            // Show tenths for under 1 minute
            return String(format: "%.1f", clock)
        } else {
            // Show MM:SS for over 1 minute
            let minutes = Int(clock) / 60
            let seconds = Int(clock) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Initializer for creating new live games
    init(teamName: String, opponent: String, location: String? = nil, gameFormat: GameFormat = .halves, periodLength: Int = 20) {
        self.id = UUID().uuidString
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.homeScore = 0
        self.awayScore = 0
        self.period = 1
        self.clock = TimeInterval(periodLength * 60)
        self.isRunning = false
        self.clockStartTime = nil
        self.clockAtStart = TimeInterval(periodLength * 60)
        self.gameFormat = gameFormat
        self.periodLength = periodLength
        self.playerStats = PlayerStats()
        self.sahilOnBench = false
        self.createdBy = nil
        self.createdAt = Date()
    }
    
    // Full initializer (used by FirebaseService)
    init(id: String, teamName: String, opponent: String, location: String?, homeScore: Int, awayScore: Int, period: Int, clock: TimeInterval, isRunning: Bool, clockStartTime: Date?, clockAtStart: TimeInterval, gameFormat: GameFormat, periodLength: Int, playerStats: PlayerStats, sahilOnBench: Bool, createdBy: String?, createdAt: Date) {
        self.id = id
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.period = period
        self.clock = clock
        self.isRunning = isRunning
        self.clockStartTime = clockStartTime
        self.clockAtStart = clockAtStart
        self.gameFormat = gameFormat
        self.periodLength = periodLength
        self.playerStats = playerStats
        self.sahilOnBench = sahilOnBench
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

// MARK: - Extensions for Firebase Compatibility
extension LiveGame {
    init(from document: QueryDocumentSnapshot) throws {
        let data = document.data()
        
        // Parse player stats
        let playerStatsData = data["playerStats"] as? [String: Any] ?? [:]
        let playerStats = PlayerStats(
            fg2m: playerStatsData["fg2m"] as? Int ?? 0,
            fg2a: playerStatsData["fg2a"] as? Int ?? 0,
            fg3m: playerStatsData["fg3m"] as? Int ?? 0,
            fg3a: playerStatsData["fg3a"] as? Int ?? 0,
            ftm: playerStatsData["ftm"] as? Int ?? 0,
            fta: playerStatsData["fta"] as? Int ?? 0,
            rebounds: playerStatsData["rebounds"] as? Int ?? 0,
            assists: playerStatsData["assists"] as? Int ?? 0,
            steals: playerStatsData["steals"] as? Int ?? 0,
            blocks: playerStatsData["blocks"] as? Int ?? 0,
            fouls: playerStatsData["fouls"] as? Int ?? 0,
            turnovers: playerStatsData["turnovers"] as? Int ?? 0
        )
        
        // Parse clock start time
        let clockStartTime: Date?
        if let timestamp = data["clockStartTime"] as? Double {
            clockStartTime = Date(timeIntervalSince1970: timestamp)
        } else {
            clockStartTime = nil
        }
        
        // Parse created date
        let createdAt: Date
        if let createdAtString = data["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        self.init(
            id: document.documentID,
            teamName: data["teamName"] as? String ?? "",
            opponent: data["opponent"] as? String ?? "",
            location: data["location"] as? String,
            homeScore: data["homeScore"] as? Int ?? 0,
            awayScore: data["awayScore"] as? Int ?? 0,
            period: data["period"] as? Int ?? 1,
            clock: data["clock"] as? TimeInterval ?? 600,
            isRunning: data["isRunning"] as? Bool ?? false,
            clockStartTime: clockStartTime,
            clockAtStart: data["clockAtStart"] as? TimeInterval ?? 600,
            gameFormat: LiveGame.GameFormat(rawValue: data["gameFormat"] as? String ?? "halves") ?? .halves,
            periodLength: data["periodLength"] as? Int ?? 20,
            playerStats: playerStats,
            sahilOnBench: data["sahilOnBench"] as? Bool ?? false,
            createdBy: data["createdBy"] as? String,
            createdAt: createdAt
        )
    }
}
