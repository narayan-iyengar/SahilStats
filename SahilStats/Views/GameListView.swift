// File: SahilStats/Views/GameListView.swift (Corrected and Refactored)

import SwiftUI
import Charts
import Foundation
import Combine
import FirebaseAuth

struct GameListView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var calendarManager = GameCalendarManager.shared
    @EnvironmentObject var authService: AuthService
    @StateObject private var filterManager = GameFilterManager()

    @State private var selectedGame: Game?
    @State private var hoveredGameId: String?
    @State private var showingDeleteAlert = false
    @State private var gameToDelete: Game?
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var isViewingTrends = false
    @State private var showingNewGame = false
    @State private var showingRoleSelection = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showingQRScanner = false
    @State private var selectedCalendarGame: GameCalendarManager.CalendarGame?
    @State private var gameToConfirm: LiveGame?
    @State private var gameForQRCode: LiveGame?

    // iPad detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        navigationView
    }
    
    // MARK: - Main View Structure
    
    private var navigationView: some View {
        NavigationView {
            contentView
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .fullScreenCover(item: $selectedGame) { game in
            GameDetailView(game: game)
        }
        .alert("Delete Game", isPresented: $showingDeleteAlert) {
            GameDeleteAlert(
                gameToDelete: $gameToDelete,
                onDelete: deleteGame
            )
        }
        .alert("Deletion Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedTeamFilter: $filterManager.selectedTeamFilter,
                selectedOpponentFilter: $filterManager.selectedOpponentFilter,
                selectedOutcomeFilter: $filterManager.selectedOutcomeFilter,
                selectedDateRange: $filterManager.selectedDateRange,
                customStartDate: $filterManager.customStartDate,
                customEndDate: $filterManager.customEndDate,
                availableTeams: availableTeams,
                availableOpponents: availableOpponents,
                onClearAll: clearAllFilters,
                isIPad: isIPad
            )
        }
        .fullScreenCover(isPresented: $showingNewGame) {
            NavigationView {
                GameSetupView()
            }
        }
        .sheet(isPresented: $showingRoleSelection) {
            if let liveGame = firebaseService.getCurrentLiveGame() {
                RoleSelectionSheet(liveGame: liveGame)
            }
        }
        .fullScreenCover(isPresented: $showingQRScanner) {
            QRCodeScannerView()
        }
        .sheet(item: $gameToConfirm) { game in
            GameConfirmationView(
                liveGame: game,
                onStart: startGameFromCalendar,
                onCancel: { gameToConfirm = nil }
            )
        }
        .fullScreenCover(item: $gameForQRCode) { game in
            GameQRCodeDisplayView(liveGame: game)
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        .onAppear {
            firebaseService.startListening()
            updateDisplayedGames()
            debugPrint("🔍 GameListView appeared - hasLiveGame: \(firebaseService.hasLiveGame)")
        }
        .onDisappear {
            firebaseService.stopListening()
        }
        .onChange(of: firebaseService.games) { _, _ in updateDisplayedGames() }
        .onChange(of: searchText) { _, _ in
            filterManager.searchText = searchText
            filterManager.resetPagination()
        }
        .onChange(of: filterManager.needsUpdate) { _, _ in updateDisplayedGames() }
        .onChange(of: filterManager.selectedTeamFilter) { _, _ in filterManager.resetPagination() }
        .onChange(of: filterManager.selectedOpponentFilter) { _, _ in filterManager.resetPagination() }
        .onChange(of: filterManager.selectedOutcomeFilter) { _, _ in filterManager.resetPagination() }
        .onChange(of: filterManager.selectedDateRange) { _, _ in filterManager.resetPagination() }
        .onChange(of: filterManager.customStartDate) { _, _ in filterManager.resetPagination() }
        .onChange(of: filterManager.customEndDate) { _, _ in filterManager.resetPagination() }
    }
    
    // MARK: - Child Views
    
    @ViewBuilder
    private var contentView: some View {
        if firebaseService.isLoading {
            LoadingView()
        } else if sortedGames.isEmpty && upcomingGames.isEmpty {
            EmptyStateView(canCreateGames: authService.canCreateGames, isIPad: isIPad)
        } else {
            List {
                // Upcoming Games Section (from calendar)
                upcomingGamesSection

                // Past Games Section
                gamesListSection
            }
            .listStyle(PlainListStyle())
        }
    }
    
    @ViewBuilder
    private var upcomingGamesSection: some View {
        if !upcomingGames.isEmpty {
            Section {
                ForEach(upcomingGames) { game in
                    CalendarGameCard(
                        game: game,
                        isIPad: isIPad,
                        onSelect: {
                            selectCalendarGame(game)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive, action: {
                            calendarManager.ignoreEvent(game.id)
                        }) {
                            Label("Ignore", systemImage: "eye.slash")
                        }
                    }
                }
            } header: {
                Text("Upcoming Games")
                    .font(isIPad ? .largeTitle : .title2)
                    .fontWeight(.heavy)
            }
            .listRowBackground(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var gamesListSection: some View {
        // Active filters display
        if hasActiveFilters {
            Section {
                ActiveFiltersView(
                    searchText: effectiveSearchText,
                    selectedTeamFilter: filterManager.selectedTeamFilter,
                    selectedOpponentFilter: filterManager.selectedOpponentFilter,
                    selectedOutcomeFilter: filterManager.selectedOutcomeFilter,
                    selectedDateRange: filterManager.selectedDateRange,
                    filteredCount: filteredGames.count,
                    totalCount: sortedGames.count,
                    onClearAll: clearAllFilters
                )
            }
            .listRowBackground(Color.orange.opacity(0.05))
            .listRowSeparator(.hidden)
        }


        
        // Games list
        Section {
            ForEach(displayedGames) { game in
                EditableGameRowView(
                    game: .constant(game),
                    isHovered: hoveredGameId == game.id,
                    canDelete: authService.canDeleteGames,
                    canEdit: authService.canEditGames,
                    onTap: { 
                        NavigationCoordinator.shared.markUserHasInteracted()
                        selectedGame = game 
                    },
                    onDelete: {
                        gameToDelete = game
                        showingDeleteAlert = true
                    },
                    onSave: saveGameChanges
                )
                .onHover { isHovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredGameId = isHovering ? game.id : nil
                    }
                }
            }
            
            // Load more indicator
            if hasMoreGames {
                LoadMoreView(onLoadMore: loadMoreGames)
            }
        } header: {
            GamesSectionHeader(
                filteredCount: filteredGames.count,
                totalCount: sortedGames.count,
                displayedCount: displayedGames.count,
                isIPad: isIPad
            )
        }
    }
    

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading toolbar items
        ToolbarItem(placement: .navigationBarLeading) {
            AdminStatusIndicator()
        }
        
        // All trailing items in one group to prevent duplicates
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: isIPad ? 12 : 8) {
                // Live Game button (highest priority)
                if firebaseService.hasLiveGame {
                    LiveGameButton(
                        action: { showingRoleSelection = true },
                        liveGame: firebaseService.getCurrentLiveGame()
                    )
                }
                
                // Filter button with badge
                Button(action: { showingFilters = true }) {
                    ZStack {
                        // Always use the same base icon to prevent grey circle appearance
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title3)
                            .foregroundColor(filterManager.activeFiltersCount > 0 ? .orange : .gray)
                        
                        // Badge for active filters
                        if filterManager.activeFiltersCount > 0 {
                            Text("\(filterManager.activeFiltersCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                // New Game button with menu
                if authService.canCreateGames {
                    Menu {
                        // QR Scanner (Easy pairing!)
                        Button(action: {
                            showingQRScanner = true
                        }) {
                            Label("Scan to Join Game", systemImage: "qrcode.viewfinder")
                        }

                        Divider()

                        // Manual Setup
                        Button(action: {
                            NavigationCoordinator.shared.markUserHasInteracted()
                            showingNewGame = true
                        }) {
                            Label("Manual Setup", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                } else {
                    Button(action: { showingNewGame = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

}
struct GamesSectionHeader: View {
    let filteredCount: Int
    let totalCount: Int
    let displayedCount: Int
    let isIPad: Bool
    
    var body: some View {
        HStack {
            Text(filteredCount == totalCount ? "Recent Games" : "Filtered Games")
                .font(isIPad ? .largeTitle : .title2)
                .fontWeight(.heavy)
            Spacer()
            if displayedCount < filteredCount {
                Text("Showing \(displayedCount) of \(filteredCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Computed Properties
extension GameListView {

    private var upcomingGames: [GameCalendarManager.CalendarGame] {
        // Get up to 5 upcoming games from calendar
        Array(calendarManager.upcomingGames.prefix(5))
    }

    /*
    private var sortedGames: [Game] {
        firebaseService.games.sorted { $0.timestamp > $1.timestamp }
    }
    */
    private var sortedGames: [Game] {
        firebaseService.games.sorted {
            // Use a distant past date for any game that has a nil timestamp.
            // This ensures they are treated as "older" and sorted to the end.
            let date1 = $0.timestamp ?? .distantPast
            let date2 = $1.timestamp ?? .distantPast

            // Sort descending, so recent games appear first.
            return date1 > date2
        }
    }
    
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
    
    private var filteredGames: [Game] {
        var games = sortedGames
        
        // Apply search filter
        if !effectiveSearchText.isEmpty {
            games = games.filter { game in
                game.teamName.localizedCaseInsensitiveContains(effectiveSearchText) ||
                game.opponent.localizedCaseInsensitiveContains(effectiveSearchText) ||
                (game.location?.localizedCaseInsensitiveContains(effectiveSearchText) ?? false)
            }
        }
        
        // Apply other filters
        games = filterManager.applyFilters(to: games)
        
        return games
    }
    
    private var displayedGames: [Game] {
        filterManager.displayedGames
    }
    
    private var effectiveSearchText: String {
        !searchText.isEmpty ? searchText : filterManager.searchText
    }
    
    private var hasActiveFilters: Bool {
        !effectiveSearchText.isEmpty || filterManager.activeFiltersCount > 0
    }

    private var hasMoreGames: Bool {
        displayedGames.count < filteredGames.count
    }
}

// MARK: - Actions
extension GameListView {
    private func updateDisplayedGames() {
        filterManager.updateDisplayedGames(from: filteredGames)
    }
    
    private func clearAllFilters() {
        searchText = ""
        filterManager.clearAllFilters()
    }
    
    private func loadMoreGames() {
        // Implementation would go in FilterManager
        filterManager.loadMoreGames(from: filteredGames)
    }
    
    private func saveGameChanges(_ game: Game) {
        Task {
            do {
                try await firebaseService.updateGame(game)
                filterManager.updateGameInDisplayed(game)
            } catch {
                debugPrint("Failed to save game changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteGame(_ game: Game) {
        Task {
            do {
                try await firebaseService.deleteGame(game.id ?? "")
                forcePrint("✅ Game deleted successfully")
            } catch {
                debugPrint("Failed to delete game: \(error)")

                // Show error to user
                await MainActor.run {
                    deleteErrorMessage = "Failed to delete game: \(error.localizedDescription)"
                    showingDeleteError = true
                }
            }
        }
    }
    
    // MARK: - Basketball Mode Helper
    
    private func startBasketballMode() {
        debugPrint("🏀 Starting Basketball Mode - Smart Device Setup")
        NavigationCoordinator.shared.markUserHasInteracted()
        NavigationCoordinator.shared.userExplicitlyJoinedGame = true

        // This will automatically:
        // 1. iPad → Controller role (stats management)
        // 2. iPhone → Recorder role (camera on tripod)
        // 3. Auto-start recording when game begins
        showingNewGame = true
    }

    private func selectCalendarGame(_ calendarGame: GameCalendarManager.CalendarGame) {
        debugPrint("🏀 Selected calendar game: \(calendarGame.opponent)")
        selectedCalendarGame = calendarGame

        // Get user's settings from SettingsManager (includes Firebase sync)
        let settingsManager = SettingsManager.shared
        let (gameFormat, quarterLength) = settingsManager.getDefaultGameSettings()

        // Extract team name from calendar event title
        // For "UNEQLD Boys 9/10U - Tentative: NBBA Tourney", extract "UNEQLD Boys 9/10U"
        let teamName = extractTeamNameFromTitle(calendarGame.title)

        let settings = GameSettings(
            teamName: teamName,
            quarterLength: quarterLength,
            gameFormat: gameFormat
        )

        // Create live game from calendar
        let liveGame = calendarManager.createLiveGameFromCalendar(calendarGame, settings: settings)

        // Set gameToConfirm to show the confirmation sheet
        gameToConfirm = liveGame
    }

    // Extract team name from calendar event title
    private func extractTeamNameFromTitle(_ title: String) -> String {
        var rawTeamName = ""

        // Check for " - " pattern (tournament format)
        if let dashRange = title.range(of: " - ") {
            let teamPart = String(title[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !teamPart.isEmpty {
                rawTeamName = teamPart
            }
        }

        // Check for " at " pattern
        if rawTeamName.isEmpty, let atRange = title.range(of: " at ", options: .caseInsensitive) {
            let teamPart = String(title[..<atRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !teamPart.isEmpty {
                rawTeamName = teamPart
            }
        }

        // Check for " vs " pattern
        if rawTeamName.isEmpty, let vsRange = title.range(of: " vs ", options: .caseInsensitive) {
            let teamPart = String(title[..<vsRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !teamPart.isEmpty {
                rawTeamName = teamPart
            }
        }

        // If we extracted a team name, normalize it for Firebase consistency
        if !rawTeamName.isEmpty {
            return normalizeTeamName(rawTeamName)
        }

        // Fallback to UserDefaults or email
        let userDefaults = UserDefaults.standard
        return userDefaults.string(forKey: "defaultTeamName")
            ?? userDefaults.string(forKey: "teamName")
            ?? authService.currentUser?.email?.components(separatedBy: "@").first?.capitalized
            ?? "Home"
    }

    // Normalize team name for Firebase consistency
    // "UNEQLD Boys 9/10U" → "Uneqld"
    // "Elements AAU" → "Elements"
    private func normalizeTeamName(_ rawName: String) -> String {
        let upperRaw = rawName.uppercased()

        // Check for UNEQLD variants
        if upperRaw.hasPrefix("UNEQLD") {
            return "Uneqld"
        }

        // Check for Elements variants
        if upperRaw.hasPrefix("ELEMENTS") {
            return "Elements"
        }

        // For other teams, take the first word and capitalize it properly
        let firstWord = rawName.components(separatedBy: .whitespaces).first ?? rawName
        return firstWord.prefix(1).uppercased() + firstWord.dropFirst().lowercased()
    }

    private func startGameFromCalendar(_ liveGame: LiveGame) {
        debugPrint("🚀 startGameFromCalendar() called with isMultiDeviceSetup = \(liveGame.isMultiDeviceSetup ?? false)")
        debugPrint("🚀 Game: \(liveGame.teamName) vs \(liveGame.opponent)")

        Task {
            do {
                // Create live game in Firebase
                debugPrint("☁️ Creating live game in Firebase...")
                let gameId = try await firebaseService.createLiveGame(liveGame)
                forcePrint("✅ Live game created from calendar: \(gameId)")

                // Update game with the ID
                var gameWithId = liveGame
                gameWithId.id = gameId

                // Dismiss confirmation screen
                await MainActor.run {
                    gameToConfirm = nil
                }

                debugPrint("🔍 Checking isMultiDeviceSetup: \(liveGame.isMultiDeviceSetup ?? false)")

                // Multi-device setup: Controller shows QR code, Recorder scans
                // Single-device setup: Go directly to live game
                if liveGame.isMultiDeviceSetup == true {
                    let roleManager = DeviceRoleManager.shared
                    let myRole = roleManager.preferredRole

                    debugPrint("📱 Multi-device mode: My role is \(myRole.displayName)")

                    if myRole == .controller {
                        // Controller: Show QR code for recorder to scan
                        debugPrint("📱 Controller: Showing QR code to display")
                        await MainActor.run {
                            gameForQRCode = gameWithId
                        }
                    } else if myRole == .recorder {
                        // Recorder: Open QR scanner to scan controller's QR code
                        debugPrint("📱 Recorder: Opening QR scanner")
                        await MainActor.run {
                            showingQRScanner = true
                        }
                    } else {
                        // No role set - show role selection sheet
                        debugPrint("📱 No role set, showing role selection")
                        await MainActor.run {
                            showingRoleSelection = true
                        }
                    }
                } else {
                    debugPrint("📱 Single-device mode: Going directly to live game")
                    debugPrint("📱 isMultiDeviceSetup value: \(liveGame.isMultiDeviceSetup.debugDescription)")
                    // Navigate directly to live game view (stats only, no recording)
                    await MainActor.run {
                        navigation.currentFlow = .liveGame(gameWithId)
                    }
                    debugPrint("📱 Should have navigated to live game view")
                }
            } catch {
                forcePrint("❌ Failed to create game from calendar: \(error)")
                await MainActor.run {
                    deleteErrorMessage = "Failed to create game: \(error.localizedDescription)"
                    showingDeleteError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct LoadMoreView: View {
    let onLoadMore: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        HStack {
            Spacer()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(0.8)
            } else {
                Button("Load More Games") {
                    isLoading = true
                    onLoadMore()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                    }
                }
                .foregroundColor(.orange)
                .font(.subheadline)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Enhanced Career Stats View
struct EnhancedCareerStatsView: View {
    let stats: CareerStats
    let games: [Game]
    @Binding var isViewingTrends: Bool
    let isIPad: Bool
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: isIPad ? 40 : 20) {
            // Tab selector (moved up to replace the large header)
            Picker("View", selection: $selectedTab) {
                Text("Overview")
                    .font(isIPad ? .largeTitle : .body)
                    .tag(0)
                Text("Trends")
                    .font(isIPad ? .largeTitle : .body)
                    .tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .scaleEffect(isIPad ? 1.3 : 1.0)
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
        .padding(isIPad ? 40 : 16)
    }
}

// MARK: - Overview Stats
struct OverviewStatsView: View {
    let stats: CareerStats
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 40 : 12) {
            // First row: Main stats
            HStack(spacing: isIPad ? 40 : 20) {
                StatBox(title: "Games", value: "\(stats.totalGames)", color: .blue, isIPad: isIPad)
                StatBox(title: "Points", value: "\(stats.totalPoints)", color: .purple, isIPad: isIPad)
                StatBox(title: "Avg", value: String(format: "%.1f", stats.averagePoints), color: .indigo, isIPad: isIPad)
                StatBox(title: "Win %", value: String(format: "%.0f%%", stats.winPercentage * 100), color: stats.winPercentage > 0.5 ? .green : .red, isIPad: isIPad)
            }
            
            // Second row: Other key stats
            HStack(spacing: isIPad ? 40 : 20) {
                StatBox(title: "Rebounds", value: "\(stats.totalRebounds)", color: .mint, isIPad: isIPad)
                StatBox(title: "Assists", value: "\(stats.totalAssists)", color: .cyan, isIPad: isIPad)
                StatBox(title: "Steals", value: "\(stats.totalSteals)", color: .yellow, isIPad: isIPad)
                StatBox(title: "Fouls", value: "\(stats.totalFouls)", color: .pink, isIPad: isIPad)
            }
            
            // Third row: Shooting percentages
            HStack(spacing: isIPad ? 40 : 20) {
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
        VStack(spacing: isIPad ? 20 : 6) {
            Text(value)
                .font(isIPad ? .system(size: 64, weight: .black) : .title3)
                .fontWeight(.black)
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
            
            Text(title)
                .font(isIPad ? .system(size: 20, weight: .semibold) : .caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 32 : 8)
        .padding(.horizontal, isIPad ? 20 : 8)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 24 : 8)
                .stroke(color.opacity(0.2), lineWidth: isIPad ? 3 : 1)
        )
        .cornerRadius(isIPad ? 24 : 8)
    }
}

// MARK: - Career Trends View
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
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 40 : 16) {
            // Header
            VStack(alignment: .leading, spacing: isIPad ? 24 : 12) {
                Text("Sahil's Progress Over Time")
                    .font(isIPad ? .system(size: 44, weight: .heavy) : .headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Track performance trends across different time periods")
                        .font(isIPad ? .title2 : .caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(isIPad ? .title3 : .caption)
                    .scaleEffect(isIPad ? 1.4 : 1.0)
                }
            }
            
            // Stat selector grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 4 : 3), spacing: isIPad ? 20 : 6) {
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
            
            // Chart
            if !games.isEmpty && games.count >= 2 {
                VStack(alignment: .leading, spacing: isIPad ? 24 : 8) {
                    HStack {
                        Text("\(selectedStat.rawValue) - \(selectedTimeframe.displayName)")
                            .font(isIPad ? .system(size: 32, weight: .bold) : .subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(selectedStat.color)
                        
                        Spacer()
                        
                        Text("Latest: \(getLatestValueText())")
                            .font(isIPad ? .title : .caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Chart {
                        ForEach(Array(getTrendData().enumerated()), id: \.offset) { index, dataPoint in
                            LineMark(
                                x: .value("Game", index + 1),
                                y: .value(selectedStat.rawValue, dataPoint)
                            )
                            .foregroundStyle(selectedStat.color)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: isIPad ? 8 : 3))
                            
                            PointMark(
                                x: .value("Game", index + 1),
                                y: .value(selectedStat.rawValue, dataPoint)
                            )
                            .foregroundStyle(selectedStat.color)
                            .symbolSize(isIPad ? 300 : 60)
                        }
                    }
                    .frame(height: isIPad ? 400 : 150)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(formatYAxisValue(doubleValue))
                                        .font(isIPad ? .title2 : .caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)")
                                        .font(isIPad ? .title2 : .caption2)
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: selectedStat)
                }
                .padding(isIPad ? 40 : 16)
                .background(selectedStat.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 28 : 12)
                        .stroke(selectedStat.color.opacity(0.2), lineWidth: isIPad ? 3 : 1)
                )
                .cornerRadius(isIPad ? 28 : 12)
            } else {
                VStack(spacing: isIPad ? 32 : 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: isIPad ? 100 : 40))
                        .foregroundColor(.secondary)
                    
                    Text("Keep Playing!")
                        .font(isIPad ? .system(size: 40, weight: .heavy) : .headline)
                        .fontWeight(.heavy)
                    
                    Text("Play a few more games to see trends over time")
                        .font(isIPad ? .largeTitle : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: isIPad ? 400 : 150)
                .frame(maxWidth: .infinity)
                .padding(isIPad ? 48 : 24)
                .background(Color(.systemGray6))
                .cornerRadius(isIPad ? 28 : 12)
            }
        }
    }
    
    private func getTrendData() -> [Double] {
        let recentGames = Array(games.suffix(min(games.count, 10)))
        
        return recentGames.map { game in
            calculateStatValue(for: [game])
        }
    }
    
    private func getLatestValueText() -> String {
        guard let latest = getTrendData().last else { return "" }
        let formatted = selectedStat.isPercentage ?
            String(format: "%.1f%%", latest) :
            String(format: "%.1f", latest)
        return formatted
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

struct CareerTrendStatButton: View {
    let stat: CareerTrendsView.CareerStatType
    let isSelected: Bool
    let isIPad: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isIPad ? 12 : 2) {
                Text(stat.rawValue)
                    .font(isIPad ? .title2 : .caption2)
                    .foregroundColor(isSelected ? stat.color : .secondary)
                    .fontWeight(isSelected ? .heavy : .medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isIPad ? 100 : 35)
            .padding(.horizontal, isIPad ? 16 : 6)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 20 : 6)
                    .fill(isSelected ? stat.color.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 20 : 6)
                    .stroke(isSelected ? stat.color.opacity(0.5) : Color.clear, lineWidth: isIPad ? 4 : 1.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Date Range Extension for FilterManager Compatibility
extension GameListView {
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
}

// MARK: - Role Selection Sheet

struct RoleSelectionSheet: View {
    let liveGame: LiveGame
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var roleManager = DeviceRoleManager.shared
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showingDeleteAlert = false

    private var isIPad: Bool { horizontalSizeClass == .regular }

    private var availableRoles: [DeviceRole] {
        // For single-device games on non-controlling devices, only show Viewer
        if liveGame.isMultiDeviceSetup == false {
            let currentDeviceId = DeviceControlManager.shared.deviceId
            let isControllingDevice = liveGame.controllingDeviceId == currentDeviceId

            if !isControllingDevice {
                // Non-controlling device in single-device game → ONLY Viewer
                return [.viewer]
            }
        }

        // Multi-device games OR controlling device in single-device game → show all available roles
        return liveGame.getAvailableRoles()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Text(liveGame.isMultiDeviceSetup == false ? "View Live Game" : "Join Live Game")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("\(liveGame.teamName) vs \(liveGame.opponent)")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    if liveGame.isMultiDeviceSetup == false {
                        Text("This is a single-device game. You can watch and request control.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Select your role to join the game")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(spacing: 16) {
                    // Controller role
                    RoleSelectionButton(
                        title: "Controller",
                        subtitle: "Control the game and manage stats",
                        icon: "gamecontroller.fill",
                        color: .blue,
                        isAvailable: availableRoles.contains(.controller),
                        action: {
                            selectRole(.controller)
                        }
                    )

                    // Recorder role - only show for multi-device games
                    if liveGame.isMultiDeviceSetup != false {
                        RoleSelectionButton(
                            title: "Recorder",
                            subtitle: "Record video and capture highlights",
                            icon: "video.fill",
                            color: .red,
                            isAvailable: availableRoles.contains(.recorder),
                            action: {
                                selectRole(.recorder)
                            }
                        )
                    }

                    // Viewer role
                    RoleSelectionButton(
                        title: "Viewer",
                        subtitle: liveGame.isMultiDeviceSetup == false ? "Watch and request control" : "Watch the game in real-time",
                        icon: "eye.fill",
                        color: .green,
                        isAvailable: true, // Viewer is always available
                        action: {
                            selectRole(.viewer)
                        }
                    )
                }
                .padding(.horizontal, 40)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if authService.showAdminFeatures {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Delete Live Game", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteLiveGame()
                }
            } message: {
                Text("Are you sure you want to delete this live game? This will cancel the game without saving any stats and return all devices to the dashboard.")
            }
        }
    }

    private func selectRole(_ role: DeviceRole) {
        debugPrint("🎯 Role selected: \(role)")
        navigation.markUserHasInteracted()
        navigation.userExplicitlyJoinedGame = true
        roleManager.deviceRole = role
        dismiss()

        // Navigate to appropriate view based on role
        switch role {
        case .recorder:
            navigation.currentFlow = .waitingToRecord(Optional(liveGame))
        case .controller, .viewer:
            navigation.currentFlow = .liveGame(liveGame)
        case .none:
            break
        }
    }

    private func deleteLiveGame() {
        debugPrint("🗑️ Admin deleting/canceling live game")
        Task {
            do {
                // Delete the live game from Firebase (no stats saved)
                if let gameId = liveGame.id {
                    try await firebaseService.deleteLiveGame(gameId)
                    forcePrint("✅ Live game deleted successfully")
                }

                // Dismiss the sheet and return to dashboard
                await MainActor.run {
                    dismiss()
                    navigation.returnToDashboard()
                }
            } catch {
                forcePrint("❌ Error deleting live game: \(error)")
            }
        }
    }
}

struct RoleSelectionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isAvailable ? color : .gray)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .gray)

                    Text(isAvailable ? subtitle : "Not available - role filled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isAvailable {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                ZStack {
                    if isAvailable {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    }

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isAvailable ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.5)
    }
}

#Preview {
    GameListView()
        .environmentObject(AuthService())
}
