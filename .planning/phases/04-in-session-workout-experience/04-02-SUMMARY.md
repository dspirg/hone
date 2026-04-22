---
phase: 04-in-session-workout-experience
plan: 02
subsystem: session-state-machine
tags: [session, viewmodel, sync, coredata, nwpathmonitor, tdd]
dependency_graph:
  requires:
    - 04-01 (CDSessionLog/CDSetLog CoreData entities + xcdatamodeld)
  provides:
    - SessionViewModel (session state machine — exercise index, timer, set logging)
    - SessionRepository (CoreData CRUD for CDSessionLog + CDSetLog)
    - SessionSyncService (NWPathMonitor + Supabase batch upsert)
  affects:
    - 04-03 (SessionView — consumes SessionViewModel)
    - 04-04 (TrainView — launches SessionView with SessionViewModel)
tech_stack:
  added: []
  patterns:
    - "@Observable @MainActor session state machine with forceTimerActiveForTesting hook"
    - "NWPathMonitor on background DispatchQueue; Task { @MainActor } bridging"
    - "isSyncing Bool guard prevents concurrent Supabase upserts"
    - "performBackgroundTask for non-blocking CoreData set log writes"
    - "Supabase upsert(onConflict: id) for idempotent session sync"
    - "TDD RED/GREEN: test files committed before implementation"
key_files:
  created:
    - WorkoutApp/Features/Session/SessionViewModel.swift
    - WorkoutApp/Core/Sync/SessionSyncService.swift
    - WorkoutApp/Features/CoreData/SessionRepository.swift
    - WorkoutAppTests/SessionViewModelTests.swift
    - WorkoutAppTests/SessionSyncServiceTests.swift
  modified:
    - WorkoutApp.xcodeproj/project.pbxproj (added Session group, Sync group, test targets)
    - WorkoutAppTests/ExerciseSearchFilterTests.swift (bug fix — videoUrl param)
decisions:
  - "SessionViewModel forceTimerActiveForTesting hook enables unit testing without async sessionLog creation"
  - "SessionSyncService isSyncing guard chosen over Task cancellation — simpler and sufficient for reconnect event frequency"
  - "SessionRepository.completeSet uses container.performBackgroundTask (non-blocking) not viewContext (blocking UI)"
  - "TDD async setUp/tearDown used instead of setUpWithError/tearDownWithError for Swift 6 @MainActor compatibility"
metrics:
  duration: ~30 minutes
  completed: 2026-04-22
  tasks_completed: 2
  files_created: 5
  files_modified: 2
requirements:
  - SESS-02
  - SESS-03
---

# Phase 04 Plan 02: SessionViewModel and SessionSyncService Summary

**One-liner:** Session state machine with date-anchored rest timer and NWPathMonitor-triggered Supabase upsert for offline-first set logging.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 RED | SessionViewModelTests (failing) | 5b0e9ba | SessionViewModelTests.swift, SessionSyncServiceTests.swift |
| 1+2 GREEN | SessionViewModel + SessionSyncService + SessionRepository | ed95a23 | SessionViewModel.swift, SessionSyncService.swift, SessionRepository.swift, project.pbxproj |
| Bug fix | ExerciseSearchFilterTests videoUrl | 65abaf1 | ExerciseSearchFilterTests.swift |

## What Was Built

### SessionViewModel (`WorkoutApp/Features/Session/SessionViewModel.swift`)

`@Observable @MainActor` state machine owning the complete in-session experience:

- **Exercise progression:** `currentExerciseIndex`, `advanceExercise()`, `exercises`, `currentExercise`, `nextContextLabel`
- **Set logging:** `completeSet(setIndex:repsLogged:)` — writes to CoreData via repository, starts rest timer on non-final sets, calls `finalizeSession` on last set of last exercise
- **Rest timer:** `timerEndDate: Date?` + `isRestTimerActive: Bool` — date-anchored pattern; `skipRest()`, `extendRest()` (+30s), `handleTimerExpired()`
- **Notifications:** `UNUserNotificationCenter` permission request at session start; rest timer notification scheduled per-set and cancelled on skip/extend
- **Session completion:** `isSessionComplete` flipped to `true` when last set logged and `finalizeSession` completes
- **Testing hook:** `forceTimerActiveForTesting(endDate:)` for unit tests that don't wait for async `startSession()`

### SessionRepository (`WorkoutApp/Features/CoreData/SessionRepository.swift`)

CoreData CRUD layer shared by SessionViewModel (writes) and SessionSyncService (reads):

- `startSession(day:planId:userId:)` — creates `CDSessionLog`, saves on `viewContext`
- `completeSet(session:exercise:setNumber:repsLogged:)` — `performBackgroundTask` non-blocking write; T-04-05 rep clamp 0–999
- `finalizeSession(_:)` — sets `completedAt`, aggregates `totalSets`/`totalReps` from set logs
- `fetchUnsyncedSessions()` — predicate: `syncedToSupabase == NO AND completedAt != nil`
- `fetchUnsyncedSetLogs(for:)` — per-session unsynced set logs
- `markSynced(session:setLogs:)` — sets `syncedToSupabase = true` on both entities

### SessionSyncService (`WorkoutApp/Core/Sync/SessionSyncService.swift`)

