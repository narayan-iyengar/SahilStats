# Step 2: Video Processing Setup & Testing

## What's New

I've implemented the complete video download and frame extraction pipeline:

### 📦 New Files

1. **Services/POC/YouTubeDownloader.swift** - Downloads YouTube videos
2. **Services/POC/VideoFrameExtractor.swift** - Extracts frames from video

### ✨ Features

- ✅ Automatic yt-dlp detection
- ✅ Manual download fallback
- ✅ Progress tracking (download + extraction)
- ✅ Video metadata extraction
- ✅ Frame preview in UI
- ✅ Saves frames to disk for debugging

## Setup

### Step 1: Add New Files to Xcode

**Add these files to your Xcode project:**

```
Services/POC/YouTubeDownloader.swift
Services/POC/VideoFrameExtractor.swift
```

**Method:**
1. In Xcode, right-click project navigator
2. "Add Files to SahilStats..."
3. Select both files
4. ✅ Uncheck "Copy items if needed"
5. ✅ Select "Create groups"
6. ✅ Check "SahilStats" target

### Step 2: Install yt-dlp (Optional but Recommended)

For automatic YouTube downloads:

```bash
brew install yt-dlp
```

**Without yt-dlp:**
- App will prompt you to download manually
- Download video from YouTube to ~/Downloads/
- App will detect and use it

### Step 3: Build and Run

```bash
# Build in Xcode (⌘B)
# Or from command line:
xcodebuild -scheme SahilStats -configuration Debug
```

## Testing Video Processing

### Step 1: Complete Step 1 First

1. Open app → Settings → Developer → AI Stats PoC
2. Select test video (default: "Elements vs Just Hoop" ⭐)
3. Tap "Retrieve Stats from Database"
4. ✅ Confirm stats appear

### Step 2: Process Video

1. Tap blue button: **"Download & Extract Frames"**
2. Watch progress:
   - **Download progress**: 0% → 100%
   - **Extraction progress**: 0% → 100%

### What Happens (with yt-dlp):

```
📥 Step 2.1: Downloading video...
   URL: https://www.youtube.com/watch?v=f5M14MI-DJo
   Using yt-dlp...
   [download] 0.0% of 45.2MB at 1.5MB/s ETA 00:30
   [download] 50.0% of 45.2MB at 2.1MB/s ETA 00:10
   [download] 100.0% of 45.2MB
✅ Video downloaded

📊 Video Metadata:
   Duration: 185.5s (03:05)
   Resolution: 1280x720
   Frame Rate: 30.0 fps

🎬 Step 2.2: Extracting frames...
   Extracting ~186 frames (1 every 1.0s)
   Extracted 10/186 frames...
   Extracted 20/186 frames...
   ...
   Extracted 180/186 frames...
✅ Frame extraction complete: 186 frames extracted

💾 Saving 186 frames to disk...
   Directory: /var/folders/.../POC_Frames
✅ All frames saved to disk
```

### What Happens (without yt-dlp):

```
⚠️ yt-dlp not found - checking for manual download...

⚠️ Video not found. Please download manually:

Option 1: Install yt-dlp (recommended)
─────────────────────────────────────────
brew install yt-dlp

Option 2: Download manually
─────────────────────────────────────────
1. Visit: https://www.youtube.com/watch?v=f5M14MI-DJo
2. Download the video (use browser extension or online downloader)
3. Save to: ~/Downloads/
4. Retry processing
```

### Expected UI Output

**During Processing:**
- Download progress bar (0-100%)
- Extraction progress bar (0-100%)

**After Success:**
- ✅ Green "Processing Complete!" box
- Video metadata:
  - Duration: 03:05
  - Resolution: 1280x720
  - Frames Extracted: 186
- **Sample frames preview**: First 5 frames shown as thumbnails
- Frame timestamps displayed (e.g., "00:00.000", "00:01.000", etc.)

### Saved Frames Location

Frames are saved to:
```
/var/folders/.../T/POC_Frames/
```

Format:
```
frame_0000_0.0s.jpg
frame_0001_1.0s.jpg
frame_0002_2.0s.jpg
...
frame_0185_185.0s.jpg
```

You can browse these frames to verify extraction worked correctly.

## Troubleshooting

### "yt-dlp failed with status 1"

**Possible causes:**
- Network error
- Video unavailable/private
- Rate limiting

**Solutions:**
1. Check internet connection
2. Try downloading manually
3. Wait a few minutes and retry

### "Processing failed: The operation couldn't be completed"

**Cause:** AVFoundation couldn't extract frames

**Solution:**
1. Ensure video is valid MP4/MOV format
2. Try re-downloading the video
3. Check Xcode console for detailed error

### Frames not appearing in UI

**Cause:** UI state not updating

**Solution:**
1. Check Xcode console - frames should be logged
2. Verify `extractedFrames` array is populated
3. Force UI refresh by switching videos

### Download stuck at 0%

**Cause:** yt-dlp not outputting progress

**Solution:**
- Download continues in background
- Check `/tmp/POC_Videos/` directory
- Wait for completion message

## Performance Notes

### Expected Times (on modern Mac/iPhone):

- **Download**: 30-60 seconds (depends on internet speed)
- **Frame Extraction**: 10-20 seconds for 3-minute video
- **Total**: ~1-2 minutes for complete processing

### Memory Usage:

- Each frame: ~1-2 MB in memory
- 186 frames: ~200-300 MB RAM
- Saved to disk: ~50-100 MB total

## What's Next

After successful frame extraction, we'll implement:

### Step 3: Player Detection (Next)
- Use Apple Vision framework to detect people
- Implement jersey number OCR
- Find Sahil (#3 in BLACK jersey)

### Step 4: Shot Detection
- Detect shooting motions using pose estimation
- Track ball trajectory
- Classify makes vs misses

### Step 5: Stats Comparison
- Generate AI-detected stats
- Compare with actual stats from Step 1
- Calculate accuracy percentage

---

**Expected Result**: 186 frames extracted, previewed in UI, saved to disk

**Next Command**: Add the new files to Xcode and tap "Download & Extract Frames"

Let me know when you've tested this step! 🎬
