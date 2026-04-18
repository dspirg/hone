---
phase: 02-exercise-library
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 20
files_reviewed_list:
  - supabase/migrations/20260416300000_create_exercises.sql
  - WorkoutApp/Core/AppState.swift
  - WorkoutApp/Core/Cache/ExerciseCacheManager.swift
  - WorkoutApp/Core/Data/ExerciseRepository.swift
  - WorkoutApp/Core/Data/PersistenceController.swift
  - WorkoutApp/Features/Main/Tabs/ProfileView.swift
  - WorkoutApp/Features/Main/Tabs/TrainView.swift
  - WorkoutApp/Features/Train/ExerciseDetailView.swift
  - WorkoutApp/Features/Train/ExerciseLibraryRowView.swift
  - WorkoutApp/Features/Train/ExerciseLibraryView.swift
  - WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift
  - WorkoutApp/Features/Train/ExercisePlaceholderView.swift
  - WorkoutApp/Features/Train/FilterChipRow.swift
  - WorkoutApp/Features/Train/VideoPlayerView.swift
  - WorkoutApp/Models/ExerciseDTO.swift
  - WorkoutApp/Models/ExerciseModel.swift
  - WorkoutAppTests/CacheEvictionTests.swift
  - WorkoutAppTests/CoreDataStackTests.swift
  - WorkoutAppTests/ExerciseRepositoryTests.swift
  - WorkoutAppTests/ExerciseSearchFilterTests.swift
findings:
  critical: 3
  warning: 4
  info: 2
  total: 9
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-18
**Depth:** standard
**Files Reviewed:** 20
**Status:** issues_found

## Summary

The exercise library phase is well-structured overall. The MVVM pattern is applied consistently, CoreData upsert logic correctly preserves local cache metadata, the RLS policy correctly covers both `anon` and `authenticated` roles, and the filter/search ViewModel is clean. Tests cover the main paths.

Three critical bugs require immediate attention before shipping: the `AVAssetDownloadURLSession` and its delegate are immediately deallocated in `downloadIfNeeded`, silently killing every background download; the `evictOldestIfNeeded` while-loop can hang indefinitely if `context.save()` fails silently; and the Mux HLS URL is force-unwrapped, risking a crash on malformed playback IDs. There are also four warning-level issues including an `updated_at` trigger missing from the migration and a notification observer registered against a potentially-nil player item.

---

## Critical Issues

### CR-01: AVAssetDownloadURLSession and delegate are immediately deallocated, silently dropping all downloads

**File:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift:153-172`

**Issue:** `downloadIfNeeded` creates a local `let delegate` and a local `let downloadSession` inside the function body. Neither is stored anywhere with a strong reference. Both are released as soon as the function returns, which cancels any in-flight `AVAssetDownloadTask` before the download can make progress. The `DownloadDelegate.didFinishDownloadingTo` callback will never fire. Every call to `downloadIfNeeded` appears to succeed (no error is returned) but downloads silently do nothing.

**Fix:** Store both the session and delegate in a persistent dictionary keyed by `exerciseId` on `ExerciseCacheManager`. Because the manager is a `@MainActor` singleton, this is thread-safe without additional locking:

```swift
// Add to ExerciseCacheManager
private var activeSessions: [UUID: AVAssetDownloadURLSession] = [:]
private var activeDelegates: [UUID: DownloadDelegate] = [:]

func downloadIfNeeded(exerciseId: UUID, muxPlaybackId: String) {
    // ... existing guard/check logic ...

    let delegate = DownloadDelegate(exerciseId: exerciseId)
    let config = URLSessionConfiguration.background(
        withIdentifier: "com.workoutapp.exercise-cache.\(exerciseId.uuidString)"
    )
    let downloadSession = AVAssetDownloadURLSession(
        configuration: config,
        assetDownloadDelegate: delegate,
        delegateQueue: .main
    )
    // Retain both strongly so the session lives until the delegate callback fires
    activeSessions[exerciseId] = downloadSession
    activeDelegates[exerciseId] = delegate

    // ... create and resume task ...
}

