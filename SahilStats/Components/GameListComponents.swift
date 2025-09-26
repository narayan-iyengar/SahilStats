// File: SahilStats/Views/Components/GameListComponents.swift

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
            Text("Loading games...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let canCreateGames: Bool
    let isIPad: Bool
    
    var body: some View {
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
            
            if canCreateGames {
                NavigationLink("Create Your First Game") {
                    GameSetupView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
}

// MARK: - Enhanced User Status Indicator
struct UserStatusIndicator: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Image(systemName: statusIcon)
            .foregroundColor(statusColor)
            .font(.body) // Make it bigger
            .frame(width: 24, height: 24) // Fixed frame for consistent centering
            .background(statusColor.opacity(0.1))
            .clipShape(Circle())
    }
    
    private var statusIcon: String {
        if authService.isSignedIn && !authService.isAnonymous {
            return "person.crop.circle.fill"
        } else if authService.isAnonymous {
            return "person.crop.circle"
        } else {
            return "person.crop.circle.badge.xmark"
        }
    }
    
    private var statusColor: Color {
        if authService.isSignedIn && !authService.isAnonymous {
            return .green
        } else if authService.isAnonymous {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if authService.isSignedIn && !authService.isAnonymous {
            return authService.userRole.displayName
        } else if authService.isAnonymous {
            return "Guest"
        } else {
            return "Not Signed In"
        }
    }
}

// MARK: - Game List Toolbar
struct GameListToolbar: View {
    let activeFiltersCount: Int
    let hasLiveGame: Bool
    let canCreateGames: Bool
    let onShowFilters: () -> Void
    let onShowLiveGame: () -> Void
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Filter button with badge
            Button(action: onShowFilters) {
                // Conditionally change the icon based on whether filters are active
                Image(systemName: activeFiltersCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            
            if hasLiveGame {
                LiveGameButton(action: onShowLiveGame)
            }
        }
    }
}

// MARK: - Live Game Button
struct LiveGameButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
}


// MARK: - Game Delete Alert
struct GameDeleteAlert: View {
    @Binding var gameToDelete: Game?
    let onDelete: (Game) -> Void
    
    var body: some View {
        Group {
            Button("Cancel", role: .cancel) {
                gameToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let game = gameToDelete {
                    onDelete(game)
                }
                gameToDelete = nil
            }
        }
    }
}
