// File: SahilStats/Models/Game.swift

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Game Model

struct Game: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var teamName: String
    var opponent: String
    var location: String?
    //var timestamp: Date
    var gameFormat: GameFormat
    var quarterLength: Int
    var numQuarter: Int
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
    //var createdAt: Date
    var adminName: String?
    var editedAt: Date?
    var editedBy: String?

    var achievements: [Achievement]

    var youtubeVideoId: String?
    var photosAssetId: String?
    var videoUploadedAt: Date?
    
    var totalPlayingTimeMinutes: Double = 0.0 // Total minutes on court
    var benchTimeMinutes: Double = 0.0 // Total minutes on bench
    var gameTimeTracking: [GameTimeSegment] = [] // Detailed time tracking
    var isMultiDeviceSetup: Bool? // Whether this was a multi-device or single-device game

    // Computed properties for proper time calculations
    var totalGameTimeMinutes: Double {
        return Double(quarterLength * numQuarter)
    }
    
    var playingTimePercentage: Double {
        return totalGameTimeMinutes > 0 ? (totalPlayingTimeMinutes / totalGameTimeMinutes) * 100 : 0
    }
    
    // Computed property to ensure bench time is calculated correctly
    var calculatedBenchTime: Double {
        return max(0, totalGameTimeMinutes - totalPlayingTimeMinutes)
    }
    
    // Custom coding keys for date handling
    enum CodingKeys: String, CodingKey {
        case teamName, opponent, location, timestamp, gameFormat, quarterLength, numQuarter, status
        case myTeamScore, opponentScore, outcome
        case points, fg2m, fg2a, fg3m, fg3a, ftm, fta, rebounds, assists, steals, blocks, fouls, turnovers
        case createdAt, adminName, editedAt, editedBy, achievements
        case totalPlayingTimeMinutes, benchTimeMinutes, gameTimeTracking
        case videoURL, youtubeVideoId, photosAssetId, youtubeURL, videoUploadedAt
        case isMultiDeviceSetup
    }
    
    @ServerTimestamp var timestamp: Date?
    @ServerTimestamp var createdAt: Date?
    
    var videoURL: String?
    var youtubeURL: String?

    
    
    
    // Custom decoder to handle different date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Basic properties
        teamName = try container.decode(String.self, forKey: .teamName)
        opponent = try container.decode(String.self, forKey: .opponent)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        
        // FIXED: Better timestamp handling with detailed logging
        if let timestampData = try? container.decode(Timestamp.self, forKey: .timestamp) {
            timestamp = timestampData.dateValue()
            //print("✅ Decoded Firestore Timestamp: \(timestamp)")
        } else if let timestampDouble = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: timestampDouble)
            //print("✅ Decoded Double timestamp: \(timestamp)")
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            //print("🔍 Attempting to parse timestamp string: \(timestampString)")
            
            // FIXED: Proper ISO8601 formatter with fractional seconds
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let parsedDate = iso8601Formatter.date(from: timestampString) {
                timestamp = parsedDate
                //print("✅ Decoded ISO8601 with fractional seconds: \(timestamp)")
            } else {
                // Fallback: ISO8601 without fractional seconds
                let iso8601FormatterNoFraction = ISO8601DateFormatter()
                iso8601FormatterNoFraction.formatOptions = [.withInternetDateTime]
                
                if let parsedDate = iso8601FormatterNoFraction.date(from: timestampString) {
                    timestamp = parsedDate
                    //print("✅ Decoded ISO8601 without fractional seconds: \(timestamp)")
                } else {
                    // Final fallback: Custom date formatter
                    let customFormatter = DateFormatter()
                    customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    customFormatter.locale = Locale(identifier: "en_US_POSIX")
                    customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    if let parsedDate = customFormatter.date(from: timestampString) {
                        timestamp = parsedDate
                        //print("✅ Decoded with custom formatter: \(timestamp)")
                    } else {
                        // Try without milliseconds
                        let customFormatterNoMs = DateFormatter()
                        customFormatterNoMs.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                        customFormatterNoMs.locale = Locale(identifier: "en_US_POSIX")
                        customFormatterNoMs.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        if let parsedDate = customFormatterNoMs.date(from: timestampString) {
                            timestamp = parsedDate
                            //print("✅ Decoded with custom formatter (no ms): \(timestamp)")
                        } else {
                           // print("❌ Failed to parse timestamp string: \(timestampString)")
                            //print("❌ Using current date as fallback - THIS SHOULD BE FIXED!")
                            timestamp = Date() // Last resort fallback
                        }
                    }
                }
            }
        } else {
            //print("❌ No valid timestamp found, using current date as fallback")
            timestamp = Date() // Last resort fallback
        }
        
        gameFormat = try container.decode(GameFormat.self, forKey: .gameFormat)
        
        // Handle quarterLength - can be stored as string or int
        if let quarterLengthInt = try? container.decode(Int.self, forKey: .quarterLength) {
            quarterLength = quarterLengthInt
        } else if let quarterLengthString = try? container.decode(String.self, forKey: .quarterLength) {
            quarterLength = Int(quarterLengthString) ?? 20
        } else {
            quarterLength = 20 // default fallback
        }
        
        // Handle numQuarter - can be stored as string or int
        if let numQuarterInt = try? container.decode(Int.self, forKey: .numQuarter) {
            numQuarter = numQuarterInt
        } else if let numQuartersString = try? container.decode(String.self, forKey: .numQuarter) {
            numQuarter = Int(numQuartersString) ?? (gameFormat == .halves ? 2 : 4)
        } else {
            numQuarter = gameFormat == .halves ? 2 : 4 // calculate from format
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
        
        // FIXED: Better createdAt handling with detailed logging
        if let createdAtData = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = createdAtData.dateValue()
            //print("✅ Decoded createdAt Firestore Timestamp: \(createdAt)")
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: createdAtDouble)
            //print("✅ Decoded createdAt Double: \(createdAt)")
        } else if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            //print("🔍 Attempting to parse createdAt string: \(createdAtString)")
            
            // FIXED: Same improved ISO8601 parsing for createdAt
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let parsedDate = iso8601Formatter.date(from: createdAtString) {
                createdAt = parsedDate
                //print("✅ Decoded createdAt ISO8601 with fractional seconds: \(createdAt)")
            } else {
                let iso8601FormatterNoFraction = ISO8601DateFormatter()
                iso8601FormatterNoFraction.formatOptions = [.withInternetDateTime]
                
                if let parsedDate = iso8601FormatterNoFraction.date(from: createdAtString) {
                    createdAt = parsedDate
                    //print("✅ Decoded createdAt ISO8601 without fractional seconds: \(createdAt)")
                } else {
                    let customFormatter = DateFormatter()
                    customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    customFormatter.locale = Locale(identifier: "en_US_POSIX")
                    customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    if let parsedDate = customFormatter.date(from: createdAtString) {
                        createdAt = parsedDate
                        //print("✅ Decoded createdAt with custom formatter: \(createdAt)")
                    } else {
                        //print("❌ Failed to parse createdAt string: \(createdAtString), using current date")
                        createdAt = Date() // Fallback for createdAt is acceptable
                    }
                }
            }
        } else {
            //print("❌ No createdAt found, using current date")
            createdAt = Date() // Fallback for createdAt is acceptable
        }
        
        // Optional metadata
        adminName = try container.decodeIfPresent(String.self, forKey: .adminName)
        videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        youtubeVideoId = try container.decodeIfPresent(String.self, forKey: .youtubeVideoId)
        photosAssetId = try container.decodeIfPresent(String.self, forKey: .photosAssetId)
        youtubeURL = try container.decodeIfPresent(String.self, forKey: .youtubeURL)

        // Handle videoUploadedAt
        if let uploadedAtData = try? container.decodeIfPresent(Timestamp.self, forKey: .videoUploadedAt) {
            videoUploadedAt = uploadedAtData.dateValue()
        } else if let uploadedAtDouble = try? container.decodeIfPresent(Double.self, forKey: .videoUploadedAt) {
            videoUploadedAt = Date(timeIntervalSince1970: uploadedAtDouble)
        } else {
            videoUploadedAt = nil
        }

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
        achievements = try container.decodeIfPresent([Achievement].self, forKey: .achievements) ?? []
        totalPlayingTimeMinutes = try container.decodeIfPresent(Double.self, forKey: .totalPlayingTimeMinutes) ?? 0.0
        benchTimeMinutes = try container.decodeIfPresent(Double.self, forKey: .benchTimeMinutes) ?? 0.0
        gameTimeTracking = try container.decodeIfPresent([GameTimeSegment].self, forKey: .gameTimeTracking) ?? []
        isMultiDeviceSetup = try container.decodeIfPresent(Bool.self, forKey: .isMultiDeviceSetup)
    }

    // MARK: - Helper Function for Date Parsing (Add this to your Game struct)

    private static func parseISODateString(_ dateString: String) -> Date? {
        // Method 1: ISO8601 with fractional seconds
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Method 2: ISO8601 without fractional seconds
        let iso8601FormatterNoFraction = ISO8601DateFormatter()
        iso8601FormatterNoFraction.formatOptions = [.withInternetDateTime]
        
        if let date = iso8601FormatterNoFraction.date(from: dateString) {
            return date
        }
        
        // Method 3: Custom formatter with milliseconds
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        customFormatter.locale = Locale(identifier: "en_US_POSIX")
        customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        if let date = customFormatter.date(from: dateString) {
            return date
        }
        
        // Method 4: Custom formatter without milliseconds
        let customFormatterNoMs = DateFormatter()
        customFormatterNoMs.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        customFormatterNoMs.locale = Locale(identifier: "en_US_POSIX")
        customFormatterNoMs.timeZone = TimeZone(secondsFromGMT: 0)
        
        return customFormatterNoMs.date(from: dateString)
    }


    var formattedDate: String {
        // First, check if the optional 'timestamp' contains a valid date.
        guard let date = timestamp else {
            // If it doesn't, return a default string.
            return "Date not available"
        }
        
        // If it does, create the formatter and use the unwrapped 'date' constant.
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    
    init(teamName: String, opponent: String, location: String? = nil, timestamp: Date = Date(), gameFormat: GameFormat = .halves, quarterLength: Int = 20, myTeamScore: Int = 0, opponentScore: Int = 0, fg2m: Int = 0, fg2a: Int = 0, fg3m: Int = 0, fg3a: Int = 0, ftm: Int = 0, fta: Int = 0, rebounds: Int = 0, assists: Int = 0, steals: Int = 0, blocks: Int = 0, fouls: Int = 0, turnovers: Int = 0, adminName: String? = nil, totalPlayingTimeMinutes: Double = 0.0,
         benchTimeMinutes: Double = 0.0,
         gameTimeTracking: [GameTimeSegment] = [],
         isMultiDeviceSetup: Bool? = nil) {
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.timestamp = timestamp
        self.gameFormat = gameFormat
        self.quarterLength = quarterLength
        self.numQuarter = gameFormat == .halves ? 2 : 4
        self.status = .final
        self.myTeamScore = myTeamScore
        self.opponentScore = opponentScore
        self.totalPlayingTimeMinutes = totalPlayingTimeMinutes
        self.benchTimeMinutes = benchTimeMinutes
        self.gameTimeTracking = gameTimeTracking
        self.isMultiDeviceSetup = isMultiDeviceSetup
        
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
        
        // Initialize achievements as empty array first, then calculate after self is fully initialized
        self.achievements = []
        
        // Now that self is fully initialized, calculate achievements
        self.achievements = Achievement.getEarnedAchievements(for: self)
    }
}

