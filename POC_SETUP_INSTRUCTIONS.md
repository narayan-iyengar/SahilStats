# PoC Setup Instructions

## What's Been Created

I've set up the foundation for the AI Stats Proof of Concept. Here's what's ready:

### 📁 Files Created

1. **AI_PRODUCT_REQUIREMENTS.md** - Full product requirements document
2. **POC_PLAN.md** - Simplified 1-week PoC sprint plan
3. **POC_ACTUAL_STATS.md** - Template for actual stats (will be auto-filled)
4. **Services/POC/StatsRetriever.swift** - Helper to query Firebase for actual stats
5. **Views/POC/VideoPOCView.swift** - Main PoC UI

### 🎯 Current Status

- ✅ Branch created: `poc-ai-stats`
- ✅ PoC UI built with 3-step workflow
- ✅ Stats retrieval logic implemented
- ✅ Integrated into Settings menu (Developer section)
- ⚠️ Files need to be added to Xcode project manually

## 🔧 Setup Steps (Required)

### Step 1: Add Files to Xcode Project

You need to manually add the new files to your Xcode project:

1. Open `SahilStats.xcodeproj` in Xcode
2. Right-click on the project navigator
3. Select "Add Files to SahilStats..."

**Add these files:**

```
Services/POC/StatsRetriever.swift
Views/POC/VideoPOCView.swift
```

**Make sure to:**
- ✅ Check "Copy items if needed"
- ✅ Select "Create groups" (not folder references)
- ✅ Add to SahilStats target

### Step 2: Verify Import

Check that `SettingsView.swift` can see the new `VideoPOCView`:

1. Open `SahilStats/Views/SettingsView.swift`
2. Look for line 45-47:
   ```swift
   NavigationLink("AI Stats PoC") {
       VideoPOCView()
   }
   ```
3. If you get a compiler error, make sure `VideoPOCView.swift` was added to the target

## 🧪 Testing the PoC

### Step 1: Build and Run

1. Select your device/simulator (iPhone 16 Pro Max recommended)
2. Build and run (⌘R)

### Step 2: Access the PoC

1. Open the app
2. Navigate to **Settings** (gear icon)
3. Scroll to **Developer** section (only visible if you're an admin)
4. Tap **AI Stats PoC**

### Step 3: Retrieve Actual Stats

1. You'll see the PoC screen with 3 steps
2. **Step 1** shows "Retrieve Actual Stats"
3. Tap the blue button: **"Retrieve Stats from Database"**
4. The app will query Firebase for the Elements vs Team Elite game
5. If found, you'll see:
   - Game score
   - Sahil's points
   - Field goal stats
   - Button to "View Full Stats"

### Step 4: View Full Stats

1. Tap **"View Full Stats"** to see detailed breakdown:
   - Shooting stats (2PT, 3PT, FT)
   - Other stats (rebounds, assists, etc.)
   - Playing time
   - PoC success targets (70%, 80%, 90% accuracy goals)

2. The stats will also be saved to `POC_ACTUAL_STATS.md` automatically

## 📊 Expected Output

When you retrieve the stats, you should see something like:

```
═══════════════════════════════════════════
📊 ACTUAL STATS: Elements vs Team Elite
═══════════════════════════════════════════

SHOOTING STATS:
───────────────
2-Point: X/Y (XX.X%)
3-Point: X/Y (XX.X%)
Free Throw: X/Y (XX.X%)
Overall FG: X/Y (XX.X%)

SCORING:
────────
Total Points: XX
Points from 2PT: XX
Points from 3PT: XX
Points from FT: XX

[... more stats ...]
```

This will print in the Xcode console.

## ❌ Troubleshooting

### "No Elements vs Team Elite game found"

**Cause**: The query couldn't find a game with:
- `teamName` = "Elements"
- `opponent` containing "Elite"

**Solutions**:
1. Check Firebase console to see what the actual opponent name is
2. Verify the game exists in the `games` collection
3. Check the exact spelling of team names

### Compiler Error: "Cannot find 'VideoPOCView'"

**Cause**: File not added to Xcode target

**Solution**:
1. In Xcode, select `VideoPOCView.swift`
2. Open File Inspector (⌘⌥1)
3. Under "Target Membership", check ✅ SahilStats

### Compiler Error: "Cannot find 'StatsRetriever'"

**Cause**: File not added to Xcode target

**Solution**: Same as above for `StatsRetriever.swift`

## 🎬 What's Next

After you successfully retrieve the actual stats:

### Phase 1: Video Processing (Next Task)
- Implement YouTube video download
- Extract frames from video (1 fps)
- Save frames for processing

### Phase 2: AI Detection (Following Task)
- Use Apple Vision framework to detect players
- Implement jersey number OCR
- Find Sahil (#3, white jersey)

### Phase 3: Shot Detection
- Detect shooting motions using pose estimation
- Classify makes vs misses
- Count total shots

### Phase 4: Accuracy Comparison
- Compare AI-detected stats vs actual stats
- Calculate accuracy percentages
- Determine if PoC is successful (≥70% accuracy)

## 📝 Notes

- The PoC is **isolated** - won't affect existing app features
- All PoC code is in `Services/POC/` and `Views/POC/` directories
- Documentation is in root directory (*.md files)
- Can be easily removed if PoC fails

## 🚀 Success Criteria

**Minimum Viable (70% accuracy)**:
- Detect 70%+ of Sahil's shots
- Classify makes/misses with 70%+ accuracy

**Good Enough (80% accuracy)**:
- Detect 80%+ of shots
- Classify 80%+ correctly

**Production Ready (90% accuracy)**:
- Detect 90%+ of shots
- Classify 90%+ correctly

---

**Current Branch**: `poc-ai-stats`
**Status**: Foundation complete, ready for testing
**Next Step**: Add files to Xcode project and test stats retrieval

Let me know once you've added the files to Xcode and tested the stats retrieval!
