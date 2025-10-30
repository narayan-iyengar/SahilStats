# SahilStats Feature To-Do List

**Last Updated**: 2025-10-30

> **How to use**: Check off items as you complete them using `- [x]`
> See `FEATURE_IDEAS.md` for detailed descriptions of each item.

---

## ✅ Recently Completed (2025-10-30)

### DockKit Gimbal Tracking Integration
- [x] iOS 18+ ML-powered intelligent basketball tracking
- [x] Automatic player detection and following (up to 9 players)
- [x] Dynamic auto-zoom based on player count (1.0x-2.5x)
- [x] Region of interest tracking for court area
- [x] Zero-setup workflow (xbotgo-style)
- [x] Court region alignment tool (optional, advanced users)
- [x] Integration with Insta360 Flow Pro 2 via DockKit
- [x] Support for baseline/courtside/corner camera positions

### UI Improvements
- [x] Added "End Game" button after regulation/overtime
- [x] Fixed Swift compiler performance issues in GameSetupView
- [x] Refactored complex Form views into smaller components

---

## 🎯 Priority: Before Adding Logos

**Do these first to make overlay more stable**

- [x] #21 - Overlay Preview Mode (test without recording) ✅ EXISTS - User doesn't use it
- [ ] #17 - GeometryReader Adaptive Sizing (use % of screen width instead of hardcoded pixels for iPad/iPhone compatibility)
- [ ] #23 - Graceful Degradation (handle logo load failures elegantly)
- [ ] #19 - Single Source of Truth for Overlay Data (simplify state management)

**User Priority**: Test logos in real recordings (not just preview)

---

## 🎨 Logo Feature Implementation

**After completing overlay improvements above**

- [ ] Add `logoURL: String?` field to Team model
- [ ] Add image picker to TeamSettingsView
- [ ] Implement Firebase Storage upload (`team-logos/{teamId}.png`)
- [ ] Add AsyncImage to score overlay with fallback
- [ ] Test logo display in overlay preview mode
- [ ] Add image optimization (resize to 200×200px)
- [ ] Implement fallback UI (show initials if logo fails)
- [ ] Handle different logo aspect ratios

---

## 🎥 Overlay Robustness (Fix Fragility)

- [ ] #16 - Overlay Component Isolation (separate UI from data)
- [ ] #17 - GeometryReader Adaptive Sizing *(prioritized above)*
- [ ] #18 - Replace Timers with Combine (prevent memory leaks)
- [ ] #19 - Single Source of Truth *(prioritized above)*
- [ ] #20 - Lock to Landscape Orientation (simplify rotation handling)
- [ ] #21 - Overlay Preview Mode *(prioritized above)*
- [ ] #22 - Overlay Configuration/Theme Model (customizable styles)
- [ ] #23 - Graceful Degradation *(prioritized above)*
- [ ] #24 - Pre-Recording Validation (check before starting)
- [ ] #25 - Separate Overlay Rendering from Camera (modular architecture)

---

## 👥 Team & Data Management

- [ ] #26 - Team Merge/Duplicate Detection (fuzzy matching)
- [ ] #27 - Team Seasons/Archives (organize by season)
- [ ] #28 - Bulk Team Import (CSV import)
- [ ] #29 - Team Statistics Dashboard (W-L, avg points, etc.)
- [ ] #30 - Smart Team Name Formatting (store multiple name formats)
- [ ] Team Editing (allow editing team names after creation)

---

## 🎬 Game & Video Features

- [ ] #31 - Video Clips/Highlights (mark moments, create clips)
- [ ] #32 - Video Thumbnail Generation (preview images)
- [ ] #33 - Multi-Camera Angles (future - complex)
- [ ] #34 - Post-Game Video Review (video + stats side-by-side)
- [ ] #35 - Automatic Highlight Detection (ML/audio analysis)

---

## ✨ UX & Polish

- [ ] #36 - Onboarding Flow (first-time user tutorial)
- [ ] #37 - Game Templates/Presets (save recurring setups)
- [ ] #38 - Quick Stats Entry Mode (bigger targets, gestures)
- [ ] #39 - Dark Mode Optimizations (OLED-friendly, battery saving)
- [ ] #40 - Haptic Feedback (vibration on actions)

---

## 🔥 Firebase & Performance

- [ ] #41 - Offline Mode Resilience (cache, queue, sync indicator)
- [ ] #42 - Image Optimization Pipeline (auto-resize uploads)
- [ ] #43 - Firestore Query Optimization (pagination, indexing)
- [ ] #44 - Analytics & Crash Reporting (Firebase Analytics/Crashlytics)

---

## 📱 QR Code & Multi-Device

- [ ] #45 - QR Code History (recent games list)
- [ ] #46 - Device Naming (identify devices easily)
- [ ] #47 - Connection Quality Indicator (signal strength)
- [ ] #48 - Role Switching (change recorder/controller mid-game)

---

## 📤 Export & Sharing

- [ ] #49 - Stats Export Formats (CSV, PDF, JSON)
- [ ] #50 - Video Export with Timestamp Chapters (quarter markers)

---

## 🚀 Quick Wins (High Impact, Low Effort)

Pick these for immediate improvements:

- [ ] Haptic Feedback (#40)
- [ ] Team Editing (allow name changes)
- [ ] Pre-Recording Validation (#24)
- [ ] Dark Mode Optimization (#39)
- [ ] Graceful Degradation (#23) *(also in priority list)*

---

## 📊 Progress Summary

**Total Features**: 50+ items
**Completed**: 11 (gimbal tracking + UI improvements)
**In Progress**: 0

---

## 📝 Notes & Decisions

Use this space to track decisions as you work through features:

### Logo Implementation Decision
- [ ] Decided on Option A/B/C (see FEATURE_IDEAS.md)
- [ ] Tested Firebase storage bandwidth
- [ ] Chose image format (PNG/SVG/WebP)

### Overlay Improvements
- [ ] Identified specific fragility issues
- [ ] Decided on architecture changes
- [ ] Tested preview mode

### Team Colors
- [ ] Decided whether to add team colors alongside logos
- [ ] Chosen color picker approach

---

## 🎯 Current Sprint

**Focus Area**: DockKit Gimbal Integration (COMPLETED 2025-10-30)

**This Week** (COMPLETED):
- [x] Implement iOS 18+ DockKit gimbal tracking
- [x] Add automatic player detection and following
- [x] Add dynamic auto-zoom feature
- [x] Fix "End Game" button missing after regulation
- [x] Simplify to zero-setup workflow

**Next Week**:
- [ ] Test gimbal tracking on actual games
- [ ] Consider overlay robustness improvements
- [ ] Evaluate priority items (overlay preview, adaptive sizing)

---

## 💡 Ideas for Future Consideration

Add new ideas here as they come up:

-
-
-

---

**See FEATURE_IDEAS.md for detailed descriptions of each feature**
