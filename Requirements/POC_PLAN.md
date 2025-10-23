# Proof of Concept - Simplified Plan

## PoC Goal: Validate AI Stats Extraction

**Simple, focused test:** Upload one Elements video → AI extracts stats → Compare to actual stats

---

## PoC Scope - Ultra Minimal

### What We're Testing:
1. ✅ Can AI detect Sahil (Elements jersey #3)?
2. ✅ Can AI detect when he shoots?
3. ✅ Can AI determine make vs miss?
4. ✅ Can AI count FGA, FGM, FG%?
5. ✅ How accurate is it compared to actual stats?

### What We're NOT Testing (Yet):
- ❌ Scheduling/calendar integration (Phase 2)
- ❌ Recording with gimbal (Phase 2)
- ❌ Team score tracking (Phase 2)
- ❌ On/off court detection (Phase 2)
- ❌ DJI SDK (Phase 2)
- ❌ Real-time processing (Phase 2)

---

## PoC User Flow

```
Step 1: Upload Video
  ├─ Select Elements video from YouTube or camera roll
  ├─ Provide context: "Elements #3, Blue jerseys"
  └─ Tap "Process"

Step 2: AI Processing
  ├─ Detect basketball court
  ├─ Find all players
  ├─ Identify Sahil (jersey #3, blue)
  ├─ Track his shooting motions
  ├─ Classify makes/misses
  └─ Generate stats

Step 3: Review Results
  ├─ Show: "Detected 12 shots, 7 makes, 5 misses"
  ├─ FG: 7/12 (58.3%)
  ├─ Compare to actual stats (if you have them)
  └─ Calculate accuracy percentage
```

---

## Development Plan - 1 Week Sprint

### Day 1-2: Setup & Video Input
- [ ] Create new branch: `poc-ai-stats`
- [ ] Create simple SwiftUI view to upload video
- [ ] Test: Can we load a YouTube video or camera roll video?
- [ ] Extract frames from video (1 fps to start)

### Day 3-4: Player Detection
- [ ] Integrate YOLOv8 or Vision framework
- [ ] Detect people in frames
- [ ] Attempt jersey number OCR
- [ ] Test: Can we find player #3?

### Day 5-6: Shot Detection
- [ ] Detect shooting motion (pose detection)
- [ ] Track ball trajectory
- [ ] Classify make vs miss
- [ ] Test: Can we count shots?

### Day 7: Results & Validation
- [ ] Display detected stats
- [ ] Compare to actual stats
- [ ] Document accuracy %
- [ ] Decision: Is this approach viable?

---

## Training Data - Elements Videos

**You mentioned having Elements videos - Perfect!**

### What We Need:
1. **1-2 videos for testing**
   - Provide YouTube URLs or video files
   - Tell us the actual stats (if you have them)
   - Jersey colors (Elements vs opponent)

2. **Additional videos for validation**
   - Different games/opponents
   - Different lighting/angles
   - Test robustness

### Test Videos - PROVIDED ✅

**Video 1: Elements vs Team Elite**
- **YouTube URL:** https://youtu.be/z9AZQ1h8XyY?si=0iVGEN8axbBkRZax
- **Team:** Elements
- **Opponent:** Team Elite
- **Sahil's Jersey:** #3
- **Jersey Colors:**
  - Elements: WHITE jerseys
  - Team Elite: [to be determined from video]
- **Sahil's Actual Stats:** [stored in database - will retrieve]
- **Notes:** First test video, basket may not be clearly visible

**Video 2: Elements vs Just Hoop** ⭐ **RECOMMENDED FOR PoC**
- **YouTube URL:** https://www.youtube.com/watch?v=f5M14MI-DJo
- **Team:** Elements
- **Opponent:** Just Hoop
- **Sahil's Jersey:** #3
- **Jersey Colors:**
  - Elements: BLACK jerseys
  - Just Hoop: [to be determined from video]
- **Sahil's Actual Stats:** [to be retrieved from database]
- **Notes:** Better video - basket is clearly visible, recommended for PoC testing
- **Advantages:**
  - Clear view of basket (critical for make/miss detection)
  - Better for AI processing
  - Will use this as primary test video

### Video Analysis Tasks:
1. [ ] Download/access video
2. [ ] Watch and manually count Sahil's stats:
   - [ ] Field goals attempted
   - [ ] Field goals made
   - [ ] 3-pointers attempted
   - [ ] 3-pointers made
   - [ ] Total points
3. [ ] Note opponent jersey color
4. [ ] Note camera angle/quality
5. [ ] Identify any challenging aspects (lighting, occlusion, etc.)

---

## Success Criteria for PoC

**Tier 1: Minimum Viable (MUST ACHIEVE)**
- ✅ Detect Sahil in 70%+ of frames where visible
- ✅ Detect 70%+ of his shots
- ✅ Classify makes/misses with 70%+ accuracy

**Tier 2: Good Enough to Continue**
- ✅ Detect Sahil in 80%+ of frames
- ✅ Detect 80%+ of shots
- ✅ Classify makes/misses with 80%+ accuracy

**Tier 3: Production Ready (Aspirational)**
- ✅ Detect Sahil in 90%+ of frames
- ✅ Detect 90%+ of shots
- ✅ Classify makes/misses with 90%+ accuracy

**If we hit Tier 1, we continue building. If not, we reassess approach.**

---

## Technical Stack (Minimal PoC)

### Swift Frameworks:
```swift
import SwiftUI          // UI
import AVFoundation     // Video processing
import Vision           // Apple's CV framework
import CoreML           // Machine learning
```

### ML Models to Test:
1. **Apple Vision Framework (Built-in)**
   - `VNDetectHumanBodyPoseRequest()` - Find shooting motion
   - `VNRecognizeTextRequest()` - Read jersey numbers
   - **Pro:** Free, no setup, optimized for iPhone
   - **Con:** May not be basketball-specific enough

2. **YOLOv8 (CoreML version)**
   - Pre-trained object detection
   - Can detect: ball, person, hoop
   - **Pro:** Very accurate
   - **Con:** Need to convert/download model

3. **Custom CoreML Model (Future)**
   - Train on your Elements videos
   - Optimized for Sahil specifically
   - **Pro:** Best accuracy
   - **Con:** Need labeled training data

**For PoC, start with #1 (Apple Vision) - easiest to test quickly.**

---

## PoC Code Structure

```
SahilStats/
├── Views/
│   └── POC/
│       ├── VideoPOCView.swift           // Main PoC UI
│       └── ResultsPOCView.swift         // Show detected stats
│
├── Services/
│   └── POC/
│       ├── VideoFrameExtractor.swift    // Extract frames from video
│       ├── PlayerDetector.swift         // Find players in frame
│       ├── JerseyNumberReader.swift     // OCR for jersey #
│       ├── ShotDetector.swift           // Detect shooting motions
│       └── StatsGenerator.swift         // Compile stats from detections
│
└── Models/
    └── POC/
        ├── DetectedShot.swift           // Data for each detected shot
        └── POCStats.swift               // Aggregated stats
```

---

## Video Processing Pipeline (Simplified)

```
Input: Video file (MP4, MOV, etc.)
  ↓
Step 1: Extract Frames
  └─ Sample 1 frame per second (reduces processing)
  ↓
Step 2: For Each Frame
  ├─ Detect all people (Vision framework)
  ├─ Find jersey numbers (OCR)
  ├─ Track player #3 (Sahil)
  └─ Store player positions
  ↓
Step 3: Detect Shooting Events
  ├─ Find frames where arms raised above shoulders
  ├─ Ball leaves hands
  └─ Mark as "shot detected"
  ↓
Step 4: Classify Make/Miss
  ├─ Track ball trajectory after shot
  ├─ Did ball enter hoop region?
  └─ Classify: MAKE or MISS
  ↓
Step 5: Generate Stats
  ├─ Count total shots (FGA)
  ├─ Count makes (FGM)
  ├─ Calculate FG%
  └─ Display results
```

---

## Testing Protocol

### Test 1: Baseline Detection
**Input:** 30-second clip of Sahil shooting
**Expected:** Find Sahil in most frames
**Metric:** Detection accuracy %

### Test 2: Shot Counting
**Input:** Same clip (count actual shots manually first)
**Expected:** AI detects similar number of shots
**Metric:** How many shots did AI catch? (e.g., 7/8 = 87.5%)

### Test 3: Make/Miss Classification
**Input:** Same clip (manually label each shot as make/miss)
**Expected:** AI classifies correctly
**Metric:** Classification accuracy (e.g., 6/7 correct = 85.7%)

### Test 4: Full Game
**Input:** Entire game video (40 min)
**Expected:** Process without crashing, reasonable stats
**Metric:** Processing time, memory usage, overall accuracy

---

## Video Storage Workflow (Simplified for PoC)

```
PoC Testing:
├─ Use existing YouTube videos (download temporarily)
├─ Process locally on iPhone
└─ No permanent storage needed

Future Production:
├─ Record with gimbal → Camera roll
├─ Automatic iCloud backup
├─ AI processes from iCloud
├─ After processing: Upload to YouTube
└─ Leverage existing YouTube upload feature
```

---

## Integration with Existing App

### PoC Phase (Week 1):
- **Separate "PoC" section** in app
- Access via hidden developer menu or button
- Doesn't affect existing features
- Easy to remove if PoC fails

### Production Phase (Later):
- Remove PoC scaffolding
- Integrate into main game creation flow
- Add to GameListView as new entry method
- Reuse all existing Game models/Firebase

---

## Decision Point After PoC

### If PoC Succeeds (≥70% accuracy):
**Next Steps:**
1. Expand to full game processing
2. Add team score tracking
3. Add on/off court detection
4. Build scheduling workflow
5. Integrate DJI recording
6. Polish UI/UX

**Timeline:** 3-4 more weeks to production

### If PoC Partially Succeeds (50-70% accuracy):
**Options:**
1. Use as "assisted mode" - AI suggests, human confirms
2. Train custom models on Elements videos
3. Combine with manual entry (hybrid approach)

**Timeline:** 4-6 weeks with refinements

### If PoC Fails (<50% accuracy):
**Options:**
1. Reassess approach (different ML models?)
2. Focus on manual entry improvements
3. Consider third-party AI services (Veo, Kinexon APIs)
4. Pivot to simpler features (just shot charts, no full stats)

---

## What We Need From You

### Immediately (to start PoC):
1. **1-2 Elements game videos**
   - YouTube URLs or video files
   - Prefer shorter clips (2-5 min) for initial testing
   - Full game videos for later validation

2. **Actual stats for those videos** (if available)
   - Sahil's FG, 3PT, points
   - So we can measure AI accuracy

3. **Jersey details:**
   - Elements jersey color (Blue? White?)
   - Opponent jersey colors

### Nice to Have:
- Multiple games (different opponents, lighting)
- Different camera angles
- Games where Sahil had high/low scoring (test range)

---

## Timeline

**Week 1: PoC Sprint**
- Days 1-2: Setup & video input
- Days 3-4: Player detection
- Days 5-6: Shot detection
- Day 7: Results & validation

**End of Week 1: Decision Point**
- Review accuracy metrics
- Decide: Continue, Refine, or Pivot?

**Weeks 2-4: Production Build** (if PoC succeeds)
- Full game processing
- Team scores
- UI polish
- Integration with existing app

---

## Notes

- **Keep it simple** - Just prove core concept works
- **Fail fast** - If detection doesn't work, know quickly
- **Elements videos only** - Train on what we have
- **Manual comparison** - You verify AI accuracy
- **Low stakes** - It's a PoC, expected to be rough

---

## Ready to Start?

**When you provide the Elements videos, I'll:**
1. Create the PoC branch
2. Build basic video upload UI
3. Implement detection pipeline
4. Test on your videos
5. Report accuracy results

**Let's do this! 🏀**

---

*PoC Owner: Product Manager (You)*
*PoC Developer: Claude*
*Target: 1 week sprint*
*Go/No-Go Decision: End of Week 1*
