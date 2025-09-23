// File: SahilStats/Managers/GameFilterManager.swift

import SwiftUI
import Combine

class GameFilterManager: ObservableObject {
    @Published var searchText = ""
    @Published var showingFilters = false
    @Published var selectedTeamFilter = "All Teams"
    @Published var selectedOpponentFilter = "All Opponents"
    @Published var selectedOutcomeFilter: GameOutcome? = nil
    @Published var selectedDateRange: GameListView.DateRange = .all
    @Published var customStartDate = Date().addingTimeInterval(-30*24*60*60)
    @Published var customEndDate = Date()
    @Published var displayedGames: [Game] = []
    @Published var needsUpdate = false
    
    private var currentPage = 1
    private let gamesPerPage = 10
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedTeamFilter != "All Teams" { count += 1 }
        if selectedOpponentFilter != "All Opponents" { count += 1 }
        if selectedOutcomeFilter != nil { count += 1 }
        if selectedDateRange != .all { count += 1 }
        return count
    }
    
    func applyFilters(to games: [Game]) -> [Game] {
        var filteredGames = games
        
        // Apply search filter
        if !searchText.isEmpty {
            filteredGames = filteredGames.filter { game in
                game.teamName.localizedCaseInsensitiveContains(searchText) ||
                game.opponent.localizedCaseInsensitiveContains(searchText) ||
                (game.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply team filter
        if selectedTeamFilter != "All Teams" {
            filteredGames = filteredGames.filter { $0.teamName == selectedTeamFilter }
        }
        
        // Apply opponent filter
        if selectedOpponentFilter != "All Opponents" {
            filteredGames = filteredGames.filter { $0.opponent == selectedOpponentFilter }
        }
        
        // Apply outcome filter
        if let outcome = selectedOutcomeFilter {
            filteredGames = filteredGames.filter { $0.outcome == outcome }
        }
        
        // Apply date range filter
        if let dateFilter = selectedDateRange.dateFilter(from: customStartDate, to: customEndDate) {
            let (startDate, endDate) = dateFilter
            filteredGames = filteredGames.filter { game in
                game.timestamp >= startDate && game.timestamp <= endDate
            }
        }
        
        return filteredGames
    }
    
    func updateDisplayedGames(from filteredGames: [Game]) {
        let endIndex = min(currentPage * gamesPerPage, filteredGames.count)
        displayedGames = Array(filteredGames.prefix(endIndex))
    }

    // Add this new function
    func loadMoreGames(from filteredGames: [Game]) {
        currentPage += 1
        updateDisplayedGames(from: filteredGames)
    }
    
    func updateGameInDisplayed(_ updatedGame: Game) {
        if let index = displayedGames.firstIndex(where: { $0.id == updatedGame.id }) {
            displayedGames[index] = updatedGame
        }
    }
    
    func clearAllFilters() {
        searchText = ""
        selectedTeamFilter = "All Teams"
        selectedOpponentFilter = "All Opponents"
        selectedOutcomeFilter = nil
        selectedDateRange = .all
        resetPagination()
    }
    
    func resetPagination() {
        currentPage = 1
        needsUpdate.toggle()
    }
    
    func triggerUpdate() {
        resetPagination()
    }
}
