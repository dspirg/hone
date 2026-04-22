---
phase: "04"
plan: "04"
subsystem: session-completion-and-train-entry-point
tags: [session, summary, trainview, navigation, coredata]
dependency_graph:
  requires:
    - 04-01  # SessionRepository, CDSessionLog
    - 04-02  # SessionViewModel with isSessionComplete, completedSets, sessionDuration
    - 04-03  # SessionView structure to wire SessionSummaryView into
  provides:
    - SessionSummaryView component (session completion screen)
    - TrainView with active plan day cards and Start Workout entry points
  affects:
    - WorkoutApp/Features/Session/SessionView.swift
tech_stack:
  added: []
  patterns:
    - SessionSummaryView replaces card area in SessionView when isSessionComplete == true
    - StatCell reusable component for value+label pairs in summary
    - TrainView fetches CDWorkoutPlan.supabaseId via NSPredicate for planId parameter
    - WorkoutDayCard NavigationLink pattern: SessionView(workoutDay:planId:) per plan day
key_files:
  created:
    - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
  modified:
    - WorkoutApp/Features/Session/SessionView.swift
    - WorkoutApp/Features/Main/Tabs/TrainView.swift
decisions:
  - SessionSummaryView uses onDone closure (dismiss()) rather than NavigationStack pop — avoids coupling summary to nav stack depth
  - StatCell defined in SessionSummaryView.swift (same file) — simpler than a shared component file for a single use case
  - TrainView fetches supabaseId in same loadActivePlan() task as WorkoutPlan decode — single async operation, consistent with HomeView pattern
  - WorkoutDayCard extracted as private struct — keeps TrainView body readable
  - CDWorkoutPlan NSPredicate fetch uses same predicate as WorkoutPlanRepository.fetchActivePlan for consistency
metrics:
  duration: "16m"
  completed_date: "2026-04-22"
  tasks_completed: 2
  files_changed: 3
---

# Phase 04 Plan 04: Session Summary + TrainView Entry Point Summary

Session completion screen and TrainView plan-first layout — closes the workout execution loop and surfaces the active plan with per-day Start Workout entry points.

## What Was Built

**SessionSummaryView** (`WorkoutApp/Features/Session/Components/SessionSummaryView.swift`): Completion screen shown after the last set of the last exercise is confirmed. Displays:
- Checkmark icon (72pt, AccentColor) with "Session complete" accessibility label
- "Great work." heading (.title semibold) + "[Day label] complete" subheading (.subheadline .secondary)
- Stat row: Exercises / Sets / Reps (HStack spacing 32, StatCell components)
- Duration stat: formatted as "42m 07s" with zero-padded seconds
- Done button (.borderedProminent, full width, 52pt height) calling `onDone` closure
- No difficulty rating (Phase 8 deferred per CONTEXT.md)

**SessionView update** (`WorkoutApp/Features/Session/SessionView.swift`): Added `isSessionComplete` branch at the top of `sessionContent(vm:)`. When `vm.isSessionComplete == true`, the entire card/button/overlay ZStack is replaced by `SessionSummaryView` with computed totals from `vm.completedSets`.

**TrainView replacement** (`WorkoutApp/Features/Main/Tabs/TrainView.swift`): Replaced the Phase 2 `ExerciseLibraryView()` host with a plan-first layout:
- Loads active plan via `WorkoutPlanRepository.fetchActivePlan` in `.task` (mirrors HomeView pattern)
- Fetches `CDWorkoutPlan.supabaseId` via NSPredicate for the `planId` parameter required by `SessionView`
- `WorkoutDayCard` (private struct): shows dayLabel, sessionName, exercise count, and "Start Workout" NavigationLink → `SessionView(workoutDay:planId:)`
- ExerciseLibraryView preserved as "Browse Exercises" NavigationLink in both plan and empty states
- Empty state: "No workout planned for today." + "Your AI plan appears here." per UI-SPEC copy

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | ff56629 | feat(04-04): build SessionSummaryView and wire into SessionView |
| Task 2 | 4d2c641 | feat(04-04): replace TrainView with active plan day cards and Start Workout entry points |

## Deviations from Plan

None — plan executed exactly as written.

The two "difficulty" matches in the grep check are comment lines documenting the intentional Phase 8 deferral — no difficulty rating UI was added.

Pre-existing build errors in `PaywallView.swift` and `BlurredPlanGateView.swift` (from Plan 07-01 RevenueCat integration) were present before this plan and are out of scope. All new code in this plan compiles without errors.

## Known Stubs

None. SessionSummaryView computes real totals from `SessionViewModel.completedSets` at call time. TrainView wires to live `WorkoutPlanRepository.fetchActivePlan`. No hardcoded placeholder values flow to the UI.

## Threat Flags

No new security-relevant surface introduced. TrainView displays plan data belonging to the authenticated user only (fetched by `userId == currentUser.id`, same trust boundary established in Phase 1). SessionSummaryView totals are computed from in-memory `completedSets` — no user-editable path to falsify them.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| WorkoutApp/Features/Session/Components/SessionSummaryView.swift | FOUND |
| WorkoutApp/Features/Session/SessionView.swift | FOUND |
| WorkoutApp/Features/Main/Tabs/TrainView.swift | FOUND |
| Commit ff56629 (Task 1) | FOUND |
| Commit 4d2c641 (Task 2) | FOUND |
