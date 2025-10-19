# Build and Test Instructions

## Quick Start

Since you have Xcode and command line tools, let's get the PoC running!

### Step 1: Add Files to Xcode Project

Open the project in Xcode:

```bash
cd /Users/narayan/SahilStats/SahilStats
open SahilStats.xcodeproj
```

**Add these two new files to the project:**

1. **File > Add Files to "SahilStats"...**
2. Navigate to and select:
   - `Services/POC/StatsRetriever.swift`
   - `Views/POC/VideoPOCView.swift`
3. **Make sure**:
   - ✅ "Copy items if needed" is UNCHECKED (files are already in the right place)
   - ✅ "Create groups" is selected
   - ✅ "SahilStats" target is checked

### Step 2: Build the Project

```bash
# Build from command line (if you prefer)
cd /Users/narayan/SahilStats/SahilStats
xcodebuild -scheme SahilStats -configuration Debug

# Or just build in Xcode (⌘B)
```

**Expected result**: Should build successfully with no errors

### Step 3: Run in Simulator

1. Select **iPhone 16 Pro Max** simulator (or any device)
2. Press ⌘R or click the Play button
3. Wait for app to launch

### Step 4: Navigate to PoC

1. **Settings** (gear icon at bottom)
2. Scroll to **Developer** section (only visible if you're an admin)
3. Tap **AI Stats PoC**

### Step 5: Test Stats Retrieval

1. You'll see 3 steps - Step 1 is active
2. **Select test video**:
   - Default: **Elements vs Just Hoop** ⭐ (RECOMMENDED)
   - Tap the video selector to switch to "Elements vs Team Elite" if desired
3. Tap **"Retrieve Stats from Database"**
4. Watch Xcode console for output:

```
🔍 Searching for Elements game with opponent containing 'hoop'...
📊 Found X Elements games
   - Just Hoop (Points: XX, FG: X/Y)
✅ Found matching game: Elements vs Just Hoop
```

5. UI should show:
   - ✅ Game score (Elements XX - Just Hoop XX)
   - ✅ Sahil's points and field goal stats
   - ✅ "View Full Stats" button

6. Tap **"View Full Stats"** to see:
   - Complete shooting breakdown
   - All other stats (rebounds, assists, etc.)
   - PoC success targets (70%, 80%, 90% accuracy goals)

### Step 6: Verify File Update

Check that the markdown file was updated:

```bash
cat /Users/narayan/SahilStats/SahilStats/POC_ACTUAL_STATS.md
```

Should show detailed stats for the selected game.

## Troubleshooting

### Build Error: "Cannot find 'VideoPOCView' in scope"

**Solution**: The file wasn't added to the Xcode target
1. Select `VideoPOCView.swift` in project navigator
2. Open File Inspector (⌘⌥1)
3. Under "Target Membership", check ✅ **SahilStats**

### Build Error: "Cannot find 'StatsRetriever' in scope"

**Solution**: Same as above for `StatsRetriever.swift`

### Runtime: "No Elements vs Just Hoop game found"

**Possible causes**:
1. Game doesn't exist in Firebase
2. Opponent name is spelled differently

**Solution**: List all Elements games to see what's available

Modify the `retrieveStats()` function temporarily to call:
```swift
let allGames = try await StatsRetriever.shared.listAllElementsGames()
```

This will print all Elements games with their opponents to the console.

### Can't see "Developer" section in Settings

**Cause**: Not signed in as admin

**Solution**:
1. Check `authService.showAdminFeatures` returns true
2. Verify you're signed in with the correct account
3. Check if admin list includes your email

## What You Should See

### Console Output (Success):

```
🔍 Searching for Elements game with opponent containing 'hoop'...
📊 Found 15 Elements games
   - Panthers (Points: 18, FG: 7/15)
   - Lions (Points: 22, FG: 9/18)
   - Just Hoop (Points: 16, FG: 6/14)
   - Lakers (Points: 20, FG: 8/17)
   ...
✅ Found matching game: Elements vs Just Hoop

═══════════════════════════════════════════
📊 ACTUAL STATS: Elements vs Just Hoop
═══════════════════════════════════════════

SHOOTING STATS:
───────────────
2-Point: 4/10 (40.0%)
3-Point: 2/4 (50.0%)
Free Throw: 4/6 (66.7%)
Overall FG: 6/14 (42.9%)

SCORING:
────────
Total Points: 16
Points from 2PT: 8
Points from 3PT: 6
Points from FT: 4

OTHER STATS:
────────────
Rebounds: 8
Assists: 3
Steals: 2
Blocks: 1
Turnovers: 3
Fouls: 4

GAME RESULT:
────────────
Elements: 65
Just Hoop: 58
Outcome: Win 🏆

PLAYING TIME:
─────────────
Minutes Played: 28.5
Total Game Time: 40.0
Playing %: 71.3%

═══════════════════════════════════════════

✅ Updated POC_ACTUAL_STATS.md with retrieved stats
```

### UI Output:

**Before retrieval:**
- Blue button: "Retrieve Stats from Database"

**After retrieval:**
- ✅ Green box showing:
  - "Stats Retrieved!"
  - Elements 65 vs Just Hoop 58
  - Sahil's Points: 16
  - FG: 6/14 (42.9%)
  - "View Full Stats" button

**Full Stats Sheet:**
- Game header with scores
- Shooting stats with percentages
- All other stats
- PoC targets section showing:
  - Minimum (70%): Detect 10+ of 14 shots
  - Good (80%): Detect 11+ of 14 shots
  - Production (90%): Detect 13+ of 14 shots

## Next Steps After Successful Test

Once stats retrieval works:

1. ✅ **Complete**: Query Firebase and retrieve actual stats
2. ✅ **Complete**: Build PoC UI with video selection
3. **Next**: Implement YouTube video download
4. **Next**: Extract frames from video
5. **Next**: AI player detection
6. **Next**: Shot detection and classification
7. **Next**: Compare AI vs actual stats

## Expected Timeline

- **Today**: Get stats retrieval working
- **Day 2-3**: Video download and frame extraction
- **Day 4-5**: Player detection and shot detection
- **Day 6**: Make/miss classification
- **Day 7**: Accuracy comparison and PoC decision

---

**Current Branch**: `poc-ai-stats`
**Xcode Project**: `/Users/narayan/SahilStats/SahilStats/SahilStats.xcodeproj`

Run this and let me know what you see! 🎯
