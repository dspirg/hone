---
phase: 02-exercise-library
plan: "04"
subsystem: cache
tags: [caching, offline, avfoundation, coredata, eviction, profile]
dependency_graph:
  requires: ["02-03"]
  provides: ["ExerciseCacheManager", "ProfileView-cache-display"]
  affects: ["AppState", "ProfileView"]
tech_stack:
  added: []
  patterns:
    - "@MainActor ExerciseCacheManager for CoreData-safe cache operations"
    - "AVAssetDownloadURLSession with DownloadDelegate (@unchecked Sendable) for HLS download"
    - "Library/-relative path storage for sandbox-safe URL persistence (Pitfall 3)"
    - "LRU eviction: NSFetchRequest sorted ascending by lastViewedAt"
    - "ByteCountFormatter for human-readable cache size in ProfileView"
key_files:
  created:
    - WorkoutApp/Core/Cache/ExerciseCacheManager.swift
    - WorkoutAppTests/CacheEvictionTests.swift
  modified:
    - WorkoutApp/Core/AppState.swift
    - WorkoutApp/Features/Main/Tabs/ProfileView.swift
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - "Option A chosen: Mux Smart Cache for playback + manual budget enforcement via ExerciseCacheManager (not Option B: manual AVAssetDownloadURLSession only)"
  - "@MainActor on ExerciseCacheManager to safely access PersistenceController.shared (main actor isolated)"
  - "DownloadDelegate uses @unchecked Sendable + Task { @MainActor in } for Swift 6 CoreData write safety"
  - "Relative path storage within Library/ prevents sandbox container path invalidation across reinstalls"
metrics:
  duration_minutes: 30
  completed_date: "2026-04-18"
  tasks_completed: 1
  files_created: 2
  files_modified: 3
---

# Phase 02 Plan 04: Exercise Video Cache Manager Summary

**One-liner:** LRU-evicting 500MB HLS video cache manager with @MainActor CoreData integration and ProfileView cache size display.

## What Was Built

### ExerciseCacheManager (`WorkoutApp/Core/Cache/ExerciseCacheManager.swift`)
- `@MainActor final class` singleton providing offline HLS video cache management
- `currentCacheSize() -> Int64`: scans CoreData Exercise entities with non-nil `localAssetURL`, sums `FileManager.attributesOfItem` file sizes
- `formattedCacheSize() -> String`: wraps `ByteCountFormatter` for "42.3 MB"-style display
- `evictOldestIfNeeded(requiredBytes:)`: LRU eviction loop — fetches exercises sorted ascending by `lastViewedAt`, deletes disk files, clears `localAssetURL` in CoreData until budget is satisfied
- `downloadIfNeeded(exerciseId:muxPlaybackId:)`: checks CoreData skip-if-cached guard, runs eviction, starts `AVAssetDownloadURLSession` background download
- `clearAllCache()`: bulk delete for future "Clear video cache" UI
- `DownloadDelegate`: private `NSObject, AVAssetDownloadDelegate, @unchecked Sendable` — stores downloaded URL as Library/-relative path, hops to `Task { @MainActor in }` for CoreData write

### AppState (`WorkoutApp/Core/AppState.swift`)
- Added `import Foundation` (required for `UUID` type with `@Observable` macro)
- Added `var activePlanExerciseIDs: Set<UUID> = []` for plan-aware cache prioritization

### ProfileView (`WorkoutApp/Features/Main/Tabs/ProfileView.swift`)
- Converted from plain `VStack` to `List` with two sections
- Section 1: existing profile placeholder content (person.fill icon + text)
- Section 2: "Storage" — `HStack` with "Exercise video cache" label and `ExerciseCacheManager.shared.formattedCacheSize()` value

### CacheEvictionTests (`WorkoutAppTests/CacheEvictionTests.swift`)
6 tests, all green:
- `testCurrentCacheSizeCalculation`: writes real temp files, verifies size sum
- `testEvictsOldestWhenOverBudget`: inserts old+new exercises, runs eviction with small budget, confirms oldest is cleared first
- `testSkipsDownloadWhenAlreadyCached`: verifies guard clause detects existing `localAssetURL`
- `testFormattedCacheSize`: verifies `ByteCountFormatter` output contains KB/MB/GB unit
- `testEmptyCacheReturnsZeroSize`: confirms zero return when no entities have `localAssetURL`
- `testEvictionDeletesFileFromDisk`: verifies physical file deletion + CoreData reference clear

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pre-existing broken pbxproj group reference for Onboarding/Components**
- **Found during:** Task 1 build verification
- **Issue:** `ChipView.swift`, `ChipGridView.swift`, `OnboardingProgressView.swift` were moved from `Features/Onboarding/Components/` to `Core/Components/` in a prior wave, but the pbxproj group still pointed to the old path — causing BUILD FAILED
- **Fix:** Moved the `Components` group reference from the `Onboarding` parent group to the `Core` parent group; removed it from `Onboarding` children
- **Files modified:** `WorkoutApp.xcodeproj/project.pbxproj`
- **Commit:** 65d7db0

**2. [Rule 1 - Bug] Missing `import Foundation` in AppState.swift**
- **Found during:** Task 1 compilation after adding `Set<UUID>`
- **Issue:** `@Observable` macro expansion could not find `UUID` type without explicit Foundation import (AppState previously imported only `Observation` and `Supabase`)
- **Fix:** Added `import Foundation`
- **Files modified:** `WorkoutApp/Core/AppState.swift`
- **Commit:** 65d7db0

**3. [Rule 1 - Bug] Swift 6 concurrency errors on ExerciseCacheManager**
- **Found during:** Task 1 compilation
- **Issue:** `PersistenceController.shared` is `@MainActor`-isolated; accessing it from a non-isolated context triggered 5 Swift 6 concurrency errors
- **Fix:** Added `@MainActor` to `ExerciseCacheManager`; marked `DownloadDelegate` as `@unchecked Sendable` and used `Task { @MainActor in }` for CoreData writes in delegate callback
- **Files modified:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift`
- **Commit:** 65d7db0

### Checkpoint Auto-Approved
Task 2 (`checkpoint:human-verify`) was auto-approved per execution instructions — this agent was spawned with the checkpoint plan already approved by the user.

## Known Stubs

None — `ExerciseCacheManager.shared.formattedCacheSize()` is fully wired to CoreData and FileManager. ProfileView displays real cache size (0 bytes initially, as expected on a fresh install with no cached videos).

## Threat Flags

None — all new surface (local file cache at 500MB limit) was already in the plan's threat model as T-02-09, mitigated by `evictOldestIfNeeded()`.

## Self-Check: PASSED

Files created:
- FOUND: WorkoutApp/Core/Cache/ExerciseCacheManager.swift
- FOUND: WorkoutAppTests/CacheEvictionTests.swift

Files modified:
- FOUND: WorkoutApp/Core/AppState.swift
- FOUND: WorkoutApp/Features/Main/Tabs/ProfileView.swift

Commits:
- FOUND: 65d7db0 (feat(02-04): ExerciseCacheManager with 500MB eviction + ProfileView cache display)

Tests: 6/6 passed (CacheEvictionTests)
