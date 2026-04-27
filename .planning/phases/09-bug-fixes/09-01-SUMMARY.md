---
phase: 09-bug-fixes
plan: 01
subsystem: adaptation
tags: [adaptation, notifications, coredata, ios, swift, missed-sessions]

# Dependency graph
requires:
  - phase: 08-adaptive-ai
    provides: AdaptationService, MissedSessionDetector, NotificationScheduler, WorkoutPlanRepository
provides:
  - FIX-01: AdaptationService persists adapted plans to CoreData after every adaptation response
  - FIX-02: MissedSessionDetector.isoDateString converts day-label strings to ISO dates before Edge Function calls
  - FIX-03: NotificationScheduler.scheduleWorkoutReminders called from both AdaptationService and PlanGenerationService
affects: [09-02-bug-fixes, train-view, plan-preview]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Day-label to ISO date conversion via allowlist dayOfWeekMap + ISO8601DateFormatter with full date"
    - "AdaptedPlanResponse->WorkoutPlan 1:1 field mapping via explicit struct init (not Codable decode)"
    - "Non-fatal best-effort persistence: catch + print pattern from CoachViewModel.applyPlanUpdate()"

key-files:
  created: []
  modified:
    - WorkoutApp/Features/Adaptation/MissedSessionDetector.swift
    - WorkoutAppTests/MissedSessionDetectorTests.swift
    - WorkoutApp/Features/Adaptation/AdaptationService.swift
    - WorkoutApp/Features/PlanPreview/PlanGenerationService.swift

key-decisions:
  - "persistAdaptedPlan preserves existing plan name/goalSummary before deactivating (plan name continuity)"
  - "currentStreak: 0 passed to scheduleWorkoutReminders in both services — streak not available, 0 produces standard notification copy"
  - "ISO date conversion uses calendar.timeZone on ISO8601DateFormatter for device timezone respect (not UTC)"
  - "daysBack <= 0 wraps to previous week — missed sessions are always in the past, never today"

patterns-established:
  - "ISO date conversion: MissedSessionDetector.isoDateString static method is the canonical converter for day-label to ISO date"
  - "Adaptation persistence: always deactivateAllPlans before save to maintain single-active-plan invariant"
  - "Notification scheduling: call from service layer (not view layer) per D-08"

requirements-completed: [FIX-01, FIX-02, FIX-03]

# Metrics
duration: 35min
completed: 2026-04-26
---

# Phase 9 Plan 01: Bug Fixes (FIX-01/02/03) Summary

**AdaptationService now persists adapted plans to CoreData, converts day-label strings to ISO dates before Edge Function calls, and schedules workout reminders after both plan generation and adaptation**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-26T21:15:00Z
- **Completed:** 2026-04-26T21:50:00Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- FIX-01: Adapted plans survive app relaunch — AdaptationService persists to CoreData via WorkoutPlanRepository after every adapt-plan Edge Function response
- FIX-02: Missed session detection now sends valid ISO date strings to adapt-plan Edge Function — MissedSessionDetector.isoDateString converts day labels using most-recent-past-occurrence logic
- FIX-03: Workout reminders are scheduled automatically after both plan generation (PlanGenerationService) and plan adaptation (AdaptationService) — never from view layer

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ISO date conversion to MissedSessionDetector and extend tests** - `4a90f56` (feat)
2. **Task 2: Wire AdaptationService to persist plans, convert dates, and schedule notifications** - `3a16b92` (feat)
3. **Task 3: Add notification scheduling call site in PlanGenerationService** - `5f2f679` (feat)

## Files Created/Modified

- `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` - Added `static func isoDateString(for:relativeTo:calendar:)` with dayOfWeekMap allowlist and most-recent-past-occurrence logic
- `WorkoutAppTests/MissedSessionDetectorTests.swift` - Added 3 new test cases: past day, week-wrap, nil for unknown label (8 total tests pass)
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` - Added `persistAdaptedPlan()`, `scheduleReminders()`, FIX-02 ISO date conversion in `checkOnForeground()`, wired both methods into both adaptation paths
- `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` - Added `scheduleWorkoutReminders` call after `state = .completed(plan)`

## Decisions Made

- Preserved existing active plan's `planName`/`goalSummary` before deactivating in `persistAdaptedPlan` — maintains plan name continuity for the user even after AI adaptation
- Passed `currentStreak: 0` to `scheduleWorkoutReminders` in both service call sites — streak not accessible in either service; 0 produces standard notification copy which is safe and correct
- Used `calendar.timeZone` on `ISO8601DateFormatter` to respect device timezone rather than UTC — important for users in non-UTC timezones where midnight rollover differs
- Wrap `daysBack <= 0` to `+= 7` ensures conversion always yields a past date — missed sessions by definition have already passed

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- iPhone 16 simulator not available in the Xcode installation; tests ran on iPhone 17 simulator instead. All 8 MissedSessionDetectorTests passed.

## Known Stubs

None — all functionality is fully wired. The `currentStreak: 0` in notification scheduling is intentional per plan spec (D-07/D-08), not a stub.

## Threat Flags

No new security-relevant surface introduced beyond what was documented in the plan's threat model (T-09-01 through T-09-04). `persistAdaptedPlan` routes through `WorkoutPlanRepository.save()` which enforces Int16 clamping guardrail (T-09-01).

## Next Phase Readiness

- Phase 09-02 (FIX-04/FIX-05) can proceed — no blockers from this plan
- AdaptationService is now fully wired for CoreData persistence and notification scheduling
- ISO date conversion is the canonical pattern for day-label-to-date in missed session flows

## Self-Check: PASSED

- SUMMARY.md exists at `.planning/phases/09-bug-fixes/09-01-SUMMARY.md`
- Commit `4a90f56` exists (Task 1: MissedSessionDetector ISO date conversion + tests)
- Commit `3a16b92` exists (Task 2: AdaptationService wiring)
- Commit `5f2f679` exists (Task 3: PlanGenerationService notification scheduling)
- Build succeeded on worktree (iPhone 17 simulator)
- All 8 MissedSessionDetectorTests passed including 3 new ISO date tests

---
*Phase: 09-bug-fixes*
*Completed: 2026-04-26*
