// File: SahilStats/Views/FilterViews.swift (Fixed Version)

import SwiftUI

// MARK: - Date Range Enum (Move this to GameListView or make it global)

enum GameDateRange: String, CaseIterable {
    case all = "All Time"
    case week = "Last Week"
    case month = "Last Month"
    case quarter = "Last 3 Months"
    case year = "Last Year"
    case custom = "Custom Range"
    
    func dateFilter(from startDate: Date, to endDate: Date) -> (Date, Date)? {
        let now = Date()
        switch self {
        case .all:
            return nil
        case .week:
            return (Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) ?? now, now)
        case .month:
            return (Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now, now)
        case .quarter:
            return (Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now, now)
        case .year:
            return (Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now, now)
        case .custom:
            return (startDate, endDate)
        }
    }
}


// MARK: - Main Filter Sheet View

struct FilterView: View {
    @Binding var selectedTeamFilter: String
    @Binding var selectedOpponentFilter: String
    @Binding var selectedOutcomeFilter: GameOutcome?
    @Binding var selectedDateRange: GameListView.DateRange  // Use the existing enum from GameListView
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    
    let availableTeams: [String]
    let availableOpponents: [String]
    let onClearAll: () -> Void
    let isIPad: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Team Filter
                Section("Team") {
                    Picker("Team", selection: $selectedTeamFilter) {
                        ForEach(availableTeams, id: \.self) { team in
                            Text(team).tag(team)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Opponent Filter
                Section("Opponent") {
                    Picker("Opponent", selection: $selectedOpponentFilter) {
                        ForEach(availableOpponents, id: \.self) { opponent in
                            Text(opponent).tag(opponent)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Outcome Filter
                Section("Game Outcome") {
                    HStack {
                        ForEach([GameOutcome.win, GameOutcome.loss, GameOutcome.tie], id: \.self) { outcome in
                            Button(action: {
                                selectedOutcomeFilter = selectedOutcomeFilter == outcome ? nil : outcome
                            }) {
                                HStack {
                                    Text(outcome.emoji)
                                    Text(outcome.displayName)
                                        .font(.subheadline)
                                }
                                .foregroundColor(selectedOutcomeFilter == outcome ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedOutcomeFilter == outcome ? Color.orange : Color(.systemGray5))
                                )
                            }
                            .buttonStyle(PillButtonStyle(isIPad: isIPad))
                        }
                    }
                }
                
                // Date Range Filter
                Section("Date Range") {
                    Picker("Date Range", selection: $selectedDateRange) {
                        ForEach(GameListView.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedDateRange == .custom {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                    }
                }
                
                // Actions
                Section {
                    Button("Clear All Filters") {
                        onClearAll()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Filter Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Active Filters Display View

struct ActiveFiltersView: View {
    let searchText: String
    let selectedTeamFilter: String
    let selectedOpponentFilter: String
    let selectedOutcomeFilter: GameOutcome?
    let selectedDateRange: GameListView.DateRange  // Use the existing enum
    let filteredCount: Int
    let totalCount: Int
    let onClearAll: () -> Void
    
    // Computed properties to break up complex expressions
    private var hasSearchFilter: Bool {
        !searchText.isEmpty
    }
    
    private var hasTeamFilter: Bool {
        selectedTeamFilter != "All Teams"
    }
    
    private var hasOpponentFilter: Bool {
        selectedOpponentFilter != "All Opponents"
    }
    
    private var hasDateFilter: Bool {
        selectedDateRange != .all
    }
    
    private var percentageText: String {
        let percentage = Int(Double(filteredCount) / Double(totalCount) * 100)
        return "\(percentage)% of games"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with clear button
            headerView
            
            // Filter chips
            filterChipsView
            
            // Results summary
            resultsSummaryView
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundColor(.orange)
            
            Text("Active Filters")
                .font(.headline)
                .foregroundColor(.orange)
            
            Spacer()
            
            Button("Clear All") {
                onClearAll()
            }
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if hasSearchFilter {
                    FilterChip(text: "Search: \"\(searchText)\"", color: .blue)
                }
                
                if hasTeamFilter {
                    FilterChip(text: "Team: \(selectedTeamFilter)", color: .green)
                }
                
                if hasOpponentFilter {
                    FilterChip(text: "vs \(selectedOpponentFilter)", color: .purple)
                }
                
                if let outcome = selectedOutcomeFilter {
                    let chipText = "\(outcome.emoji) \(outcome.displayName)"
                    FilterChip(text: chipText, color: .orange)
                }
                
                if hasDateFilter {
                    FilterChip(text: selectedDateRange.rawValue, color: .indigo)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var resultsSummaryView: some View {
        HStack {
            Text("Showing \(filteredCount) of \(totalCount) games")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if filteredCount != totalCount {
                Text(percentageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Quick Filter Buttons

struct QuickFilterButtons: View {
    @Binding var selectedOutcomeFilter: GameOutcome?
    @Binding var selectedDateRange: GameListView.DateRange  // Use the existing enum
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Outcome filters
            HStack(spacing: 8) {
                Text("Quick Filters:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach([GameOutcome.win, GameOutcome.loss], id: \.self) { outcome in
                    Button(action: {
                        selectedOutcomeFilter = selectedOutcomeFilter == outcome ? nil : outcome
                    }) {
                        HStack(spacing: 4) {
                            Text(outcome.emoji)
                            Text(outcome.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(selectedOutcomeFilter == outcome ? .white : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedOutcomeFilter == outcome ? Color.orange : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PillButtonStyle(isIPad: isIPad))
                }
                
                Spacer()
            }
            
            // Date range filters
            HStack(spacing: 8) {
                ForEach([GameListView.DateRange.week, GameListView.DateRange.month, GameListView.DateRange.quarter], id: \.self) { range in
                    Button(action: {
                        selectedDateRange = selectedDateRange == range ? .all : range
                    }) {
                        Text(range.rawValue)
                            .font(.caption2)
                            .foregroundColor(selectedDateRange == range ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedDateRange == range ? Color.blue : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(PillButtonStyle(isIPad: isIPad))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Search Results Summary

struct SearchResultsSummary: View {
    let searchText: String
    let filteredCount: Int
    let totalCount: Int
    
    var body: some View {
        if !searchText.isEmpty {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                
                Text("Search results for \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredCount) found")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Filter Statistics View

struct FilterStatsView: View {
    let filteredGames: [Game]
    let totalGames: [Game]
    
    private var stats: FilterStats {
        FilterStats(filtered: filteredGames, total: totalGames)
    }
    
    private var shouldShowStats: Bool {
        filteredGames.count != totalGames.count && !filteredGames.isEmpty
    }
    
    private var gamesCountText: String {
        "\(filteredGames.count) of \(totalGames.count) games"
    }
    
    private var avgPointsText: String {
        String(format: "%.1f", stats.avgPoints)
    }
    
    private var winRateText: String {
        String(format: "%.0f%%", stats.winRate * 100)
    }
    
    private var gamesCountValueText: String {
        "\(filteredGames.count)"
    }
    
    var body: some View {
        if shouldShowStats {
            VStack(spacing: 12) {
                statsHeaderView
                statsCardsView
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var statsHeaderView: some View {
        HStack {
            Text("Filter Results")
                .font(.headline)
                .foregroundColor(.orange)
            
            Spacer()
            
            Text(gamesCountText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statsCardsView: some View {
        HStack(spacing: 20) {
            StatSummaryCard(
                title: "Avg Points",
                value: avgPointsText,
                change: stats.avgPointsChange,
                color: .purple
            )
            
            StatSummaryCard(
                title: "Win Rate",
                value: winRateText,
                change: stats.winRateChange,
                color: .green
            )
            
            StatSummaryCard(
                title: "Games",
                value: gamesCountValueText,
                change: nil,
                color: .blue
            )
        }
    }
}

struct StatSummaryCard: View {
    let title: String
    let value: String
    let change: Double?
    let color: Color
    
    private var hasChange: Bool {
        change != nil
    }
    
    private var changeValue: Double {
        change ?? 0
    }
    
    private var isPositiveChange: Bool {
        changeValue >= 0
    }
    
    private var changeText: String {
        String(format: "%.1f", abs(changeValue))
    }
    
    private var changeColor: Color {
        isPositiveChange ? .green : .red
    }
    
    private var changeIcon: String {
        isPositiveChange ? "arrow.up" : "arrow.down"
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if hasChange {
                changeIndicatorView
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var changeIndicatorView: some View {
        HStack(spacing: 2) {
            Image(systemName: changeIcon)
                .font(.caption2)
            Text(changeText)
                .font(.caption2)
        }
        .foregroundColor(changeColor)
    }
}

// MARK: - Supporting Data Models

struct FilterStats {
    let avgPoints: Double
    let winRate: Double
    let avgPointsChange: Double?
    let winRateChange: Double?
    
    init(filtered: [Game], total: [Game]) {
        // Filtered stats
        let filteredPoints = filtered.reduce(0) { $0 + $1.points }
        self.avgPoints = filtered.isEmpty ? 0 : Double(filteredPoints) / Double(filtered.count)
        
        let filteredWins = filtered.filter { $0.outcome == .win }.count
        self.winRate = filtered.isEmpty ? 0 : Double(filteredWins) / Double(filtered.count)
        
        // Total stats for comparison
        let totalPoints = total.reduce(0) { $0 + $1.points }
        let totalAvgPoints = total.isEmpty ? 0 : Double(totalPoints) / Double(total.count)
        
        let totalWins = total.filter { $0.outcome == .win }.count
        let totalWinRate = total.isEmpty ? 0 : Double(totalWins) / Double(total.count)
        
        // Calculate changes
        self.avgPointsChange = total.isEmpty ? nil : avgPoints - totalAvgPoints
        self.winRateChange = total.isEmpty ? nil : winRate - totalWinRate
    }
}
