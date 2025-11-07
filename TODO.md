# SahilStats TODO - Video Recording Workflow Decision

## Current Decision Point

Choosing between two video recording approaches:
- **Option 1:** Optimize current SahilStats + DockKit recording
- **Option 3:** Switch to Native Camera app + Insta360 Hoop Mode + Post-processing

Both options require post-processing overlay for smooth clock animation and countdown effects.

---

## Phase 1: Testing & Decision (This Weekend)

**Goal:** Determine which approach works better

- [ ] **Test current SahilStats setup**
  - Check console logs for actual zoom level achieved
  - Measure video quality
  - Monitor battery drain (start % → end %)
  - Evaluate DockKit tracking performance
  - Check for crashes/overheating
  - Console logs to check:
    - `"📹 Using [camera type]"`
    - `"📹 Zoom range: [min]x - [max]x"`
    - `"📹 Camera ready - set initial zoom to [actual]x"`

- [ ] **Test Native Camera + Insta360 Hoop Mode**
  - Record from same corner position at 0.5x
  - Compare video quality vs current setup
  - Evaluate Hoop Mode tracking (basket-to-basket action)
  - Test ease of use
  - Check battery drain

**Outcome:** Choose Option 1 OR Option 3 based on real-world performance

---

## Phase 2: Timeline Capture & Export

**Goal:** Save game data for post-processing

- [ ] **Implement JSON timeline export**
  - Second-by-second snapshots (1Hz capture rate)
  - Data: homeScore, awayScore, quarter, clock, timestamp
  - Export to Files/iCloud for transfer
  - File size: ~150KB for 40-minute game

- [ ] **Add sync marker storage**
  - Store `gameClockStarted` timestamp on recorder device
  - Enables automatic video/timeline alignment
  - Save to persistent storage for post-game retrieval

**JSON Format:**
```json
{
  "gameId": "abc123",
  "syncMarker": 1704567890.123,
  "captureRate": 1.0,
  "snapshots": [
    {"t": 0, "home": 0, "away": 0, "q": 1, "clock": 600.0},
    {"t": 1, "home": 0, "away": 0, "q": 1, "clock": 599.0},
    ...
  ]
}
```

---

## Phase 3: Video Import & Sync

**Goal:** Import video and align with timeline

- [ ] **Build video import UI**
  - Select video from Photos library
  - Display video info (duration, resolution, creation date)
  - Load associated JSON timeline

- [ ] **Create timeline sync UI**
  - Auto-calculate offset from sync marker timestamps
  - Video preview with current overlay
  - Manual adjustment slider (±10 seconds)
  - Real-time preview of sync accuracy
  - "Confirm & Process" button

**Sync Calculation:**
```swift
let videoStart = videoAsset.creationDate
let gameStart = syncMarker  // from JSON
let offset = videoStart.timeIntervalSince(gameStart)
```

---

## Phase 4: Smooth Overlay Rendering (Critical!)

**Goal:** Render overlay with smooth 60fps clock animation

- [ ] **Implement smooth clock rendering**
  - Timeline has 1-second snapshots
  - Video renders at 30/60 fps
  - **Interpolate clock values between snapshots**
  - Example: Frame at t=120.5s shows "1:59.5" (not jumps)

**Interpolation Logic:**
```swift
func interpolateClockTime(videoTime: TimeInterval, timeline: [Snapshot]) -> String {
    let before = timeline.snapshotAt(floor(videoTime))
    let after = timeline.snapshotAt(ceil(videoTime))
    let fraction = videoTime - floor(videoTime)

    let beforeSeconds = clockToSeconds(before.clock)
    let afterSeconds = clockToSeconds(after.clock)
    let currentSeconds = beforeSeconds - (beforeSeconds - afterSeconds) * fraction

    return formatClock(currentSeconds)  // "M:SS.s"
}
```

- [ ] **Add countdown effect rendering**
  - Clock < 60 seconds: Change color to red
  - Optional: Pulsing animation or size increase
  - Visual urgency (NBA broadcast style)
  - Smooth color transition at 1:00 mark

- [ ] **Build post-processing overlay compositor**
  - Process each video frame sequentially
  - Look up game state from timeline (with interpolation)
  - Render overlay with MetalScoreboardRenderer
  - Composite onto video frame
  - Write to output video file

---

## Phase 4.5: Professional Overlay Enhancements (Optional)