// In DownloadDelegate.didFinishDownloadingTo, after saving to CoreData:
Task { @MainActor in
    ExerciseCacheManager.shared.activeSessions.removeValue(forKey: exerciseId)
    ExerciseCacheManager.shared.activeDelegates.removeValue(forKey: exerciseId)
}
```

---

### CR-02: Potential infinite loop in evictOldestIfNeeded when context.save() fails silently

**File:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift:88-119`

**Issue:** The `while` loop condition calls `currentCacheSize()` on every iteration. If `context.save()` fails (the error is swallowed by `try?`), the `localAssetURL` on the oldest entity is still set in-memory (the save failure means the nil-write was rolled back or the context is in an inconsistent state). On the next iteration the same entity is fetched again, the same file path is resolved (file is already deleted from disk), `removeItem` fails silently again, `setValue(nil,...)` sets the in-memory value but `save()` fails again — creating an infinite loop that spins the main thread.

**Fix:** Propagate or at minimum log the save error, and add a guard that breaks on save failure:

```swift
func evictOldestIfNeeded(requiredBytes: Int64 = 50 * 1_024 * 1_024) {
    let context = PersistenceController.shared.container.viewContext

    while currentCacheSize() + requiredBytes > maxCacheBytes {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "localAssetURL != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "lastViewedAt", ascending: true)]
        request.fetchLimit = 1

        guard let entities = try? context.fetch(request),
              let oldest = entities.first,
              let relativePath = oldest.value(forKey: "localAssetURL") as? String else {
            break
        }

        // ... resolve fileURL, remove file ...

        oldest.setValue(nil, forKey: "localAssetURL")
        do {
            try context.save()
        } catch {
            // Cannot persist eviction — break to avoid infinite loop.
            // Log to analytics in production.
            context.rollback()
            break
        }
    }
}
```

---

### CR-03: Force-unwrapped URL construction crashes on malformed muxPlaybackId

**File:** `WorkoutApp/Core/Cache/ExerciseCacheManager.swift:150`

**Issue:** `URL(string: "https://stream.mux.com/\(muxPlaybackId).m3u8")!` force-unwraps the result. If `muxPlaybackId` contains URL-invalid characters (spaces, percent signs, brackets, etc.) — which is possible since it comes from a Supabase TEXT column with no client-side validation — the initializer returns `nil` and the force-unwrap crashes the app.

**Fix:**
```swift
guard let hlsURL = URL(string: "https://stream.mux.com/\(muxPlaybackId).m3u8") else {
    // Invalid playback ID — skip download silently, log in production
    return
}
let asset = AVURLAsset(url: hlsURL)
```

---

## Warnings

### WR-01: updated_at column never auto-updates — stale-while-revalidate logic is broken

**File:** `supabase/migrations/20260416300000_create_exercises.sql:19-20`

**Issue:** The `updated_at` column is set to `NOW()` at insert time but there is no trigger to update it on `UPDATE`. Any row changed via a service-role UPDATE will keep the original insert timestamp. `ExerciseDTO.updatedAt` is documented as driving stale-while-revalidate cache invalidation, but it will always reflect the creation date — making cache invalidation permanently non-functional.

**Fix:** Add a trigger after the table definition:

```sql
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER exercises_set_updated_at
  BEFORE UPDATE ON public.exercises
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
```

---

### WR-02: Notification observer registered on potentially-nil currentItem — matches all player items globally

**File:** `WorkoutApp/Features/Train/VideoPlayerView.swift:59-71`

**Issue:** In `setupLooping(player:)`, the observer is registered with `object: player.currentItem`. For the online Mux path, `vc.player` is retrieved from an `AVPlayerViewController` initialised by MuxPlayerSwift. At the moment `makeUIViewController` calls `context.coordinator.setupLooping(player: vc.player)`, the player's `currentItem` may be `nil` (the HLS manifest hasn't loaded yet). When `object:` is `nil`, `NotificationCenter.addObserver(forName:object:queue:)` matches notifications from *any* object — meaning any other `AVPlayerItem` finishing playback elsewhere in the app will trigger a seek-to-zero on this player.

**Fix:** Observe on the player itself (object-agnostic) and check identity in the handler, or delay observation until `currentItem` is populated via KVO:

