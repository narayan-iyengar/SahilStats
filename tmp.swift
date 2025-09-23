// MARK: - FILE: SahilStats/Services/FirebaseService.swift
// Add these efficiency metrics to the existing CareerStats struct

struct CareerStats

// MARK: - FILE: SahilStats/Views/ModernCareerDashboard.swift
// Add these new efficiency stat types to the existing TrendStatType enum

extension ModernCareerTrendsView {
    enum TrendStatType: String, CaseIterable {
        // EXISTING stats (keep all your existing ones)
        case avgPoints = "Avg Points"
        case totalPoints = "Total Points"
        case avgRebounds = "Avg Rebounds"
        case totalRebounds = "Total Rebounds"
        case avgAssists = "Avg Assists"
        case totalAssists = "Total Assists"
        case fieldGoalPct = "Field Goal %"
        case threePointPct = "3-Point %"
        case freeThrowPct = "Free Throw %"
        case winRate = "Win Rate"
        case gamesPlayed = "Games Played"
        case avgPlayingTime = "Avg Playing Time"
        case playingTimePercentage = "Court Time %"
        
        // ADD THESE NEW EFFICIENCY STATS
        case efficiencyRating = "Efficiency Rating"
        case pointsPerMinute = "Points/Minute"
        case trueShootingPct = "True Shooting %"
        case effectiveFGPct = "Effective FG %"
        case playerEfficiencyRating = "Player Efficiency"
        case efficiencyPerMinute = "Efficiency/Min"
        
        var color: Color {
            switch self {
            case .totalPoints, .avgPoints: return .purple
            case .totalRebounds, .avgRebounds: return .mint
            case .totalAssists, .avgAssists: return .cyan
            case .fieldGoalPct: return .blue
            case .threePointPct: return .green
            case .freeThrowPct: return .orange
            case .winRate: return .green
            case .gamesPlayed: return .blue
            case .avgPlayingTime: return .indigo
            case .playingTimePercentage: return .teal
            
            // NEW EFFICIENCY COLORS
            case .efficiencyRating: return .indigo
            case .pointsPerMinute: return .red
            case .trueShootingPct: return .cyan
            case .effectiveFGPct: return .teal
            case .playerEfficiencyRating: return .purple
            case .efficiencyPerMinute: return .mint
            }
        }
        