extension Game {
    // FIXED: Proper encoding that avoids problematic data types
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "teamName": teamName,
            "opponent": opponent,
            "gameFormat": gameFormat.rawValue,
            "quarterLength": quarterLength,
            "numQuarter": numQuarter,
            "status": status.rawValue,
            "myTeamScore": myTeamScore,
            "opponentScore": opponentScore,
            "outcome": outcome.rawValue,
            
            // Stats as explicit integers
            "points": points,
            "fg2m": fg2m,
            "fg2a": fg2a,
            "fg3m": fg3m,
            "fg3a": fg3a,
            "ftm": ftm,
            "fta": fta,
            "rebounds": rebounds,
            "assists": assists,
            "steals": steals,
            "blocks": blocks,
            "fouls": fouls,
            "turnovers": turnovers,
            
            // Time tracking as doubles
            "totalPlayingTimeMinutes": totalPlayingTimeMinutes,
            "benchTimeMinutes": benchTimeMinutes
        ]

        // SAFE: Add isMultiDeviceSetup if it exists
        if let isMultiDeviceSetup = isMultiDeviceSetup {
            data["isMultiDeviceSetup"] = isMultiDeviceSetup
        }

        // SAFE: Only add optional fields if they exist
        if let location = location, !location.isEmpty {
            data["location"] = location
        }
        
        if let adminName = adminName {
            data["adminName"] = adminName
        }
        
        if let editedBy = editedBy {
            data["editedBy"] = editedBy
        }
        
        // CRITICAL: Handle timestamps safely
        if let timestamp = timestamp {
            data["timestamp"] = Timestamp(date: timestamp)
        } else {
            data["timestamp"] = Timestamp(date: Date()) // Fallback
        }
        
        if let createdAt = createdAt {
            data["createdAt"] = Timestamp(date: createdAt)
        } else {
            data["createdAt"] = Timestamp(date: Date()) // Fallback
        }
        
        if let editedAt = editedAt {
            data["editedAt"] = Timestamp(date: editedAt)
        }

        // SAFE: Add video URLs if they exist
        if let videoURL = videoURL {
            data["videoURL"] = videoURL
        }

        if let youtubeVideoId = youtubeVideoId {
            data["youtubeVideoId"] = youtubeVideoId
        }

        if let photosAssetId = photosAssetId {
            data["photosAssetId"] = photosAssetId
        }

        if let youtubeURL = youtubeURL {
            data["youtubeURL"] = youtubeURL
        }

        if let videoUploadedAt = videoUploadedAt {
            data["videoUploadedAt"] = Timestamp(date: videoUploadedAt)
        }

        // SAFE: Convert achievements to array of dictionaries
        data["achievements"] = achievements.map { achievement in
            [
                "id": achievement.id,
                "name": achievement.name,
                "emoji": achievement.emoji,
                "description": achievement.description
            ]
        }
        
        // SAFE: Convert time segments to array of dictionaries
        data["gameTimeTracking"] = gameTimeTracking.map { segment in
            var segmentData: [String: Any] = [
                "isOnCourt": segment.isOnCourt,
                "startTime": Timestamp(date: segment.startTime)
            ]
            
            if let endTime = segment.endTime {
                segmentData["endTime"] = Timestamp(date: endTime)
            }
            
            return segmentData
        }
        
        return data
    }
}

