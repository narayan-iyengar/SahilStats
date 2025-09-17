// File: SahilStats/Models/Game.swift

import Foundation
import FirebaseFirestore

// MARK: - Game Model

struct Game: Identifiable, Codable {
    @DocumentID var id: String?
    var teamName: String
    var opponent: String
    var location: String?
    var timestamp: Date
    var gameFormat: GameFormat
    var periodLength: Int
    var numPeriods: Int
    var status: GameStatus
    
    // Scores
    var myTeamScore: Int
    var opponentScore: Int
    var outcome: GameOutcome
    
    // Player Stats
    var points: Int
    var fg2m: Int
    var fg2a: Int
    var fg3m: Int
    var fg3a: Int
    var ftm: Int
    var fta: Int
    var rebounds: Int
    var assists: Int
    var steals: Int
    var blocks: Int
    var fouls: Int
    var turnovers: Int
    
    // Metadata
    var createdAt: Date
    var adminName: String?
    var editedAt: Date?
    var editedBy: String?
    var photos: [GamePhoto]?
    var achievements: [Achievement]
    
    // Computed properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var fieldGoalPercentage: Double {
        let totalMade = fg2m + fg3m
        let totalAttempted = fg2a + fg3a
        return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) : 0.0
    }
    
    var freeThrowPercentage: Double {
        return fta > 0 ? Double(ftm) / Double(fta) : 0.0
    }
    
    var twoPointPercentage: Double {
        return fg2a > 0 ? Double(fg2m) / Double(fg2a) : 0.0
    }
    
    var threePointPercentage: Double {
        return fg3a > 0 ? Double(fg3m) / Double(fg3a) : 0.0
    }
    
    var assistTurnoverRatio: Double {
        return turnovers > 0 ? Double(assists) / Double(turnovers) : Double(assists)
    }
    
    init(teamName: String, opponent: String, location: String? = nil, timestamp: Date = Date(), gameFormat: GameFormat = .halves, periodLength: Int = 20, myTeamScore: Int = 0, opponentScore: Int = 0, fg2m: Int = 0, fg2a: Int = 0, fg3m: Int = 0, fg3a: Int = 0, ftm: Int = 0, fta: Int = 0, rebounds: Int = 0, assists: Int = 0, steals: Int = 0, blocks: Int = 0, fouls: Int = 0, turnovers: Int = 0, adminName: String? = nil) {
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.timestamp = timestamp
        self.gameFormat = gameFormat
        self.periodLength = periodLength
        self.numPeriods = gameFormat == .halves ? 2 : 4
        self.status = .final
        self.myTeamScore = myTeamScore
        self.opponentScore = opponentScore
        
        // Calculate outcome
        if myTeamScore > opponentScore {
            self.outcome = .win
        } else if myTeamScore < opponentScore {
            self.outcome = .loss
        } else {
            self.outcome = .tie
        }
        
        // Calculate points from shooting stats
        self.points = (fg2m * 2) + (fg3m * 3) + ftm
        
        self.fg2m = fg2m
        self.fg2a = fg2a
        self.fg3m = fg3m
        self.fg3a = fg3a
        self.ftm = ftm
        self.fta = fta
        self.rebounds = rebounds
        self.assists = assists
        self.steals = steals
        self.blocks = blocks
        self.fouls = fouls
        self.turnovers = turnovers
        
        self.createdAt = Date()
        self.adminName = adminName
        self.editedAt = nil
        self.editedBy = nil
        self.photos = nil
        self.achievements = Achievement.getEarnedAchievements(for: self)
    }
}

// MARK: - Live Game Model

struct LiveGame: Identifiable, Codable {
    @DocumentID var id: String?
    var teamName: String
    var opponent: String
    var location: String?
    var gameFormat: GameFormat
    var periodLength: Int
    var numPeriods: Int
    
    // Live game state
    var isRunning: Bool
    var period: Int
    var clock: Int // seconds remaining
    var clockStartTime: Date?
    var clockAtStart: Int?
    
    // Current scores
    var homeScore: Int
    var awayScore: Int
    
    // Player stats
    var playerStats: PlayerStats
    
    // Metadata
    var createdAt: Date
    var createdBy: String?
    var sahilOnBench: Bool?
    
    init(teamName: String, opponent: String, location: String? = nil, gameFormat: GameFormat = .halves, periodLength: Int = 20, createdBy: String? = nil) {
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.gameFormat = gameFormat
        self.periodLength = periodLength
        self.numPeriods = gameFormat == .halves ? 2 : 4
        self.isRunning = false
        self.period = 1
        self.clock = periodLength * 60
        self.clockStartTime = nil
        self.clockAtStart = nil
        self.homeScore = 0
        self.awayScore = 0
        self.playerStats = PlayerStats()
        self.createdAt = Date()
        self.createdBy = createdBy
        self.sahilOnBench = false
    }
}

// MARK: - Player Stats

struct PlayerStats: Codable {
    var fg2m: Int = 0
    var fg2a: Int = 0
    var fg3m: Int = 0
    var fg3a: Int = 0
    var ftm: Int = 0
    var fta: Int = 0
    var rebounds: Int = 0
    var assists: Int = 0
    var steals: Int = 0
    var blocks: Int = 0
    var fouls: Int = 0
    var turnovers: Int = 0
    
