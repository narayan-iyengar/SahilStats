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
    
    // Custom coding keys for date handling
    enum CodingKeys: String, CodingKey {
        case teamName, opponent, location, timestamp, gameFormat, periodLength, numPeriods, status
        case myTeamScore, opponentScore, outcome
        case points, fg2m, fg2a, fg3m, fg3a, ftm, fta, rebounds, assists, steals, blocks, fouls, turnovers
        case createdAt, adminName, editedAt, editedBy, photos, achievements
    }
    
    // Custom decoder to handle different date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Basic properties
        teamName = try container.decode(String.self, forKey: .teamName)
        opponent = try container.decode(String.self, forKey: .opponent)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        
        // Handle timestamp - try different formats
        if let timestampData = try? container.decode(Timestamp.self, forKey: .timestamp) {
            timestamp = timestampData.dateValue()
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: timestampString) ?? Date()
        } else if let timestampDouble = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: timestampDouble)
        } else {
            timestamp = Date() // fallback
        }
        
        gameFormat = try container.decode(GameFormat.self, forKey: .gameFormat)
        
        // Handle periodLength - can be stored as string or int
        if let periodLengthInt = try? container.decode(Int.self, forKey: .periodLength) {
            periodLength = periodLengthInt
        } else if let periodLengthString = try? container.decode(String.self, forKey: .periodLength) {
            periodLength = Int(periodLengthString) ?? 20
        } else {
            periodLength = 20 // default fallback
        }
        
        // Handle numPeriods - can be stored as string or int
        if let numPeriodsInt = try? container.decode(Int.self, forKey: .numPeriods) {
            numPeriods = numPeriodsInt
        } else if let numPeriodsString = try? container.decode(String.self, forKey: .numPeriods) {
            numPeriods = Int(numPeriodsString) ?? (gameFormat == .halves ? 2 : 4)
        } else {
            numPeriods = gameFormat == .halves ? 2 : 4 // calculate from format
        }
        
        status = try container.decode(GameStatus.self, forKey: .status)
        
        // Handle scores - can be stored as string or int
        if let myTeamScoreInt = try? container.decode(Int.self, forKey: .myTeamScore) {
            myTeamScore = myTeamScoreInt
        } else if let myTeamScoreString = try? container.decode(String.self, forKey: .myTeamScore) {
            myTeamScore = Int(myTeamScoreString) ?? 0
        } else {
            myTeamScore = 0
        }
        
        if let opponentScoreInt = try? container.decode(Int.self, forKey: .opponentScore) {
            opponentScore = opponentScoreInt
        } else if let opponentScoreString = try? container.decode(String.self, forKey: .opponentScore) {
            opponentScore = Int(opponentScoreString) ?? 0
        } else {
            opponentScore = 0
        }
        
        outcome = try container.decode(GameOutcome.self, forKey: .outcome)
        
        // Handle all stat fields - can be stored as string or int
        // Helper function to decode Int from either String or Int
        func decodeIntFromStringOrInt(key: CodingKeys) -> Int {
            if let intValue = try? container.decode(Int.self, forKey: key) {
                return intValue
            } else if let stringValue = try? container.decode(String.self, forKey: key) {
                return Int(stringValue) ?? 0
            }
            return 0
        }
        
        points = decodeIntFromStringOrInt(key: .points)
        fg2m = decodeIntFromStringOrInt(key: .fg2m)
        fg2a = decodeIntFromStringOrInt(key: .fg2a)
        fg3m = decodeIntFromStringOrInt(key: .fg3m)
        fg3a = decodeIntFromStringOrInt(key: .fg3a)
        ftm = decodeIntFromStringOrInt(key: .ftm)
        fta = decodeIntFromStringOrInt(key: .fta)
        rebounds = decodeIntFromStringOrInt(key: .rebounds)
        assists = decodeIntFromStringOrInt(key: .assists)
        steals = decodeIntFromStringOrInt(key: .steals)
        blocks = decodeIntFromStringOrInt(key: .blocks)
        fouls = decodeIntFromStringOrInt(key: .fouls)
        turnovers = decodeIntFromStringOrInt(key: .turnovers)
        
        // Handle createdAt - try different formats
        if let createdAtData = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = createdAtData.dateValue()
        } else if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString) ?? Date()
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: createdAtDouble)
        } else {
            createdAt = Date() // fallback
        }
        
        // Optional metadata
        adminName = try container.decodeIfPresent(String.self, forKey: .adminName)
        
        // Handle editedAt - try different formats
        if let editedAtData = try? container.decodeIfPresent(Timestamp.self, forKey: .editedAt) {
            editedAt = editedAtData.dateValue()
        } else if let editedAtString = try? container.decodeIfPresent(String.self, forKey: .editedAt) {
            let formatter = ISO8601DateFormatter()
            editedAt = formatter.date(from: editedAtString)
        } else if let editedAtDouble = try? container.decodeIfPresent(Double.self, forKey: .editedAt) {
            editedAt = Date(timeIntervalSince1970: editedAtDouble)
        } else {
            editedAt = nil
        }
        
        editedBy = try container.decodeIfPresent(String.self, forKey: .editedBy)
        photos = try container.decodeIfPresent([GamePhoto].self, forKey: .photos)
        achievements = try container.decodeIfPresent([Achievement].self, forKey: .achievements) ?? []
    }
    
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
        
        // Initialize achievements as empty array first, then calculate after self is fully initialized
        self.achievements = []
        
        // Now that self is fully initialized, calculate achievements
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
    var clock: TimeInterval // Changed from Int to TimeInterval for better precision
    var clockStartTime: Date?
    var clockAtStart: TimeInterval?
    
    // Current scores
    var homeScore: Int
    var awayScore: Int
    
    // Player stats
    var playerStats: PlayerStats
    
    // Metadata
    @ServerTimestamp var createdAt: Date?
    var createdBy: String?
    var sahilOnBench: Bool?
    
    // Computed properties
    var isGameOver: Bool {
        period >= numPeriods && clock <= 0 && !isRunning
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
    
    var periodName: String {
        gameFormat == .halves ? "Half" : "Period"
    }
    
    init(teamName: String, opponent: String, location: String? = nil, gameFormat: GameFormat = .halves, periodLength: Int = 20, createdBy: String? = nil) {
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.gameFormat = gameFormat
        self.periodLength = periodLength
        self.numPeriods = gameFormat == .halves ? 2 : 4
        self.isRunning = false
        self.period = 1
        self.clock = TimeInterval(periodLength * 60)
        self.clockStartTime = nil
        self.clockAtStart = TimeInterval(periodLength * 60)
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
    
    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case name, createdAt
    }
    
    // Custom decoder to handle missing createdAt field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        
        // Handle missing createdAt field for older documents
        if let createdAtData = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = createdAtData.dateValue()
        } else if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString) ?? Date()
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: createdAtDouble)
        } else {
            // Fallback for older documents without createdAt
            createdAt = Date()
        }
    }
    
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
    
    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case id, url, description, timestamp, isICloudLink
    }
    
    // Custom decoder to handle different id types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id as either String or Number
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else if let idNumber = try? container.decode(Int.self, forKey: .id) {
            self.id = String(idNumber)
        } else if let idDouble = try? container.decode(Double.self, forKey: .id) {
            self.id = String(Int(idDouble))
        } else {
            // Fallback to generate new UUID
            self.id = UUID().uuidString
        }
        
        self.url = try container.decode(String.self, forKey: .url)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? "Game photo"
        
        // Handle timestamp - try different formats
        if let timestampData = try? container.decode(Timestamp.self, forKey: .timestamp) {
            self.timestamp = timestampData.dateValue()
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            self.timestamp = formatter.date(from: timestampString) ?? Date()
        } else if let timestampDouble = try? container.decode(Double.self, forKey: .timestamp) {
            self.timestamp = Date(timeIntervalSince1970: timestampDouble)
        } else {
            self.timestamp = Date()
        }
        
        self.isICloudLink = try container.decodeIfPresent(Bool.self, forKey: .isICloudLink) ?? false
    }
    
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
        
        // Parse clock start time - handle missing field
        let clockStartTime: Date?
        if let timestamp = data["clockStartTime"] as? Double {
            clockStartTime = Date(timeIntervalSince1970: timestamp)
        } else if let timestampData = data["clockStartTime"] as? Timestamp {
            clockStartTime = timestampData.dateValue()
        } else {
            clockStartTime = nil
        }
        
        // Parse created date - handle multiple formats and missing field
        let createdAt: Date
        if let timestampData = data["createdAt"] as? Timestamp {
            createdAt = timestampData.dateValue()
        } else if let createdAtString = data["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString) ?? Date()
        } else if let createdAtDouble = data["createdAt"] as? Double {
            createdAt = Date(timeIntervalSince1970: createdAtDouble)
        } else {
            // Fallback for older documents
            createdAt = Date()
        }
        
        self.id = document.documentID
        self.teamName = data["teamName"] as? String ?? ""
        self.opponent = data["opponent"] as? String ?? ""
        self.location = data["location"] as? String
        self.gameFormat = GameFormat(rawValue: data["gameFormat"] as? String ?? "halves") ?? .halves
        self.periodLength = data["periodLength"] as? Int ?? 20
        self.numPeriods = self.gameFormat == .halves ? 2 : 4
        self.isRunning = data["isRunning"] as? Bool ?? false
        self.period = data["period"] as? Int ?? 1
        self.clock = data["clock"] as? TimeInterval ?? TimeInterval(self.periodLength * 60)
        self.clockStartTime = clockStartTime
        self.clockAtStart = data["clockAtStart"] as? TimeInterval ?? TimeInterval(self.periodLength * 60)
        self.homeScore = data["homeScore"] as? Int ?? 0
        self.awayScore = data["awayScore"] as? Int ?? 0
        self.playerStats = playerStats
        self.createdAt = createdAt
        self.createdBy = data["createdBy"] as? String
        self.sahilOnBench = data["sahilOnBench"] as? Bool ?? false
    }
}