        var isPercentage: Bool {
            switch self {
            case .fieldGoalPct, .threePointPct, .freeThrowPct, .winRate, .trueShootingPct, .effectiveFGPct, .playingTimePercentage:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - FILE: SahilStats/Views/ModernCareerDashboard.swift
// Add these new efficiency cards to the ModernOverviewStatsView body

extension ModernOverviewStatsView {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: isIPad ? 16 : 12) {
            // EXISTING stats (keep your existing ones)
            ModernStatCard(title: "Games", value: "\(stats.totalGames)", color: .blue, isIPad: isIPad)
            ModernStatCard(title: "Points", value: "\(stats.totalPoints)", color: .purple, isIPad: isIPad)
            ModernStatCard(title: "Avg", value: String(format: "%.1f", stats.averagePoints), color: .indigo, isIPad: isIPad)
            ModernStatCard(title: "Win %", value: String(format: "%.0f%%", stats.winPercentage * 100), color: stats.winPercentage > 0.5 ? .green : .red, isIPad: isIPad)
            ModernStatCard(title: "Avg Time", value: String(format: "%.0fm", stats.averagePlayingTimePerGame), color: .teal, isIPad: isIPad)
            ModernStatCard(title: "Court %", value: String(format: "%.0f%%", stats.playingTimePercentage), color: .green, isIPad: isIPad)
            ModernStatCard(title: "Rebounds", value: "\(stats.totalRebounds)", color: .mint, isIPad: isIPad)
            ModernStatCard(title: "Assists", value: "\(stats.totalAssists)", color: .cyan, isIPad: isIPad)
            
            // ADD THESE NEW EFFICIENCY CARDS (replace some existing or add more rows)
            ModernStatCard(title: "Efficiency", value: String(format: "%.1f", stats.efficiencyRating), color: .indigo, isIPad: isIPad)
            ModernStatCard(title: "True Shooting", value: String(format: "%.0f%%", stats.trueShootingPercentage * 100), color: .cyan, isIPad: isIPad)
            ModernStatCard(title: "Effective FG", value: String(format: "%.0f%%", stats.effectiveFieldGoalPercentage * 100), color: .teal, isIPad: isIPad)
            ModernStatCard(title: "PER", value: String(format: "%.1f", stats.playerEfficiencyRating), color: .purple, isIPad: isIPad)
            
            // Only show these if playing time data exists
            if stats.totalPlayingTimeMinutes > 0 {
                ModernStatCard(title: "Pts/Min", value: String(format: "%.2f", stats.pointsPerMinute), color: .red, isIPad: isIPad)
                ModernStatCard(title: "Eff/Min", value: String(format: "%.2f", stats.efficiencyPerMinute), color: .mint, isIPad: isIPad)
            }
            
            // Keep other existing stats...
            ModernStatCard(title: "FG%", value: String(format: "%.0f%%", stats.fieldGoalPercentage * 100), color: .blue, isIPad: isIPad)
            ModernStatCard(title: "3P%", value: String(format: "%.0f%%", stats.threePointPercentage * 100), color: .green, isIPad: isIPad)
        }
    }
}

// MARK: - FILE: SahilStats/Views/ModernCareerDashboard.swift
// Add these cases to the existing calculateStatValue function in ModernCareerTrendsView

private func calculateStatValue(for games: [Game]) -> Double {
    let gameCount = Double(games.count)
    guard gameCount > 0 else { return 0 }
    
    switch selectedStat {
    // EXISTING cases (keep all your existing ones)
    case .avgPoints:
        return Double(games.reduce(0) { $0 + $1.points }) / gameCount
    case .totalPoints:
        return Double(games.reduce(0) { $0 + $1.points })
    case .fieldGoalPct:
        let totalMade = games.reduce(0) { $0 + $1.fg2m + $1.fg3m }
        let totalAttempted = games.reduce(0) { $0 + $1.fg2a + $1.fg3a }
        return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
    case .winRate:
        let wins = games.filter { $0.outcome == .win }.count
        return gameCount > 0 ? Double(wins) / gameCount * 100 : 0
    
    // ADD THESE NEW EFFICIENCY CASES
    case .efficiencyRating:
        let totalPositive = games.reduce(0) { $0 + $1.points + $1.rebounds + $1.assists + $1.steals + $1.blocks }
        let totalMissedFG = games.reduce(0) { $0 + ($1.fg2a + $1.fg3a) - ($1.fg2m + $1.fg3m) }
        let totalMissedFT = games.reduce(0) { $0 + $1.fta - $1.ftm }
        let totalNegative = games.reduce(0) { $0 + $1.turnovers } + totalMissedFG + totalMissedFT
        return Double(totalPositive - totalNegative) / gameCount
        
    case .pointsPerMinute:
        let totalPoints = games.reduce(0) { $0 + $1.points }
        let totalMinutes = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }
        return totalMinutes > 0 ? Double(totalPoints) / totalMinutes : 0
        
    case .trueShootingPct:
        let totalPoints = games.reduce(0) { $0 + $1.points }
        let totalShots = games.reduce(0) { $0 + $1.fg2a + $1.fg3a + Int($1.fta * 0.44) }
        return totalShots > 0 ? (Double(totalPoints) / (2.0 * Double(totalShots))) * 100 : 0
        
    case .effectiveFGPct:
        let totalMade = games.reduce(0) { $0 + $1.fg2m + $1.fg3m }
        let totalThreeMade = games.reduce(0) { $0 + $1.fg3m }
        let totalAttempted = games.reduce(0) { $0 + $1.fg2a + $1.fg3a }
        let adjustedMade = Double(totalMade) + (Double(totalThreeMade) * 0.5)
        return totalAttempted > 0 ? (adjustedMade / Double(totalAttempted)) * 100 : 0
        
    case .playerEfficiencyRating:
        // Simplified PER calculation per game average
        let totalPER = games.reduce(0.0) { result, game in
            let fg = Double(game.fg2m + game.fg3m)
            let fga = Double(game.fg2a + game.fg3a)
            let ft = Double(game.ftm)
            let fta_stat = Double(game.fta)
            let threePM = Double(game.fg3m)
            let ast = Double(game.assists)
            let reb = Double(game.rebounds)
            let stl = Double(game.steals)
            let blk = Double(game.blocks)
            let pf = Double(game.fouls)
            let to = Double(game.turnovers)
            
            let gamePER = (fg * 85.91) + (stl * 53.897) + (threePM * 51.757) + (ft * 46.845) +
                         (blk * 39.190) + (pf * -17.174) + ((fga - fg) * -39.190) +
                         ((fta_stat - ft) * -20.091) + (to * -53.897) +
                         (ast * 34.677) + (reb * 14.707)
            return result + gamePER
        }
        return totalPER / gameCount
        
    case .efficiencyPerMinute:
        let totalEfficiency = games.reduce(0.0) { result, game in
            let positive = game.points + game.rebounds + game.assists + game.steals + game.blocks
            let missedFG = (game.fg2a + game.fg3a) - (game.fg2m + game.fg3m)
            let missedFT = game.fta - game.ftm
            let negative = game.turnovers + missedFG + missedFT
            return result + Double(positive - negative)
        }
        let totalMinutes = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }
        return totalMinutes > 0 ? totalEfficiency / totalMinutes : 0
        
    // Continue with other existing cases...
    default:
        return 0
    }
}title: "Points", value: "\(stats.totalPoints)", color: .purple, isIPad: isIPad)
            ModernStatCard(title: "Win %", value: String(format: "%.0f%%", stats.winPercentage * 100), color: stats.winPercentage > 0.5 ? .green : .red, isIPad: isIPad)
            
            // NEW EFFICIENCY CARDS
            ModernStatCard(title: "Efficiency", value: String(format: "%.1f", stats.efficiencyRating), color: .indigo, isIPad: isIPad)
            ModernStatCard(title: "True Shooting", value: String(format: "%.0f%%", stats.trueShootingPercentage * 100), color: .cyan, isIPad: isIPad)
            ModernStatCard(title: "PER", value: String(format: "%.1f", stats.playerEfficiencyRating), color: .purple, isIPad: isIPad)
            
            if stats.totalPlayingTimeMinutes > 0 {
                ModernStatCard(title: "Pts/Min", value: String(format: "%.2f", stats.pointsPerMinute), color: .red, isIPad: isIPad)
                ModernStatCard(title: "Eff/Min", value: String(format: "%.2f", stats.efficiencyPerMinute), color: .mint, isIPad: isIPad)
            }
            
            // Continue with other existing stats...
        }
    }
}
