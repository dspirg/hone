---
phase: 10-design-system-and-visual-identity
plan: "01"
subsystem: design-system
tags: [theme, colors, dark-mode, components, swift]
dependency_graph:
  requires: []
  provides:
    - WorkoutApp/Core/Theme.swift
    - WorkoutApp/Assets.xcassets/AccentColor.colorset
    - WorkoutApp/Assets.xcassets/AppBackground.colorset
    - WorkoutApp/Assets.xcassets/CardBackground.colorset
    - WorkoutApp/Assets.xcassets/SurfaceElevated.colorset
    - WorkoutApp/Assets.xcassets/BorderSubtle.colorset
    - WorkoutApp/Assets.xcassets/SuccessGreen.colorset
    - WorkoutApp/Assets.xcassets/DestructiveRed.colorset
    - WorkoutApp/Features/Coach/Components/HoneAvatarView.swift
    - WorkoutApp/Features/Train/VideoOverlayView.swift
  affects:
    - WorkoutApp/WorkoutApp.swift
tech_stack:
  added: []
  patterns:
    - "Typed color token enum (Theme) backed by asset catalog named colors"
    - "Dual light/dark colorset entries for adaptive appearance"
    - "preferredColorScheme(.dark) on ContentView for app-wide dark mode enforcement"
    - "LinearGradient clipShape(Circle()) for avatar component"
    - "VideoPlayerView reuse in overlay without AVPlayerLooper"
key_files:
  created:
    - WorkoutApp/Core/Theme.swift
    - WorkoutApp/Assets.xcassets/SurfaceElevated.colorset/Contents.json
    - WorkoutApp/Assets.xcassets/BorderSubtle.colorset/Contents.json
    - WorkoutApp/Assets.xcassets/SuccessGreen.colorset/Contents.json
    - WorkoutApp/Assets.xcassets/DestructiveRed.colorset/Contents.json
    - WorkoutApp/Features/Coach/Components/HoneAvatarView.swift
    - WorkoutApp/Features/Train/VideoOverlayView.swift
  modified:
    - WorkoutApp/Assets.xcassets/AccentColor.colorset/Contents.json
    - WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json
    - WorkoutApp/Assets.xcassets/CardBackground.colorset/Contents.json
    - WorkoutApp/WorkoutApp.swift
decisions:
  - "preferredColorScheme(.dark) placed on ContentView (not MainTabView) so fullScreenCover presentations inherit dark mode from window root"
  - "VideoOverlayView wraps existing VideoPlayerView without AVPlayerLooper since VideoPlayerView already handles seek-to-zero looping for HLS"
  - "Theme enum (not struct/class) to prevent instantiation; static members only"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-26"
  tasks_completed: 2
  files_changed: 11
---

# Phase 10 Plan 01: Design System Foundation Summary

**One-liner:** JWT-free design system with amber Theme token enum, 7 dual-variant colorsets, forced dark mode, HoneAvatarView gradient avatar, and VideoOverlayView for fullscreen exercise video.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create asset catalog color sets and Theme.swift | ade9c0b | Theme.swift, 7 colorset JSONs |
| 2 | Force dark mode + HoneAvatarView + VideoOverlayView | 6d6fc66 | WorkoutApp.swift, HoneAvatarView.swift, VideoOverlayView.swift |

## What Was Built

### Theme.swift Token File

A centralized `enum Theme` in `WorkoutApp/Core/Theme.swift` providing:
- 7 typed color tokens: `accent`, `background`, `surface`, `surfaceElevated`, `borderSubtle`, `successGreen`, `destructiveRed`
- `Theme.Spacing` nested enum with 7 steps: xs(4), sm(8), md(16), lg(24), xl(32), xxl(48), xxxl(64)

All colors backed by asset catalog named colors with dark variant support.

### Asset Catalog Colorsets

7 colorsets with dual light/dark entries:

| Colorset | Light | Dark |
|----------|-------|------|
| AccentColor | #da7706 (amber-700) | #f59e0b (amber) |
| AppBackground | #f5f5f5 | #0a0a0a |
| CardBackground | #ffffff | #161616 |
| SurfaceElevated | #f2f2f2 | #1e1e1e |
| BorderSubtle | #e0e0e0 | #2a2a2a |
| SuccessGreen | #22996f | #34d399 |
| DestructiveRed | #e03939 | #f87171 |

### Dark Mode Enforcement

`.preferredColorScheme(.dark)` added on `ContentView()` in `WorkoutApp.swift`. Placed before `.environment(appState)` so it applies to the entire window including `fullScreenCover` presentations.

### HoneAvatarView

`WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` — reusable amber-to-orange gradient circle:
- Takes a `diameter: CGFloat` parameter
- `LinearGradient` from `Theme.accent` (#f59e0b) to orange #f97316
- `.clipShape(Circle())` for circular masking
- Abstract gradient — no face or character

### VideoOverlayView

`WorkoutApp/Features/Train/VideoOverlayView.swift` — fullscreen video overlay:
- Takes `muxPlaybackId: String` and `exerciseName: String`
- Wraps existing `VideoPlayerView(muxPlaybackId:localAssetURL:)` without AVPlayerLooper
- Black background with `.ignoresSafeArea()` for true fullscreen
- Dismiss handled by calling view via `.fullScreenCover` presentation

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundaries introduced. All items align with the plan's threat model:
- T-10-01: Mux playback IDs are public by design — accepted
- T-10-02: AsyncImage (used by future plans) handles load failures — accepted

## Known Stubs

None — this plan creates infrastructure (tokens, colorsets, components) with no data rendering paths that could be stubbed.

## Self-Check

- [x] WorkoutApp/Core/Theme.swift exists
- [x] All 7 colorset Contents.json files exist
- [x] HoneAvatarView.swift exists with correct structure
- [x] VideoOverlayView.swift exists with VideoPlayerView usage
- [x] WorkoutApp.swift contains preferredColorScheme(.dark)
- [x] Build succeeds: `** BUILD SUCCEEDED **`
- [x] Commits ade9c0b and 6d6fc66 exist in git log

## Self-Check: PASSED
