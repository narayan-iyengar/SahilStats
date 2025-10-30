//
//  ScheduleView.swift
//  SahilStats
//
//  Upcoming games from calendar - focused schedule view
//

import SwiftUI

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

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var upcomingGames: [GameCalendarManager.CalendarGame] {
        calendarManager.upcomingGames.filter { !calendarManager.isEventIgnored($0.id) }
    }

    var body: some View {
        NavigationView {
            Group {
                if upcomingGames.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(upcomingGames) { game in
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
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        calendarManager.requestCalendarAccess()
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
            }
        }
        .sheet(item: $gameToConfirm) { game in
            GameConfirmationView(
                liveGame: game,
                onStart: { liveGame in
                    Task {
                        await confirmAndStartGame(game)
                    }
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
                calendarManager.requestCalendarAccess()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

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

    private func confirmAndStartGame(_ liveGame: LiveGame) async {
        do {
            let isMultiDevice = roleManager.preferredRole != .none && multipeer.connectedPeers.count > 0
            let myRole = roleManager.preferredRole

            if isMultiDevice {
                if !multipeer.isConnected {
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
