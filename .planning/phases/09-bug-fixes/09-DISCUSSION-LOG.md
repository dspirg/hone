# Phase 9: Bug Fixes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 09-bug-fixes
**Areas discussed:** Notification scheduling triggers, Date format fix direction, Weekly ring data source

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| CoreData write strategy | FIX-01/02: How to persist adapted plan — overwrite or new record? | |
| Notification scheduling triggers | FIX-03: Where and when to call scheduleWorkoutReminders | ✓ |
| Date format fix direction | FIX-02: Fix on iOS side or Edge Function side | ✓ |
| Weekly ring data source | FIX-04: Where to get planned days count | ✓ |

---

## Notification Scheduling Triggers

### Q1: When should workout reminder notifications be rescheduled?

| Option | Description | Selected |
|--------|-------------|----------|
| Both generation + adaptation | Call after every plan generation AND every adaptation | ✓ |
| Plan generation only | Only reschedule when a brand-new plan is generated | |
| You decide | Claude picks based on codebase patterns | |

**User's choice:** Both generation + adaptation

### Q2: Cancel existing notifications or add alongside?

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel + reschedule | Remove all pending workout-category notifications, then schedule fresh | ✓ |
| Incremental update | Only cancel notifications for days that changed | |
| You decide | Claude picks based on existing patterns | |

**User's choice:** Cancel + reschedule

### Q3: Where should the call site live?

| Option | Description | Selected |
|--------|-------------|----------|
| Inside services | AdaptationService and PlanGenerationService call internally | ✓ |
| At call sites | Views explicitly call after adaptation/generation | |
| You decide | Claude picks based on separation of concerns | |

**User's choice:** Inside services

---

## Date Format Fix Direction

### Q1: Fix on iOS or Edge Function side?

| Option | Description | Selected |
|--------|-------------|----------|
| Fix on iOS side | MissedSessionDetector converts day labels to ISO dates | ✓ |
| Fix on Edge Function side | Modify adapt-plan to accept day labels | |
| You decide | Claude picks based on data richness | |

**User's choice:** Fix on iOS side

### Q2: How to resolve day labels to ISO dates?

| Option | Description | Selected |
|--------|-------------|----------|
| Most recent past date | "Monday" -> last Monday's date | ✓ |
| This week's date | "Monday" -> this ISO week's Monday | |
| You decide | Claude picks semantically correct approach | |

**User's choice:** Most recent past date

---

## Weekly Ring Data Source

### Q1: Where should ProgressViewModel get planned days count?

| Option | Description | Selected |
|--------|-------------|----------|
| CDWorkoutPlan.weeklyDays count | Read from active plan's weeklyDays array length | ✓ |
| UserProfile.daysPerWeek | Read from onboarding profile | |
| You decide | Claude picks based on data accuracy | |

**User's choice:** CDWorkoutPlan.weeklyDays count

### Q2: Fetch strategy for ProgressViewModel?

| Option | Description | Selected |
|--------|-------------|----------|
| Fetch directly | Use WorkoutPlanRepository.fetchActivePlan() internally | ✓ |
| Pass as parameter | Caller passes plannedDaysCount | |
| You decide | Claude picks based on existing patterns | |

**User's choice:** Fetch directly

---

## Claude's Discretion

- Day-label-to-ISO-date conversion implementation details
- Helper method placement for date conversion
- CoreData save error handling strategy
- Test coverage approach for each fix

## Deferred Ideas

None — discussion stayed within phase scope.
