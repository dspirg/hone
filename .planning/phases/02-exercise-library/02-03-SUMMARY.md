---
phase: "02"
plan: "03"
subsystem: exercise-detail
tags: [video-playback, mux, avkit, swiftui, exercise-library]
dependency_graph:
  requires: ["02-02"]
  provides: [ExerciseDetailView, VideoPlayerView, ExercisePlaceholderView]
  affects: [ExerciseLibraryView]
tech_stack:
  added: [MuxPlayerSwift 1.5.0]
  patterns: [UIViewControllerRepresentable, seek-to-zero HLS loop, NavigationLink push]
key_files:
  created:
    - WorkoutApp/Features/Train/VideoPlayerView.swift
    - WorkoutApp/Features/Train/ExercisePlaceholderView.swift
    - WorkoutApp/Features/Train/ExerciseDetailView.swift
  modified:
    - WorkoutApp/Features/Train/ExerciseLibraryView.swift
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - "Used seek-to-zero notification pattern for HLS looping (NOT AVPlayerLooper — broken for HLS)"
  - "Used secondarySystemBackground / tertiarySystemBackground semantic colors for placeholder gradient instead of hardcoded hex to support both light and dark mode"
  - "TagPill wrapped in horizontal ScrollView to handle long tag text without clipping"
metrics:
  duration: "~30 min"
  completed: "2026-04-18"
  tasks: 2
  files: 5
---

# Phase 02 Plan 03: Exercise Detail View + Video Playback Summary

**One-liner:** HLS video detail view with seek-to-zero loop via MuxPlayerSwift, gradient placeholder for unlicensed exercises, and NavigationLink wired from exercise library to detail.

---

## What Was Built

### Task 1: MuxPlayerSwift SPM + VideoPlayerView + ExercisePlaceholderView

Added MuxPlayerSwift 1.5.0 as an SPM dependency via project.pbxproj edits. Created two new Swift files in `WorkoutApp/Features/Train/`:

**VideoPlayerView.swift** — `UIViewControllerRepresentable` wrapping `AVPlayerViewController` with two playback paths:
- **Online path:** `AVPlayerViewController(playbackID:playbackOptions:)` via MuxPlayerSwift with Smart Cache at `.only720p` single rendition
- **Offline path:** `AVPlayer(url:)` with standard `AVPlayerViewController` using a local cached asset URL from CoreData

Both paths use the seek-to-zero looping pattern via `AVPlayerItemDidPlayToEndTime` notification with `player.actionAtItemEnd = .none`. `AVPlayerLooper` is explicitly avoided — it is incompatible with HLS streams (creates duplicate AVPlayerItem copies causing redundant downloads).

**ExercisePlaceholderView.swift** — Gradient card with `video.slash` SF Symbol and "Video coming soon" label. Uses semantic `secondarySystemBackground`/`tertiarySystemBackground` colors (adapts to light/dark mode) instead of hardcoded hex. Aspect ratio matches the video player (16:9) so layout is stable across both states.

### Task 2: ExerciseDetailView + NavigationLink Wiring

**ExerciseDetailView.swift** — Full exercise detail screen in a `ScrollView` with:
- Video area: `VideoPlayerView` if `exercise.hasVideo`, else `ExercisePlaceholderView`
- Exercise name (`.title2` semibold)
- Tag pills in a horizontal `ScrollView`: primary muscle (accent), equipment, difficulty
- "How To" numbered steps (`ForEach(enumerated)` — step number + body text)
- "Form Tips" section (shown only when `exercise.formTips` is non-nil and non-empty)
- `.navigationTitle(exercise.name)` with `.inline` display mode
- `.task` modifier calls `ExerciseRepository.shared.updateLastViewed(exerciseId:)` for LRU cache tracking (EXRC-04)

**ExerciseLibraryView.swift** — Updated NavigationLink destination from placeholder `Text(exercise.name)` to `ExerciseDetailView(exercise: exercise)`. Comment updated to reflect Plan 03 completion.

---

## Acceptance Criteria Verification

| Criterion | Status |
|-----------|--------|
| MuxPlayerSwift in project.pbxproj | PASS |
| No AVPlayerLooper usage in VideoPlayerView | PASS |
| actionAtItemEnd = .none present | PASS |
| AVPlayerItemDidPlayToEndTime notification present | PASS |
| seek(to: .zero) present | PASS |
| "Video coming soon" in ExercisePlaceholderView | PASS |
| video.slash SF Symbol in ExercisePlaceholderView | PASS |
| ExerciseDetailView created | PASS |
| VideoPlayerView referenced in ExerciseDetailView | PASS |
| ExercisePlaceholderView referenced in ExerciseDetailView | PASS |
| "How To" section in ExerciseDetailView | PASS |
| "Form Tips" section in ExerciseDetailView | PASS |
| ExerciseDetailView wired in ExerciseLibraryView NavigationLink | PASS |
| Color("AccentColor") used in TagPill | PASS |

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Enhancement] Semantic colors for placeholder gradient instead of hardcoded hex**
- **Found during:** Task 1
- **Issue:** Plan specified `Color(hex: "#1C1C1E")` and `Color(hex: "#2C2C2E")` but no `Color(hex:)` initializer exists in the codebase, and hardcoded hex colors don't adapt to light/dark mode automatically
- **Fix:** Used `Color(.secondarySystemBackground)` and `Color(.tertiarySystemBackground)` which achieve the same dark-mode dark gray appearance while supporting Dynamic Appearance automatically
- **Files modified:** WorkoutApp/Features/Train/ExercisePlaceholderView.swift

**2. [Rule 2 - Enhancement] TagPill wrapped in horizontal ScrollView**
- **Found during:** Task 2
- **Issue:** Plan put `HStack(spacing: 8)` with tag pills directly in the layout; if exercise name + tags are long they could clip at the right edge
- **Fix:** Wrapped the `HStack` in a `ScrollView(.horizontal, showsIndicators: false)` so long tag lists scroll rather than clip
- **Files modified:** WorkoutApp/Features/Train/ExerciseDetailView.swift

---

## Known Stubs

None. All displayed fields are wired to `ExerciseModel` properties passed via NavigationLink. No hardcoded placeholder data flows to UI rendering in production paths (preview data is `#if DEBUG` only).

---

## Threat Flags

None. This plan adds no new network endpoints, auth paths, or schema changes. The Mux playback ID is fetched from Supabase at runtime (established in Plan 02-01), not hardcoded in the binary. Trust boundaries match the threat model in the plan: Mux CDN -> AVPlayer (accepted per T-02-06, T-02-07).

---

## Self-Check

Files created/modified:
- WorkoutApp/Features/Train/VideoPlayerView.swift — EXISTS
- WorkoutApp/Features/Train/ExercisePlaceholderView.swift — EXISTS
- WorkoutApp/Features/Train/ExerciseDetailView.swift — EXISTS
- WorkoutApp/Features/Train/ExerciseLibraryView.swift — MODIFIED (NavigationLink wired)
- WorkoutApp.xcodeproj/project.pbxproj — MODIFIED (MuxPlayerSwift added, 3 new files registered)

## Self-Check: PASSED
