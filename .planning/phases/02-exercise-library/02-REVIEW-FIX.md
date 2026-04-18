---
phase: 02-exercise-library
fixed_at: 2026-04-18T00:00:00Z
review_path: .planning/phases/02-exercise-library/02-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-04-18
**Source review:** .planning/phases/02-exercise-library/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (3 Critical + 4 Warning)
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: AVAssetDownloadURLSession and delegate are immediately deallocated

**Files modified:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift`
**Commit:** 8b4c776
**Applied fix:** Added `private var activeSessions: [UUID: AVAssetDownloadURLSession]` and `private var activeDelegates: [UUID: DownloadDelegate]` properties to `ExerciseCacheManager`. In `downloadIfNeeded`, both are stored keyed by `exerciseId` before `task.resume()`. In `DownloadDelegate.didFinishDownloadingTo`, both are removed via `removeValue(forKey:)` inside the `@MainActor` Task after the CoreData save, releasing them only after the download completes.

---

### CR-02: Potential infinite loop in evictOldestIfNeeded when context.save() fails silently

**Files modified:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift`
**Commit:** 8b4c776
**Applied fix:** Replaced `try? context.save()` in the eviction while-loop with a `do/catch` block. On save failure, `context.rollback()` is called and the loop breaks immediately, preventing the same entity from being re-fetched and re-attempted indefinitely.

---

### CR-03: Force-unwrapped URL construction crashes on malformed muxPlaybackId

**Files modified:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift`
**Commit:** 8b4c776
**Applied fix:** Replaced `URL(string: "https://stream.mux.com/\(muxPlaybackId).m3u8")!` with a `guard let hlsURL = URL(string:) else { return }` pattern. Malformed playback IDs now cause a silent early return instead of a crash.

---

### WR-01: updated_at column never auto-updates — stale-while-revalidate logic is broken

**Files modified:** `supabase/migrations/20260416300000_create_exercises.sql`
**Commit:** ce42cd7
**Applied fix:** Added a `set_updated_at()` plpgsql function and a `BEFORE UPDATE` trigger `exercises_set_updated_at` that sets `NEW.updated_at = NOW()` on every row update. Inserted after the table definition (section 1b) so it is applied in the same migration that creates the table.

---

### WR-02: Notification observer registered on potentially-nil currentItem

**Files modified:** `WorkoutApp/Features/Train/VideoPlayerView.swift`
**Commit:** 78c9cb5
**Applied fix:** Changed `object: player.currentItem` to `object: nil` in the `NotificationCenter.addObserver` call inside `Coordinator.setupLooping`. Added an identity check in the handler: `guard let item = notification.object as? AVPlayerItem, item === player?.currentItem else { return }`. This correctly handles the case where `currentItem` is nil at setup time (HLS not yet loaded) while still preventing spurious seek-to-zero calls from other player items elsewhere in the app.

---

### WR-03: Silent random UUID generation on CoreData id cast failure

**Files modified:** `WorkoutApp/Models/ExerciseModel.swift`
**Commit:** 1eafa00
**Applied fix:** Replaced the silent `?? UUID()` fallback with a closure that calls `assertionFailure("Exercise entity missing id — data model may be corrupt")` before returning the fallback UUID. This surfaces data model corruption in debug builds while remaining type-safe in production.

---

### WR-04: Test context is shared across test cases via a static singleton

**Files modified:** `WorkoutAppTests/CacheEvictionTests.swift`, `WorkoutAppTests/CoreDataStackTests.swift`, `WorkoutAppTests/ExerciseRepositoryTests.swift`
**Commit:** da4ecc2
**Applied fix:** Replaced `PersistenceController.preview.container.viewContext` with a fresh `PersistenceController(inMemory: true)` instantiated in `setUpWithError()` and stored as a `private var persistenceController` on each test class. `tearDownWithError()` sets both `context` and `persistenceController` to nil, discarding the store. The old `NSBatchDeleteRequest` teardown is removed — not needed when the store is discarded entirely between tests.

---

_Fixed: 2026-04-18_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
