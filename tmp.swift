# Playing Time Feature Implementation Guide

This guide will help you add playing time tracking to the SahilStats app, including real-time tracking during live games and career statistics.

## Step 1: Update Game Model (Game.swift)

### Add New Properties to Game Struct

Add these properties to your existing `Game` struct:

```swift
// Add these new properties to the Game struct
var totalPlayingTimeMinutes: Double = 0.0 // Total minutes on court
var benchTimeMinutes: Double = 0.0 // Total minutes on bench
var gameTimeTracking: [GameTimeSegment] = [] // Detailed time tracking

// Add computed property for playing time percentage
var playingTimePercentage: Double {
    let totalGameTime = totalPlayingTimeMinutes + benchTimeMinutes
    return totalGameTime > 0 ? (totalPlayingTimeMinutes / totalGameTime) * 100 : 0
}
```

### Add Supporting Struct

Add this new struct in the same file (Game.swift):

```swift
struct GameTimeSegment: Codable, Identifiable {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var isOnCourt: Bool // true = on court, false = on bench
    
    var durationMinutes: Double {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime) / 60.0
    }
}
```

## Step 2: Update LiveGame Model (Game.swift)

### Add Time Tracking to LiveGame Struct

Add these properties to your existing `LiveGame` struct:

```swift
// Add these to LiveGame struct
var currentTimeSegment: GameTimeSegment?
var timeSegments: [GameTimeSegment] = []

// Computed properties
var totalPlayingTime: Double {
    return timeSegments.filter { $0.isOnCourt }.reduce(0) { $0 + $1.durationMinutes }
}

var totalBenchTime: Double {
    return timeSegments.filter { !$0.isOnCourt }.reduce(0) { $0 + $1.durationMinutes }
}
```

## Step 3: Add Time Tracking Logic to LiveGameView

### Add Methods to LiveGameControllerView

In `LiveGameView.swift`, add these methods to the `LiveGameControllerView` struct:

```swift
// Add these methods to LiveGameControllerView
private func startTimeTracking(onCourt: Bool) {
    // End current segment if exists
    endCurrentTimeSegment()
    
    // Start new segment
    let newSegment = GameTimeSegment(
        startTime: Date(),
        endTime: nil,
        isOnCourt: onCourt
    )
    
    var updatedGame = serverGameState
    updatedGame.currentTimeSegment = newSegment
    
    Task {
        try await firebaseService.updateLiveGame(updatedGame)
    }
}

private func endCurrentTimeSegment() {
    guard var currentSegment = serverGameState.currentTimeSegment else { return }
    
    currentSegment.endTime = Date()
    
    var updatedGame = serverGameState
    updatedGame.timeSegments.append(currentSegment)
    updatedGame.currentTimeSegment = nil
    
    Task {
        try await firebaseService.updateLiveGame(updatedGame)
    }
}

private func updatePlayingStatus() {
    let wasOnCourt = serverGameState.currentTimeSegment?.isOnCourt ?? true
    let isNowOnCourt = !sahilOnBench
    
    if wasOnCourt != isNowOnCourt {
        startTimeTracking(onCourt: isNowOnCourt)
    }
    
    scheduleUpdate()
}
```

## Step 4: Update Player Status Change Handler

### Modify PlayerStatusCard Call

In your `LiveGameControllerView`, find the `PlayerStatusCard` and update it:

```swift
// Replace the existing PlayerStatusCard call with this:
PlayerStatusCard(
    sahilOnBench: $sahilOnBench,
    isIPad: isIPad,
    hasControl: deviceControl.hasControl,
    onStatusChange: updatePlayingStatus // Changed from scheduleUpdate
)
```

## Step 5: Create Playing Time Display Component

### Add to CompactLiveGameComponents.swift

Add these new components to `CompactLiveGameComponents.swift`:

```swift
struct PlayingTimeCard: View {
    let totalPlayingTime: Double
    let totalBenchTime: Double
    let isIPad: Bool
    
    private var totalTime: Double {
        totalPlayingTime + totalBenchTime
    }
    
    private var playingPercentage: Double {
        totalTime > 0 ? (totalPlayingTime / totalTime) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            Text("Playing Time")
                .font(isIPad ? .title3 : .headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: isIPad ? 20 : 16) {
                TimeStatItem(
                    title: "On Court",
                    time: totalPlayingTime,
                    color: .green,
                    isIPad: isIPad
                )
                
                TimeStatItem(
                    title: "On Bench",
                    time: totalBenchTime,
                    color: .orange,
                    isIPad: isIPad
                )
            }
            
            // Playing time percentage bar
            VStack(spacing: 4) {
                HStack {
                    Text("Court Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(playingPercentage))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * (playingPercentage / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(Color(.systemGray6))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

struct TimeStatItem: View {
    let title: String
    let time: Double
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Text(formatTime(time))
                .font(isIPad ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isIPad ? .caption : .caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatTime(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
```