//MARK: Platying Time
struct GameTimeSegment: Codable, Identifiable, Equatable {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var isOnCourt: Bool // true = on court, false = on bench
    
    var durationMinutes: Double {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime) / 60.0
    }
}


// MARK: - Player Stats
struct PlayerStats: Codable, Equatable {
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
    
    // Equatable conformance is automatically synthesized for structs with Equatable properties
}

// MARK: - Team Model

struct Team: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var createdAt: Date

    // Equatable conformance
    static func == (lhs: Team, rhs: Team) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
    
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
    case quarters = "quarters"
    
    var displayName: String {
        switch self {
        case .halves: return "Halves"
        case .quarters: return "Quarters"
        }
    }
    
    var quarterCount: Int {
        switch self {
        case .halves: return 2
        case .quarters: return 4
        }
    }
    
    var quarterName: String {
        switch self {
        case .halves: return "Half"
        case .quarters: return "Quarter"
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



// MARK: - Live Game Model (Enhanced with FIXED Time Tracking)

// MARK: - Game Configuration
struct GameConfiguration {
    var teamName: String = ""
    var opponent: String = ""
    var location: String = ""
    var date: Date = Date()
    var gameFormat: GameFormat = .quarters
    var quarterLength: Int = 10
    var numQuarter: Int = 4
}

// Backward compatibility alias
typealias GameConfig = GameConfiguration

struct LiveGame: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var teamName: String
    var opponent: String
    var location: String?
    var gameFormat: GameFormat
    var quarterLength: Int
    var numQuarter: Int
    
    // Live game state
    var isRunning: Bool
    var quarter: Int
    var clock: TimeInterval
    var clockStartTime: Date? // When the clock was last started
    var clockAtStart: TimeInterval? // Clock value when started
    
    // Enhanced Device Control System
    var controllingDeviceId: String? // Which device has control
    var controllingUserEmail: String? // Which user has control
    var controlRequestedBy: String? // User requesting control
    var controlRequestingDeviceId: String? // Device requesting control
    var controlRequestTimestamp: Date? // When the control request was made
    var lastClockUpdate: Date? // Server timestamp of last clock update
    
    // Current scores
    var homeScore: Int
    var awayScore: Int
    
    var isActive: Bool = true  // Add this
    var endedAt: Date?         // Add this too
    
    
    
    // Player stats
    var playerStats: PlayerStats
    
    // Metadata
    @ServerTimestamp var createdAt: Date?
    var createdBy: String?
    var sahilOnBench: Bool?
    var isMultiDeviceSetup: Bool?
    
    // 🔥 FIXED: Consistent time tracking properties (all stored in Firebase)
    var totalPlayingTimeMinutes: Double = 0.0 // Cumulative court time from completed segments
    var benchTimeMinutes: Double = 0.0        // Cumulative bench time from completed segments
    var timeSegments: [GameTimeSegment] = []  // Array of completed time segments
    var currentTimeSegment: GameTimeSegment? = nil // Currently active segment (if any)

    // 🔥 FIXED: Computed properties that include live active segment time
    var totalPlayingTime: Double {
        var total = totalPlayingTimeMinutes // Start with stored completed time
        
        // Add current active segment time if it's court time
        if let current = currentTimeSegment, current.isOnCourt, current.endTime == nil {
            let currentDuration = Date().timeIntervalSince(current.startTime) / 60.0
            total += currentDuration
        }
        
        return total
    }

    var totalBenchTime: Double {
        var total = benchTimeMinutes // Start with stored completed time
        
        // Add current active segment time if it's bench time
        if let current = currentTimeSegment, !current.isOnCourt, current.endTime == nil {
            let currentDuration = Date().timeIntervalSince(current.startTime) / 60.0
            total += currentDuration
        }
        
        return total
    }
    
    // Computed properties (existing ones)
    var isGameOver: Bool {
        quarter >= numQuarter && clock <= 0 && !isRunning
    }
    
    // Calculate current clock based on server time (prevents drift)
    func getCurrentClock() -> TimeInterval {
        // If game is not running, return the static clock value
        guard isRunning else {
            return clock
        }
        
        // If game is running but we don't have proper timing data, return static clock
        guard let startTime = clockStartTime,
              let clockAtStart = clockAtStart else {
            return clock
        }
        
        // Calculate how much time has elapsed since the clock started
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Calculate current clock value
        let currentClock = max(0, clockAtStart - elapsedTime)
        
        return currentClock
    }
    
    var currentClockDisplay: String {
        let currentTime = getCurrentClock()
        if currentTime <= 59 {
            return String(format: "%.1f", currentTime)
        } else {
            let minutes = Int(currentTime) / 60
            let seconds = Int(currentTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var quarterName: String {
        gameFormat == .halves ? "Half" : "Quarter"
    }
    
    init(teamName: String, opponent: String, location: String? = nil, gameFormat: GameFormat = .halves, quarterLength: Int = 20, createdBy: String? = nil, deviceId: String? = nil, isMultiDeviceSetup: Bool = false) {
        self.teamName = teamName
        self.opponent = opponent
        self.location = location
        self.gameFormat = gameFormat
        self.quarterLength = quarterLength
        self.numQuarter = gameFormat == .halves ? 2 : 4
        self.isRunning = false
        self.quarter = 1
        self.clock = TimeInterval(quarterLength * 60)
        self.clockStartTime = nil
        self.clockAtStart = TimeInterval(quarterLength * 60)

        // AUTO-GRANT CONTROL: Set the creating device as the controller
        self.controllingDeviceId = deviceId
        self.controllingUserEmail = createdBy
        self.controlRequestedBy = nil
        self.controlRequestingDeviceId = nil
        self.controlRequestTimestamp = nil
        self.lastClockUpdate = nil

        self.homeScore = 0
        self.awayScore = 0
        self.playerStats = PlayerStats()
        self.createdAt = Date()
        self.createdBy = createdBy
        self.sahilOnBench = false
        self.isMultiDeviceSetup = isMultiDeviceSetup

        // 🔥 CRITICAL FIX: Explicitly initialize time tracking as nil/empty
        self.totalPlayingTimeMinutes = 0.0
        self.benchTimeMinutes = 0.0
        self.currentTimeSegment = nil  // ✅ This ensures startInitialTimeTracking() will be called
        self.timeSegments = []         // ✅ Start with empty completed segments

        debugPrint("🔥 NEW LiveGame created - currentTimeSegment is NIL: \(currentTimeSegment == nil)")
    }
}


// MARK: - Extensions for Firebase Compatibility (Updated with Time Tracking Fix)
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
        
        // FIXED: Parse time segments
        var timeSegments: [GameTimeSegment] = []
        if let timeSegmentsData = data["timeSegments"] as? [[String: Any]] {
            timeSegments = timeSegmentsData.compactMap { segmentData in
                guard let startTimeData = segmentData["startTime"],
                      let isOnCourt = segmentData["isOnCourt"] as? Bool else {
                    return nil
                }
                
                let startTime: Date
                if let timestamp = startTimeData as? Timestamp {
                    startTime = timestamp.dateValue()
                } else if let timestampDouble = startTimeData as? Double {
                    startTime = Date(timeIntervalSince1970: timestampDouble)
                } else {
                    return nil
                }
                
                let endTime: Date?
                if let endTimeData = segmentData["endTime"] {
                    if let timestamp = endTimeData as? Timestamp {
                        endTime = timestamp.dateValue()
                    } else if let timestampDouble = endTimeData as? Double {
                        endTime = Date(timeIntervalSince1970: timestampDouble)
                    } else {
                        endTime = nil
                    }
                } else {
                    endTime = nil
                }
                
                return GameTimeSegment(
                    startTime: startTime,
                    endTime: endTime,
                    isOnCourt: isOnCourt
                )
            }
        }
        
        // FIXED: Parse current time segment (this was missing!)
        var currentTimeSegment: GameTimeSegment? = nil
        if let currentSegmentData = data["currentTimeSegment"] as? [String: Any],
           let startTimeData = currentSegmentData["startTime"],
           let isOnCourt = currentSegmentData["isOnCourt"] as? Bool {
            
            let startTime: Date
            if let timestamp = startTimeData as? Timestamp {
                startTime = timestamp.dateValue()
            } else if let timestampDouble = startTimeData as? Double {
                startTime = Date(timeIntervalSince1970: timestampDouble)
            } else {
                startTime = Date() // fallback
            }
            
            let endTime: Date?
            if let endTimeData = currentSegmentData["endTime"] {
                if let timestamp = endTimeData as? Timestamp {
                    endTime = timestamp.dateValue()
                } else if let timestampDouble = endTimeData as? Double {
                    endTime = Date(timeIntervalSince1970: timestampDouble)
                } else {
                    endTime = nil
                }
            } else {
                endTime = nil
            }
            
            currentTimeSegment = GameTimeSegment(
                startTime: startTime,
                endTime: endTime,
                isOnCourt: isOnCourt
            )
        }
        
        self.id = document.documentID
        self.teamName = data["teamName"] as? String ?? ""
        self.opponent = data["opponent"] as? String ?? ""
        self.location = data["location"] as? String
        self.gameFormat = GameFormat(rawValue: data["gameFormat"] as? String ?? "halves") ?? .halves
        self.quarterLength = data["quarterLength"] as? Int ?? 20
        self.numQuarter = self.gameFormat == .halves ? 2 : 4
        self.isRunning = data["isRunning"] as? Bool ?? false
        self.quarter = data["quarter"] as? Int ?? 1
        self.clock = data["clock"] as? TimeInterval ?? TimeInterval(self.quarterLength * 60)
        self.clockStartTime = clockStartTime
        self.clockAtStart = data["clockAtStart"] as? TimeInterval ?? TimeInterval(self.quarterLength * 60)
        
        // Enhanced control fields
        self.controllingDeviceId = data["controllingDeviceId"] as? String
        self.controllingUserEmail = data["controllingUserEmail"] as? String
        self.controlRequestedBy = data["controlRequestedBy"] as? String
        self.controlRequestingDeviceId = data["controlRequestingDeviceId"] as? String
        
        // Parse controlRequestTimestamp
        if let timestampData = data["controlRequestTimestamp"] as? Timestamp {
            self.controlRequestTimestamp = timestampData.dateValue()
        } else if let timestampDouble = data["controlRequestTimestamp"] as? Double {
            self.controlRequestTimestamp = Date(timeIntervalSince1970: timestampDouble)
        } else {
            self.controlRequestTimestamp = nil
        }
        
        // Parse lastClockUpdate
        if let lastUpdateData = data["lastClockUpdate"] as? Timestamp {
            self.lastClockUpdate = lastUpdateData.dateValue()
        } else if let lastUpdateDouble = data["lastClockUpdate"] as? Double {
            self.lastClockUpdate = Date(timeIntervalSince1970: lastUpdateDouble)
        } else {
            self.lastClockUpdate = nil
        }
        
        self.homeScore = data["homeScore"] as? Int ?? 0
        self.awayScore = data["awayScore"] as? Int ?? 0
        self.playerStats = playerStats
        self.createdAt = createdAt
        self.createdBy = data["createdBy"] as? String
        self.sahilOnBench = data["sahilOnBench"] as? Bool ?? false
        
        // FIXED: Set the time tracking properties
        self.timeSegments = timeSegments
        self.currentTimeSegment = currentTimeSegment
        
        debugPrint("🔍 DECODED LiveGame - currentTimeSegment: \(currentTimeSegment != nil ? "EXISTS" : "NIL")")
        debugPrint("🔍 DECODED LiveGame - timeSegments count: \(timeSegments.count)")
    }
    
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "teamName": teamName,
            "opponent": opponent,
            "gameFormat": gameFormat.rawValue,
            "quarterLength": quarterLength,
            "numQuarter": numQuarter,
            "isRunning": isRunning,
            "quarter": quarter,
            "clock": clock,
            "homeScore": homeScore,
            "awayScore": awayScore,
            
            // Player stats as nested dictionary
            "playerStats": [
                "fg2m": playerStats.fg2m,
                "fg2a": playerStats.fg2a,
                "fg3m": playerStats.fg3m,
                "fg3a": playerStats.fg3a,
                "ftm": playerStats.ftm,
                "fta": playerStats.fta,
                "rebounds": playerStats.rebounds,
                "assists": playerStats.assists,
                "steals": playerStats.steals,
                "blocks": playerStats.blocks,
                "fouls": playerStats.fouls,
                "turnovers": playerStats.turnovers
            ],
            
            // Time tracking
            "totalPlayingTimeMinutes": totalPlayingTimeMinutes,
            "benchTimeMinutes": benchTimeMinutes,
            "sahilOnBench": sahilOnBench ?? false
        ]
        
        // SAFE: Handle optional strings
        if let location = location, !location.isEmpty {
            data["location"] = location
        }
        
        if let createdBy = createdBy {
            data["createdBy"] = createdBy
        }
        
        if let controllingDeviceId = controllingDeviceId {
            data["controllingDeviceId"] = controllingDeviceId
        }
        
        if let controllingUserEmail = controllingUserEmail {
            data["controllingUserEmail"] = controllingUserEmail
        }
        
        if let controlRequestedBy = controlRequestedBy {
            data["controlRequestedBy"] = controlRequestedBy
        }
        
        if let controlRequestingDeviceId = controlRequestingDeviceId {
            data["controlRequestingDeviceId"] = controlRequestingDeviceId
        }
        
        // CRITICAL: Handle timestamps safely
        if let createdAt = createdAt {
            data["createdAt"] = Timestamp(date: createdAt)
        }
        
        if let clockStartTime = clockStartTime {
            data["clockStartTime"] = Timestamp(date: clockStartTime)
        }
        
        if let clockAtStart = clockAtStart {
            data["clockAtStart"] = clockAtStart
        }
        
        if let lastClockUpdate = lastClockUpdate {
            data["lastClockUpdate"] = Timestamp(date: lastClockUpdate)
        }
        
        if let controlRequestTimestamp = controlRequestTimestamp {
            data["controlRequestTimestamp"] = Timestamp(date: controlRequestTimestamp)
        }
        
        // SAFE: Convert time segments
        data["timeSegments"] = timeSegments.map { segment in
            var segmentData: [String: Any] = [
                "isOnCourt": segment.isOnCourt,
                "startTime": Timestamp(date: segment.startTime)
            ]
            
            if let endTime = segment.endTime {
                segmentData["endTime"] = Timestamp(date: endTime)
            }
            
            return segmentData
        }
        
        // SAFE: Handle current time segment
        if let currentSegment = currentTimeSegment {
            var currentSegmentData: [String: Any] = [
                "isOnCourt": currentSegment.isOnCourt,
                "startTime": Timestamp(date: currentSegment.startTime)
            ]
            
            if let endTime = currentSegment.endTime {
                currentSegmentData["endTime"] = Timestamp(date: endTime)
            }
            
            data["currentTimeSegment"] = currentSegmentData
        }
        
        return data
    }
    // Track which device is the recorder (for multi-device setups)
        var recordingDeviceId: String? {
              get {
                  // You can add this as a stored property to your LiveGame struct
                  // For now, return nil as placeholder
                  return nil
              }
              set {
                  // Implement setter when you add this as a stored property

              }
          }
    
    var recordingUserEmail: String? {
        get {
            // You can add this as a stored property to your LiveGame struct
            // For now, return nil as placeholder
            return nil
        }
        set {
            // Implement setter when you add this as a stored property

        }
    }
    
    // Track connected viewers
    var connectedViewers: [String] {
        get {
            // You can add this as a stored property to your LiveGame struct
            // For now, return nil as placeholder
            return []
        }
        set {
            // Implement setter when you add this as a stored property

        }
    }
    
    // MARK: - Role Availability Check Methods
    
func isControllerRoleAvailable() -> Bool {
        return controllingDeviceId == nil || controllingUserEmail == nil
    }
    
    func isRecorderRoleAvailable() -> Bool {
        // Always allow recorder - anyone should be able to join as recorder
        // (The original multi-device setup restriction was too limiting)
        return true
    }
    
    func getAvailableRoles() -> [DeviceRole] {
        var roles: [DeviceRole] = []
        
        if isControllerRoleAvailable() {
            roles.append(.controller)
        }
        
        if isRecorderRoleAvailable() {
            roles.append(.recorder)
        }
        
        // Viewers are always allowed
        roles.append(.viewer)
        
        return roles
    }
    
    func getRoleStatus() -> String {
        var status: [String] = []
        
        if controllingDeviceId != nil {
            status.append("Controller: Connected")
        } else {
            status.append("Controller: Available")
        }
        
        // Always show recorder status since recorder role is always available
        if recordingDeviceId != nil {
            status.append("Recorder: Connected")
        } else {
            status.append("Recorder: Available")
        }
        
        if !connectedViewers.isEmpty {
            status.append("Viewers: \(connectedViewers.count)")
        }
        
        return status.joined(separator: " • ")
    }
}