**Goal:** Match broadcast-quality overlays like ScoreCam

### Current Overlay Strengths (Already Implemented):
- ✅ Gradient background (dark to darker)
- ✅ Team logos with aspect-fit rendering
- ✅ Shadows and depth effects
- ✅ Semi-transparent background (0.85-0.9 alpha)
- ✅ Clean layout (team names, scores, clock, period)
- ✅ Bottom-center positioning

### Professional Enhancements to Add:

- [ ] **Team color accents**
  - Thin colored line/glow under home/away sections
  - Use actual team colors from game setup
  - Subtle but adds polish and team branding

- [ ] **Score change animations** (subtle)
  - Brief flash or glow when score updates
  - Scale animation (1.0x → 1.1x → 1.0x over 0.3s)
  - Makes score changes more noticeable in post-processing
  - Only trigger when score actually changes between frames

- [ ] **Enhanced countdown urgency**
  - Clock < 60 seconds: Orange/yellow color
  - Clock < 10 seconds: Red color + pulsing animation
  - Pulse effect: Scale 1.0x → 1.05x → 1.0x (repeat every 0.5s)
  - Faster pulse under 5 seconds

- [ ] **Smooth period transition animations**
  - Period change: Fade out old period label, fade in new (0.5s)
  - Quarter/Half ending: Brief highlight or flash
  - Overtime indicator: Special styling (different color?)

- [ ] **Multiple overlay style presets** (future enhancement)
  - **Minimal:** Just scores and clock (smallest footprint)
  - **Standard:** Current design (default)
  - **Broadcast:** Larger, more colorful, team color accents
  - **Custom:** User-configurable colors, size, position

### Design Reference:

**Current Layout:**
```
┌──────────────────────────────────┐
│  [LOGO] HAWKS    Q1    TIGERS [LOGO]  │
│     85         8:23        82     │
└──────────────────────────────────┘
```

**With Enhancements:**
```
┌──────────────────────────────────┐
│  [LOGO] HAWKS    Q1    TIGERS [LOGO]  │
│  ━━━━━ 85     8:23      82 ━━━━━  │  ← Team color accents
└──────────────────────────────────┘
    (pulse/glow effects when score changes)
```

### Optional Advanced Features:
- [ ] Possession indicator (if tracked)
- [ ] Timeout indicators (if tracked)
- [ ] Foul count display (if tracked)
- [ ] Player stats ticker (scrolling at bottom)

---

## Phase 5: Quality Verification

**Goal:** Ensure professional-quality output

- [ ] **Test post-processed video**
  - Verify smooth 60fps clock countdown (no stuttering/jumping)
  - Confirm countdown effects activate under 1 minute
  - Check overlay alignment with video
  - Validate scores update correctly
  - Test with full 40-minute game footage
  - Export and upload to YouTube for quality check

---

## Technical Notes

### Key Requirements:
- **Smooth Clock:** Must interpolate between 1-second snapshots for 60fps smoothness
- **Countdown Effect:** Visual urgency under 1 minute (color change, possible animation)
- **Sync Accuracy:** ±0.5 second alignment between video and timeline
- **Quality:** Final video should be broadcast-quality with professional overlay

### Current Blockers:
- ❌ **0.5x ultra-wide + dynamic zoom** - iOS limitation, can't have both with AVFoundation
- ⚠️ **Need to test** which approach (current vs native Camera) works better in practice

### Decision Criteria:
1. Video quality comparison
2. Battery life impact
3. Tracking effectiveness
4. Ease of use during games
5. Reliability (crashes, overheating)

---

## Future Considerations

**If Option 1 (Current Setup) Chosen:**
- Optimize recording (remove live overlay rendering)
- Post-process for better quality
- Keep remote control and DockKit tracking

**If Option 3 (Native Camera) Chosen:**
- Full post-processing workflow
- Manual recording start/stop
- Better video quality, simpler recording device
- Insta360 Hoop Mode for basic tracking

---

## Notes from Latest Session

**Key Insights:**
- Corner position + 0.5x ultra-wide captures full court
- Dynamic zoom desired for basket-to-basket action tracking
- Current setup tries to set 0.5x but doesn't achieve it (AVFoundation limitation)
- Native Camera quality is noticeably better
- Need smooth clock countdown in final video (interpolation required)
- Second-accurate timeline sufficient for post-processing

**Testing Priority:**
Test real-world performance before committing to code changes!
