---
phase: 10-design-system-and-visual-identity
plan: "04"
subsystem: exercise-video-thumbnails
tags: [thumbnails, video, fullscreen, CoreData, SwiftUI, AsyncImage]
dependency_graph:
  requires:
    - WorkoutApp/Features/Train/VideoOverlayView.swift  # from Plan 01
    - WorkoutApp/Core/Theme.swift                       # from Plan 01
    - WorkoutApp/Core/Data/ExerciseRepository.swift
  provides:
    - WorkoutApp/Features/Train/ExerciseLibraryRowView.swift  # tap-to-fullscreen added
    - WorkoutApp/Features/Train/ExerciseDetailView.swift      # expand button added
    - WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift  # thumbnail + tap-to-fullscreen added
  affects:
    - WorkoutApp/Features/PlanPreview/  # ExerciseRowView now shows thumbnails
tech_stack:
  added: []
  patterns:
    - "AsyncImage with dumbbell placeholder on Theme.surface for missing thumbnails"
    - "onTapGesture guarded by muxPlaybackId != nil before setting showVideo = true"
    - "fullScreenCover presenting VideoOverlayView consistently across exercise contexts"
    - "ExerciseRepository.shared.fetchByName() for CoreData exercise resolution in views"
    - "@MainActor async method for CoreData thumbnail resolution in SwiftUI .task modifier"
key_files:
  created: []
  modified:
    - WorkoutApp/Features/Train/ExerciseLibraryRowView.swift
    - WorkoutApp/Features/Train/ExerciseDetailView.swift
    - WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift
decisions:
  - "Used ExerciseRepository.shared.fetchByName() in ExerciseRowView instead of raw NSFetchRequest to match ExerciseCardView pattern and avoid duplicating fetch logic"
  - "Plan specified entityName 'CDExercise' but actual CoreData entity is 'Exercise' — used correct name via repository layer"
  - "Fullscreen expand button on ExerciseDetailView targets only muxPlaybackId path (not videoUrl fallback) since VideoOverlayView requires a Mux playback ID"
metrics:
  duration: "~12 minutes"
  completed: "2026-04-26"
  tasks_completed: 2
  files_changed: 3
---

# Phase 10 Plan 04: Tap-to-Fullscreen Video Thumbnails Summary

**One-liner:** Wired tap-to-fullscreen VideoOverlayView on exercise library rows, exercise detail expand button, and plan preview rows with CoreData-resolved thumbnails using AsyncImage and dumbbell placeholders.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Add tap-to-fullscreen on ExerciseLibraryRowView and ExerciseDetailView | 7f19a05 | ExerciseLibraryRowView.swift, ExerciseDetailView.swift |
| 2 | Add thumbnail to plan preview ExerciseRowView with CoreData lookup | 4faa7f1 | ExerciseRowView.swift |

## What Was Built

### ExerciseLibraryRowView — Tap-to-Fullscreen

Added `@State private var showVideo = false` with an `onTapGesture` guard on `muxPlaybackId` on the existing 52x52 AsyncImage thumbnail. Tapping a thumbnail with a valid `muxPlaybackId` presents `VideoOverlayView` via `.fullScreenCover`. Thumbnail already used `Theme.surface` placeholder from Plan 02. Accessibility label updated to include "tap to play video" when video is available.

### ExerciseDetailView — Fullscreen Expand Button

Added `@State private var showFullscreen = false` and a button overlay on the `VideoPlayerView` (muxPlaybackId path only) with `arrow.up.left.and.arrow.down.right` system image on `ultraThinMaterial` background. Tapping presents `VideoOverlayView` via `.fullScreenCover`. The `videoUrl` fallback path does not get an expand button (it lacks a Mux playback ID for `VideoOverlayView`).

### ExerciseRowView — Thumbnail with CoreData Lookup

Refactored from text-only to `HStack` with a leading 52x52 thumbnail. Thumbnail is resolved asynchronously from the local CoreData "Exercise" entity by name using `ExerciseRepository.shared.fetchByName()` in a `@MainActor` `resolveThumbnail()` method called via `.task`. Resolves both `thumbnailURL` and `muxPlaybackId`. Tapping the thumbnail (when `muxPlaybackId` is non-nil) presents `VideoOverlayView` via `.fullScreenCover`. Missing thumbnail shows dumbbell SF Symbol on `Theme.surface`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrong CoreData entity name in plan instructions**
- **Found during:** Task 2
- **Issue:** Plan specified `entityName: "CDExercise"` in the raw NSFetchRequest, but the actual CoreData entity is named "Exercise" (only plan entities use the "CD" prefix)
- **Fix:** Used `ExerciseRepository.shared.fetchByName()` which internally uses `NSFetchRequest<NSManagedObject>(entityName: "Exercise")` with the correct name — matches `ExerciseCardView` pattern
- **Files modified:** ExerciseRowView.swift
- **Commit:** 4faa7f1

## Known Stubs

None — thumbnail display is fully wired. When no exercise is cached in CoreData, the dumbbell placeholder is shown, which is the documented correct behavior.

## Threat Surface Scan

No new network endpoints or auth paths introduced. All surface aligns with plan's threat model:
- T-10-05: Mux thumbnail URLs contain only public playback ID — accepted
- T-10-06: ExerciseRowView reads CoreData read-only — accepted

## Self-Check

- [x] ExerciseLibraryRowView.swift contains `@State private var showVideo = false`
- [x] ExerciseLibraryRowView.swift contains `.onTapGesture` with guard
- [x] ExerciseLibraryRowView.swift contains `.fullScreenCover(isPresented: $showVideo)`
- [x] ExerciseLibraryRowView.swift contains `VideoOverlayView(muxPlaybackId:`
- [x] ExerciseLibraryRowView.swift contains accessibilityLabel with "tap to play video"
- [x] ExerciseDetailView.swift contains `@State private var showFullscreen = false`
- [x] ExerciseDetailView.swift contains `.fullScreenCover(isPresented: $showFullscreen)`
- [x] ExerciseDetailView.swift contains `VideoOverlayView(muxPlaybackId:`
- [x] ExerciseRowView.swift contains `import CoreData`
- [x] ExerciseRowView.swift contains `AsyncImage(url: URL(string: thumbnailURL`
- [x] ExerciseRowView.swift contains `resolveThumbnail()` method
- [x] ExerciseRowView.swift contains `VideoOverlayView(muxPlaybackId:`
- [x] ExerciseRowView.swift contains `.fullScreenCover(isPresented: $showVideo)`
- [x] ExerciseRowView.swift contains `.frame(width: 52, height: 52)`
- [x] ExerciseRowView.swift preview uses `Theme.surface`
- [x] ExerciseRowView.swift contains `Image(systemName: "dumbbell")` as placeholder
- [x] No file contains `AVPlayerLooper`
- [x] Build succeeds: `** BUILD SUCCEEDED **`
- [x] Commits 7f19a05 and 4faa7f1 exist in git log

## Self-Check: PASSED
