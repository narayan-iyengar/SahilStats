# Codebase Analysis: SahilStats Video & Overlay Pipeline

## Overview
SahilStats is a sophisticated basketball statistics tracking app for iOS/macOS, built with SwiftUI, Combine, and Firebase. It features a robust video recording pipeline (`VideoRecordingManager`) that integrates with AVFoundation, Metal (`MetalScoreboardRenderer`), and Core Animation (`HardwareAcceleratedOverlayCompositor`) to produce professional-quality game recordings with data overlays.

## Key Components Analysis

### 1. Video Recording Pipeline (`VideoRecordingManager.swift`)
- **Status:** Functional. Handles camera session, recording start/stop, and post-processing trigger.
- **Capabilities:**
  - Manages AVFoundation capture sessions with various presets and device selection logic (prioritizing ultra-wide/triple cameras).
  - Handles device orientation and stabilization.
  - Integration with `ScoreTimelineTracker` to capture game events during recording.
  - Triggers `HardwareAcceleratedOverlayCompositor` after recording stops.
  - Uploads to YouTube and saves to Photos.
- **Observations:**
  - The recording logic is tightly coupled with the `LiveGame` model.
  - It supports different camera zoom levels (0.5x, 1x, etc.), which is crucial for the "Option 1" vs "Option 3" decision in `TODO.md`.

### 2. Timeline Tracking (`ScoreTimelineTracker.swift`)
- **Status:** Functional. Captures game state snapshots.
- **Data Model:** `ScoreSnapshot` captures timestamp, scores, clock, quarter, team info, and zoom level.
- **Capture Logic:**
  - Periodic capture (default 1.0s interval).
  - Event-driven capture (updates on score changes).
  - Serializes data to JSON for persistence.
- **Gap vs TODO:**
  - `TODO.md` mentions "Phase 2: Timeline Capture & Export" with specific requirements for "Sync Marker Storage" (`syncMarker` in JSON root) which is currently **missing**. The current implementation saves a list of snapshots but doesn't explicitly store a separate sync marker in the JSON structure as requested.

### 3. Overlay Composition (`HardwareAcceleratedOverlayCompositor.swift`)
- **Status:** Functional. Uses Core Animation and Metal for post-processing.
- **Rendering Logic:**
  - **Bitmap Approach:** Creates a `CALayer` for each unique scoreboard state and animates opacity.
  - **Animation:** Supports simple opacity transitions.
  - **Metal Integration:** Uses `MetalScoreboardRenderer` for high-quality visual effects (glassmorphism, glows).
- **Gap vs TODO:**
  - **Smooth Clock Interpolation:** The TODO "Phase 4: Smooth Overlay Rendering" explicitly calls for interpolating clock values between 1-second snapshots (e.g., "1:59.5"). The current implementation uses a **bitmap approach** where it pre-renders unique states. If snapshots are 1s apart, the clock will jump (e.g., 1:00 -> 0:59) without sub-second interpolation, unless `ScoreTimelineTracker` captures sub-second updates (which it currently doesn't, limiting to ~1Hz timer).
  - **Countdown Effects:** The TODO requests "Countdown urgency" (color changes, pulsing). While `MetalScoreboardRenderer` handles static drawing, the *animation* of these effects (pulsing) is not explicitly implemented in the compositor's layer animation logic.

### 4. Scoreboard Rendering (`MetalScoreboardRenderer.swift`)
- **Status:** High Quality.
- **Features:**
  - Uses Metal/CoreImage for effects (Glow, Frosted Glass).
  - Falls back to Core Graphics (`ScoreboardRenderer.swift`).
  - Renders team logos, scores, and clock.
- **Visuals:** Matches the "Professional Overlay Enhancements" described in Phase 4.5 to a large extent (gradients, shadows).

## Comparison with TODO.md

| Feature | TODO Requirement | Current Status | Gap |
| :--- | :--- | :--- | :--- |
| **Timeline Export** | JSON export with sync marker | JSON export implemented. | Missing explicit `syncMarker` field in JSON root. |
| **Smooth Clock** | Interpolate between snapshots (60fps) | Discrete states based on snapshots. | **Critical:** No interpolation logic for clock text. Clock updates will be stepped (1Hz) rather than smooth. |
| **Countdown Effect** | Color change (Red/Orange), Pulsing | Basic color logic exists. | Missing pulsing animation logic in Compositor. |
| **Sync UI** | Manual adjustment slider | Not implemented. | Entire "Phase 3: Video Import & Sync" is missing. |
| **Video Import** | Import from Photos | Not implemented. | System relies on in-app recording currently. |

## Recommendations

1.  **Implement Smooth Clock Interpolation:**
    -   Modify `HardwareAcceleratedOverlayCompositor` to move away from purely static bitmaps for the clock. The clock text layer needs to be dynamic or pre-render sub-second frames if bitmap approach is retained (which would be memory intensive). Alternatively, render the clock separately using a `CATextLayer` or custom drawing that accepts an interpolated time value during the composition instruction (requires `AVVideoComposition` with a custom compositor class, or massive amounts of keyframes).
    -   *Simpler Approach:* Increase `ScoreTimelineTracker` capture rate (e.g., to 10Hz or 30Hz) to approximate smoothness without complex interpolation logic, though this increases JSON size.

2.  **Add Sync Marker:**
    -   Update `ScoreTimelineTracker` to store the `gameClockStarted` timestamp or a specific "sync" event in the JSON export to fulfill Phase 2 requirements.

3.  **Phase 3 Implementation:**
    -   The codebase is currently set up for *recording* within the app. "Phase 3: Video Import & Sync" requires building new UI to pick a video from the library and associate it with a JSON timeline, which is currently non-existent.

4.  **Refine Compositor for Effects:**
    -   Add logic in `createBitmapScoreboardLayers` or a new method to specifically handle "pulsing" animations (using `CAKeyframeAnimation` on `transform.scale`) when the clock is low, as per requirements.

## Conclusion
The codebase provides a solid foundation with high-quality rendering. The primary gap is the "smoothness" of the clock in post-processing and the specific "Sync/Import" workflow features outlined in the TODO. The current architecture favors the "Option 1" (In-app recording) path, while "Option 3" (Import + Sync) requires significant new UI development.
