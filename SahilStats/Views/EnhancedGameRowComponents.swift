// File: SahilStats/Views/EnhancedGameRowComponents.swift


import SwiftUI
import Combine
import Foundation

// MARK: - Enhanced Editable Game Row View

struct EditableGameRowView: View {
    @Binding var game: Game
    let isHovered: Bool
    let canDelete: Bool
    let canEdit: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSave: (Game) -> Void
    
    @State private var isEditing = false
    @State private var editingGame: Game
    @State private var showingSaveAlert = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    init(game: Binding<Game>, isHovered: Bool, canDelete: Bool, canEdit: Bool, onTap: @escaping () -> Void, onDelete: @escaping () -> Void, onSave: @escaping (Game) -> Void) {
        self._game = game
        self.isHovered = isHovered
        self.canDelete = canDelete
        self.canEdit = canEdit
        self.onTap = onTap
        self.onDelete = onDelete
        self.onSave = onSave
        self._editingGame = State(initialValue: game.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main game row content
            HStack(spacing: 12) {
                // Game outcome indicator
                Circle()
                    .fill(outcomeColor)
                    .frame(width: isHovered ? 16 : 12, height: isHovered ? 16 : 12)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                
                VStack(alignment: .leading, spacing: 6) {
                    gameRowHeader
                    gameRowStats
                    gameRowFooter
                }
            }
            
            // Edit controls (show when editing)
            if isEditing {
                EditControlsBar(
                    onSave: { showingSaveAlert = true },
                    onCancel: cancelEditing
                )
                .padding(.top, 12)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }
        }
        .padding(.vertical, isHovered ? 8 : 4)
        .padding(.horizontal, isHovered ? 4 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isEditing ? Color.blue.opacity(0.05) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: isHovered ? .gray.opacity(0.2) : .clear, radius: isHovered ? 4 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.3), value: isEditing)
        .onTapGesture {
            if !isEditing {
                onTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            if canEdit && !isEditing {
                startEditing()
            }
        }
        .alert("Save Changes", isPresented: $showingSaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveChanges()
            }
        } message: {
            Text("Save the changes to this game?")
        }
        .contextMenu {
            contextMenuItems
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            swipeActionItems
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            swipeActionItems
        }
    }
    
    private var outcomeColor: Color {
        switch game.outcome {
        case .win: return .green
        case .loss: return .red
        case .tie: return .gray
        }
    }
    
    private func startEditing() {
        editingGame = game
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditing = true
        }
        
    #if !targetEnvironment(simulator)
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
    #endif
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditing = false
        }
        editingGame = game // Reset to original values
    }
    
    private func saveChanges() {
        game = editingGame
        onSave(game)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditing = false
        }
        
        // Success haptic
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
/*
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
*/
    private func formatRelativeDate(_ date: Date?) -> String {
        // Safely unwrap the optional date.
        guard let date = date else {
            // Provide a default string if the date is nil.
            return "Date unknown"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    

    // MARK: - Child Views
    
    private var gameRowHeader: some View {
        HStack {
            Text("\(game.teamName) vs \(game.opponent)")
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("\(game.myTeamScore) - \(game.opponentScore)")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(outcomeColor)
                
                // Action buttons (only show on hover for admins)
                if isHovered && !isEditing {
                    actionButtons
                }
            }
        }
    }
    
    private var gameRowStats: some View {
        Group {
            if isEditing {
                EditableStatsGrid(game: $editingGame)
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            } else {
                // Regular stats display
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
                                .font(isIPad ? .body : .caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var gameRowFooter: some View {
        Group {
            if !isEditing {
                HStack {
                    if let location = game.location {
                        Label(location, systemImage: "location")
                            .font(isIPad ? .body : .caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatRelativeDate(game.timestamp))
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                }
                
                // Achievements (always visible)
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
    }
    
    private var actionButtons: some View {
        HStack(spacing: 4) {
            if canEdit {
                Button(action: startEditing) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .transition(.opacity)
            }
            
            if canDelete {
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

    @ViewBuilder
    private var contextMenuItems: some View {
        if !isEditing {
            Button("View Details") {
                onTap()
            }
            if canDelete {
                Button("Delete Game", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
    
    @ViewBuilder
    private var swipeActionItems: some View {
        if !isEditing {
            if canDelete {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .tint(.red)
            }
            
            if canEdit {
                Button("Edit") {
                    startEditing()
                }
                .tint(.blue)
            }
            
            Button("Details") {
                onTap()
            }
            .tint(.green)
        }
    }
}


// MARK: - Editable Stats Grid

struct EditableStatsGrid: View {
    @Binding var game: Game
    
    var body: some View {
        VStack(spacing: 12) {
            // Main stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                EditableStatCell(title: "PTS", value: $game.points, color: .purple)
                EditableStatCell(title: "REB", value: $game.rebounds, color: .blue)
                EditableStatCell(title: "AST", value: $game.assists, color: .green)
                EditableStatCell(title: "STL", value: $game.steals, color: .yellow)
                EditableStatCell(title: "BLK", value: $game.blocks, color: .red)
                EditableStatCell(title: "TO", value: $game.turnovers, color: .pink)
            }
            
            // Score editing
            HStack {
                Text("Score:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                EditableScoreCell(title: game.teamName, value: $game.myTeamScore, color: .blue)
                
                Text("-")
                    .foregroundColor(.secondary)
                
                EditableScoreCell(title: game.opponent, value: $game.opponentScore, color: .red)
                
                Spacer()
            }
        }
    }
}

// MARK: - Editable Stat Cell

struct EditableStatCell: View {
    let title: String
    @Binding var value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Button("-") {
                    if value > 0 { value -= 1 }
                }
                .buttonStyle(MiniEditButtonStyle())
                
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(minWidth: 20)
                
                Button("+") {
                    value += 1
                }
                .buttonStyle(MiniEditButtonStyle())
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Editable Score Cell

struct EditableScoreCell: View {
    let title: String
    @Binding var value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 60)
            
            HStack(spacing: 4) {
                Button("-") {
                    if value > 0 { value -= 1 }
                }
                .buttonStyle(MiniEditButtonStyle())
                
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .frame(minWidth: 25)
                
                Button("+") {
                    value += 1
                }
                .buttonStyle(MiniEditButtonStyle())
            }
        }
    }
}

// MARK: - Edit Controls Bar

struct EditControlsBar: View {
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                onCancel()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            Spacer()
            
            Button("Save Changes") {
                onSave()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .cornerRadius(8)
        }
    }
}

// MARK: - Mini Edit Button Style

struct MiniEditButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Stat Pill

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