    var points: Int {
        return (fg2m * 2) + (fg3m * 3) + ftm
    }
}

// MARK: - Team Model

struct Team: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var createdAt: Date
    
    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Supporting Enums

enum GameFormat: String, Codable, CaseIterable {
    case halves = "halves"
    case periods = "periods"
    
    var displayName: String {
        switch self {
        case .halves: return "Halves"
        case .periods: return "Periods"
        }
    }
    
    var periodCount: Int {
        switch self {
        case .halves: return 2
        case .periods: return 4
        }
    }
    
    var periodName: String {
        switch self {
        case .halves: return "Half"
        case .periods: return "Period"
        }
    }
}

enum GameStatus: String, Codable {
    case live = "live"
    case final = "final"
}

enum GameOutcome: String, Codable, CaseIterable {
    case win = "W"
    case loss = "L"
    case tie = "T"
    
    var displayName: String {
        switch self {
        case .win: return "Win"
        case .loss: return "Loss"
        case .tie: return "Tie"
        }
    }
    
    var emoji: String {
        switch self {
        case .win: return "🏆"
        case .loss: return "💪"
        case .tie: return "🤝"
        }
    }
    
    var color: String {
        switch self {
        case .win: return "green"
        case .loss: return "red"
        case .tie: return "gray"
        }
    }
}

// MARK: - Game Photo

struct GamePhoto: Codable, Identifiable {
    var id: String
    var url: String
    var description: String
    var timestamp: Date
    var isICloudLink: Bool
    
    init(url: String, description: String = "Game photo") {
        self.id = UUID().uuidString
        self.url = url
        self.description = description
        self.timestamp = Date()
        self.isICloudLink = url.contains("icloud.com")
    }
}

// MARK: - Achievement

struct Achievement: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var description: String
    
    static let allAchievements: [Achievement] = [
        Achievement(id: "double_digits", name: "Double Digits", emoji: "🏀", description: "10+ points in a game"),
        Achievement(id: "big_game", name: "Big Game", emoji: "🔥", description: "20+ points in a game"),
        Achievement(id: "perfect_shooter", name: "Perfect Shooter", emoji: "💯", description: "100% shooting (3+ attempts)"),
        Achievement(id: "perfect_free_throws", name: "Perfect Free Throws", emoji: "🎯", description: "100% free throws (3+ attempts)"),
        Achievement(id: "sharpshooter", name: "Sharpshooter", emoji: "🎯", description: "3+ three-pointers made"),
        Achievement(id: "playmaker", name: "Playmaker", emoji: "🤝", description: "5+ assists in a game"),
        Achievement(id: "defender", name: "Defender", emoji: "🛡️", description: "3+ steals or blocks"),
        Achievement(id: "hustle", name: "Hustle", emoji: "💪", description: "10+ rebounds in a game"),
        Achievement(id: "triple_double", name: "Triple Double", emoji: "⭐", description: "10+ in three stat categories"),
        Achievement(id: "no_turnovers", name: "Clean Game", emoji: "✨", description: "Zero turnovers"),
        Achievement(id: "assist_machine", name: "Assist Machine", emoji: "🎪", description: "8+ assists in a game")
    ]
    
    static func getEarnedAchievements(for game: Game) -> [Achievement] {
        var earned: [Achievement] = []
        
        // Double Digits
        if game.points >= 10 {
            earned.append(allAchievements.first { $0.id == "double_digits" }!)
        }
        
        // Big Game
        if game.points >= 20 {
            earned.append(allAchievements.first { $0.id == "big_game" }!)
        }
        
        // Perfect Shooter
        let totalMade = game.fg2m + game.fg3m
        let totalAttempted = game.fg2a + game.fg3a
        if totalAttempted >= 3 && totalMade == totalAttempted {
            earned.append(allAchievements.first { $0.id == "perfect_shooter" }!)
        }
        
        // Perfect Free Throws
        if game.fta >= 3 && game.ftm == game.fta {
            earned.append(allAchievements.first { $0.id == "perfect_free_throws" }!)
        }
        
        // Sharpshooter
        if game.fg3m >= 3 {
            earned.append(allAchievements.first { $0.id == "sharpshooter" }!)
        }
        
        // Playmaker
        if game.assists >= 5 {
            earned.append(allAchievements.first { $0.id == "playmaker" }!)
        }
        
        // Defender
        if (game.steals + game.blocks) >= 3 {
            earned.append(allAchievements.first { $0.id == "defender" }!)
        }
        
        // Hustle
        if game.rebounds >= 10 {
            earned.append(allAchievements.first { $0.id == "hustle" }!)
        }
        
        // Triple Double
        let statValues = [game.points, game.rebounds, game.assists, game.steals, game.blocks]
        let doubleDigitStats = statValues.filter { $0 >= 10 }.count
        if doubleDigitStats >= 3 {
            earned.append(allAchievements.first { $0.id == "triple_double" }!)
        }
        
        // No Turnovers
        if game.turnovers == 0 {
            earned.append(allAchievements.first { $0.id == "no_turnovers" }!)
        }
        
        // Assist Machine
        if game.assists >= 8 {
            earned.append(allAchievements.first { $0.id == "assist_machine" }!)
        }
        
        return earned
    }
}
