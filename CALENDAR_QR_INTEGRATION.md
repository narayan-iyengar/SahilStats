# Calendar + QR Code Integration

## Overview
Simplifies game setup by pulling game details from iOS Calendar and using QR codes for instant device pairing.

## New User Flow

### Stats Phone (Controller):
1. Open app → Dashboard shows "Upcoming Games" section
2. Tap today's game (auto-filled from calendar):
   - "Cavaliers vs Warriors - 3:00 PM at Lincoln Gym"
3. Quick edit screen (pre-filled, editable):
   - ✓ Opponent: Warriors
   - ✓ Location: Lincoln Gym
   - ✓ Quarter Length: 8 min
4. Tap "Start Game" → Shows QR code
5. Stats phone automatically goes to controller view

### Camera Phone (Recorder):
1. Open app → Tap "Scan to Join Game" button
2. Scan QR code
3. See game confirmation:
   - "Join: Cavaliers vs Warriors?"
4. Tap "Start Recording" → Camera opens automatically
5. Done! Recording starts when stats phone presses record button

## Components Created

### 1. GameCalendarManager.swift
- Requests iOS calendar access (EventKit)
- Scans calendars for basketball games
- Parses opponent from various formats:
  - "Cavaliers vs Warriors"
  - "Warriors @ Cavaliers"
  - "Basketball game vs Eagles"
- Matches user's team name to determine opponent
- Returns list of upcoming games

### 2. GameQRCodeManager.swift
- Generates QR codes containing game details (JSON)
- Parses QR codes back into LiveGame objects
- Includes: gameId, teams, location, format, quarter length
- QR code data is encrypted in JSON format

### 3. CalendarGameSelectionView.swift
- Shows list of upcoming games from calendar
- Calendar permission request flow
- Game confirmation/edit screen
- Shows QR code after game created

### 4. QRCodeScannerView.swift
- Camera-based QR scanner
- Parses game details from QR code
- Auto-joins game as recorder
- Shows confirmation before joining

## Integration Points

### Dashboard (DashboardView.swift)
Add button to show calendar games:
```swift
Button("Upcoming Games") {
    showingCalendarGames = true
}
.sheet(isPresented: $showingCalendarGames) {
    CalendarGameSelectionView()
}

Button("Scan to Join Game") {
    showingQRScanner = true
}
.sheet(isPresented: $showingQRScanner) {
    QRCodeScannerView()
}
```

### Settings (SettingsView.swift)
Add calendar configuration section:
```swift
Section("Calendar Integration") {
    Toggle("Use Calendar for Games", isOn: $useCalendar)

    if useCalendar {
        NavigationLink("Select Calendars") {
            CalendarSelectionView()
        }

        TextField("Your Team Name", text: $defaultTeamName)
            .textContentType(.organizationName)
    }
}
```

### Info.plist
Add calendar permission description:
```xml
<key>NSCalendarsUsageDescription</key>
<string>SahilStats needs calendar access to automatically fill in game details from your schedule.</string>

<key>NSCameraUsageDescription</key>
<string>SahilStats needs camera access to scan QR codes for joining games.</string>
```

## Calendar Event Parsing Examples

| Calendar Title | User Team | Opponent | Result |
|---------------|-----------|----------|---------|
| "Cavaliers vs Warriors" | Cavaliers | ✓ Warriors | Works |
| "Warriors @ Cavaliers" | Cavaliers | ✓ Warriors | Works |
| "Basketball: Eagles vs Cavaliers" | Cavaliers | ✓ Eagles | Works |
| "Game vs Thunder" | (any) | ✓ Thunder | Works (assumes second team) |
| "Cavaliers Game" | (any) | ✗ Fails | Needs "vs" |
| "Meeting" | (any) | ✗ Fails | No basketball keyword |

## Benefits

1. **Faster Setup**: 2-3 taps instead of 10+ taps
2. **Less Typing**: Opponent/location pre-filled
3. **Fewer Errors**: Calendar has correct info
4. **Kid-Friendly**: Scan QR code = cool and simple
5. **No Role Confusion**: QR code auto-assigns roles
6. **No Device Pairing UI**: QR code contains game ID

## Future Enhancements

- [ ] Write final score back to calendar notes
- [ ] Show game reminders ("Game in 30 min")
- [ ] Support multiple teams (if user has multiple kids)
- [ ] Learn from past games to improve team name matching
- [ ] Support league/tournament schedules
