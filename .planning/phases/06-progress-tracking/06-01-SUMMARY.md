---
phase: 06
plan: 01
subsystem: progress-tracking
tags: [viewmodel, coredata, streak, pr-detection, unit-tests]
dependency_graph:
  requires:
    - CDSessionLog (CoreData entity, Phase 04)
    - CDSetLog (CoreData entity, Phase 04)
    - PersistenceController (Core/Data, Phase 01)
    - AppState (Core, Phase 01)
  provides:
    - ProgressViewModel (all progress computation)
    - PRResult (PR detection result type)
    - WeekBucket / WeekKey (chart data types)
    - ProgressViewModelTests (10 unit tests)
  affects:
    - Phase 06 Plan 02 (Progress UI — reads from ProgressViewModel)
tech_stack:
  added:
    - ProgressViewModel using @Observable @MainActor pattern (mirrors CoachViewModel)
    - In-memory CoreData test setup (mirrors SessionRepositoryTests pattern)
  patterns:
    - NSFetchRequest with userId predicate for cross-user data isolation (T-06-01)
    - Calendar.current.startOfDay(for:) + Set<Date> deduplication for streak
    - yearForWeekOfYear / weekOfYear DateComponents for ISO week bucketing
    - userId-scoped CDSetLog queries via session relationship (T-06-02)
key_files:
  created:
    - WorkoutApp/Features/Progress/Models/PRResult.swift
    - WorkoutApp/Features/Progress/Models/WeekBucket.swift
    - WorkoutApp/Features/Progress/ProgressViewModel.swift
    - WorkoutAppTests/ProgressViewModelTests.swift
  modified:
    - WorkoutApp.xcodeproj/project.pbxproj (added Progress group and all new files)
    - WorkoutAppTests/CoachViewModelTests.swift (added missing CoreData import)
decisions:
  - detectPRs scopes prior CDSetLog queries via fetchUserSessionIds() helper — CDSetLog has no direct userId field, so we fetch all session IDs for the user then filter set logs by those IDs
  - computeWeekBuckets returns [WeekBucket] and also sets self.weekBuckets — dual assignment enables both direct return in tests and state binding in production
  - longestStreak computed in full pass over sorted days rather than just during current streak walk — ensures longest is always correct even when current streak is 0
  - weeklyPlanned defaults to 4 when no active plan data is available; UI layer can override via direct assignment before displaying
metrics:
  duration: "~20 minutes"
  completed: "2026-04-23"
  tasks_completed: 2
  files_created: 4
  files_modified: 2
---

# Phase 06 Plan 01: ProgressViewModel Data Layer Summary

ProgressViewModel with complete streak/weekly ring/chart/PR computation from CoreData, plus 10 passing unit tests covering all logic paths including userId-scoped query isolation.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create model types and ProgressViewModel | fddf5d6 | PRResult.swift, WeekBucket.swift, ProgressViewModel.swift, project.pbxproj |
| 2 | Create ProgressViewModelTests | 5df2a16 | ProgressViewModelTests.swift, CoachViewModelTests.swift |

## What Was Built

**PRResult.swift** — `struct PRResult: Identifiable, Equatable` with `exerciseName`, `newRecord`, and `previousBest` fields. Used by `detectPRs(for:)` to surface exercise improvements after session completion.

**WeekBucket.swift** — `struct WeekKey: Hashable, Comparable` for ISO week grouping, and `struct WeekBucket: Identifiable` with `weekLabel`, `sessionCount`, and `volume` for the progress chart.

**ProgressViewModel.swift** — `@Observable @MainActor final class ProgressViewModel` with:
- `fetchCompletedSessions()` — NSFetchRequest with `completedAt != nil AND userId == %@` predicate (T-06-01)
- `computeStreak(from:)` — calendar-day deduplication via `Calendar.current.startOfDay(for:)` + `Set<Date>`, tracks both current and longest streak
- `computeWeeklyRing(from:)` — uses `Calendar.current.dateInterval(of: .weekOfYear, for: Date())`
- `computeWeekBuckets(from:)` — 8-week ISO week grouping sorted ascending by `WeekKey`
- `detectPRs(for:)` — userId-scoped prior CDSetLog lookup via `fetchUserSessionIds()` helper (T-06-02)
- `setUserIdForTesting(_:)` — test helper following CoachViewModel pattern

**ProgressViewModelTests.swift** — 10 unit tests all passing:
1. `testFetchCompletedSessionsExcludesInProgress` — nil completedAt excluded
2. `testFetchCompletedSessionsFiltersByUserId` — cross-user isolation verified
3. `testStreakConsecutiveDays` — 3-day streak computed correctly
4. `testStreakBrokenByGap` — gap resets streak to 1
5. `testStreakDeduplicatesSameDay` — two sessions same day = streak of 1
6. `testStreakZeroWhenNoRecentSessions` — 5-day-old session = currentStreak 0
7. `testWeeklyBucketsGroupsByWeek` — 3 different weeks produce 3 buckets
8. `testPRDetectionFindsNewRecord` — 15 vs 10 prior = PRResult detected
9. `testPRDetectionReturnsEmptyWhenNoPR` — 10 vs 15 prior = no PRResult
10. `testPRDetectionFirstTimeExercise` — first occurrence = PR with previousBest 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed pre-existing CoachViewModelTests compilation error**
- **Found during:** Task 2 (running tests)
- **Issue:** `CoachViewModelTests.swift` line 326 used `NSEntityDescription` without importing `CoreData`, causing the entire test target to fail to compile, blocking ProgressViewModelTests from running
- **Fix:** Added `import CoreData` to `CoachViewModelTests.swift`
- **Files modified:** `WorkoutAppTests/CoachViewModelTests.swift`
- **Commit:** 5df2a16

## Threat Coverage

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-06-01 | `fetchCompletedSessions` always uses `NSPredicate(format: "completedAt != nil AND userId == %@", cachedUserId ?? "")` |
| T-06-02 | `detectPRs` fetches all user session IDs via `fetchUserSessionIds()` and filters prior CDSetLog records to that set |

## Known Stubs

None — ProgressViewModel does not stub any data. All state is computed from real CoreData queries.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced. All data reads from existing CoreData entities within existing trust boundary.

## Self-Check

- [x] `WorkoutApp/Features/Progress/Models/PRResult.swift` exists
- [x] `WorkoutApp/Features/Progress/Models/WeekBucket.swift` exists
- [x] `WorkoutApp/Features/Progress/ProgressViewModel.swift` exists
- [x] `WorkoutAppTests/ProgressViewModelTests.swift` exists
- [x] Task 1 commit `fddf5d6` exists
- [x] Task 2 commit `5df2a16` exists
- [x] All 10 tests pass (`** TEST SUCCEEDED **`)
- [x] App builds with zero errors (`** BUILD SUCCEEDED **`)

## Self-Check: PASSED
