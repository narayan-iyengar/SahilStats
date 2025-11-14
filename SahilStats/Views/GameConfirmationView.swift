//
//  GameConfirmationView.swift
//  SahilStats
//
//  Shared components for calendar game selection and confirmation
//

import SwiftUI
import FirebaseAuth

// MARK: - Calendar Game Card

struct CalendarGameCard: View {
    let game: GameCalendarManager.CalendarGame
    let isIPad: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Main game info
                HStack(alignment: .top, spacing: 12) {
                    // Basketball icon
                    Image(systemName: "basketball.fill")
                        .font(.system(size: isIPad ? 36 : 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isIPad ? 50 : 40)

                    // Game matchup info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gameMatchupText)
                            .font(isIPad ? .title2 : .title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        // Location (simplified)
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(simplifiedLocation)
                                .font(isIPad ? .subheadline : .caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Tap to start indicator
                    VStack(spacing: 4) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("TAP")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .opacity(0.7)
                }

                // Date & Time
                HStack(spacing: 16) {
                    // Date badge
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text(gameDateLabel)
                            .font(isIPad ? .subheadline : .caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(dateBackgroundColor)
                    .cornerRadius(8)

                    // Time
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(game.timeString)
                            .font(isIPad ? .subheadline : .caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    Spacer()
                }
            }
            .padding(isIPad ? 20 : 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var gameDateLabel: String {
        if game.isToday {
            return "Today"
        } else if game.isTomorrow {
            return "Tomorrow"
        } else {
            // Show short format: "Sat, Oct 21"
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            return formatter.string(from: game.startTime)
        }
    }

    private var dateBackgroundColor: Color {
        if game.isToday {
            return .green
        } else if game.isTomorrow {
            return .orange
        } else {
            return .blue
        }
    }

    private var simplifiedLocation: String {
        // Extract just the venue name, not the full address
        let location = game.location

        // If it contains a comma, take the first part (usually the venue name)
        if let commaIndex = location.firstIndex(of: ",") {
            return String(location[..<commaIndex])
        }

        // Otherwise return the full location
        return location
    }

    private var gameMatchupText: String {
        // Extract team name from title
        let teamName = extractTeamName(from: game.title)
        // Return "Team vs Opponent" format
        return "\(teamName) vs \(game.opponent)"
    }

    private func extractTeamName(from title: String) -> String {
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

        // Normalize team name for Firebase consistency before returning
        if !rawTeamName.isEmpty {
            return normalizeTeamName(rawTeamName)
        }

        // Fallback to a generic team name
        return "Team"
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
}

// MARK: - Game Confirmation View

struct GameConfirmationView: View {
    @State var liveGame: LiveGame
    let onStart: (LiveGame) -> Void
    let onCancel: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var showLocationPermissionAlert = false

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    // Create a non-optional binding for location
    private var locationBinding: Binding<String> {
        Binding(
            get: { liveGame.location ?? "" },
            set: { liveGame.location = $0.isEmpty ? nil : $0 }
        )
    }

    // Dynamic label based on game format
    private var periodLabel: String {
        liveGame.gameFormat == .quarters ? "Quarter Length" : "Half Length"
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Game Details") {
                    HStack {
                        Text("Sahil's Team")
                        Spacer()
                        TextField("Team Name", text: $liveGame.teamName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Opponent")
                        Spacer()
                        TextField("Team Name", text: $liveGame.opponent)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Location")
                        Spacer()
                        HStack {
                            TextField("Court/Gym", text: locationBinding)
                                .multilineTextAlignment(.trailing)

                            Button(action: {
                                locationManager.requestLocation()
                            }) {
                                if locationManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(locationManager.isLoading)
                        }
                    }
                }

                Section("Game Settings") {
                    Picker("Format", selection: $liveGame.gameFormat) {
                        Text("Quarters").tag(GameFormat.quarters)
                        Text("Halves").tag(GameFormat.halves)
                    }

                    Stepper("\(periodLabel): \(liveGame.quarterLength) min", value: $liveGame.quarterLength, in: 1...60)
                }

                Section {
                    GameSetupModeSelectionView(
                        onSelectMultiDevice: {
                            debugPrint("🎮 USER SELECTED: Multi-Device (Stats + Recording)")
                            var updatedGame = liveGame
                            updatedGame.isMultiDeviceSetup = true
                            debugPrint("🎮 Setting isMultiDeviceSetup = true")
                            debugPrint("🎮 Game config: \(updatedGame.teamName) vs \(updatedGame.opponent), multiDevice=\(updatedGame.isMultiDeviceSetup ?? false)")
                            onStart(updatedGame)
                        },
                        onSelectSingleDevice: {
                            debugPrint("🎮 USER SELECTED: Single-Device (Stats Only)")
                            var updatedGame = liveGame
                            updatedGame.isMultiDeviceSetup = false
                            debugPrint("🎮 Setting isMultiDeviceSetup = false")
                            debugPrint("🎮 Game config: \(updatedGame.teamName) vs \(updatedGame.opponent), multiDevice=\(updatedGame.isMultiDeviceSetup ?? false)")
                            onStart(updatedGame)
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("How do you want to set up?")
                        .font(.subheadline)
                        .textCase(nil)
                }
            }
            .navigationTitle("Confirm Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle")
                            .font(isIPad ? .title2 : .title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: locationManager.locationName) { _, newLocation in
                if !newLocation.isEmpty {
                    liveGame.location = newLocation
                }
            }
            .alert("Location Permission Required", isPresented: $showLocationPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable location services in Settings to use this feature.")
            }
        }
    }
}