## Step 6: Add to Live Game Display

### Update LiveGameControllerView

In your `LiveGameControllerView` body, add the playing time card after your existing stats:

```swift
// Add this after your existing stats cards in the ScrollView
PlayingTimeCard(
    totalPlayingTime: serverGameState.totalPlayingTime,
    totalBenchTime: serverGameState.totalBenchTime,
    isIPad: isIPad
)
```

## Step 7: Update Career Stats

### Modify CareerStats Struct

In `FirebaseService.swift`, add these properties to the `CareerStats` struct:

```swift
// Add these to CareerStats struct
let totalPlayingTimeMinutes: Double
let averagePlayingTimePerGame: Double
let playingTimePercentage: Double
```

### Update getCareerStats Function

In the `getCareerStats()` function in `FirebaseService.swift`, add these calculations:

```swift
// Add these calculations in getCareerStats() function
let totalPlayingTime = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }
let avgPlayingTime = totalGames > 0 ? totalPlayingTime / Double(totalGames) : 0.0
let totalGameTime = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes + $1.benchTimeMinutes }
let playingPercentage = totalGameTime > 0 ? (totalPlayingTime / totalGameTime) * 100 : 0

// Add these to the return statement
return CareerStats(
    // ... existing stats
    totalPlayingTimeMinutes: totalPlayingTime,
    averagePlayingTimePerGame: avgPlayingTime,
    playingTimePercentage: playingPercentage
)
```

## Step 8: Add Playing Time to Career Dashboard

### Update ModernOverviewStatsView

In `ModernCareerDashboard.swift`, add playing time stats:

```swift
// Add these StatCards to your existing LazyVGrid
ModernStatCard(
    title: "Avg Time",
    value: String(format: "%.0fm", stats.averagePlayingTimePerGame),
    color: .teal,
    isIPad: isIPad
)

ModernStatCard(
    title: "Court %",
    value: String(format: "%.0f%%", stats.playingTimePercentage),
    color: .green,
    isIPad: isIPad
)
```

### Add to Trends View

In the `TrendStatType` enum, add:

```swift
case avgPlayingTime = "Avg Playing Time"
case playingTimePercentage = "Court Time %"
```

And update the `calculateStatValue` function:

```swift
case .avgPlayingTime:
    return Double(games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }) / gameCount
case .playingTimePercentage:
    let totalPlaying = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes }
    let totalTime = games.reduce(0) { $0 + $1.totalPlayingTimeMinutes + $1.benchTimeMinutes }
    return totalTime > 0 ? (totalPlaying / totalTime) * 100 : 0
```

## Step 9: Update Game Finishing Logic

### Modify finishGame Function

In `LiveGameControllerView`, update the `finishGame()` function to include playing time:

```swift
private func finishGame() {
    guard deviceControl.hasControl else { return }
    
    // End current time segment
    endCurrentTimeSegment()
    
    // Calculate total playing time
    let totalPlayingTime = serverGameState.totalPlayingTime
    let totalBenchTime = serverGameState.totalBenchTime
    
    Task {
        do {
            let finalGame = Game(
                // ... existing parameters
                totalPlayingTimeMinutes: totalPlayingTime,
                benchTimeMinutes: totalBenchTime,
                gameTimeTracking: serverGameState.timeSegments
            )
            
            try await firebaseService.addGame(finalGame)
            try await firebaseService.deleteLiveGame(serverGameState.id ?? "")
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to finish game: \(error.localizedDescription)"
            }
        }
    }
}
```

## Implementation Notes

1. **Start with Step 1-2**: Update the data models first to support the new fields
2. **Test each step**: After implementing each section, test to ensure it compiles
3. **Firebase compatibility**: The new fields will automatically sync to Firebase
4. **Backward compatibility**: Existing games without playing time data will show 0 minutes
5. **Real-time updates**: Playing time will update automatically as users switch between court/bench

## Troubleshooting

- If you get compilation errors, make sure all new properties have default values
- If Firebase sync issues occur, check that all new structs conform to Codable
- For display issues, verify the PlayingTimeCard is added to the correct ScrollView section

This implementation provides comprehensive playing time tracking with real-time updates during games and historical analysis in career stats.