`@Observable @MainActor` connectivity monitor + batch sync:

- `startMonitoring()` — `NWPathMonitor` on `DispatchQueue(label: "com.workoutapp.network-monitor")`, never `.main` (T-04-08)
- `pathUpdateHandler` bridges to `@MainActor` via `Task { @MainActor [weak self] in ... }`
- `isSyncing` Bool guard prevents concurrent Supabase calls on rapid reconnect (T-04-06)
- `syncPendingLogs()` — up to 3 retries; `syncBannerVisible = true` after all 3 fail
- `performBatchSync()` — upserts `session_logs` first (FK), then `set_logs` per session; marks synced after both succeed
- `SessionLogRow` / `SetLogRow` — private `Encodable` structs with snake_case `CodingKeys`
- Testing hooks: `syncNowSkippingSupabaseForTesting()`, `setIsSyncingForTesting(_:)`

## Test Results

### SessionViewModelTests (5 tests — all passed)

| Test | Result |
|------|--------|
| testAdvanceExerciseIncrementsIndex | passed |
| testCompleteSetSetsTimerEndDate | passed |
| testSkipRestClearsTimerState | passed |
| testExtendRestAdds30Seconds | passed |
| testSessionCompleteOnLastSetOfLastExercise | passed |

### SessionSyncServiceTests (4 tests — all passed)

| Test | Result |
|------|--------|
| testSyncBannerInitiallyFalse | passed |
| testIsSyncingPreventsDoubleExecution | passed |
| testEmptySyncSucceedsWithoutError | passed |
| testMarkSyncedClearsUnsyncedFetch | passed |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed missing videoUrl param in ExerciseSearchFilterTests**
- **Found during:** Task 1 test run
- **Issue:** `ExerciseSearchFilterTests.swift` called `ExerciseDTO(...)` without the `videoUrl` parameter added by the quick task `260420-a0` (video pipeline). This caused a compile error blocking all test execution.
- **Fix:** Added `videoUrl: nil` to the `ExerciseDTO` call in `makeExercise()`
- **Files modified:** `WorkoutAppTests/ExerciseSearchFilterTests.swift`
- **Commit:** 65abaf1

**2. [Rule 3 - Blocking] Used async setUp/tearDown instead of setUpWithError/tearDownWithError**
- **Found during:** Task 1 — Swift 6 concurrency warnings on `@MainActor` property access from nonisolated `setUpWithError`
- **Issue:** `setUpWithError() throws` is nonisolated; accessing `@MainActor`-isolated `PersistenceController` and `SessionRepository` properties caused Swift 6 warnings that would be errors in strict mode
- **Fix:** Changed both test classes to `setUp() async throws` / `tearDown() async throws` which run on the main actor
- **Files modified:** `WorkoutAppTests/SessionViewModelTests.swift`, `WorkoutAppTests/SessionSyncServiceTests.swift`
- **Commit:** Included in 5b0e9ba

**3. [Rule 2 - Missing critical functionality] SessionRepository included as compilation dependency**
- **Found during:** Task 1 — SessionViewModel and SessionSyncService both reference `SessionRepository` which 04-01 was producing in parallel
- **Issue:** Parallel execution means 04-01's `SessionRepository` does not exist at build time in this worktree
- **Fix:** Implemented full `SessionRepository` in this plan (matching the interface contract specified in the plan's `<interfaces>` section). The orchestrator will resolve any conflict with 04-01's version at merge time.
- **Files created:** `WorkoutApp/Features/CoreData/SessionRepository.swift`
- **Commit:** ed95a23

## TDD Gate Compliance

- RED gate: `test(04-02)` commit 5b0e9ba — test files written before implementation
- GREEN gate: `feat(04-02)` commit ed95a23 — all 9 tests pass after implementation

Both gates satisfied.

## Known Stubs

None — all public methods are fully implemented. No hardcoded empty values or placeholder data.

## Threat Flags

No new trust boundaries introduced beyond what is in the plan's threat model:
- T-04-05 (repsLogged clamp 0–999): implemented in `SessionRepository.completeSet`
- T-04-06 (isSyncing guard): implemented in `SessionSyncService.syncNow` + `pathUpdateHandler`
- T-04-07 (userId from AppState JWT): userId flows from `startSession(userId:)` parameter — callers must supply from AppState
- T-04-08 (NWPathMonitor on background queue): implemented — monitor started on `monitorQueue`, never `.main`

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| WorkoutApp/Features/Session/SessionViewModel.swift | FOUND (committed in ed95a23) |
| WorkoutApp/Core/Sync/SessionSyncService.swift | FOUND (committed in ed95a23) |
| WorkoutApp/Features/CoreData/SessionRepository.swift | FOUND (committed in ed95a23) |
| WorkoutAppTests/SessionViewModelTests.swift | FOUND (committed in 5b0e9ba) |
| WorkoutAppTests/SessionSyncServiceTests.swift | FOUND (committed in 5b0e9ba) |
| commit 5b0e9ba (RED) | FOUND in git log |
| commit ed95a23 (GREEN) | FOUND in git log |
| commit 65abaf1 (bug fix) | FOUND in git log |
| All 9 tests pass | VERIFIED — xcodebuild TEST SUCCEEDED |
