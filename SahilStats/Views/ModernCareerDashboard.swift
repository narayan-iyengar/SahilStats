//
//  ModernCareerDashboard.swift.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/20/25.
//

// File: SahilStats/Views/ModernCareerDashboard.swift

import SwiftUI
import Charts
import Foundation
import Combine

// MARK: - Modern Career Dashboard

struct StatSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
}

enum StatCategory: String, CaseIterable {
    case core = "Core"
    case performance = "Performance"
    case shooting = "Shooting"
    case advanced = "Advanced"
}


struct ModernCareerDashboard: View {
    let stats: CareerStats
    let games: [Game]
    @Binding var isViewingTrends: Bool
    let isIPad: Bool
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {  // Changed to 0 for manual spacing control
            // Add a spacer or empty view for header spacing
            Spacer()
            Color.clear
                .frame(height: isIPad ? 52 : 40)  // Dedicated header space
            
            // Modern Tab Selector
            ModernTabSelector(
                selectedTab: $selectedTab,
                isIPad: isIPad,
                onSelectionChange: { newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isViewingTrends = (newValue == 1)
                    }
                }
            )
            .padding(.bottom, isIPad ? 40 : 32)  // Space between tabs and content
            
            // Content based on selected tab
            if selectedTab == 0 {
                ModernOverviewStatsView(stats: stats, isIPad: isIPad)
            } else {
                ModernCareerTrendsView(games: games, isIPad: isIPad)
            }
        }
        .padding(.horizontal, isIPad ? 32 : 20)
        .padding(.bottom, isIPad ? 32 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isIPad ? 24 : 16)
    }
}

// MARK: - Modern Tab Selector

    struct ModernTabSelector: View {
        @Binding var selectedTab: Int
        let isIPad: Bool
        let onSelectionChange: (Int) -> Void
        
        var body: some View {
            HStack(spacing: 0) {
                ForEach(0..<2) { index in
                    Button(action: {
                        selectedTab = index
                        onSelectionChange(index)
                    }) {
                        Text(index == 0 ? "Overview" : "Trends")
                            .font(isIPad ? .title2 : .body)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isIPad ? 8 : 6)  // Further reduced from 10:8 to 8:6
                            .background(
                                RoundedRectangle(cornerRadius: isIPad ? 12 : 8)  // Reduced corner radius to match smaller size
                                    .fill(selectedTab == index ? Color(.systemBackground) : Color.clear)
                                    .shadow(
                                        color: selectedTab == index ? .black.opacity(0.1) : .clear,
                                        radius: selectedTab == index ? 4 : 0,
                                        x: 0,
                                        y: selectedTab == index ? 2 : 0
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)  // Reduced outer corner radius too
                    .fill(Color(.systemGray6))
            )
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
    }

// MARK: - Modern Overview Stats View

// In ModernCareerDashboard.swift.swift

struct ModernOverviewStatsView: View {
    let stats: CareerStats
    let isIPad: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            
            // --- Core Stats Section ---
            StatSectionHeader(title: "Core Stats")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: isIPad ? 16 : 12) {
                ModernStatCard(title: "Games", value: "\(stats.totalGames)", color: .blue, isIPad: isIPad)
                ModernStatCard(title: "Points", value: "\(stats.totalPoints)", color: .purple, isIPad: isIPad)
                ModernStatCard(title: "Avg", value: String(format: "%.1f", stats.averagePoints), color: .indigo, isIPad: isIPad)
                ModernStatCard(title: "Win %", value: String(format: "%.0f%%", stats.winPercentage * 100), color: stats.winPercentage > 0.5 ? .green : .red, isIPad: isIPad)
            }

            // --- Performance Section ---
            StatSectionHeader(title: "Performance")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: isIPad ? 16 : 12) {
                ModernStatCard(title: "Rebounds", value: "\(stats.totalRebounds)", color: .mint, isIPad: isIPad)
                ModernStatCard(title: "Assists", value: "\(stats.totalAssists)", color: .cyan, isIPad: isIPad)
                ModernStatCard(title: "Steals", value: "\(stats.totalSteals)", color: .yellow, isIPad: isIPad)
                ModernStatCard(title: "A/T", value: String(format: "%.1f", stats.assistTurnoverRatio), color: .indigo, isIPad: isIPad)
            }
            
            // --- Shooting Efficiency Section ---
            StatSectionHeader(title: "Shooting")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: isIPad ? 16 : 12) {
                ModernStatCard(title: "FG%", value: String(format: "%.0f%%", stats.fieldGoalPercentage * 100), color: .blue, isIPad: isIPad)
                ModernStatCard(title: "3P%", value: String(format: "%.0f%%", stats.threePointPercentage * 100), color: .green, isIPad: isIPad)
                ModernStatCard(title: "FT%", value: String(format: "%.0f%%", stats.freeThrowPercentage * 100), color: .orange, isIPad: isIPad)
                ModernStatCard(title: "Shot %", value: String(format: "%.0f%%", stats.trueShootingPercentage * 100), color: .cyan, isIPad: isIPad)
            }
            
            // --- Advanced Analytics Section ---
            if stats.totalPlayingTimeMinutes > 0 {
                StatSectionHeader(title: "Advanced Analytics")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: isIPad ? 16 : 12) {
                    ModernStatCard(title: "PER", value: String(format: "%.1f", stats.playerEfficiencyRating), color: .purple, isIPad: isIPad)
                    ModernStatCard(title: "Pts/Min", value: String(format: "%.2f", stats.pointsPerMinute), color: .red, isIPad: isIPad)
                    ModernStatCard(title: "Eff/Min", value: String(format: "%.2f", stats.efficiencyPerMinute), color: .mint, isIPad: isIPad)
                    ModernStatCard(title: "Efficiency", value: String(format: "%.1f", stats.efficiencyRating), color: .indigo, isIPad: isIPad)
                }
            }
        }
    }
}

