//
//  GameCalendarManager.swift
//  SahilStats
//
//  Calendar integration for pre-filling game details from iOS calendar
//

import Foundation
import EventKit
import SwiftUI
import Combine

class GameCalendarManager: ObservableObject {
    static let shared = GameCalendarManager()

    private let eventStore = EKEventStore()

    @Published var hasCalendarAccess = false
    @Published var upcomingGames: [CalendarGame] = []
    @Published var selectedCalendars: [String] = [] // Calendar identifiers
    @Published var weekendsOnly = true // Filter to show only weekend events
    @Published var ignoredEventIds: Set<String> = [] // Event IDs to ignore

    private let userDefaults = UserDefaults.standard
    private let selectedCalendarsKey = "com.sahilstats.selectedCalendars"
    private let weekendsOnlyKey = "com.sahilstats.weekendsOnly"
    private let ignoredEventsKey = "com.sahilstats.ignoredCalendarEvents"

    // MARK: - Calendar Game Model

    struct CalendarGame: Identifiable, Codable {
        let id: String // Event identifier
        let title: String
        let opponent: String
        let location: String
        let startTime: Date
        let endTime: Date
        let notes: String?
        let calendarTitle: String

        var displayTitle: String {
            return "vs \(opponent)"
        }

        var timeString: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: startTime)
        }

        var dateString: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: startTime)
        }

        var isToday: Bool {
            Calendar.current.isDateInToday(startTime)
        }

        var isTomorrow: Bool {
            Calendar.current.isDateInTomorrow(startTime)
        }

        var isUpcoming: Bool {
            startTime > Date()
        }
    }

    private init() {
        loadSelectedCalendars()
        loadWeekendsOnlySetting()
        loadIgnoredEvents()
        checkCalendarAccess()
    }

    // MARK: - Calendar Access

    func checkCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)

        DispatchQueue.main.async {
            // Handle both iOS 17+ and earlier versions
            if #available(iOS 17.0, *) {
                self.hasCalendarAccess = (status == .fullAccess || status == .writeOnly)
            } else {
                self.hasCalendarAccess = (status == .authorized)
            }

            if self.hasCalendarAccess {
                debugPrint("✅ Calendar access granted")
                self.loadUpcomingGames()
            } else {
                debugPrint("⚠️ Calendar access not granted: \(status.rawValue)")
            }
        }
    }

    func requestCalendarAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.hasCalendarAccess = granted
                    if granted {
                        debugPrint("✅ Calendar full access granted")
                        self.loadUpcomingGames()
                    }
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    self.hasCalendarAccess = granted
                    if granted {
                        debugPrint("✅ Calendar access granted")
                        self.loadUpcomingGames()
                    }
                }
                return granted
            }
        } catch {
            forcePrint("❌ Calendar access request failed: \(error)")
            await MainActor.run {
                self.hasCalendarAccess = false
            }
            return false
        }
    }

    // MARK: - Calendar Selection

    func getAvailableCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }

    func saveSelectedCalendars(_ calendarIdentifiers: [String]) {
        selectedCalendars = calendarIdentifiers
        userDefaults.set(calendarIdentifiers, forKey: selectedCalendarsKey)
        forcePrint("✅ Saved selected calendars: \(calendarIdentifiers)")
        loadUpcomingGames()
    }

    private func loadSelectedCalendars() {
        if let saved = userDefaults.array(forKey: selectedCalendarsKey) as? [String] {
            selectedCalendars = saved
            debugPrint("📅 Loaded selected calendars: \(saved)")
        }
    }

    func saveWeekendsOnlySetting(_ value: Bool) {
        weekendsOnly = value
        userDefaults.set(value, forKey: weekendsOnlyKey)
        forcePrint("✅ Saved weekends-only setting: \(value)")
        loadUpcomingGames()
    }

    private func loadWeekendsOnlySetting() {
        // Default to true if not set
        if userDefaults.object(forKey: weekendsOnlyKey) != nil {
            weekendsOnly = userDefaults.bool(forKey: weekendsOnlyKey)
            debugPrint("📅 Loaded weekends-only setting: \(weekendsOnly)")
        } else {
            weekendsOnly = true
            debugPrint("📅 Using default weekends-only setting: true")
        }
    }

    // MARK: - Ignored Events Management

    func ignoreEvent(_ eventId: String) {
        ignoredEventIds.insert(eventId)
        saveIgnoredEvents()
        loadUpcomingGames() // Refresh to remove ignored event
        forcePrint("✅ Event ignored: \(eventId)")
    }

    func unignoreEvent(_ eventId: String) {
        ignoredEventIds.remove(eventId)
        saveIgnoredEvents()
        loadUpcomingGames() // Refresh to show unignored event
        forcePrint("✅ Event unignored: \(eventId)")
    }

    private func loadIgnoredEvents() {
        if let saved = userDefaults.array(forKey: ignoredEventsKey) as? [String] {
            ignoredEventIds = Set(saved)
            debugPrint("🚫 Loaded \(ignoredEventIds.count) ignored event(s)")
        }
    }

    private func saveIgnoredEvents() {
        let array = Array(ignoredEventIds)
        userDefaults.set(array, forKey: ignoredEventsKey)
        debugPrint("💾 Saved \(array.count) ignored event(s)")
    }

    // MARK: - Game Loading

    func loadUpcomingGames() {
        guard hasCalendarAccess else {
            debugPrint("⚠️ Cannot load games - no calendar access")
            return
        }

        // Get calendars to search
        let calendarsToSearch: [EKCalendar]
        if selectedCalendars.isEmpty {
            // If no calendars selected, search all
            calendarsToSearch = eventStore.calendars(for: .event)
        } else {
            // Only search selected calendars
            calendarsToSearch = eventStore.calendars(for: .event).filter {
                selectedCalendars.contains($0.calendarIdentifier)
            }
        }

        guard !calendarsToSearch.isEmpty else {
            debugPrint("⚠️ No calendars to search")
            return
        }

        debugPrint("🔍 Searching \(calendarsToSearch.count) calendar(s) for games")

        // Search from today to 30 days in future
        let now = Date()
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: thirtyDaysFromNow,
            calendars: calendarsToSearch
        )

        let events = eventStore.events(matching: predicate)
        debugPrint("📅 Found \(events.count) total events")

        // Optionally filter to weekend events only
        let filteredEvents: [EKEvent]
        if weekendsOnly {
            filteredEvents = events.filter { event in
                let weekday = Calendar.current.component(.weekday, from: event.startDate)
                // weekday: 1 = Sunday, 7 = Saturday
                return weekday == 1 || weekday == 7
            }
            debugPrint("📅 Found \(filteredEvents.count) weekend events (weekends-only filter enabled)")
        } else {
            filteredEvents = events
            debugPrint("📅 Showing all \(filteredEvents.count) events (weekends-only filter disabled)")
        }

        // Parse all filtered events and filter out practices/training/ignored events
        let games = filteredEvents.compactMap { event -> CalendarGame? in
            let eventTitle = event.title ?? "Untitled Event"
            let eventId = event.eventIdentifier ?? UUID().uuidString

            // Skip ignored events
            if ignoredEventIds.contains(eventId) {
                debugPrint("   🚫 Skipping ignored event: \(eventTitle)")
                return nil
            }

            // Skip practice and training events
            if isPracticeOrTraining(eventTitle) {
                debugPrint("   ⏭️ Skipping practice/training event: \(eventTitle)")
                return nil
            }

            // Try to parse opponent, fallback to full title if parsing fails
            let opponent = parseOpponent(from: eventTitle) ?? extractTournamentOpponent(from: eventTitle) ?? eventTitle

            return CalendarGame(
                id: eventId,
                title: eventTitle,
                opponent: opponent,
                location: event.location ?? "Unknown Location",
                startTime: event.startDate,
                endTime: event.endDate,
                notes: event.notes,
                calendarTitle: event.calendar?.title ?? "Unknown Calendar"
            )
        }

        DispatchQueue.main.async {
            self.upcomingGames = games.sorted { $0.startTime < $1.startTime }
            debugPrint("🏀 Found \(games.count) basketball game(s)")

            for game in games.prefix(3) {
                debugPrint("   - \(game.opponent) at \(game.timeString) on \(game.dateString)")
            }
        }
    }

    // MARK: - Game Parsing

    private func parseOpponent(from title: String) -> String? {
        // Get user's team name(s) from settings
        let userTeamNames = getUserTeamNames()

        // Extract both teams from calendar title
        let teams = extractTeamNames(from: title)

        // If we found two teams, figure out which is the opponent
        if teams.count == 2 {
            let team1 = teams[0]
            let team2 = teams[1]

            // Check if either team matches user's team (using fuzzy matching)
            let team1IsUsers = userTeamNames.contains { userTeam in
                fuzzyMatch(userTeam: userTeam, calendarTeam: team1)
            }
            let team2IsUsers = userTeamNames.contains { userTeam in
                fuzzyMatch(userTeam: userTeam, calendarTeam: team2)
            }

            if team1IsUsers && !team2IsUsers {
                // Team 1 is user's team, team 2 is opponent
                debugPrint("   📝 Parsed teams: \(team1) (user) vs \(team2) (opponent)")
                return team2
            } else if team2IsUsers && !team1IsUsers {
                // Team 2 is user's team, team 1 is opponent
                debugPrint("   📝 Parsed teams: \(team2) (user) vs \(team1) (opponent)")
                return team1
            } else if !team1IsUsers && !team2IsUsers {
                // Neither matches - assume second team is opponent
                debugPrint("   📝 Parsed teams: \(team1) vs \(team2) (assuming \(team2) is opponent)")
                return team2
            }
        }

        // If no teams found, return nil (will use full title as fallback)
        return nil
    }

    private func isPracticeOrTraining(_ title: String) -> Bool {
        let lowercased = title.lowercased()
        let practiceKeywords = [
            "practice",
            "training",
            "skills",
            "drill",
            "workout",
            "scrimmage"
        ]

        return practiceKeywords.contains { keyword in
            lowercased.contains(keyword)
        }
    }

    private func fuzzyMatch(userTeam: String, calendarTeam: String) -> Bool {
        let userLower = userTeam.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let calendarLower = calendarTeam.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match
        if userLower == calendarLower {
            debugPrint("   ✅ Exact match: '\(userTeam)' == '\(calendarTeam)'")
            return true
        }

        // Check if calendar team starts with user team (e.g., "Elements" matches "Elements AAU")
        if calendarLower.hasPrefix(userLower + " ") || calendarLower.hasPrefix(userLower) {
            debugPrint("   ✅ Prefix match: '\(userTeam)' matches start of '\(calendarTeam)'")
            return true
        }

        // Check if user team is contained as a whole word in calendar team
        // This handles cases like "Uneqld" in "Uneqld Boys 9/10U"
        let calendarWords = calendarLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if calendarWords.contains(userLower) {
            debugPrint("   ✅ Word match: '\(userTeam)' found as word in '\(calendarTeam)'")
            return true
        }

        return false
    }

    private func extractTeamNames(from title: String) -> [String] {
        var teams: [String] = []
        let lowercased = title.lowercased()

        // Pattern: "Team1 vs Team2", "Team1 @ Team2", "Team1 at Team2", "Team1 - Team2"
        let separators = [
            " vs ", " vs. ", " v. ",
            " @ ",
            " at ",
            " - "
        ]

        for separator in separators {
            if let range = lowercased.range(of: separator) {
                // Get text before separator
                let beforeSeparator = String(title[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)

                // Get text after separator
                let afterSeparator = String(title[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                // Extract team names (removing common keywords)
                let team1 = cleanTeamName(beforeSeparator)
                let team2 = cleanTeamName(afterSeparator)

                if let team1 = team1 {
                    teams.append(team1)
                }
                if let team2 = team2 {
                    teams.append(team2)
                }

                if teams.count == 2 {
                    debugPrint("   🔍 Found teams using '\(separator)': \(teams[0]) vs \(teams[1])")
                    return teams
                }
            }
        }

        return teams
    }

    private func cleanTeamName(_ text: String) -> String? {
        let keywords = ["basketball", "bball", "game"]
        var cleaned = text

        // Remove keywords
        for keyword in keywords {
            cleaned = cleaned.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }

        // Clean up extra whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Replace multiple spaces with single space
        let words = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        cleaned = words.joined(separator: " ")

        // Return the full cleaned team name (preserving "Elements AAU", "Uneqld Boys 9/10U", etc.)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func extractSingleOpponent(from title: String) -> String? {
        let lowercased = title.lowercased()

        // Try "vs" or "v." pattern
        if let vsRange = lowercased.range(of: "vs ") ?? lowercased.range(of: "v. ") {
            let afterVs = String(title[vsRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let opponent = cleanTeamName(afterVs) {
                return opponent
            }
        }

        // Try "against" pattern
        if let againstRange = lowercased.range(of: "against ") {
            let afterAgainst = String(title[againstRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let opponent = cleanTeamName(afterAgainst) {
                return opponent
            }
        }

        // Try "@" pattern
        if let atRange = lowercased.range(of: " @ ") {
            let afterAt = String(title[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let opponent = cleanTeamName(afterAt) {
                return opponent
            }
        }

        return nil
    }

    private func extractTournamentOpponent(from title: String) -> String? {
        // Handle tournament/event format: "UNEQLD Boys 9/10U - Tentative: NBBA Tourney"
        // Pattern: "Team Name - EventType: Tournament Name"

        let lowercased = title.lowercased()

        // Check for dash separator (common in tournament events)
        if let dashRange = title.range(of: " - ") {
            let afterDash = String(title[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Remove common prefixes like "Tentative:", "Confirmed:", etc.
            let prefixesToRemove = ["tentative:", "confirmed:", "scheduled:", "pending:"]
            var cleanedOpponent = afterDash

            for prefix in prefixesToRemove {
                if lowercased.hasPrefix(String(title[..<dashRange.lowerBound]).lowercased() + " - " + prefix) {
                    if let colonRange = afterDash.range(of: ":") {
                        cleanedOpponent = String(afterDash[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                    break
                }
            }

            // Clean and return
            if let cleaned = cleanTeamName(cleanedOpponent), !cleaned.isEmpty {
                debugPrint("   🏆 Tournament event detected: '\(cleaned)'")
                return cleaned
            }
        }

        return nil
    }

    private func getUserTeamNames() -> [String] {
        // Get all possible team names the user might use
        var teamNames: [String] = []

        // Try to get from UserDefaults or settings
        if let savedTeamName = userDefaults.string(forKey: "defaultTeamName") {
            teamNames.append(savedTeamName)
        }

        // Also try common settings keys
        if let teamName = userDefaults.string(forKey: "teamName") {
            teamNames.append(teamName)
        }

        // TODO: Could also pull from recent games in Firebase
        // For now, if we don't have a saved team name, we'll rely on the second team being the opponent

        debugPrint("   📋 Known user team names: \(teamNames.isEmpty ? "none (will assume second team is opponent)" : teamNames.joined(separator: ", "))")

        return teamNames
    }

    // MARK: - Game Creation

    func createLiveGameFromCalendar(_ calendarGame: CalendarGame, settings: GameSettings) -> LiveGame {
        debugPrint("🏀 Creating live game from calendar event:")
        debugPrint("   Opponent: \(calendarGame.opponent)")
        debugPrint("   Location: \(calendarGame.location)")
        debugPrint("   Time: \(calendarGame.timeString)")

        return LiveGame(
            teamName: settings.teamName,
            opponent: calendarGame.opponent,
            location: calendarGame.location,
            gameFormat: settings.gameFormat,
            quarterLength: settings.quarterLength,
            isMultiDeviceSetup: false
        )
    }

    // MARK: - Manual Refresh

    func refreshGames() {
        debugPrint("🔄 Manual refresh requested")
        loadUpcomingGames()
    }
}

// MARK: - Game Settings Helper

struct GameSettings {
    var teamName: String
    var quarterLength: Int
    var gameFormat: GameFormat

    static var `default`: GameSettings {
        GameSettings(
            teamName: "Home",
            quarterLength: 8,
            gameFormat: .quarters
        )
    }
}
