# Phase 9: Bug Fixes - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Close 5 integration gaps identified in the v1.0 milestone audit so adaptive AI, progress tracking, and notifications behave correctly without workarounds. No new features — strictly fixing broken or incomplete wiring between existing components.

</domain>

<decisions>
## Implementation Decisions

### CoreData Write After Adaptation (FIX-01)
- **D-01:** After AdaptationService receives an adapted plan response, persist the updated weeklyDays to CoreData immediately — follow the existing `CoachViewModel.applyPlanUpdate()` pattern as the reference implementation
- **D-02:** TrainView must show the updated plan without requiring an app relaunch — the CoreData write triggers SwiftUI observation refresh

### ISO Date Format Fix (FIX-02)
- **D-03:** Fix on iOS side — MissedSessionDetector converts day-label strings ("Monday") to actual ISO dates ("2026-04-25") before sending to adapt-plan Edge Function
- **D-04:** Resolution strategy: use the most recent past occurrence of that day name (missed sessions are by definition in the past)
- **D-05:** Edge Function's ISO date regex validation stays as-is — it's the correct contract

### Notification Scheduling (FIX-03)
- **D-06:** Call `scheduleWorkoutReminders` after both plan generation AND plan adaptation — reminders always match the current plan
- **D-07:** Cancel + reschedule pattern: remove all pending workout-category notifications first, then schedule fresh. Clean slate every time.
- **D-08:** Call site lives inside services (AdaptationService and PlanGenerationService), not at view call sites — callers don't need to know about notifications

### Dynamic Weekly Ring (FIX-04)
- **D-09:** ProgressViewModel reads planned days count from `CDWorkoutPlan.weeklyDays.count` on the active plan — source of truth for the actual schedule
- **D-10:** ProgressViewModel fetches the plan directly via `WorkoutPlanRepository.fetchActivePlan()` — same self-contained pattern as TrainView and HomeView

### Dead Property Cleanup (FIX-05)
- **D-11:** Remove `AppState.isOnboarded` property and all references — dead state that's set but never read

### Claude's Discretion
- Exact implementation of day-label-to-ISO-date conversion (Calendar API usage)
- Whether to add a helper method on MissedSessionDetector or inline the conversion
- CoreData save error handling strategy (retry, log, or surface to user)
- Test coverage approach for each fix

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.0 Audit (Root Cause Documentation)
- `.planning/v1.0-MILESTONE-AUDIT.md` — All 5 gaps documented with severity, evidence, and fix directions

### Adaptation Layer
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` — FIX-01 target: adapted plan response decoded but not persisted
- `WorkoutApp/Features/Adaptation/Models/AdaptedPlan.swift` — AdaptedPlanResponse model with weeklyDays field
- `supabase/functions/adapt-plan/index.ts` — Edge Function with ISO date regex validation (FIX-02 contract)

### CoreData & Plan Repository
- `WorkoutApp/Features/Coach/CoachViewModel.swift` — `applyPlanUpdate()` reference pattern for CoreData plan write (FIX-01)
- `WorkoutApp/Features/Main/Tabs/TrainView.swift` — Must refresh after CoreData write (FIX-01 verification)

### Notifications
- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — Fully implemented `scheduleWorkoutReminders` with zero call sites (FIX-03)
- `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` — Plan generation service where notification call should be added

### Progress Tracking
- `WorkoutApp/Features/Progress/ProgressViewModel.swift` — `computeWeeklyRing()` with hardcoded weeklyPlanned = 4 (FIX-04)

### App State
- `WorkoutApp/Core/AppState.swift` — Contains dead `isOnboarded` property (FIX-05)

### Requirements
- `.planning/REQUIREMENTS.md` §Bug Fixes — FIX-01 through FIX-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **CoachViewModel.applyPlanUpdate()**: Reference pattern for writing adapted plan data to CoreData — FIX-01 should follow this exact approach
- **NotificationScheduler.scheduleWorkoutReminders(planDays:currentStreak:)**: Fully implemented, just needs call sites wired up (FIX-03)
- **WorkoutPlanRepository.fetchActivePlan()**: Already used by TrainView and HomeView for plan access — reuse in ProgressViewModel (FIX-04)
- **Calendar(identifier: .iso8601)**: Already used in AdaptationService for ISO week key computation — reuse for day-to-date conversion (FIX-02)

### Established Patterns
- **@Observable @MainActor**: All ViewModels and services follow this pattern
- **Fire-and-forget Task**: Post-session adaptation uses this pattern — notification scheduling fits naturally
- **WorkoutPlanRepository**: Centralized CoreData plan CRUD — all plan reads/writes go through this
- **Edge Function proxy**: All AI calls proxied through Supabase Edge Functions with Bearer token auth

### Integration Points
- **AdaptationService → WorkoutPlanRepository**: New write path needed after adaptation response (FIX-01)
- **AdaptationService → NotificationScheduler**: New call after successful adaptation (FIX-03)
- **PlanGenerationService → NotificationScheduler**: New call after plan generation (FIX-03)
- **ProgressViewModel → WorkoutPlanRepository**: New read for planned days count (FIX-04)
- **MissedSessionDetector → adapt-plan**: Date format conversion before Edge Function call (FIX-02)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 09-bug-fixes*
*Context gathered: 2026-04-26*
