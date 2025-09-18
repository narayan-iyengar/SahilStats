// File: SahilStats/Views/GameListView.swift (Clean Working Version)

import SwiftUI
import Charts

struct GameListView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @State private var selectedGame: Game?
    @State private var hoveredGameId: String?
    @State private var showingDeleteAlert = false
    @State private var gameToDelete: Game?
    @State private var isLoadingMore = false
    @State private var gamesPerPage = 10
    @State private var currentPage = 1
    @State private var isViewingTrends = false
    
    // Computed property to ensure games are sorted latest first
    private var sortedGames: [Game] {
        firebaseService.games.sorted { $0.timestamp > $1.timestamp }
    }
    
    // Paginated games
    private var displayedGames: [Game] {
        let endIndex = min(currentPage * gamesPerPage, sortedGames.count)
        return Array(sortedGames.prefix(endIndex))
    }
    
    private var hasMoreGames: Bool {
        displayedGames.count < sortedGames.count
    }
    
    var body: some View {
        Group {
            if firebaseService.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    Text("Loading games...")
                        .foregroundColor(.secondary)
                }
            } else if sortedGames.isEmpty {
                emptyStateView
            } else {
                gamesList
            }
        }
        .navigationTitle("Sahil's Basketball Stats")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if firebaseService.hasLiveGame {
                        liveGameButton
                    }
                    
                    if authService.canCreateGames {
                        addGameButton
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                if authService.isSignedIn {
                    userStatusIndicator
                }
            }
        }
        .sheet(item: $selectedGame) { game in
            GameDetailView(game: game)
        }
        .alert("Delete Game", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                gameToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let game = gameToDelete {
                    deleteGame(game)
                }
                gameToDelete = nil
            }
        } message: {
            if let game = gameToDelete {
                Text("Are you sure you want to delete the game against \(game.opponent)? This action cannot be undone.")
            }
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        .onAppear {
            firebaseService.startListening()
        }
        .onDisappear {
            firebaseService.stopListening()
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("No games yet!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start playing to see your stats here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if authService.canCreateGames {
                NavigationLink("Create Your First Game") {
                    GameSetupView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
    
    private var gamesList: some View {
        List {
            // Career stats section
            EnhancedCareerStatsView(
                stats: firebaseService.getCareerStats(),
                games: Array(sortedGames.prefix(10)),
                isViewingTrends: $isViewingTrends
            )
            .listRowBackground(Color.blue.opacity(0.08))
            .listRowSeparator(.hidden)
            
            // Only show games section when not viewing trends
            if !isViewingTrends {
                // Live game indicator if present
                if firebaseService.hasLiveGame {
                    LiveGameIndicatorView()
                        .listRowBackground(Color.red.opacity(0.1))
                }
                
                // Games section with pagination
                Section {
                    ForEach(displayedGames) { game in
                        GameRowView(
                            game: game,
                            isHovered: hoveredGameId == game.id,
                            canDelete: authService.canDeleteGames,
                            onTap: {
                                selectedGame = game
                            },
                            onDelete: {
                                gameToDelete = game
                                showingDeleteAlert = true
                            }
                        )
                        .onHover { isHovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredGameId = isHovering ? game.id : nil
                            }
                        }
                    }
                    
                    // Load more section
                    if hasMoreGames {
                        LoadMoreButton(
                            isLoading: isLoadingMore,
                            totalGames: sortedGames.count,
                            displayedGames: displayedGames.count,
                            onLoadMore: loadMoreGames
                        )
                        .listRowSeparator(.hidden)
                    }
                    
                } header: {
                    HStack {
                        Text("Recent Games")
                        Spacer()
                        if displayedGames.count < sortedGames.count {
                            Text("Showing \(displayedGames.count) of \(sortedGames.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var liveGameButton: some View {
        NavigationLink(destination: LiveGameView()) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var addGameButton: some View {
        NavigationLink(destination: GameSetupView()) {
            Image(systemName: "plus")
                .fontWeight(.semibold)
                .foregroundColor(.orange)
        }
    }
    
    private var userStatusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .clipShape(Circle())
    }
    
    // MARK: - Helper Methods
    
    private func loadMoreGames() {
        guard !isLoadingMore && hasMoreGames else { return }
        
        isLoadingMore = true
        
        // Simulate loading delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentPage += 1
            isLoadingMore = false
        }
    }
    
    private func deleteGame(_ game: Game) {
        Task {
            do {
                try await firebaseService.deleteGame(game.id ?? "")
            } catch {
                print("Failed to delete game: \(error)")
            }
        }
    }
}

// MARK: - Game Row Component

struct GameRowView: View {
    let game: Game
    let isHovered: Bool
    let canDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Game outcome indicator
            Circle()
                .fill(outcomeColor)
                .frame(width: isHovered ? 16 : 12, height: isHovered ? 16 : 12)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            VStack(alignment: .leading, spacing: 6) {
                // Teams and score
                HStack {
                    Text("\(game.teamName) vs \(game.opponent)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(game.myTeamScore) - \(game.opponentScore)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(outcomeColor)
                        
                        // Delete button (only show on hover for admins)
                        if canDelete && isHovered {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .transition(.opacity)
                        }
                    }
                }
                
                // Key stats
                HStack(spacing: 12) {
                    StatPill(label: "PTS", value: "\(game.points)", color: .purple)
                    StatPill(label: "REB", value: "\(game.rebounds)", color: .blue)
                    StatPill(label: "AST", value: "\(game.assists)", color: .green)
                    
                    Spacer()
                    
                    // Shooting efficiency
                    if game.fieldGoalPercentage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "target")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(Int(game.fieldGoalPercentage * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Date and location
                HStack {
                    if let location = game.location {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatRelativeDate(game.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Achievements
                if !game.achievements.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(game.achievements.prefix(5)), id: \.id) { achievement in
                                HStack(spacing: 2) {
                                    Text(achievement.emoji)
                                        .font(.caption)
                                    if isHovered {
                                        Text(achievement.name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                            }
                            
                            if game.achievements.count > 5 {
                                Text("+\(game.achievements.count - 5)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
            }
        }
        .padding(.vertical, isHovered ? 8 : 4)
        .padding(.horizontal, isHovered ? 4 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.05) : Color.clear)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: isHovered ? .gray.opacity(0.2) : .clear, radius: isHovered ? 4 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("View Details") {
                onTap()
            }
            
            if canDelete {
                Button("Delete Game", role: .destructive) {
                    onDelete()
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDelete {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .tint(.red)
            }
            
            Button("Details") {
                onTap()
            }
            .tint(.blue)
        }
    }
    
    private var outcomeColor: Color {
        switch game.outcome {
        case .win: return .green
        case .loss: return .red
        case .tie: return .gray
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Load More Component

struct LoadMoreButton: View {
    let isLoading: Bool
    let totalGames: Int
    let displayedGames: Int
    let onLoadMore: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(0.8)
                    
                    Text("Loading more games...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Button(action: onLoadMore) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Load More Games")
                                    .fontWeight(.semibold)
                                Text("\(totalGames - displayedGames) more available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .foregroundColor(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Progress indicator
                    VStack(spacing: 4) {
                        HStack {
                            Text("Showing \(displayedGames) of \(totalGames) games")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(Double(displayedGames) / Double(totalGames) * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        
                        ProgressView(value: Double(displayedGames), total: Double(totalGames))
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                            .scaleEffect(y: 0.5)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Supporting Components

struct StatPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundColor(color.opacity(0.8))
                .fontWeight(.medium)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
        .cornerRadius(6)
    }
}

// MARK: - Career Stats (Simplified)

struct EnhancedCareerStatsView: View {
    let stats: CareerStats
    let games: [Game]
    @State private var selectedTab = 0
    @Binding var isViewingTrends: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🏀 Sahil's Career Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Trends").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedTab) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isViewingTrends = (newValue == 1)
                }
            }
            
            // Content based on selected tab
            if selectedTab == 0 {
                OverviewStatsView(stats: stats)
            } else {
                CareerTrendsView(games: games)
            }
        }
        .padding()
    }
}

struct CareerTrendsView: View {
    let games: [Game]
    @State private var selectedStat: CareerStatType = .avgPoints
    
    enum CareerStatType: String, CaseIterable {
        case avgPoints = "Avg Points"
        case totalPoints = "Total Points"
        case avgRebounds = "Avg Rebounds"
        case totalRebounds = "Total Rebounds"
        case avgAssists = "Avg Assists"
        case totalAssists = "Total Assists"
        case totalSteals = "Total Steals"
        case totalBlocks = "Total Blocks"
        case fieldGoalPct = "Field Goal %"
        case threePointPct = "3-Point %"
        case freeThrowPct = "Free Throw %"
        case winPercentage = "Win Rate"
        case assistTurnoverRatio = "A/T Ratio"
        case gamesPerYear = "Games Played"
        
        var color: Color {
            switch self {
            case .totalPoints, .avgPoints: return .purple
            case .totalRebounds, .avgRebounds: return .mint
            case .totalAssists, .avgAssists: return .cyan
            case .totalSteals: return .yellow
            case .totalBlocks: return .red
            case .fieldGoalPct: return .blue
            case .threePointPct: return .green
            case .freeThrowPct: return .orange
            case .winPercentage: return .green
            case .assistTurnoverRatio: return .indigo
            case .gamesPerYear: return .blue
            }
        }
        
        var unit: String {
            switch self {
            case .fieldGoalPct, .threePointPct, .freeThrowPct, .winPercentage:
                return "%"
            default:
                return ""
            }
        }
        
        var isPercentage: Bool {
            switch self {
            case .fieldGoalPct, .threePointPct, .freeThrowPct, .winPercentage:
                return true
            default:
                return false
            }
        }
    }
    
    // Calculate Sahil's age at the time of each game
    private func calculateAgeAtGame(_ game: Game) -> Double {
        let birthday = Calendar.current.date(from: DateComponents(year: 2016, month: 11, day: 1))!
        let ageInSeconds = game.timestamp.timeIntervalSince(birthday)
        let ageInYears = ageInSeconds / (365.25 * 24 * 60 * 60) // Account for leap years
        return ageInYears
    }
    
    // Group games by year and calculate yearly stats
    private func getYearlyProgressionData() -> [(age: Double, value: Double)] {
        let calendar = Calendar.current
        
        // Group games by calendar year
        let gamesByYear = Dictionary(grouping: games) { game in
            calendar.component(.year, from: game.timestamp)
        }
        
        var yearlyData: [(age: Double, value: Double)] = []
        
        for year in gamesByYear.keys.sorted() {
            guard let gamesInYear = gamesByYear[year] else { continue }
            
            // Calculate Sahil's average age during this year
            let avgAge = gamesInYear.map { calculateAgeAtGame($0) }.reduce(0, +) / Double(gamesInYear.count)
            
            // Calculate the stat value for this year
            let value = calculateYearlyStatValue(for: gamesInYear, upToYear: year, allGamesByYear: gamesByYear)
            
            yearlyData.append((age: avgAge, value: value))
        }
        
        return yearlyData.sorted { $0.age < $1.age }
    }
    
    private func calculateYearlyStatValue(for yearGames: [Game], upToYear: Int, allGamesByYear: [Int: [Game]]) -> Double {
        let gameCount = Double(yearGames.count)
        
        switch selectedStat {
        case .avgPoints:
            return gameCount > 0 ? Double(yearGames.reduce(0) { $0 + $1.points }) / gameCount : 0
        case .totalPoints:
            // Cumulative total up to this year
            let allGamesUpToYear = allGamesByYear.filter { $0.key <= upToYear }.values.flatMap { $0 }
            return Double(allGamesUpToYear.reduce(0) { $0 + $1.points })
        case .avgRebounds:
            return gameCount > 0 ? Double(yearGames.reduce(0) { $0 + $1.rebounds }) / gameCount : 0
        case .totalRebounds:
            let allGamesUpToYear = allGamesByYear.filter { $0.key <= upToYear }.values.flatMap { $0 }
            return Double(allGamesUpToYear.reduce(0) { $0 + $1.rebounds })
        case .avgAssists:
            return gameCount > 0 ? Double(yearGames.reduce(0) { $0 + $1.assists }) / gameCount : 0
        case .totalAssists:
            let allGamesUpToYear = allGamesByYear.filter { $0.key <= upToYear }.values.flatMap { $0 }
            return Double(allGamesUpToYear.reduce(0) { $0 + $1.assists })
        case .totalSteals:
            return Double(yearGames.reduce(0) { $0 + $1.steals })
        case .totalBlocks:
            return Double(yearGames.reduce(0) { $0 + $1.blocks })
        case .fieldGoalPct:
            let totalMade = yearGames.reduce(0) { $0 + $1.fg2m + $1.fg3m }
            let totalAttempted = yearGames.reduce(0) { $0 + $1.fg2a + $1.fg3a }
            return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
        case .threePointPct:
            let totalMade = yearGames.reduce(0) { $0 + $1.fg3m }
            let totalAttempted = yearGames.reduce(0) { $0 + $1.fg3a }
            return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
        case .freeThrowPct:
            let totalMade = yearGames.reduce(0) { $0 + $1.ftm }
            let totalAttempted = yearGames.reduce(0) { $0 + $1.fta }
            return totalAttempted > 0 ? Double(totalMade) / Double(totalAttempted) * 100 : 0
        case .winPercentage:
            let wins = yearGames.filter { $0.outcome == .win }.count
            return gameCount > 0 ? Double(wins) / gameCount * 100 : 0
        case .assistTurnoverRatio:
            let totalAssists = yearGames.reduce(0) { $0 + $1.assists }
            let totalTurnovers = yearGames.reduce(0) { $0 + $1.turnovers }
            return totalTurnovers > 0 ? Double(totalAssists) / Double(totalTurnovers) : Double(totalAssists)
        case .gamesPerYear:
            return gameCount
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stat selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Sahil's Development Over Time")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Track how Sahil's skills have grown as he gets older")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Clickable stat grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(CareerStatType.allCases, id: \.self) { stat in
                        CareerTrendStatButton(
                            stat: stat,
                            isSelected: selectedStat == stat
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedStat = stat
                            }
                        }
                    }
                }
            }
            
            // Chart for selected stat
            if !games.isEmpty {
                let yearlyData = getYearlyProgressionData()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(selectedStat.rawValue) by Age")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedStat.color)
                        
                        Spacer()
                        
                        // Show current age and value
                        let currentAge = calculateAgeAtGame(games.first ?? Game(teamName: "", opponent: ""))
                        let currentValue = yearlyData.last?.value ?? 0
                        Text("Age \(String(format: "%.1f", currentAge)): \(String(format: selectedStat.isPercentage ? "%.1f" : "%.1f", currentValue))\(selectedStat.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Chart {
                        ForEach(yearlyData, id: \.age) { dataPoint in
                            LineMark(
                                x: .value("Age", dataPoint.age),
                                y: .value(selectedStat.rawValue, dataPoint.value)
                            )
                            .foregroundStyle(selectedStat.color)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Age", dataPoint.age),
                                y: .value(selectedStat.rawValue, dataPoint.value)
                            )
                            .foregroundStyle(selectedStat.color)
                            .symbolSize(40)
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(String(format: selectedStat.isPercentage ? "%.0f" : "%.0f", doubleValue))\(selectedStat.unit)")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(String(format: "%.1f", doubleValue))")
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: selectedStat)
                }
                .padding()
                .background(selectedStat.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedStat.color.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
            } else {
                Text("Not enough games to show Sahil's development over time")
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            }
        }
    }
}

struct CareerTrendStatButton: View {
    let stat: CareerTrendsView.CareerStatType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(stat.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? stat.color : .secondary)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 45)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? stat.color.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? stat.color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct OverviewStatsView: View {
    let stats: CareerStats
    
    var body: some View {
        VStack(spacing: 12) {
            // First row: Main stats
            HStack(spacing: 20) {
                StatBox(title: "Games", value: "\(stats.totalGames)", color: .blue)
                StatBox(title: "Points", value: "\(stats.totalPoints)", color: .purple)
                StatBox(title: "Avg", value: String(format: "%.1f", stats.averagePoints), color: .indigo)
                StatBox(title: "Win %", value: String(format: "%.0f%%", stats.winPercentage * 100), color: stats.winPercentage > 0.5 ? .green : .red)
            }
            
            // Second row: Other key stats
            HStack(spacing: 20) {
                StatBox(title: "Rebounds", value: "\(stats.totalRebounds)", color: .mint)
                StatBox(title: "Assists", value: "\(stats.totalAssists)", color: .cyan)
                StatBox(title: "Steals", value: "\(stats.totalSteals)", color: .yellow)
                StatBox(title: "Fouls", value: "\(stats.totalFouls)", color: .pink)
            }
            
            // Third row: Shooting percentages
            HStack(spacing: 20) {
                StatBox(title: "FG%", value: String(format: "%.0f%%", stats.fieldGoalPercentage * 100), color: .blue)
                StatBox(title: "3P%", value: String(format: "%.0f%%", stats.threePointPercentage * 100), color: .green)
                StatBox(title: "FT%", value: String(format: "%.0f%%", stats.freeThrowPercentage * 100), color: .orange)
                StatBox(title: "A/T", value: String(format: "%.1f", stats.assistTurnoverRatio), color: .indigo)
            }
        }
    }
}

struct TrendsView: View {
    let games: [Game]
    @State private var selectedStat: StatType = .points
    
    enum StatType: String, CaseIterable {
        case points = "Points"
        case rebounds = "Rebounds"
        case assists = "Assists"
        case steals = "Steals"
        case blocks = "Blocks"
        case fouls = "Fouls"
        case turnovers = "Turnovers"
        case fg2m = "2PT Made"
        case fg2a = "2PT Att"
        case fg3m = "3PT Made"
        case fg3a = "3PT Att"
        case ftm = "FT Made"
        case fta = "FT Att"
        case fieldGoalPct = "FG%"
        case threePointPct = "3P%"
        case freeThrowPct = "FT%"
        case assistTurnoverRatio = "A/T Ratio"
        
        var color: Color {
            switch self {
            case .points: return .purple
            case .rebounds: return .mint
            case .assists: return .cyan
            case .steals: return .yellow
            case .blocks: return .red
            case .fouls: return .pink
            case .turnovers: return .red.opacity(0.8)
            case .fg2m, .fg2a: return .blue
            case .fg3m, .fg3a: return .green
            case .ftm, .fta: return .orange
            case .fieldGoalPct: return .blue
            case .threePointPct: return .green
            case .freeThrowPct: return .orange
            case .assistTurnoverRatio: return .indigo
            }
        }
        
        func getValue(from game: Game) -> Double {
            switch self {
            case .points: return Double(game.points)
            case .rebounds: return Double(game.rebounds)
            case .assists: return Double(game.assists)
            case .steals: return Double(game.steals)
            case .blocks: return Double(game.blocks)
            case .fouls: return Double(game.fouls)
            case .turnovers: return Double(game.turnovers)
            case .fg2m: return Double(game.fg2m)
            case .fg2a: return Double(game.fg2a)
            case .fg3m: return Double(game.fg3m)
            case .fg3a: return Double(game.fg3a)
            case .ftm: return Double(game.ftm)
            case .fta: return Double(game.fta)
            case .fieldGoalPct: return game.fieldGoalPercentage * 100
            case .threePointPct: return game.threePointPercentage * 100
            case .freeThrowPct: return game.freeThrowPercentage * 100
            case .assistTurnoverRatio: return game.assistTurnoverRatio
            }
        }
        
        var unit: String {
            switch self {
            case .fieldGoalPct, .threePointPct, .freeThrowPct:
                return "%"
            default:
                return ""
            }
        }
        
        var isPercentage: Bool {
            switch self {
            case .fieldGoalPct, .threePointPct, .freeThrowPct:
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stat selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance Trends")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Tap a stat to see its trend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Clickable stat grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(StatType.allCases, id: \.self) { stat in
                        TrendStatButton(
                            stat: stat,
                            games: games,
                            isSelected: selectedStat == stat
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedStat = stat
                            }
                        }
                    }
                }
            }
            
            // Chart for selected stat
            if !games.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(selectedStat.rawValue) Trend")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedStat.color)
                        
                        Spacer()
                        
                        // Show average
                        let average = games.map { selectedStat.getValue(from: $0) }.reduce(0, +) / Double(games.count)
                        Text("Avg: \(String(format: selectedStat.isPercentage ? "%.1f" : "%.1f", average))\(selectedStat.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Chart {
                        ForEach(Array(games.enumerated()), id: \.offset) { index, game in
                            LineMark(
                                x: .value("Game", index + 1),
                                y: .value(selectedStat.rawValue, selectedStat.getValue(from: game))
                            )
                            .foregroundStyle(selectedStat.color)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Game", index + 1),
                                y: .value(selectedStat.rawValue, selectedStat.getValue(from: game))
                            )
                            .foregroundStyle(selectedStat.color)
                            .symbolSize(40)
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(String(format: selectedStat.isPercentage ? "%.0f" : "%.0f", doubleValue))\(selectedStat.unit)")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("G\(intValue)")
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: selectedStat)
                }
                .padding()
                .background(selectedStat.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedStat.color.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
            } else {
                Text("Not enough games for trends")
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            }
        }
    }
}

struct TrendStatButton: View {
    let stat: TrendsView.StatType
    let games: [Game]
    let isSelected: Bool
    let action: () -> Void
    
    private var latestValue: Double {
        guard let latestGame = games.first else { return 0 }
        return stat.getValue(from: latestGame)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(stat.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? stat.color : .secondary)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text("\(String(format: stat.isPercentage ? "%.0f" : "%.0f", latestValue))\(stat.unit)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? stat.color : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? stat.color.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? stat.color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Live Game Components

struct LiveGameIndicatorView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(0.8)
                .animation(.easeInOut(duration: 1).repeatForever(), value: true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("🔴 Live Game in Progress")
                    .font(.headline)
                    .foregroundColor(.red)
                
                if let liveGame = firebaseService.getCurrentLiveGame() {
                    Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Period \(liveGame.period) • \(liveGame.currentClockDisplay)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            NavigationLink(destination: LiveGameView()) {
                Text("Watch")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct LiveGameView: View {
    var body: some View {
        Text("Live Game View")
            .navigationTitle("Live Game")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Game Detail View (Simplified)

struct GameDetailView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    gameHeader
                    
                    // Stats
                    gameStats
                    
                    // Achievements
                    if !game.achievements.isEmpty {
                        achievementsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var gameHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.teamName) vs \(game.opponent)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(game.outcome.emoji)
                    .font(.title)
            }
            
            Text("Final Score: \(game.myTeamScore) - \(game.opponentScore)")
                .font(.title2)
                .foregroundColor(game.outcome == .win ? .green : .red)
            
            Text(game.formattedDate)
                .foregroundColor(.secondary)
            
            if let location = game.location {
                Text("📍 \(location)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var gameStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Stats")
                .font(.headline)
            
            // First row: Shooting stats (6 stats)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                DetailStatCard(title: "Points", value: "\(game.points)", color: .purple)
                DetailStatCard(title: "2PT Made", value: "\(game.fg2m)", color: .blue)
                DetailStatCard(title: "2PT Att", value: "\(game.fg2a)", color: .blue)
                DetailStatCard(title: "3PT Made", value: "\(game.fg3m)", color: .green)
                DetailStatCard(title: "3PT Att", value: "\(game.fg3a)", color: .green)
                DetailStatCard(title: "FT Made", value: "\(game.ftm)", color: .orange)
            }
            
            // Second row: Other stats (6 stats)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                DetailStatCard(title: "FT Att", value: "\(game.fta)", color: .orange)
                DetailStatCard(title: "Rebounds", value: "\(game.rebounds)", color: .mint)
                DetailStatCard(title: "Assists", value: "\(game.assists)", color: .cyan)
                DetailStatCard(title: "Steals", value: "\(game.steals)", color: .yellow)
                DetailStatCard(title: "Blocks", value: "\(game.blocks)", color: .red)
                DetailStatCard(title: "Fouls", value: "\(game.fouls)", color: .pink)
            }
            
            // Third row: Advanced stats (2 stats)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                DetailStatCard(title: "Turnovers", value: "\(game.turnovers)", color: .red)
                DetailStatCard(title: "A/T Ratio", value: String(format: "%.2f", game.assistTurnoverRatio), color: .indigo)
            }
            
            // Fourth section: Shooting percentages
            VStack(alignment: .leading, spacing: 12) {
                Text("Shooting Percentages")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    ShootingPercentageCard(
                        title: "Field Goal",
                        percentage: game.fieldGoalPercentage,
                        made: game.fg2m + game.fg3m,
                        attempted: game.fg2a + game.fg3a,
                        color: .blue
                    )
                    ShootingPercentageCard(
                        title: "Two Point",
                        percentage: game.twoPointPercentage,
                        made: game.fg2m,
                        attempted: game.fg2a,
                        color: .blue
                    )
                    ShootingPercentageCard(
                        title: "Three Point",
                        percentage: game.threePointPercentage,
                        made: game.fg3m,
                        attempted: game.fg3a,
                        color: .green
                    )
                    ShootingPercentageCard(
                        title: "Free Throw",
                        percentage: game.freeThrowPercentage,
                        made: game.ftm,
                        attempted: game.fta,
                        color: .orange
                    )
                }
            }
        }
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(game.achievements, id: \.id) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
    }
}

struct DetailStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct ShootingPercentageCard: View {
    let title: String
    let percentage: Double
    let made: Int
    let attempted: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text("\(Int(percentage * 100))%")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("\(made)/\(attempted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 8) {
            Text(achievement.emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

#Preview {
    GameListView()
        .environmentObject(AuthService())
}
