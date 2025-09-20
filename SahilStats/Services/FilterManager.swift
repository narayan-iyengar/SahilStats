//
//  FilterManager.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/20/25.
//
// File: SahilStats/Services/FilterManager.swift

import Foundation
import SwiftUI
import Combine

// MARK: - Filter Manager for Persistent Preferences

class FilterManager: ObservableObject {
    static let shared = FilterManager()
    
    @Published var recentSearches: [String] = []
    @Published var favoriteTeams: [String] = []
    @Published var favoriteOpponents: [String] = []
    
    private let maxRecentSearches = 10
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadFromUserDefaults()
    }
    
    // MARK: - Recent Searches
    
    func addRecentSearch(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !recentSearches.contains(trimmed) else { return }
        
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveToUserDefaults()
    }
    
    func clearRecentSearches() {
        recentSearches.removeAll()
        saveToUserDefaults()
    }
    
    // MARK: - Favorite Teams/Opponents
    
    func toggleFavoriteTeam(_ team: String) {
        if favoriteTeams.contains(team) {
            favoriteTeams.removeAll { $0 == team }
        } else {
            favoriteTeams.append(team)
        }
        saveToUserDefaults()
    }
    
    func toggleFavoriteOpponent(_ opponent: String) {
        if favoriteOpponents.contains(opponent) {
            favoriteOpponents.removeAll { $0 == opponent }
        } else {
            favoriteOpponents.append(opponent)
        }
        saveToUserDefaults()
    }
    
    // MARK: - Persistence
    
    private func loadFromUserDefaults() {
        recentSearches = userDefaults.stringArray(forKey: "recentSearches") ?? []
        favoriteTeams = userDefaults.stringArray(forKey: "favoriteTeams") ?? []
        favoriteOpponents = userDefaults.stringArray(forKey: "favoriteOpponents") ?? []
    }
    
    private func saveToUserDefaults() {
        userDefaults.set(recentSearches, forKey: "recentSearches")
        userDefaults.set(favoriteTeams, forKey: "favoriteTeams")
        userDefaults.set(favoriteOpponents, forKey: "favoriteOpponents")
    }
    
    // MARK: - Smart Suggestions
    
    func getSmartSuggestions(for searchText: String, from games: [Game]) -> [SearchSuggestion] {
        guard !searchText.isEmpty else {
            return getRecentSuggestions()
        }
        
        var suggestions: [SearchSuggestion] = []
        
        // Team suggestions
        let teams = Set(games.map { $0.teamName })
        let matchingTeams = teams.filter { $0.localizedCaseInsensitiveContains(searchText) }
        suggestions.append(contentsOf: matchingTeams.map {
            SearchSuggestion(text: $0, type: .team, isFavorite: favoriteTeams.contains($0))
        })
        
        // Opponent suggestions
        let opponents = Set(games.map { $0.opponent })
        let matchingOpponents = opponents.filter { $0.localizedCaseInsensitiveContains(searchText) }
        suggestions.append(contentsOf: matchingOpponents.map {
            SearchSuggestion(text: $0, type: .opponent, isFavorite: favoriteOpponents.contains($0))
        })
        
        // Location suggestions
        let locations = Set(games.compactMap { $0.location })
        let matchingLocations = locations.filter { $0.localizedCaseInsensitiveContains(searchText) }
        suggestions.append(contentsOf: matchingLocations.map {
            SearchSuggestion(text: $0, type: .location, isFavorite: false)
        })
        
        // Sort by relevance (favorites first, then alphabetical)
        return suggestions.sorted { first, second in
            if first.isFavorite != second.isFavorite {
                return first.isFavorite
            }
            return first.text < second.text
        }
    }
    
    private func getRecentSuggestions() -> [SearchSuggestion] {
        return recentSearches.map { SearchSuggestion(text: $0, type: .recent, isFavorite: false) }
    }
}

