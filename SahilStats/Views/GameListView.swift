// File: SahilStats/Views/GameListView.swift (Updated for larger iPad modal)

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
    @State private var showingLiveGame = false
    
    // MARK: - NEW: Search and Filter States
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedTeamFilter = "All Teams"
    @State private var selectedOpponentFilter = "All Opponents"
    @State private var selectedOutcomeFilter: GameOutcome? = nil
    @State private var selectedDateRange: DateRange = .all
    @State private var showingDatePicker = false
    @State private var customStartDate = Date().addingTimeInterval(-30*24*60*60) // 30 days ago
    @State private var customEndDate = Date()
    
    // iPad detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    // MARK: - Date Range Filter
    enum DateRange: String, CaseIterable {
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
    
    // MARK: - Computed Properties
    
    // Base games (sorted)
    private var sortedGames: [Game] {
        firebaseService.games.sorted { $0.timestamp > $1.timestamp }
    }
    
    // Available teams and opponents for filters
    private var availableTeams: [String] {
        let teamSet = Set(sortedGames.map(\.teamName))
        let sortedTeams = Array(teamSet).sorted()
        return ["All Teams"] + sortedTeams
    }
    
    private var availableOpponents: [String] {
        let opponentSet = Set(sortedGames.map(\.opponent))
        let sortedOpponents = Array(opponentSet).sorted()
        return ["All Opponents"] + sortedOpponents
    }
    
    // FIXED: Broken-up filtering logic to prevent compilation timeout
    private var filteredGames: [Game] {
        var games = sortedGames
        
        // Apply text search filter
        games = applySearchFilter(to: games)
        
        // Apply team filter
        games = applyTeamFilter(to: games)
        
        // Apply opponent filter
        games = applyOpponentFilter(to: games)
        
        // Apply outcome filter
        games = applyOutcomeFilter(to: games)
        
        // Apply date range filter
        games = applyDateRangeFilter(to: games)
        
        return games
    }
    
    // FIXED: Individual filter methods to simplify compilation
    private func applySearchFilter(to games: [Game]) -> [Game] {
        guard !searchText.isEmpty else { return games }
        
        return games.filter { game in
            let teamMatches = game.teamName.localizedCaseInsensitiveContains(searchText)
            let opponentMatches = game.opponent.localizedCaseInsensitiveContains(searchText)
            let locationMatches = game.location?.localizedCaseInsensitiveContains(searchText) ?? false
            
            return teamMatches || opponentMatches || locationMatches
        }
    }
    
    private func applyTeamFilter(to games: [Game]) -> [Game] {
        guard selectedTeamFilter != "All Teams" else { return games }
        return games.filter { $0.teamName == selectedTeamFilter }
    }
    
    private func applyOpponentFilter(to games: [Game]) -> [Game] {
        guard selectedOpponentFilter != "All Opponents" else { return games }
        return games.filter { $0.opponent == selectedOpponentFilter }
    }
    
    private func applyOutcomeFilter(to games: [Game]) -> [Game] {
        guard let outcome = selectedOutcomeFilter else { return games }
        return games.filter { $0.outcome == outcome }
    }
    
    private func applyDateRangeFilter(to games: [Game]) -> [Game] {
        guard let dateFilter = selectedDateRange.dateFilter(from: customStartDate, to: customEndDate) else {
            return games
        }
        
        let (startDate, endDate) = dateFilter
        return games.filter { game in
            game.timestamp >= startDate && game.timestamp <= endDate
        }
    }
    
    // Paginated games
    private var displayedGames: [Game] {
        let endIndex = min(currentPage * gamesPerPage, filteredGames.count)
        return Array(filteredGames.prefix(endIndex))
    }
    
    private var hasMoreGames: Bool {
        displayedGames.count < filteredGames.count
    }
    
    // Active filters count
    private var activeFiltersCount: Int {
        var count = 0
        if selectedTeamFilter != "All Teams" { count += 1 }
        if selectedOpponentFilter != "All Opponents" { count += 1 }
        if selectedOutcomeFilter != nil { count += 1 }
        if selectedDateRange != .all { count += 1 }
        return count
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
                    // Filter button with badge
                    Button(action: {
                        showingFilters = true
                    }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(.orange)
                            
                            if activeFiltersCount > 0 {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text("\(activeFiltersCount)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(2)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    
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
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedTeamFilter: $selectedTeamFilter,
                selectedOpponentFilter: $selectedOpponentFilter,
                selectedOutcomeFilter: $selectedOutcomeFilter,
                selectedDateRange: $selectedDateRange,
                customStartDate: $customStartDate,
                customEndDate: $customEndDate,
                availableTeams: availableTeams,
                availableOpponents: availableOpponents,
                onClearAll: clearAllFilters,
                isIPad: isIPad
            )
        }
        .fullScreenCover(isPresented: $showingLiveGame) {
            LiveGameFullScreenView {
                showingLiveGame = false
            }
            .environmentObject(authService)
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
        .onChange(of: searchText) { _, _ in
            resetPagination()
        }
        .onChange(of: selectedTeamFilter) { _, _ in
            resetPagination()
        }
        .onChange(of: selectedOpponentFilter) { _, _ in
            resetPagination()
        }
        .onChange(of: selectedOutcomeFilter) { _, _ in
            resetPagination()
        }
        .onChange(of: selectedDateRange) { _, _ in
            resetPagination()
        }
    }
    
    // MARK: - Views
    
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
            // Career stats section (only if not heavily filtered)
            if activeFiltersCount <= 1 && searchText.isEmpty {
                EnhancedCareerStatsView(
                    stats: firebaseService.getCareerStats(),
                    games: Array(sortedGames.prefix(10)),
                    isViewingTrends: $isViewingTrends
                )
                .listRowBackground(Color.blue.opacity(0.08))
                .listRowSeparator(.hidden)
            }
            
            // Only show games section when not viewing trends
            if !isViewingTrends {
                // Active filters display
                if activeFiltersCount > 0 || !searchText.isEmpty {
                    ActiveFiltersView(
                        searchText: searchText,
                        selectedTeamFilter: selectedTeamFilter,
                        selectedOpponentFilter: selectedOpponentFilter,
                        selectedOutcomeFilter: selectedOutcomeFilter,
                        selectedDateRange: selectedDateRange,
                        filteredCount: filteredGames.count,
                        totalCount: sortedGames.count,
                        onClearAll: clearAllFilters
                    )
                    .listRowBackground(Color.orange.opacity(0.05))
                    .listRowSeparator(.hidden)
                }
                
                // Live game indicator if present
                if firebaseService.hasLiveGame {
                    LiveGameIndicatorView(onTap: {
                        showingLiveGame = true
                    })
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
                            totalGames: filteredGames.count,
                            displayedGames: displayedGames.count,
                            onLoadMore: loadMoreGames
                        )
                        .listRowSeparator(.hidden)
                    }
                    
                } header: {
                    HStack {
                        Text(filteredGames.count == sortedGames.count ? "Recent Games" : "Filtered Games")
                        Spacer()
                        if displayedGames.count < filteredGames.count {
                            Text("Showing \(displayedGames.count) of \(filteredGames.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // ... (keep all existing helper methods: liveGameButton, addGameButton, etc.)
    
    // MARK: - New Helper Methods
    
    private func clearAllFilters() {
        searchText = ""
        selectedTeamFilter = "All Teams"
        selectedOpponentFilter = "All Opponents"
        selectedOutcomeFilter = nil
        selectedDateRange = .all
        resetPagination()
    }
    
    private func resetPagination() {
        currentPage = 1
    }
    
    private func loadMoreGames() {
        guard !isLoadingMore && hasMoreGames else { return }
        
        isLoadingMore = true
        
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
    
    // MARK: - Existing helper methods (keep these unchanged)
    private var liveGameButton: some View {
        Button(action: {
            showingLiveGame = true
        }) {
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
    
    @ViewBuilder
    private func LiveGameFullScreenView(onDismiss: @escaping () -> Void) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                FullScreenNavigationBar(onDismiss: onDismiss)
                LiveGameView().environmentObject(authService)
            }
        }
    }
    
    @ViewBuilder
    private func FullScreenNavigationBar(onDismiss: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                Text("Live Game")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
}

// Keep all existing structs: LiveGameIndicatorView, GameRowView, LoadMoreButton, etc.

// MARK: - Live Game Components (Updated)

struct LiveGameIndicatorView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Game in Progress")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    if let liveGame = firebaseService.getCurrentLiveGame() {
                        Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Period \(liveGame.period) - \(formatClock(liveGame.clock))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Watch/Control")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func formatClock(_ time: TimeInterval) -> String {
        if time <= 59 {
            return String(format: "%.1f", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Game Row Component (keeping same implementation)

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

// MARK: - Career Stats (Simplified - keeping existing implementation)

struct EnhancedCareerStatsView: View {
    let stats: CareerStats
    let games: [Game]
    @State private var selectedTab = 0
    @Binding var isViewingTrends: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 24 : 16) {
            HStack {
                Text("Sahil's Career Dashboard")
                    .font(isIPad ? .largeTitle : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Tab selector with larger fonts on iPad
            Picker("View", selection: $selectedTab) {
                Text("Overview")
                    .font(isIPad ? .title2 : .body)
                    .tag(0)
                Text("Trends")
                    .font(isIPad ? .title2 : .body)
                    .tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedTab) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isViewingTrends = (newValue == 1)
                }
            }
            
            // Content based on selected tab
            if selectedTab == 0 {
                OverviewStatsView(stats: stats, isIPad: isIPad)
            } else {
                CareerTrendsView(games: games, isIPad: isIPad)
            }
        }
        .padding(isIPad ? 24 : 16)
    }
}


// MARK: - Career Stats Components
// Replace your existing CareerTrendsView with this smart version:

struct CareerTrendsView: View {
    let games: [Game]
    let isIPad: Bool
    @State private var selectedStat: CareerStatType = .avgPoints
    @State private var selectedTimeframe: TrendTimeframe = .auto
    
    enum CareerStatType: String, CaseIterable {
        case avgPoints = "Avg Points"
        case totalPoints = "Total Points"
        case avgRebounds = "Avg Rebounds"
        case totalRebounds = "Total Rebounds"
        case avgAssists = "Avg Assists"
        case totalAssists = "Total Assists"
        case fieldGoalPct = "Field Goal %"
        case threePointPct = "3-Point %"
        case freeThrowPct = "Free Throw %"
        case winPercentage = "Win Rate"
        case gamesPlayed = "Games Played"
        
        var color: Color {
            switch self {
            case .totalPoints, .avgPoints: return .purple
            case .totalRebounds, .avgRebounds: return .mint
            case .totalAssists, .avgAssists: return .cyan
            case .fieldGoalPct: return .blue
            case .threePointPct: return .green
            case .freeThrowPct: return .orange
            case .winPercentage: return .green
            case .gamesPlayed: return .blue
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
    
    enum TrendTimeframe: String, CaseIterable {
        case auto = "Auto"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
        
        var displayName: String { rawValue }
        
        var description: String {
            switch self {
            case .auto: return "Smart timeframe based on data"
            case .weekly: return "Week by week progress"
            case .monthly: return "Month by month progress"
            case .quarterly: return "Quarter by quarter progress"
            case .yearly: return "Year by year progress"
            }
        }
    }
    
    private var smartTimeframe: TrendTimeframe {
        if selectedTimeframe != .auto {
            return selectedTimeframe
        }
        
        let gameCount = games.count
        let dateRange = getDateRange()
        
        if gameCount < 5 {
            return .weekly
        } else if dateRange.days < 60 {
            return .weekly
        } else if dateRange.days < 180 {
            return .monthly
        } else if dateRange.years < 2 {
            return .quarterly
        } else {
            return .yearly
        }
    }
    
    private func getDateRange() -> (days: Int, years: Double) {
        guard let oldestGame = games.min(by: { $0.timestamp < $1.timestamp }),
              let newestGame = games.max(by: { $0.timestamp < $1.timestamp }) else {
            return (days: 0, years: 0)
        }
        
        let timeInterval = newestGame.timestamp.timeIntervalSince(oldestGame.timestamp)
        let days = Int(timeInterval / (24 * 60 * 60))
        let years = timeInterval / (365.25 * 24 * 60 * 60)
        
        return (days: days, years: years)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 24 : 16) {
            // Header with larger fonts
            VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
                Text("Sahil's Progress Over Time")
                    .font(isIPad ? .title : .headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(getSmartDescription())
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Timeframe picker with larger font
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(isIPad ? .body : .caption)
                }
            }
            
            // Stat selector grid with better iPad layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 6 : 4), spacing: isIPad ? 10 : 6) {
                ForEach(CareerStatType.allCases, id: \.self) { stat in
                    CareerTrendStatButton(
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
            
            // Chart for selected stat
            if !games.isEmpty {
                let trendData = getSmartTrendData()
                
                if trendData.count >= 2 {
                    VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                        HStack {
                            Text("\(selectedStat.rawValue) - \(smartTimeframe.displayName)")
                                .font(isIPad ? .title3 : .subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedStat.color)
                            
                            Spacer()
                            
                            Text(getCurrentValueText(trendData))
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Chart {
                            ForEach(Array(trendData.enumerated()), id: \.offset) { index, dataPoint in
                                LineMark(
                                    x: .value("Period", dataPoint.label),
                                    y: .value(selectedStat.rawValue, dataPoint.value)
                                )
                                .foregroundStyle(selectedStat.color)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: isIPad ? 4 : 3))
                                
                                PointMark(
                                    x: .value("Period", dataPoint.label),
                                    y: .value(selectedStat.rawValue, dataPoint.value)
                                )
                                .foregroundStyle(selectedStat.color)
                                .symbolSize(isIPad ? 100 : 60)
                            }
                        }
                        .frame(height: isIPad ? 200 : 150)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(formatYAxisValue(doubleValue))
                                            .font(isIPad ? .body : .caption2)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let stringValue = value.as(String.self) {
                                        Text(stringValue)
                                            .font(isIPad ? .body : .caption2)
                                    }
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.5), value: selectedStat)
                        .animation(.easeInOut(duration: 0.5), value: selectedTimeframe)
                    }
                    .padding(isIPad ? 24 : 16)
                    .background(selectedStat.color.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                            .stroke(selectedStat.color.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(isIPad ? 16 : 12)
                } else {
                    // Not enough data message with larger fonts
                    VStack(spacing: isIPad ? 16 : 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: isIPad ? 60 : 40))
                            .foregroundColor(.secondary)
                        
                        Text("Keep Playing!")
                            .font(isIPad ? .title : .headline)
                            .fontWeight(.semibold)
                        
                        Text("Play a few more games to see trends over time")
                            .font(isIPad ? .title3 : .subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: isIPad ? 200 : 150)
                    .frame(maxWidth: .infinity)
                    .padding(isIPad ? 32 : 24)
                    .background(Color(.systemGray6))
                    .cornerRadius(isIPad ? 16 : 12)
                }
            }
        }
    }
    
    // Keep all the existing helper methods unchanged:
    // - getSmartDescription()
    // - getCurrentValueText()
    // - formatYAxisValue()
    // - getSmartTrendData()
    // - etc.
    
    private func getSmartDescription() -> String {
        let gameCount = games.count
        let timeframe = smartTimeframe
        
        switch timeframe {
        case .auto:
            return "Smart timeframe selected automatically"
        case .weekly:
            return "Tracking \(gameCount) games week by week"
        case .monthly:
            return "Tracking \(gameCount) games month by month"
        case .quarterly:
            return "Tracking \(gameCount) games by quarter"
        case .yearly:
            return "Tracking \(gameCount) games year by year"
        }
    }
    
    private func getCurrentValueText(_ data: [(label: String, value: Double)]) -> String {
        guard let latest = data.last else { return "" }
        let formatted = selectedStat.isPercentage ?
            String(format: "%.1f%%", latest.value) :
            String(format: "%.1f", latest.value)
        return "Latest: \(formatted)"
    }
    
    private func formatYAxisValue(_ value: Double) -> String {
        if selectedStat.isPercentage {
            return String(format: "%.0f%%", value)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    private func getSmartTrendData() -> [(label: String, value: Double)] {
        let timeframe = smartTimeframe
        let calendar = Calendar.current
        
        switch timeframe {
        case .auto:
            return getSmartTrendData()
            
        case .weekly:
            return getWeeklyTrendData(calendar: calendar)
            
        case .monthly:
            return getMonthlyTrendData(calendar: calendar)
            
        case .quarterly:
            return getQuarterlyTrendData(calendar: calendar)
            
        case .yearly:
            return getYearlyTrendData(calendar: calendar)
        }
    }
    
    // Include all the existing trend data methods (getWeeklyTrendData, etc.)
    // and calculateStatValue method - keep them exactly the same
    
    private func getWeeklyTrendData(calendar: Calendar) -> [(label: String, value: Double)] {
        let gamesByWeek = Dictionary(grouping: games) { game in
            calendar.dateInterval(of: .weekOfYear, for: game.timestamp)?.start ?? game.timestamp
        }
        
        let sortedWeeks = gamesByWeek.keys.sorted()
        
        return sortedWeeks.compactMap { weekStart in
            guard let gamesInWeek = gamesByWeek[weekStart] else { return nil }
            
            let weekFormatter = DateFormatter()
            weekFormatter.dateFormat = "MMM d"
            let label = weekFormatter.string(from: weekStart)
            
            let value = calculateStatValue(for: gamesInWeek)
            return (label: label, value: value)
        }
    }
    
    private func getMonthlyTrendData(calendar: Calendar) -> [(label: String, value: Double)] {
        let gamesByMonth = Dictionary(grouping: games) { game in
            let components = calendar.dateComponents([.year, .month], from: game.timestamp)
            return calendar.date(from: components) ?? game.timestamp
        }
        
        let sortedMonths = gamesByMonth.keys.sorted()
        
        return sortedMonths.compactMap { monthStart in
            guard let gamesInMonth = gamesByMonth[monthStart] else { return nil }
            
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            let label = monthFormatter.string(from: monthStart)
            
            let value = calculateStatValue(for: gamesInMonth)
            return (label: label, value: value)
        }
    }
    
    private func getQuarterlyTrendData(calendar: Calendar) -> [(label: String, value: Double)] {
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
            return (label: label, value: value)
        }
    }
    
    private func getYearlyTrendData(calendar: Calendar) -> [(label: String, value: Double)] {
        let gamesByYear = Dictionary(grouping: games) { game in
            calendar.component(.year, from: game.timestamp)
        }
        
        let sortedYears = gamesByYear.keys.sorted()
        
        return sortedYears.compactMap { year in
            guard let gamesInYear = gamesByYear[year] else { return nil }
            
            let label = String(year)
            let value = calculateStatValue(for: gamesInYear)
            return (label: label, value: value)
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
        case .winPercentage:
            let wins = games.filter { $0.outcome == .win }.count
            return gameCount > 0 ? Double(wins) / gameCount * 100 : 0
        case .gamesPlayed:
            return gameCount
        }
    }
}

// MARK: - Updated Stat Button (More Compact)

struct CareerTrendStatButton: View {
    let stat: CareerTrendsView.CareerStatType
    let isSelected: Bool
    let isIPad: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isIPad ? 4 : 2) {
                Text(stat.rawValue)
                    .font(isIPad ? .body : .caption2)
                    .foregroundColor(isSelected ? stat.color : .secondary)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isIPad ? 50 : 35)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 10 : 6)
                    .fill(isSelected ? stat.color.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 10 : 6)
                    .stroke(isSelected ? stat.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
struct OverviewStatsView: View {
    let stats: CareerStats
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 12) {
            // First row: Main stats
            HStack(spacing: isIPad ? 24 : 20) {
                StatBox(title: "Games", value: "\(stats.totalGames)", color: .blue, isIPad: isIPad)
                StatBox(title: "Points", value: "\(stats.totalPoints)", color: .purple, isIPad: isIPad)
                StatBox(title: "Avg", value: String(format: "%.1f", stats.averagePoints), color: .indigo, isIPad: isIPad)
                StatBox(title: "Win %", value: String(format: "%.0f%%", stats.winPercentage * 100), color: stats.winPercentage > 0.5 ? .green : .red, isIPad: isIPad)
            }
            
            // Second row: Other key stats
            HStack(spacing: isIPad ? 24 : 20) {
                StatBox(title: "Rebounds", value: "\(stats.totalRebounds)", color: .mint, isIPad: isIPad)
                StatBox(title: "Assists", value: "\(stats.totalAssists)", color: .cyan, isIPad: isIPad)
                StatBox(title: "Steals", value: "\(stats.totalSteals)", color: .yellow, isIPad: isIPad)
                StatBox(title: "Fouls", value: "\(stats.totalFouls)", color: .pink, isIPad: isIPad)
            }
            
            // Third row: Shooting percentages
            HStack(spacing: isIPad ? 24 : 20) {
                StatBox(title: "FG%", value: String(format: "%.0f%%", stats.fieldGoalPercentage * 100), color: .blue, isIPad: isIPad)
                StatBox(title: "3P%", value: String(format: "%.0f%%", stats.threePointPercentage * 100), color: .green, isIPad: isIPad)
                StatBox(title: "FT%", value: String(format: "%.0f%%", stats.freeThrowPercentage * 100), color: .orange, isIPad: isIPad)
                StatBox(title: "A/T", value: String(format: "%.1f", stats.assistTurnoverRatio), color: .indigo, isIPad: isIPad)
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 10 : 6) {
            Text(value)
                .font(isIPad ? .largeTitle : .title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isIPad ? .body : .caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 16 : 8)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(isIPad ? 12 : 8)
    }
}

// MARK: - Game Detail View

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
                Text("\(location)")
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