// MARK: - Modern Stat Card

struct ModernStatCard: View {
    let title: String
    let value: String
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text(value)
                .font(isIPad ? .system(size: 32, weight: .bold) : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6) // Allow more aggressive scaling for values
            
            Text(title)
                .font(isIPad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7) // Allow title to scale down if needed
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 120 : 80, maxHeight: isIPad ? 120 : 80) // Fixed height for consistency
        .padding(.vertical, isIPad ? 20 : 16)
        .padding(.horizontal, isIPad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Modern Career Trends View

struct ModernCareerTrendsView: View {
    let games: [Game]
    let isIPad: Bool
    @State private var selectedStat: TrendStatType = .avgPoints
    @State private var selectedTimeframe: TrendTimeframe = .auto
    
    enum TrendStatType: String, CaseIterable {
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
            case .fieldGoalPct, .threePointPct, .freeThrowPct, .winRate:
                return true
            default:
                return false
            }
        }
        
        var category: StatCategory {
            switch self {
            case .avgPoints, .totalPoints, .winRate, .gamesPlayed:
                return .core
            case .avgRebounds, .totalRebounds, .avgAssists, .totalAssists:
                return .performance
            case .fieldGoalPct, .threePointPct, .freeThrowPct, .trueShootingPct, .effectiveFGPct:
                return .shooting
            case .avgPlayingTime, .playingTimePercentage, .efficiencyRating, .pointsPerMinute, .playerEfficiencyRating, .efficiencyPerMinute:
                return .advanced
            }
        }
    }
    
    enum TrendTimeframe: String, CaseIterable {
        case auto = "Auto"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        
        var displayName: String { rawValue }
    }
    
    private var smartTimeframe: TrendTimeframe {
        if selectedTimeframe != .auto {
            return selectedTimeframe
        }
        
        let gameCount = games.count
        if gameCount < 5 {
            return .weekly
        } else if gameCount < 15 {
            return .monthly
        } else {
            return .quarterly
        }
    }
    
    private var trendData: [TrendDataPoint] {
        getTrendData()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 24 : 16) {
            // Header
            VStack(alignment: .leading, spacing: isIPad ? 16 : 8) {
                Text("Sahil's Progress Over Time")
                    .font(isIPad ? .system(size: 28, weight: .bold) : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Tracking \(games.count) games \(smartTimeframe.displayName.lowercased()) by \(smartTimeframe.displayName.lowercased())")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                            Button(timeframe.displayName) {
                                selectedTimeframe = timeframe
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Timeframe")
                            Text(selectedTimeframe.displayName)
                                .foregroundColor(.orange)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stat selector buttons
            VStack(alignment: .leading, spacing: 8) {
                ForEach(StatCategory.allCases, id: \.self) { category in
                    // Only show the section if there are stats for it
                    let statsForCategory = TrendStatType.allCases.filter { $0.category == category }
                    if !statsForCategory.isEmpty {
                        
                        StatSectionHeader(title: category.rawValue)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 4 : 3), spacing: isIPad ? 12 : 8) {
                            ForEach(statsForCategory, id: \.self) { stat in
                                ModernStatButton(
                                    stat: stat,
                                    isSelected: selectedStat == stat,
                                    isIPad: isIPad
                                ) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedStat = stat
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Chart
            if !trendData.isEmpty {
                VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
                    HStack {
                        Text("\(selectedStat.rawValue) - \(smartTimeframe.displayName)")
                            .font(isIPad ? .title3 : .headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedStat.color)
                        
                        Spacer()
                        
                        if let latest = trendData.last {
                            Text("Latest: \(formatValue(latest.value))")
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Chart {
                        ForEach(Array(trendData.enumerated()), id: \.offset) { index, dataPoint in
                            LineMark(
                                x: .value("Quarter", dataPoint.label),
                                y: .value(selectedStat.rawValue, dataPoint.value)
                            )
                            .foregroundStyle(selectedStat.color)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: isIPad ? 4 : 3))
                            
                            PointMark(
                                x: .value("Quarter", dataPoint.label),
                                y: .value(selectedStat.rawValue, dataPoint.value)
                            )
                            .foregroundStyle(selectedStat.color)
                            .symbolSize(isIPad ? 100 : 60)
                        }
                    }
                    .frame(height: isIPad ? 300 : 200)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(formatAxisValue(doubleValue))
                                        .font(isIPad ? .caption : .caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel {
                                if let stringValue = value.as(String.self) {
                                    Text(stringValue)
                                        .font(isIPad ? .caption : .caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: selectedStat)
                }
                .padding(isIPad ? 24 : 16)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                        .fill(selectedStat.color.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                        .stroke(selectedStat.color.opacity(0.2), lineWidth: 1)
                )
            } else {
                EmptyTrendsView(isIPad: isIPad)
            }
        }
    }
    
    private func getTrendData() -> [TrendDataPoint] {
        guard games.count >= 2 else { return [] }
        
        // For simplicity, group recent games by week/month
        let recentGames = Array(games.suffix(min(games.count, 20)))
        let calendar = Calendar.current
        
        switch smartTimeframe {
        case .auto, .weekly:
            return getWeeklyData(from: recentGames, calendar: calendar)
        case .monthly:
            return getMonthlyData(from: recentGames, calendar: calendar)
        case .quarterly:
            return getQuarterlyData(from: recentGames, calendar: calendar)
        }
    }

    /*
    private func getWeeklyData(from games: [Game], calendar: Calendar) -> [TrendDataPoint] {
        let gamesByWeek = Dictionary(grouping: games) { game in
            calendar.dateInterval(of: .weekOfYear, for: game.timestamp)?.start ?? game.timestamp
        }
        
        let sortedWeeks = gamesByWeek.keys.sorted()
        
        return sortedWeeks.compactMap { weekStart in
            guard let gamesInWeek = gamesByWeek[weekStart] else { return nil }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let label = formatter.string(from: weekStart)
            
            let value = calculateStatValue(for: gamesInWeek)
            return TrendDataPoint(label: label, value: value)
        }
    }
    */
    
    private func getWeeklyData(from games: [Game], calendar: Calendar) -> [TrendDataPoint] {
        // First, filter for games that have a valid timestamp.
        let validGames = games.filter { $0.timestamp != nil }
        
        let gamesByWeek = Dictionary(grouping: validGames) { game in
            // Force-unwrap is now safe because we filtered out nil values.
            let date = game.timestamp!
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        }
        
        let sortedWeeks = gamesByWeek.keys.sorted()
        
        return sortedWeeks.compactMap { weekStart in
            guard let gamesInWeek = gamesByWeek[weekStart] else { return nil }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let label = formatter.string(from: weekStart)
            
            let value = calculateStatValue(for: gamesInWeek)
            return TrendDataPoint(label: label, value: value)
        }
    }
    
    /*
    private func getMonthlyData(from games: [Game], calendar: Calendar) -> [TrendDataPoint] {
        let gamesByMonth = Dictionary(grouping: games) { game in
            let components = calendar.dateComponents([.year, .month], from: game.timestamp)
            return calendar.date(from: components) ?? game.timestamp
        }
        
        let sortedMonths = gamesByMonth.keys.sorted()
        
        return sortedMonths.compactMap { monthStart in
            guard let gamesInMonth = gamesByMonth[monthStart] else { return nil }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: monthStart)
            
            let value = calculateStatValue(for: gamesInMonth)
            return TrendDataPoint(label: label, value: value)
        }
    }
    */
    private func getMonthlyData(from games: [Game], calendar: Calendar) -> [TrendDataPoint] {
        // First, filter for games that have a valid timestamp.
        let validGames = games.filter { $0.timestamp != nil }
        
        let gamesByMonth = Dictionary(grouping: validGames) { game in
            // Force-unwrap is now safe.
            let date = game.timestamp!
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        }
        
        let sortedMonths = gamesByMonth.keys.sorted()
        
        return sortedMonths.compactMap { monthStart in
            guard let gamesInMonth = gamesByMonth[monthStart] else { return nil }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: monthStart)
            
            let value = calculateStatValue(for: gamesInMonth)
            return TrendDataPoint(label: label, value: value)
        }
    }
    
    /*
    private func getQuarterlyData(from games: [Game], calendar: Calendar) -> [TrendDataPoint] {
        let gamesByQuarter = Dictionary(grouping: games) { game in
            let components = calendar.dateComponents([.year, .month], from: game.timestamp)
            let quarter = ((components.month ?? 1) - 1) / 3 + 1
            let quarterStart = DateComponents(year: components.year, month: (quarter - 1) * 3 + 1)
            return calendar.date(from: quarterStart) ?? game.timestamp
        }
        
        let sortedQuarters = gamesByQuarter.keys.sorted()
        
        return sortedQuarters.compactMap { quarterStart in
            guard let gamesInQuarter = gamesByQuarter[quarterStart] else { return nil }
            
            let components = calendar.dateComponents([.year, .month], from: quarterStart)
            let quarter = ((components.month ?? 1) - 1) / 3 + 1
            let label = "Q\(quarter) '\(String(components.year ?? 0).suffix(2))"
            
            let value = calculateStatValue(for: gamesInQuarter)
            return TrendDataPoint(label: label, value: value)
        }
    }
     */
    private func getQuarterlyData(from games: [Game], calendar: Calendar) -> [TrendDataPoint] {
        // First, filter for games that have a valid timestamp.
        let validGames = games.filter { $0.timestamp != nil }
        
        let gamesByQuarter = Dictionary(grouping: validGames) { game in
            // Force-unwrap is now safe.
            let date = game.timestamp!
            let components = calendar.dateComponents([.year, .month], from: date)
            let quarter = ((components.month ?? 1) - 1) / 3 + 1
            let quarterStart = DateComponents(year: components.year, month: (quarter - 1) * 3 + 1)
            return calendar.date(from: quarterStart) ?? date
        }
        
        let sortedQuarters = gamesByQuarter.keys.sorted()
        
        return sortedQuarters.compactMap { quarterStart in
            guard let gamesInQuarter = gamesByQuarter[quarterStart] else { return nil }
            
            let components = calendar.dateComponents([.year, .month], from: quarterStart)
            let quarter = ((components.month ?? 1) - 1) / 3 + 1
            let label = "Q\(quarter) '\(String(components.year ?? 0).suffix(2))"
            
            let value = calculateStatValue(for: gamesInQuarter)
            return TrendDataPoint(label: label, value: value)
        }
    }
    
    private func calculateStatValue(for games: [Game]) -> Double {
        let gameCount = Double(games.count)
        guard gameCount > 0 else { return 0 }
        
        switch selectedStat {
        case .avgPoints:
            return Double(games.reduce(0) { $0 + $1.points }) / gameCount
        case .totalPoints:
            return Double(games.reduce(0) { $0 + $1.points })
        case .avgRebounds:
            return Double(games.reduce(0) { $0 + $1.rebounds }) / gameCount
        case .totalRebounds:
            return Double(games.reduce(0) { $0 + $1.rebounds })
        case .avgAssists:
            return Double(games.reduce(0) { $0 + $1.assists }) / gameCount
        case .totalAssists:
            return Double(games.reduce(0) { $0 + $1.assists })
        case .fieldGoalPct:
            let totalMade = games.reduce(0) { $0 + $1.fg2m + $1.fg3m }
            let totalAttempted = games.reduce(0) { $0 + $1.fg2a + $1.fg3a }
            return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
        case .threePointPct:
            let totalMade = games.reduce(0) { $0 + $1.fg3m }
            let totalAttempted = games.reduce(0) { $0 + $1.fg3a }
            return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
        case .freeThrowPct:
            let totalMade = games.reduce(0) { $0 + $1.ftm }
            let totalAttempted = games.reduce(0) { $0 + $1.fta }
            return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
        case .winRate:
            let wins = games.filter { $0.outcome == .win }.count
            return gameCount > 0 ? Double(wins) / gameCount * 100 : 0
        case .gamesPlayed:
            return gameCount
        case .avgPlayingTime:
            return Double(games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }) / gameCount
        case .playingTimePercentage:
            let totalPlayingTime = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }
            let totalPossibleGameTime = games.reduce(0) { $0 + $1.totalGameTimeMinutes }
            return totalPossibleGameTime > 0 ? (totalPlayingTime / totalPossibleGameTime) * 100 : 0
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
            let totalShots = games.reduce(0) { accumulator, game in
                let twoPointAttempts = game.fg2a
                let threePointAttempts = game.fg3a
                let freeThrowPossessions = Int(Double(game.fta) * 0.44)
                return accumulator + twoPointAttempts + threePointAttempts + freeThrowPossessions
            }
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
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if selectedStat.isPercentage {
            return String(format: "%.1f%%", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func formatAxisValue(_ value: Double) -> String {
        if selectedStat.isPercentage {
            return String(format: "%.0f%%", value)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Modern Stat Button

struct ModernStatButton: View {
    let stat: ModernCareerTrendsView.TrendStatType
    let isSelected: Bool
    let isIPad: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(stat.rawValue)
                .font(isIPad ? .body : .caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? stat.color : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 60 : 40)
                .padding(.horizontal, isIPad ? 12 : 8)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                        .fill(isSelected ? stat.color.opacity(0.15) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                        .stroke(isSelected ? stat.color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Empty Trends View

struct EmptyTrendsView: View {
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 24 : 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: isIPad ? 60 : 40))
                .foregroundColor(.secondary)
            
            Text("Keep Playing!")
                .font(isIPad ? .title : .headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Play a few more games to see trends over time")
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: isIPad ? 300 : 200)
        .frame(maxWidth: .infinity)
        .padding(isIPad ? 32 : 24)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 20 : 16)
    }
}

// MARK: - Supporting Data Models

struct TrendDataPoint {
    let label: String
    let value: Double
}
