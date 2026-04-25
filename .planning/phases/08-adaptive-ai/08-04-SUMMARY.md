---
phase: 08-adaptive-ai
plan: "04"
subsystem: ui
tags: [swiftui, adaptation, edge-functions, coredata, observable, scenePhase]

# Dependency graph
requires:
  - phase: 08-adaptive-ai plan 02
    provides: DifficultyRating enum, onDone(DifficultyRating) closure in SessionView
  - phase: 08-adaptive-ai plan 03
    provides: adapt-plan and regenerate-plan Supabase Edge Functions

provides:
  - AdaptationService: @Observable @MainActor iOS client calling adapt-plan and regenerate-plan with Bearer auth
  - MissedSessionDetector: pure struct detecting unfinished planned workout days in current ISO week
  - AdaptedPlan model: Codable response struct matching Edge Function JSON schema
  - MainTabView: scenePhase observer triggering weekly regen (Monday) and missed session check on every foreground
  - SessionView: post-session adaptation triggered after difficulty rating is saved (fire-and-forget)
  - TrainView: AdaptationSummaryBanner showing lastAdjustmentSummary (D-05 rationale)

affects: [plan_adaptations-table, user_plans-table, 08-05, 08-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AdaptationService follows PlanSSEClient/CoachSSEClient auth pattern: supabase.auth.session called inside service rather than token passed from AppState (SDK issue #634 workaround)"
    - "ISO week deduplication for Monday regen: Calendar(identifier: .iso8601) with yearForWeekOfYear gives correct YYYY-Www key"
    - "Fire-and-forget post-session adaptation: Task { await adaptationService.requestPostSessionAdaptation } after dismiss — does not block UI"
    - "AdaptationService injected at MainTabView level via .environment(adaptationService) so all descendant views (SessionView, TrainView) share one instance"

key-files:
  created:
    - WorkoutApp/Features/Adaptation/Models/AdaptedPlan.swift
    - WorkoutApp/Features/Adaptation/MissedSessionDetector.swift
    - WorkoutApp/Features/Adaptation/AdaptationService.swift
  modified:
    - WorkoutApp/Features/Main/MainTabView.swift
    - WorkoutApp/Features/Session/SessionView.swift
    - WorkoutApp/Features/Main/Tabs/TrainView.swift
    - WorkoutApp.xcodeproj/project.pbxproj

key-decisions:
  - "AdaptationService fetches access token internally via supabase.auth.session — not passed from AppState — consistent with PlanSSEClient and CoachSSEClient (SDK issue #634)"
  - "ISO week key uses Calendar(identifier: .iso8601) + yearForWeekOfYear to avoid edge-case where Dec-31 is ISO week 1 of next year"
  - "MissedSessionDetector is a pure static struct (no state, fully testable) rather than a method on AdaptationService"
  - "Post-session adaptation is fire-and-forget — dismiss() runs immediately, network call continues in background Task"

patterns-established:
  - "Foreground check pattern: scenePhase .onChange in MainTabView queries CoreData for plan day labels + sessions, delegates to service"
  - "AdaptationSummaryBanner: lightweight inline card with sparkles icon and accent border for AI rationale (D-05)"

requirements-completed: [ADPT-01, ADPT-02, ADPT-03]

# Metrics
duration: 23min
completed: 2026-04-25
---

# Phase 8 Plan 04: Adaptive AI — iOS Adaptation Client Summary

**AdaptationService wires post-session ratings (Plan 02) to adapt-plan/regenerate-plan Edge Functions (Plan 03): weekly Monday regen, missed session detection, and post-session AI adjustment all trigger from the iOS client via scenePhase and onDone hooks**

## Performance

- **Duration:** 23 min
- **Started:** 2026-04-25T14:17:34Z
- **Completed:** 2026-04-25T14:40:00Z
- **Tasks:** 2
- **Files modified:** 7 (3 created, 4 modified)

## Accomplishments

- AdaptationService is a single @Observable @MainActor service shared across the whole tab hierarchy via @Environment — SessionView and TrainView both access the same instance injected at MainTabView level
- Post-session flow is complete: rate session -> saveDifficultyRating -> requestPostSessionAdaptation(rating) -> adapt-plan Edge Function (fire-and-forget, doesn't block dismiss)
- Foreground check runs on every app foreground: queries CoreData for active plan day labels and completed sessions, then delegates to MissedSessionDetector (local) and weekly regen gated by ISO week key
- TrainView shows adjustment summary banner (D-05 rationale text) with sparkles icon and accent border whenever lastAdjustmentSummary is set

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AdaptedPlan model, MissedSessionDetector, AdaptationService** - `befb7aa` (feat)
2. **Task 2: Integrate AdaptationService into MainTabView, SessionView, TrainView** - `71002eb` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `WorkoutApp/Features/Adaptation/Models/AdaptedPlan.swift` - Codable response struct (AdaptedPlanResponse, AdaptedDay, AdaptedExercise, AdaptPlanRequest) matching Edge Function JSON schema with snake_case CodingKeys
- `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` - Pure static struct comparing activePlanDayLabels vs CDSessionLog.workoutDayLabel for current ISO week; only flags past planned days
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` - @Observable @MainActor service; requestPostSessionAdaptation, requestMissedSessionAdaptation, requestWeeklyRegeneration, checkOnForeground; ISO week dedup for Monday; Bearer token from supabase.auth.session
- `WorkoutApp/Features/Main/MainTabView.swift` - Added @State adaptationService, .environment injection, scenePhase .onChange calling runForegroundCheck (loads CoreData plan+sessions, calls checkOnForeground)
- `WorkoutApp/Features/Session/SessionView.swift` - Added @Environment(AdaptationService.self); onDone fires requestPostSessionAdaptation after saveDifficultyRating
- `WorkoutApp/Features/Main/Tabs/TrainView.swift` - Added @Environment(AdaptationService.self); AdaptationSummaryBanner shown when lastAdjustmentSummary is non-nil
- `WorkoutApp.xcodeproj/project.pbxproj` - Registered 3 new files (B009 namespace): PBXBuildFile, PBXFileReference, Adaptation group + Models subgroup, Sources build phase entries

## Decisions Made

- AdaptationService fetches the Bearer token internally via `supabase.auth.session` rather than accepting a token parameter from AppState. This is consistent with PlanSSEClient and CoachSSEClient — the SDK issue #634 pattern is now established across all three AI-calling services.
- Post-session adaptation fires in a Task{} after saveDifficultyRating and before dismiss(). dismiss() runs synchronously — the network call doesn't block the user. If the call fails, it logs to console (non-fatal).
- ISO week key uses `Calendar(identifier: .iso8601)` with `yearForWeekOfYear` — this handles the edge case where Dec 31 belongs to ISO week 1 of the following year, which `Calendar.current.component(.weekOfYear)` does not handle correctly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] AdaptationService fetches own auth token instead of accepting accessToken parameter**
- **Found during:** Task 1 (AdaptationService implementation)
- **Issue:** Plan template passed `accessToken: String` as a parameter to all public methods, requiring the caller (MainTabView/SessionView) to acquire the token. AppState has no `accessToken` property. The established pattern in this codebase is for each service to call `supabase.auth.session` internally.
- **Fix:** Made all public methods parameter-free for the token; `fetchAccessToken()` private helper calls `supabase.auth.session`. checkOnForeground and requestPostSessionAdaptation no longer require a token parameter.
- **Files modified:** WorkoutApp/Features/Adaptation/AdaptationService.swift
- **Verification:** BUILD SUCCEEDED; all callers (MainTabView, SessionView) work without needing to pass tokens
- **Committed in:** befb7aa (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical consistency with established auth pattern)
**Impact on plan:** Essential fix; aligns with PlanSSEClient/CoachSSEClient conventions. No scope creep.

## Issues Encountered

None.

## Threat Model Coverage

| Threat | Mitigation | Applied |
|--------|-----------|---------|
| T-08-11: AdaptationService auth | Bearer token from supabase.auth.session on every call; never stored | AdaptationService.fetchAccessToken() |
| T-08-12: Unbounded foreground checks | Weekly regen gated by ISO week key (lastWeeklyCheckKey); missed detection is pure local compute | checkOnForeground |

## Known Stubs

None — adaptation calls real Edge Functions. The lastAdjustmentSummary is nil by default (banner hidden) until a real adaptation response arrives.

## Next Phase Readiness

- Full iOS adaptation pipeline is wired: ratings (Plan 02) -> AdaptationService -> Edge Functions (Plan 03) -> plan update
- AdaptationService.lastAdjustmentSummary is the in-memory display surface — if CoreData persistence of the adapted plan content is needed, that is a future plan
- Plans 05 and 06 (smart notifications, engagement) can build on AdaptationService for re-engagement trigger detection

---
*Phase: 08-adaptive-ai*
*Completed: 2026-04-25*