// MARK: - Search Suggestion Model

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let isFavorite: Bool
    
    enum SuggestionType {
        case team
        case opponent
        case location
        case recent
        
        var icon: String {
            switch self {
            case .team: return "sportscourt"
            case .opponent: return "person.2"
            case .location: return "location"
            case .recent: return "clock"
            }
        }
        
        var color: Color {
            switch self {
            case .team: return .blue
            case .opponent: return .purple
            case .location: return .green
            case .recent: return .gray
            }
        }
    }
}

// MARK: - Enhanced Search Bar with Suggestions

struct EnhancedSearchBar: View {
    @Binding var searchText: String
    let games: [Game]
    let onSuggestionTap: (String) -> Void
    
    @StateObject private var filterManager = FilterManager.shared
    @State private var showingSuggestions = false
    @State private var suggestions: [SearchSuggestion] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search teams, opponents, or locations", text: $searchText)
                        .onSubmit {
                            if !searchText.isEmpty {
                                filterManager.addRecentSearch(searchText)
                            }
                            showingSuggestions = false
                        }
                        .onTapGesture {
                            showingSuggestions = true
                            updateSuggestions()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            showingSuggestions = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Suggestions dropdown
            if showingSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(8)) { suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            onTap: {
                                searchText = suggestion.text
                                onSuggestionTap(suggestion.text)
                                showingSuggestions = false
                                
                                if suggestion.type != .recent {
                                    filterManager.addRecentSearch(suggestion.text)
                                }
                            },
                            onFavoriteToggle: {
                                switch suggestion.type {
                                case .team:
                                    filterManager.toggleFavoriteTeam(suggestion.text)
                                case .opponent:
                                    filterManager.toggleFavoriteOpponent(suggestion.text)
                                default:
                                    break
                                }
                                updateSuggestions()
                            }
                        )
                        
                        if suggestion.id != suggestions.prefix(8).last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .onChange(of: searchText) { _, newValue in
            updateSuggestions()
            showingSuggestions = !newValue.isEmpty || suggestions.isEmpty == false
        }
        .onTapGesture {
            // Dismiss suggestions when tapping outside
            showingSuggestions = false
        }
    }
    
    private func updateSuggestions() {
        suggestions = filterManager.getSmartSuggestions(for: searchText, from: games)
    }
}

// MARK: - Suggestion Row Component

struct SuggestionRow: View {
    let suggestion: SearchSuggestion
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(suggestion.type.color)
                    .frame(width: 20)
                
                Text(suggestion.text)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if suggestion.type == .team || suggestion.type == .opponent {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: suggestion.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(suggestion.isFavorite ? .red : .gray)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                
                if suggestion.type == .recent {
                    Button(action: {
                        FilterManager.shared.recentSearches.removeAll { $0 == suggestion.text }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    @Binding var selectedOutcomeFilter: GameOutcome?
    @Binding var selectedDateRange: GameListView.DateRange
    let onClearAll: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Clear all button
                Button("Clear All") {
                    onClearAll()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                    .frame(height: 20)
                
                // Outcome filters
                ForEach([GameOutcome.win, GameOutcome.loss], id: \.self) { outcome in
                    Button(action: {
                        selectedOutcomeFilter = selectedOutcomeFilter == outcome ? nil : outcome
                    }) {
                        HStack(spacing: 4) {
                            Text(outcome.emoji)
                            Text(outcome.displayName)
                        }
                        .font(.caption)
                        .foregroundColor(selectedOutcomeFilter == outcome ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedOutcomeFilter == outcome ? Color.orange : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 20)
                
                // Date range filters
                ForEach([GameListView.DateRange.week, GameListView.DateRange.month], id: \.self) { range in
                    Button(action: {
                        selectedDateRange = selectedDateRange == range ? .all : range
                    }) {
                        Text(range.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedDateRange == range ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedDateRange == range ? Color.blue : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}
