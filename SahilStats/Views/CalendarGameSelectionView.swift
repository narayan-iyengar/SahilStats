//
//  CalendarGameSelectionView.swift
//  SahilStats
//
//  UI for selecting games from calendar and starting with QR code
//

import SwiftUI
import FirebaseAuth

struct CalendarGameSelectionView: View {
    @ObservedObject private var calendarManager = GameCalendarManager.shared
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var showingCalendarPermission = false
    @State private var showingGameConfirmation = false
    @State private var selectedCalendarGame: GameCalendarManager.CalendarGame?
    @State private var editableGame: LiveGame?
    @State private var showingQRCode = false

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationView {
            ZStack {
                if !calendarManager.hasCalendarAccess {
                    calendarPermissionView
                } else if calendarManager.upcomingGames.isEmpty {
                    noGamesView
                } else {
                    gameListView
                }
            }
            .navigationTitle("Upcoming Games")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        calendarManager.refreshGames()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingGameConfirmation) {
                if let game = editableGame {
                    GameConfirmationView(
                        liveGame: game,
                        onStart: startGame,
                        onCancel: { showingGameConfirmation = false }
                    )
                }
            }
            .sheet(isPresented: $showingQRCode) {
                if let game = editableGame {
                    GameQRCodeDisplayView(liveGame: game)
                }
            }
        }
    }

    // MARK: - Calendar Permission View

    private var calendarPermissionView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Calendar Access")
                    .font(.title)
                    .fontWeight(.bold)

                Text("SahilStats can pull your game schedule from your calendar to make setup faster.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Text("We'll use your calendar to:")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    PermissionBulletPoint(
                        icon: "checkmark.circle.fill",
                        text: "Auto-fill opponent names",
                        color: .green
                    )
                    PermissionBulletPoint(
                        icon: "checkmark.circle.fill",
                        text: "Pre-set game times and locations",
                        color: .green
                    )
                    PermissionBulletPoint(
                        icon: "checkmark.circle.fill",
                        text: "Show upcoming games on dashboard",
                        color: .green
                    )
                }
                .padding(.horizontal)
            }

            Button("Allow Calendar Access") {
                Task {
                    await calendarManager.requestCalendarAccess()
                }
            }
            .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))

            Button("Skip for Now") {
                dismiss()
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
        }
        .padding()
    }

    // MARK: - No Games View

    private var noGamesView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("No Games Found")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("We couldn't find any basketball games in your calendar for the next 30 days.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Text("Add games to your calendar with:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("• \"Basketball vs Warriors\"")
                    Text("• \"Game vs Eagles\"")
                    Text("• \"vs Thunder\"")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Button("Create Manual Game") {
                dismiss()
                // Navigate to manual game creation
            }
            .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))

            Button("Go to Settings") {
                dismiss()
                // Navigate to calendar settings
            }
            .buttonStyle(UnifiedSecondaryButtonStyle(isIPad: isIPad))
        }
        .padding()
    }

    // MARK: - Game List View

    private var gameListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(calendarManager.upcomingGames) { game in
                    CalendarGameCard(
                        game: game,
                        isIPad: isIPad,
                        onSelect: {
                            selectGame(game)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive, action: {
                            calendarManager.ignoreEvent(game.id)
                        }) {
                            Label("Ignore This Game", systemImage: "eye.slash")
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Game Selection

    private func selectGame(_ calendarGame: GameCalendarManager.CalendarGame) {
        selectedCalendarGame = calendarGame

        // Get user's default settings
        let settings = GameSettings(
            teamName: authService.currentUser?.email?.components(separatedBy: "@").first?.capitalized ?? "Home",
            quarterLength: 8, // Default - user can edit
            gameFormat: .quarters // Default - user can edit
        )

        // Create live game from calendar
        let liveGame = calendarManager.createLiveGameFromCalendar(calendarGame, settings: settings)
        editableGame = liveGame

        // Show confirmation screen
        showingGameConfirmation = true
    }

    private func startGame(_ liveGame: LiveGame) {
        Task {
            do {
                // Create live game in Firebase
                let gameId = try await firebaseService.createLiveGame(liveGame)
                forcePrint("✅ Live game created with ID: \(gameId)")

                // Update editableGame with the ID
                var gameWithId = liveGame
                gameWithId.id = gameId
                editableGame = gameWithId

                // Dismiss confirmation
                await MainActor.run {
                    showingGameConfirmation = false
                }

                // Show QR code for camera phone to scan
                await MainActor.run {
                    showingQRCode = true
                }

                // Navigate to controller view (stats phone)
                await MainActor.run {
                    navigation.currentFlow = .liveGame(gameWithId)
                    dismiss()
                }

            } catch {
                forcePrint("❌ Failed to create live game: \(error)")
            }
        }
    }
}

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

                    // Opponent info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.opponent)
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
}

// MARK: - Game Confirmation View

struct GameConfirmationView: View {
    @State var liveGame: LiveGame
    let onStart: (LiveGame) -> Void
    let onCancel: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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

    var body: some View {
        NavigationView {
            Form {
                Section("Game Details") {
                    HStack {
                        Text("Opponent")
                        Spacer()
                        TextField("Team Name", text: $liveGame.opponent)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Location")
                        Spacer()
                        TextField("Court/Gym", text: locationBinding)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Game Settings") {
                    Picker("Format", selection: $liveGame.gameFormat) {
                        Text("Quarters").tag(GameFormat.quarters)
                        Text("Halves").tag(GameFormat.halves)
                    }

                    Stepper("Quarter Length: \(liveGame.quarterLength) min", value: $liveGame.quarterLength, in: 1...20)
                }

                Section {
                    Button("Start Game") {
                        onStart(liveGame)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .font(.headline)
                }
            }
            .navigationTitle("Confirm Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Permission Bullet Point

struct PermissionBulletPoint: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    CalendarGameSelectionView()
        .environmentObject(AuthService())
}
