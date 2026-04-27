---
phase: 11-screen-redesigns
fixed_at: 2026-04-27T20:58:41Z
review_path: .planning/phases/11-screen-redesigns/11-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 11: Code Review Fix Report

**Fixed at:** 2026-04-27T20:58:41Z
**Source review:** .planning/phases/11-screen-redesigns/11-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (1 Critical, 5 Warnings)
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: Unscoped CDSetLog Fetch Loads All Users' Set Data

**Files modified:** `WorkoutApp/Features/Main/HomeViewModel.swift`
**Commit:** f7f248b
**Applied fix:** Replaced the bare `CDSetLog.fetchRequest()` with a predicate-scoped fetch using `NSPredicate(format: "sessionId IN %@", userSessionIds as CVarArg)`. The in-memory `filter` call was removed. Satisfies T-11-03 at the CoreData layer, matching the pattern used by `SessionRepository.fetchBestReps`.

---

### WR-01: Race Condition — completeSet Silently Drops When sessionLog Is Nil

**Files modified:** `WorkoutApp/Features/Session/SessionViewModel.swift`
**Commit:** c3f6e3e
**Applied fix:** Added a `private(set) var sessionSetupFailed: Bool = false` property. `startSession()` now sets `sessionSetupFailed = true` in its catch block. `completeSet()` split the combined guard into two guards — first on `currentExercise`, then on `sessionLog` — and logs a diagnostic message when `sessionSetupFailed` is true. `SessionView` can observe `sessionSetupFailed` to display an error banner.

---

### WR-02: "Good Night" Greeting Fires at Hour 0 (Midnight to 4 AM)

**Files modified:** `WorkoutApp/Features/Main/HomeViewModel.swift`
**Commit:** 6f05506
**Applied fix:** Extended the `Good evening` case from `17..<21` to `17..<22`, so users opening the app between 9 PM and 10 PM see "Good evening" rather than "Good night". Hours 22–23 and 0–4 retain "Good night".

---

### WR-03: Force-Unwrap Crash Risk on Optional sessionId in completeSet Background Context

**Files modified:** `WorkoutApp/Features/CoreData/SessionRepository.swift`
**Commit:** e933cfb
**Applied fix:** Replaced `sessionId! as CVarArg` with a `guard let safeSessionId = sessionId else { try? bgCtx.save(); return }` guard. The set log record is still saved to the background context if `sessionId` is nil; only the inverse relationship wiring is skipped. No force-unwrap remains in the background task.

---

### WR-04: Weekly Regen Dedup Not Concurrency-Safe — Multiple Foreground Calls Can Race

**Files modified:** `WorkoutApp/Features/Adaptation/AdaptationService.swift`
**Commit:** 74d2247
**Applied fix:** Added `private var isWeeklyCheckInProgress: Bool = false`. The `checkOnForeground` guard condition now requires `!isWeeklyCheckInProgress` in addition to the ISO week key check. The flag is set to `true` before the `await requestWeeklyRegeneration()` call and reset to `false` after, making the dedup atomic across cooperative scheduler suspension points.

---

### WR-05: HomeExerciseRowView Always Passes url: nil to AsyncImage — Success Branch Is Dead Code

**Files modified:** `WorkoutApp/Features/Main/Components/HomeExerciseRowView.swift`
**Commit:** dc16850
**Applied fix:** Removed the `AsyncImage(url: nil)` phase-switching block entirely. Replaced with a direct `Theme.surface` placeholder view with a dumbbell overlay. Added a `TODO` comment pointing to ExerciseRepository wiring for the D-04 full rebuild.

---

_Fixed: 2026-04-27T20:58:41Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
