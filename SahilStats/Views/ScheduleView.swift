//
//  ScheduleView.swift
//  SahilStats
//
//  Upcoming games from calendar - focused schedule view
//

import SwiftUI
import FirebaseAuth

struct ScheduleView: View {
    @ObservedObject private var calendarManager = GameCalendarManager.shared
    @StateObject private var roleManager = DeviceRoleManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var multipeer = MultipeerConnectivityManager.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var gameToConfirm: LiveGame?
    @State private var showingQRScanner = false
    @State private var gameForQRCode: LiveGame?
    @State private var showingRoleSelection = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showingNewGame = false

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var upcomingGames: [GameCalendarManager.CalendarGame] {
        calendarManager.upcomingGames.filter { !calendarManager.ignoredEventIds.contains($0.id) }
    }

    // Categorize games by time period
    private var todayGames: [GameCalendarManager.CalendarGame] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return upcomingGames.filter { game in
            game.startTime >= today && game.startTime < tomorrow
        }
    }

    private var thisWeekGames: [GameCalendarManager.CalendarGame] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        return upcomingGames.filter { game in
            game.startTime >= tomorrow && game.startTime < weekFromNow
        }
    }

    private var laterGames: [GameCalendarManager.CalendarGame] {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))!
        return upcomingGames.filter { game in
            game.startTime >= weekFromNow
        }
    }

    private var hasGamesInNextWeek: Bool {
        !todayGames.isEmpty || !thisWeekGames.isEmpty
    }

    var body: some View {
        NavigationView {
            Group {
                if upcomingGames.isEmpty {
                    emptyStateView
                } else if !hasGamesInNextWeek {
                    noNearbyGamesView
                } else {
                    List {
                        // Today's games
                        if !todayGames.isEmpty {
                            Section(header: Text("Today")) {
                                ForEach(todayGames) { game in
                                    gameRow(for: game)
                                }
                            }
                        }

                        // This week's games
                        if !thisWeekGames.isEmpty {
                            Section(header: Text("This Week")) {
                                ForEach(thisWeekGames) { game in
                                    gameRow(for: game)
                                }
                            }
                        }

                        // Later games
                        if !laterGames.isEmpty {
                            Section(header: Text("Upcoming")) {
                                ForEach(laterGames) { game in
                                    gameRow(for: game)
                                }
                            }
                        }
                    }
                    .refreshable {
                        debugPrint("🔄 Pull-to-refresh triggered in ScheduleView")
                        await Task {
                            calendarManager.refreshGames()
                            debugPrint("🔄 Schedule refresh completed")
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }.value
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: isIPad ? 12 : 8) {
                        // Live Game button
                        if firebaseService.hasLiveGame {
                            LiveGameButton(
                                action: { showingRoleSelection = true },
                                liveGame: firebaseService.getCurrentLiveGame()
                            )
                        }

                        // New Game menu
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
        .sheet(item: $gameToConfirm) { game in
            GameConfirmationView(
                liveGame: game,
                onStart: { liveGame in
                    confirmAndStartGameSync(game)
                },
                onCancel: {
                    gameToConfirm = nil
                }
            )
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView()
        }
        .sheet(item: $gameForQRCode) { game in
            GameQRCodeDisplayView(liveGame: game)
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
        .alert("Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
        .onAppear {
            firebaseService.startListening()
        }
        .onDisappear {
            firebaseService.stopListening()
        }
    }

    // Helper to create a game row with swipe actions
    @ViewBuilder
    private func gameRow(for game: GameCalendarManager.CalendarGame) -> some View {
        CalendarGameCard(
            game: game,
            isIPad: isIPad,
            onSelect: {
                selectCalendarGame(game)
            }
        )
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Ignore", role: .destructive) {
                calendarManager.ignoreEvent(game.id)
            }

            Button("Start") {
                selectCalendarGame(game)
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Ignore", role: .destructive) {
                calendarManager.ignoreEvent(game.id)
            }

            Button("Start") {
                selectCalendarGame(game)
            }
            .tint(.orange)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("No Upcoming Games")
                .font(.title2)
                .fontWeight(.bold)

            Text("Games from your calendar will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Grant Calendar Access") {
                Task {
                    await calendarManager.requestCalendarAccess()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noNearbyGamesView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("No Games This Week")
                .font(.title2)
                .fontWeight(.bold)

            if let nextGame = laterGames.first {
                VStack(spacing: 8) {
                    Text("Next game:")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text(nextGame.opponent)
                        .font(.headline)

                    Text("\(nextGame.dateString) at \(nextGame.timeString)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            } else {
                Text("Check back later for upcoming games")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Show list of all games at bottom
            if !laterGames.isEmpty {
                VStack(spacing: 12) {
                    Text("All Upcoming Games")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(laterGames) { game in
                                Button(action: {
                                    selectCalendarGame(game)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(game.opponent)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)

                                            Text("\(game.dateString) at \(game.timeString)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 200)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Game Selection Logic (from GameListView)

    private func selectCalendarGame(_ calendarGame: GameCalendarManager.CalendarGame) {
        debugPrint("🏀 Selected calendar game: \(calendarGame.opponent)")

        // Get user's settings from SettingsManager (includes Firebase sync)
        let settingsManager = SettingsManager.shared
        let (gameFormat, quarterLength) = settingsManager.getDefaultGameSettings()

        // Extract team name from calendar event title
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

    private func confirmAndStartGameSync(_ liveGame: LiveGame) {
        Task {
            await confirmAndStartGame(liveGame)
        }
    }

    private func confirmAndStartGame(_ liveGame: LiveGame) async {
        do {
            let isMultiDevice = roleManager.preferredRole != .none && multipeer.connectedPeers.count > 0
            let myRole = roleManager.preferredRole

            if isMultiDevice {
                let hasConnection = multipeer.connectedPeers.count > 0
                if !hasConnection {
                    forcePrint("❌ Cannot start game, not connected.")
                    return
                }
            }

            if myRole == .controller {
                debugPrint("📱 Controller: Creating game and showing QR code")
                let gameId = try await firebaseService.createLiveGame(liveGame)
                forcePrint("✅ Live game created from calendar: \(gameId)")

                var gameWithId = liveGame
                gameWithId.id = gameId

                await MainActor.run {
                    gameToConfirm = nil
                    gameForQRCode = gameWithId
                }
            } else if myRole == .recorder {
                debugPrint("📱 Recorder: Opening QR scanner")
                await MainActor.run {
                    gameToConfirm = nil
                    showingQRScanner = true
                }
            } else {
                debugPrint("📱 No role set - creating game and showing role selection")
                let gameId = try await firebaseService.createLiveGame(liveGame)

                var gameWithId = liveGame
                gameWithId.id = gameId

                await MainActor.run {
                    gameToConfirm = nil
                    showingRoleSelection = true
                }
            }
        } catch {
            forcePrint("❌ Failed to create game from calendar: \(error)")
            await MainActor.run {
                gameToConfirm = nil
                deleteErrorMessage = "Failed to create game: \(error.localizedDescription)"
                showingDeleteError = true
            }
        }
    }
}

#Preview {
    ScheduleView()
}