```swift
func setupLooping(player: AVPlayer?) {
    guard let player else { return }
    player.actionAtItemEnd = .none
    observer = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: nil,   // observe all, then filter
        queue: .main
    ) { [weak player] notification in
        // Only react if the notification is for our player's current item
        guard let item = notification.object as? AVPlayerItem,
              item === player?.currentItem else { return }
        player?.seek(to: .zero) { _ in
            player?.play()
        }
    }
}
```

---

### WR-03: Silent random UUID generation on CoreData id cast failure silently creates ghost models

**File:** `WorkoutApp/Models/ExerciseModel.swift:73`

**Issue:** `self.id = entity.value(forKey: "id") as? UUID ?? UUID()` — if the `id` attribute is nil or is stored as a type that cannot be cast to `UUID`, a fresh random `UUID()` is generated silently. The resulting `ExerciseModel` cannot be matched back to the CoreData entity, to `lastViewedAt` updates, or to the cache manager's lookup by `exerciseId`. In practice this means `updateLastViewed` and `downloadIfNeeded` silently operate on a nonexistent exercise ID.

**Fix:** Fail loudly in debug builds and return a sentinel/nil in production:

```swift
// Option A: assert in debug, use a known invalid UUID in production
self.id = (entity.value(forKey: "id") as? UUID) ?? {
    assertionFailure("Exercise entity missing id — data model may be corrupt")
    return UUID() // still needed for type safety; log to analytics
}()
```

Or restructure `init(from entity:)` as a failable init and handle the nil case in `loadFromCoreData()`.

---

### WR-04: Test context is shared across test cases via a static singleton — state can bleed between tests

**File:** `WorkoutAppTests/CacheEvictionTests.swift:20`, `WorkoutAppTests/CoreDataStackTests.swift:16`, `WorkoutAppTests/ExerciseRepositoryTests.swift:16`

**Issue:** All three test files use `PersistenceController.preview.container.viewContext`. `PersistenceController.preview` is a `static let` — it is created once and shared for the lifetime of the test process. `NSBatchDeleteRequest` (used in `tearDownWithError`) bypasses the NSManagedObjectContext's in-memory object graph, so after a batch delete the context's in-memory cache still holds references to the deleted objects. If tests run in an order where a prior test's teardown leaves the in-memory context in a dirty state, subsequent tests may see phantom objects or stale data.

**Fix:** Create a fresh `PersistenceController(inMemory: true)` per test class instance instead of using the shared `preview` singleton:

```swift
override func setUpWithError() throws {
    let controller = PersistenceController(inMemory: true)
    context = controller.container.viewContext
    // controller is retained by `self` via a stored property
}
```

This gives each test class a clean, isolated store.

---

## Info

### IN-01: AsyncImage passed empty string URL when thumbnailURL is nil — minor code smell

**File:** `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift:23`

**Issue:** `URL(string: exercise.thumbnailURL ?? "")` passes an empty string literal when `thumbnailURL` is nil. `URL(string: "")` returns `nil`, so the fallback placeholder is shown correctly — but the intent is obscured. A reader might wonder whether the empty string is intentional or a latent bug.

**Fix:**
```swift
AsyncImage(url: exercise.thumbnailURL.flatMap { URL(string: $0) }) { phase in
```

This expresses the intent directly: show the image if the URL parses successfully, otherwise show the placeholder.

---

### IN-02: mapError relies on localizedDescription string matching — fragile across localisations

**File:** `WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift:103-108`

**Issue:** `mapError` inspects `error.localizedDescription.lowercased()` for substrings like `"network"`, `"connection"`, `"offline"`. `localizedDescription` is locale-sensitive — on a device set to a non-English locale this matching will always fall through to the generic message. Additionally, as the Supabase Swift SDK evolves, error description strings may change.

**Fix:** Match on typed error cases instead of string content:

```swift
private func mapError(_ error: Error) -> String {
    // URLError covers most network failure cases
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            return "Couldn't load exercises. Check your connection."
        default:
            break
        }
    }
    return "Couldn't load exercises. Please try again."
}
```

---

_Reviewed: 2026-04-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
