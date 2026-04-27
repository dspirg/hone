---
phase: 11-screen-redesigns
plan: 02
subsystem: ui
tags: [swiftui, coredata, homeview, homeviewmodel, observable, sessions, stats, prs]

# Dependency graph
requires:
  - phase: 11-screen-redesigns/11-01
    provides: StatPillView, WeekStreakBar, HomeExerciseRowView, AdaptationBannerView, AppState.selectedTab, AdaptationService.lastAdjustmentDate/lastAdjustmentSummary

provides:
  - HomeViewModel: @Observable @MainActor ViewModel with parallel plan+stats loading, PR computation, session launch state
  - HomeView: Full card-stack rebuild matching Sketch 001-A with all 5 sections

affects: [11-03, 11-04, session-launch, home-tab]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HomeViewModel uses async let for parallel plan+stats fetch (mirrors ProgressViewModel pattern)"
    - "activePlanId field captures CDWorkoutPlan.supabaseId separately from decoded WorkoutPlan (mirrors TrainView.activePlanSupabaseId)"
    - "PR detection via sessionExerciseMax dictionary + chronological session ordering (same pattern as ProgressViewModel.detectPRs)"
    - "Post-session refresh via onChange(of: viewModel.showSession) { _, isShowing in if !isShowing { reload } }"

key-files:
  created: []
  modified:
    - WorkoutApp/Features/Main/HomeViewModel.swift
    - WorkoutApp/Features/Main/Tabs/HomeView.swift

key-decisions:
  - "activePlanId stored separately in HomeViewModel as supabaseId from CDWorkoutPlan (WorkoutPlan struct has no planId field)"
  - "PR count uses totalSets from CDSessionLog.totalSets aggregate (denormalized) for sets stat, and CDSetLog query for PR detection"
  - "User name displayed from currentUser.email prefix (User struct has email but no displayName in Supabase auth)"
  - "Greeting section replaces .navigationTitle per UI-SPEC"

patterns-established:
  - "HomeViewModel pattern: @Observable @MainActor, load(appState:adaptationService:context:) async, async let parallel fetch"
  - "activePlanId: separate supabaseId capture mirrors TrainView approach for SessionView launch"

requirements-completed: [UI-04]

# Metrics
duration: 25min
completed: 2026-04-27
---

# Phase 11 Plan 02: Home Screen Rebuild Summary

**HomeView rebuilt as card-stack layout (Sketch 001-A) with greeting, adaptation banner, workout card, streak bar, and quick stats; HomeViewModel drives all data with real PR computation from CDSetLog history**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-27T19:47:48Z
- **Completed:** 2026-04-27T20:12:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- HomeViewModel created with @Observable @MainActor pattern, parallel async let plan+stats loading, time-of-day greeting, 24h adaptation banner check, and real PR count computed from CDSetLog history per D-05
- HomeView fully rebuilt with 5-section card-stack layout: greeting, conditional adaptation banner, today's workout card with exercise rows and Start Workout CTA, weekly streak bar, quick stats row
- Session launch via fullScreenCover (D-13, D-16), post-session refresh via onChange (D-14), subscription gate preserved via BlurredPlanGateView
- Pull-to-refresh, empty state (figure.run), and error state (wifi.slash) implemented
- Build verified: xcodebuild BUILD SUCCEEDED

## Task Commits

Each task was committed atomically:

1. **Task 1: Create HomeViewModel with parallel data loading** - `bc1931d` (feat)
2. **Task 2: Full rebuild of HomeView matching Sketch 001-A card-stack layout** - `6c4ed85` (feat)

**Plan metadata:** *(docs commit follows)*

## Files Created/Modified

- `WorkoutApp/Features/Main/HomeViewModel.swift` - @Observable @MainActor ViewModel: parallel plan+stats load, PR computation, adaptation 24h gate, showSession state, activePlanId for SessionView launch
- `WorkoutApp/Features/Main/Tabs/HomeView.swift` - Full rebuild: greeting, AdaptationBannerView, workout card + HomeExerciseRowView rows, WeekStreakBar, StatPillView quick stats, fullScreenCover session launch

## Decisions Made

- `activePlanId` stored as separate field in HomeViewModel (String, the supabaseId from CDWorkoutPlan) because `WorkoutPlan` struct has no `planId` field; mirrors the `activePlanSupabaseId` pattern in TrainView
- User name displayed from `currentUser?.email?.components(separatedBy: "@").first` since Supabase `User` struct exposes `email` but not `displayName`; plan referenced `currentUser?.displayName` which doesn't exist on the auth User type
- Total sets stat uses CDSessionLog.totalSets aggregate (denormalized field written by SessionRepository) rather than fetching all CDSetLog records — more efficient, avoids the extra fetch
- Greeting replaces `.navigationTitle("Home")` per UI-SPEC

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] activePlan?.planId does not exist — added activePlanId field**
- **Found during:** Task 1 (HomeViewModel creation)
- **Issue:** Plan's action code used `viewModel.activePlan?.planId` to pass to SessionView, but WorkoutPlan struct has no `planId` property. This would fail to compile.
- **Fix:** Added `activePlanId: String` property to HomeViewModel, populated from CDWorkoutPlan.supabaseId during loadPlan(), mirrors TrainView's activePlanSupabaseId pattern. HomeView uses `viewModel.activePlanId` when launching SessionView.
- **Files modified:** WorkoutApp/Features/Main/HomeViewModel.swift, WorkoutApp/Features/Main/Tabs/HomeView.swift
- **Verification:** Build succeeded
- **Committed in:** bc1931d (Task 1), 6c4ed85 (Task 2)

**2. [Rule 1 - Bug] currentUser?.displayName does not exist — use email prefix**
- **Found during:** Task 2 (HomeView creation)
- **Issue:** Plan's action code used `appState.currentUser?.displayName` but Supabase `User` type exposes `email` not `displayName`.
- **Fix:** Use `currentUser?.email?.components(separatedBy: "@").first` as the displayed name; falls back to "Hey there" gracefully.
- **Files modified:** WorkoutApp/Features/Main/Tabs/HomeView.swift
- **Verification:** Build succeeded
- **Committed in:** 6c4ed85 (Task 2)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs — plan referenced properties that don't exist on the actual types)
**Impact on plan:** Both fixes necessary for correctness. Design intent fully preserved.

## Issues Encountered

None beyond the two auto-fixed type mismatches.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- HomeView and HomeViewModel are complete and building cleanly
- SessionView launch from Home tab works via fullScreenCover with workoutDay + planId
- Plan 03 (TrainView/ProgressView redesigns) can proceed — no blockers from this plan
- No stubs: all stat values (sessions, sets, PRs) are computed from real CoreData data

## Self-Check

- [x] WorkoutApp/Features/Main/HomeViewModel.swift — FOUND
- [x] WorkoutApp/Features/Main/Tabs/HomeView.swift — FOUND
- [x] Commit bc1931d — verified in git log
- [x] Commit 6c4ed85 — verified in git log
- [x] Build succeeded: xcodebuild BUILD SUCCEEDED

## Self-Check: PASSED

---
*Phase: 11-screen-redesigns*
*Completed: 2026-04-27*
