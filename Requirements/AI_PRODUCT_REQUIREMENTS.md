# AI Basketball Stats - Product Requirements Document

## Product Vision

Build an AI-powered video processing system that automatically extracts basketball statistics from game recordings, allowing parents to enjoy watching their kid play instead of manually tracking stats.

---

## Core User Story

**As a parent watching Sahil play basketball:**
- I want to just record the game and enjoy watching
- So that I don't miss moments trying to track stats manually
- And I still get detailed statistics after the game

---

## Key Product Decisions

### Player Context
- **Primary player:** Sahil (only basketball player in family)
- **Teams:** Plays for two different teams
  - Elements (wears #3)
  - Team Unequld (wears #11)
- **Jersey numbers vary by team** → Need flexible setup per game

### Older Brother's Contribution
- Suggested calendar integration idea
- Not a player - just helping with product ideas

---

## Processing Requirements

### Q1: Sample Videos
- **Available:** Multiple YouTube videos of Sahil's games
- **To be provided:** 2-3 sample videos for testing
- **Need for each video:**
  - Team name (Elements or Team Unequld)
  - Jersey number (#3 or #11)
  - Both teams' jersey colors
  - Any quirks (lighting, camera angle, etc.)

### Q2: Jersey Number Recognition
- **Elements:** #3
- **Team Unequld:** #11
- **AI must:** Identify jersey number via OCR to track correct player

### Q3: Team Identification
- **Method:** Jersey colors (visual detection)
- **Workflow:** Pre-game "onboarding" setup
  - Before game: Configure team colors, jersey number, opponent
  - At gym: Just tap "Start" and record
  - No configuration needed during game

### Q4: Processing Time
- **Timeline:** Asynchronous - can process whenever
- **Not required:** Real-time processing
- **Options:**
  - Process on device (iPhone 16 Pro Max)
  - Process on Synology NAS at home
  - Can process overnight
- **No rush:** Stats don't need to be immediate

### Q5: Output Priority
- **Equal importance:**
  1. Accurate Sahil on/off court tracking
  2. Accurate team scores (both teams)
- **Flexible:** Open to adjusting priorities based on what works

---

## Pre-Game Scheduling Workflow (Older Brother's Idea)

### Concept
Instead of configuring at the gym, set up game details in advance:

```
Before Game (at home):
├─ Schedule game in app
├─ Link to family calendar (optional)
├─ Set team info (Elements vs Lakers)
├─ Set jersey colors (Blue vs Red)
├─ Set player number (#3)
└─ Pre-configured and ready!

At Gym:
├─ Open app → See scheduled game
├─ Tap "Start Recording"
├─ Just record - everything already set
└─ Enjoy watching Sahil play! 🎉

After Game (at home):
├─ Upload to Synology or process on phone
├─ AI analyzes with pre-configured context
├─ Review stats (5-10 min)
└─ Save to game history
```

### Benefits
1. **Family coordination** - Everyone knows when games are
2. **No gym scrambling** - Everything pre-configured
3. **Better AI accuracy** - Knows what to look for ahead of time
4. **Calendar integration** - Syncs with family schedule
5. **Reminders** - "Game in 1 hour - charge your phone!"

---

## What AI Should Extract

### Primary Stats (When Sahil is ON Court)

**Tier 1: High Priority**
- Field Goal Attempts (FGA)
- Field Goals Made (FGM)
- Field Goal Percentage (FG%)
- 2-point vs 3-point breakdown
- Minutes played
- Plus/Minus (team score differential when playing)

**Tier 2: Medium Priority**
- Rebounds (offensive/defensive)
- Free Throws (attempts/made)
- Assists (if detectable)

**Tier 3: Nice to Have**
- Steals
- Blocks
- Turnovers

### Team Stats (Entire Game)
- Both teams' running score
- Final score
- Quarter/half scores
- Game timeline (when Sahil in/out)

---

## Technical Context

### Hardware Available
- **iPhone 16 Pro Max** - Primary recording device, can also process
- **iPad Mini A17** - Secondary device for review/processing
- **Osmo Mobile 7P** - DJI gimbal with ActiveTrack
- **Synology NAS** - Home server for heavy processing

### Existing App (SahilStats)
- **Keep everything:** Current game history, manual entry, analytics
- **Add AI as option:** New way to create games, not replacement
- **Backward compatible:** AI-processed games use same data model

### Data to Preserve
- All historical games and stats
- Career statistics
- Shot charts and analytics
- YouTube upload integration
- Firebase sync

---

## User Flows

### Flow 1: Schedule Game (Before Game Day)
```
App → Upcoming Games → Schedule New Game
  ↓
Enter game details:
  - Date & time
  - Team (Elements or Team Unequld)
  - Opponent
  - Location
  - Jersey # for this game (#3 or #11)
  - Team colors (Blue, Red, etc.)
  ↓
Optionally add to Family Calendar
  ↓
Game appears in "Upcoming" list
```

### Flow 2: Record Game (At Gym)
```
Open app → See "TODAY: Elements vs Lakers"
  ↓
Tap "Start Recording"
  ↓
Mount phone on Osmo gimbal
  ↓
DJI ActiveTrack follows Sahil automatically
  ↓
Just watch the game! 🎉
  ↓
Tap "Stop Recording" when game ends
  ↓
Choose: Process now? or Process later?
```

### Flow 3: Process Game (At Home)
```
Open app → "Processing Queue"
  ↓
Tap "Process Now" (or auto-process overnight)
  ↓
AI analyzes video:
  - Finds Sahil (jersey #3, blue color)
  - Tracks when he's on/off court
  - Detects shots, makes/misses
  - Tracks both teams' scores
  ↓
Review AI-suggested stats (5-10 min)
  ↓
Approve/adjust if needed
  ↓
Save → Game appears in history with manual games
```

---

## AI Processing Pipeline

### Input
- Video file (40 min typical game)
- Pre-configured context from scheduled game:
  - Player jersey number (#3 or #11)
  - Team jersey color
  - Opponent jersey color
  - Team names

### Processing Steps
1. **Court Detection** - Find basketball court boundaries
2. **Player Detection** - Identify all players in each frame
3. **Sahil Identification** - Find player with correct jersey # + color
4. **On/Off Tracking** - Determine when Sahil is actively playing
5. **Shot Detection** - Detect when any player shoots
6. **Team Attribution** - Determine which team scored based on jersey color
7. **Score Tracking** - Maintain running score for both teams
8. **Timeline Building** - Create game timeline with key events

### Output
- Game object (same as manual entry)
- Additional AI metadata:
  - Video URL
  - Confidence scores
  - Shot timestamps
  - On/off court timeline
  - Processing date

---

## Success Metrics for PoC

**We'll know the PoC succeeded if:**

1. ✅ **Sahil Identification:** Correctly identify Sahil in 80%+ of frames where visible
2. ✅ **On/Off Tracking:** Accurately detect 90%+ of Sahil's substitutions
3. ✅ **Shot Detection:** Catch 70%+ of Sahil's shots
4. ✅ **Made/Miss Classification:** 75%+ accuracy on made vs missed
5. ✅ **Score Tracking:** Final score within ±5 points of actual
6. ✅ **End-to-End Flow:** Complete one full game from scheduling → recording → processing → stats

**If we hit these targets**, we know the approach works and can refine!

---

## Development Approach

### Recommendation: Integrated Development
- Build AI features into existing SahilStats app
- Create new feature branch: `feature/ai-video-processing`
- Keep all existing features working
- AI becomes additional workflow alongside manual entry

### Why Not Separate PoC?
- Can reuse existing data models (Game, Team, etc.)
- Can reuse Firebase integration
- Can reuse UI components (game list, stats display)
- Faster iteration - see AI games alongside manual games immediately
- No data migration needed later

### What We Add (New Code Only)
```
Services/AI/
├── AIVideoProcessor.swift
├── PlayerDetectionService.swift
├── SahilIdentifier.swift
├── ShotDetectionService.swift
└── GameEventTimeline.swift

Views/AI/
├── UpcomingGamesView.swift
├── ScheduleGameView.swift
├── RecordingView.swift
├── ProcessingProgressView.swift
└── AIStatsReviewView.swift

Models/
├── ScheduledGame.swift (NEW)
└── Game.swift (extend with AI fields)
```

---

## Data Model Extensions

### New: ScheduledGame
```swift
struct ScheduledGame: Codable, Identifiable {
    var id: String
    var scheduledDate: Date
    var teamName: String           // "Elements" or "Team Unequld"
    var opponent: String
    var location: String?
    var jerseyNumber: Int          // 3 or 11
    var teamJerseyColor: JerseyColor
    var opponentJerseyColor: JerseyColor
    var calendarEventId: String?
    var status: GameStatus         // .scheduled, .recording, .processing, .completed
}
```

### Extended: Game (existing model)
```swift
extension Game {
    var scheduledGameId: String?     // Link back to scheduled game
    var videoURL: URL?                // Video file location
    var wasAIProcessed: Bool          // How was game created?
    var aiMetadata: AIMetadata?       // AI processing details
}

struct AIMetadata: Codable {
    var processingDate: Date
    var processingDuration: TimeInterval
    var confidence: Double            // Overall confidence 0-1
    var sahilMinutesPlayed: TimeInterval
    var onCourtTimestamps: [TimeRange]
    var detectedShots: [ShotEvent]
}
```

---

## Phase 1 Deliverables (Weeks 1-2)

### Week 1: Scheduling System
- [ ] Create ScheduledGame model
- [ ] Build UpcomingGamesView UI
- [ ] Build ScheduleGameView form
- [ ] Save scheduled games to Firebase
- [ ] Display upcoming games
- [ ] Optional: Calendar integration (EventKit)

### Week 2: Recording
- [ ] RecordingView with scheduled game context
- [ ] Video recording with metadata
- [ ] Link video to scheduled game
- [ ] Save video locally or upload to Synology
- [ ] Update scheduled game status

---

## Phase 2 Deliverables (Weeks 3-4)

### Week 3: Basic AI Processing
- [ ] Video frame extraction
- [ ] Player detection (YOLOv8 or CoreML)
- [ ] Jersey number OCR
- [ ] Sahil identification by jersey # + color
- [ ] On/off court tracking
- [ ] Shot detection (basic)

### Week 4: Stats Generation
- [ ] Team score tracking
- [ ] FG attempts/makes counting
- [ ] Timeline building
- [ ] Generate Game object from AI analysis
- [ ] AIStatsReviewView for approval
- [ ] Save to Firebase

---

## Testing Plan

### Test Videos Needed
Please provide 2-3 YouTube videos with:
- **Video 1:** Elements game (Sahil #3)
  - Team jersey color
  - Opponent jersey color
  - Game details (score, date if known)

- **Video 2:** Team Unequld game (Sahil #11)
  - Team jersey color
  - Opponent jersey color
  - Game details

- **Video 3:** Different camera angle or lighting
  - Test robustness

### For Each Video, Document:
- YouTube URL
- Team name
- Jersey number Sahil wore
- Both teams' jersey colors
- Actual final score (if known)
- Any quirks (bad lighting, unusual angle, etc.)

---

## Future Enhancements (Post-PoC)

### Phase 3+:
- **DJI SDK Integration** - Record directly in app with ActiveTrack
- **Advanced Stats** - Rebounds, assists, steals, blocks
- **Shot Charts** - Heat map visualization
- **Highlight Reels** - Auto-generate video clips of key moments
- **Multi-Angle Support** - Combine multiple camera angles
- **Live Processing** - Real-time stats during game (stretch goal)
- **Parent Sharing** - Auto-send highlights to family group chat
- **Season Analytics** - Track improvement over time
- **Opponent Scouting** - Track opponent tendencies

---

## Open Questions - ANSWERED

1. **Video Storage:** ✅ ANSWERED
   - **Workflow:** Record on device with gimbal → Store in iCloud during processing
   - **After processing:** Keep video for overlay features, then upload to YouTube
   - **Access:** YouTube ensures access from anywhere
   - **Existing feature:** Leverage current YouTube upload integration

2. **Processing Location:** ✅ ANSWERED
   - **Open to either approach:**
     - iPhone on-device (A18 Pro Neural Engine)
     - Synology NAS (heavy lifting overnight)
   - **Decision:** Start with iPhone, add Synology as fallback/enhancement

3. **Calendar Integration:** ✅ ANSWERED
   - **Primary:** iOS Calendar (EventKit)
   - **Shared family calendar** - so everyone knows game schedule

4. **Multiple Players Future:**
   - **Current:** Only Sahil plays basketball
   - **Design:** Build for single player, easy to extend later if needed

5. **Video Quality:** ✅ ANSWERED
   - **Standard:** 1080p (good balance)
   - **Variable:** Depends on quality needs for specific game
   - **Processing:** 1080p is ideal for AI (4K overkill, 720p may miss details)

---

## Next Steps

1. **Product Manager (You):**
   - [ ] Review this PRD
   - [ ] Provide sample YouTube videos for testing
   - [ ] Answer open questions above
   - [ ] Approve approach (integrated vs separate PoC)

2. **Developer (Me):**
   - [ ] Set up feature branch
   - [ ] Create initial project structure
   - [ ] Research/download basketball detection models
   - [ ] Build scheduling UI (Week 1)
   - [ ] Test AI processing on sample videos

---

## Success Criteria

**The AI video processing feature is successful if:**
- ✅ Parent can watch entire game without tracking stats
- ✅ Stats are 80%+ accurate (within margin of manual tracking)
- ✅ Processing completes in reasonable time (can happen overnight)
- ✅ Workflow is simpler than manual stat tracking
- ✅ Integrates seamlessly with existing app features

**Bonus success:**
- 🎉 Other parents ask "how did you build that?"
- 🎉 Older brother's friends want it for their siblings
- 🎉 Could potentially productize/sell to other families

---

*Last Updated: January 2025*
*Document Owner: Product Manager (You)*
*Developer: Claude*
