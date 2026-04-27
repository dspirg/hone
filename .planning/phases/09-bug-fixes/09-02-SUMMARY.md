---
phase: 09-bug-fixes
plan: 02
subsystem: progress-tracking, app-state
tags: [bug-fix, coredata, dead-code-removal, progress-ring]
dependency_graph:
  requires: []
  provides: [dynamic-weekly-planned, clean-app-state]
  affects: [ProgressViewModel, AppState]
tech_stack:
  added: []
  patterns: [WorkoutPlanRepository.fetchActivePlan pattern used in ProgressViewModel]
key_files:
  created: []
  modified:
    - WorkoutApp/Features/Progress/ProgressViewModel.swift
    - WorkoutApp/Core/AppState.swift
decisions:
  - Default weeklyPlanned to 3 (not 4) when no active plan exists — safer default for new users who haven't generated a plan yet
metrics:
  duration: 4 minutes
  completed: 2026-04-27T03:22:33Z
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Phase 09 Plan 02: Progress Ring Dynamic Planned Days + Dead Code Removal Summary

**One-liner:** Dynamic weeklyPlanned from WorkoutPlanRepository.fetchActivePlan replacing hardcoded max(weeklyPlanned, 4), plus dead isOnboarded property removed from AppState.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace hardcoded weeklyPlanned with dynamic value from active plan | d3cacff | WorkoutApp/Features/Progress/ProgressViewModel.swift |
| 2 | Remove dead AppState.isOnboarded property | 9141e0d | WorkoutApp/Core/AppState.swift |

## What Was Built

### Task 1 — FIX-04: Dynamic weeklyPlanned (D-09, D-10)

In `ProgressViewModel.loadProgress()`, added a `WorkoutPlanRepository.fetchActivePlan(userId:)` call immediately before `computeWeeklyRing(from:)` is invoked. The planned days count is now derived from `plan.weeklyDays.count` with a fallback of `3` (safer than the old `4` for new users with no plan).

Removed the hardcoded override `weeklyPlanned = max(weeklyPlanned, 4)` from `computeWeeklyRing(from:)` — this was the bug that unconditionally overrode whatever value was set. Also removed the `weeklyPlanned = 4` assignment from the guard's early-return path.

### Task 2 — FIX-05: Remove dead isOnboarded property (D-11)

Deleted from `AppState.swift`:
- Comment: `// isOnboarded mirrors onboardingCompleted for SUBS-03 compatibility...`
- Property: `var isOnboarded: Bool = false`
- Assignment inside `markOnboardingComplete()`: `self.isOnboarded = true`

`markOnboardingComplete()` now only sets `self.onboardingCompleted = true`. Zero remaining references to `isOnboarded` in project Swift files (grep confirms only references are in other worktrees' unrelated copies).

## Verification Results

- `grep -n "max(weeklyPlanned, 4)" ProgressViewModel.swift` → empty (PASSED)
- `grep -n "fetchActivePlan" ProgressViewModel.swift` → line 68 (PASSED)
- `grep -n "weeklyPlanned = plan" ProgressViewModel.swift` → line 69 (PASSED)
- `grep -n "isOnboarded" AppState.swift` → empty (PASSED)
- `xcodebuild build -scheme WorkoutApp` → BUILD SUCCEEDED (PASSED)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — both changes are complete implementations with no placeholders.

## Threat Flags

None — FIX-04 reads from local CoreData only; FIX-05 is dead code removal. No new trust boundaries introduced.

## Self-Check: PASSED

- WorkoutApp/Features/Progress/ProgressViewModel.swift — FOUND (modified)
- WorkoutApp/Core/AppState.swift — FOUND (modified)
- Commit d3cacff — FOUND
- Commit 9141e0d — FOUND
