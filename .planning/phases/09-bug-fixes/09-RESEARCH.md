# Phase 9: Bug Fixes - Research

**Researched:** 2026-04-26
**Domain:** Swift/SwiftUI iOS — CoreData wiring, Calendar API, UserNotifications, dead code removal
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** After AdaptationService receives an adapted plan response, persist the updated weeklyDays to CoreData immediately — follow the existing `CoachViewModel.applyPlanUpdate()` pattern as the reference implementation
- **D-02:** TrainView must show the updated plan without requiring an app relaunch — the CoreData write triggers SwiftUI observation refresh
- **D-03:** Fix on iOS side — MissedSessionDetector converts day-label strings ("Monday") to actual ISO dates ("2026-04-25") before sending to adapt-plan Edge Function
- **D-04:** Resolution strategy: use the most recent past occurrence of that day name (missed sessions are by definition in the past)
- **D-05:** Edge Function's ISO date regex validation stays as-is — it's the correct contract
- **D-06:** Call `scheduleWorkoutReminders` after both plan generation AND plan adaptation — reminders always match the current plan
- **D-07:** Cancel + reschedule pattern: remove all pending workout-category notifications first, then schedule fresh. Clean slate every time.
- **D-08:** Call site lives inside services (AdaptationService and PlanGenerationService), not at view call sites — callers don't need to know about notifications
- **D-09:** ProgressViewModel reads planned days count from `CDWorkoutPlan.weeklyDays.count` on the active plan — source of truth for the actual schedule
- **D-10:** ProgressViewModel fetches the plan directly via `WorkoutPlanRepository.fetchActivePlan()` — same self-contained pattern as TrainView and HomeView
- **D-11:** Remove `AppState.isOnboarded` property and all references — dead state that's set but never read

### Claude's Discretion
- Exact implementation of day-label-to-ISO-date conversion (Calendar API usage)
- Whether to add a helper method on MissedSessionDetector or inline the conversion
- CoreData save error handling strategy (retry, log, or surface to user)
- Test coverage approach for each fix

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FIX-01 | Adapted workout plan written to CoreData immediately after AI adaptation, TrainView shows updated plan without app relaunch | `applyPlanUpdate()` in CoachViewModel is the reference pattern; `WorkoutPlanRepository.save()` + `deactivateAllPlans()` are both available; `AdaptedPlanResponse.weeklyDays` already decoded |
| FIX-02 | Missed session detector sends ISO date strings (YYYY-MM-DD) to adapt-plan Edge Function, not day-label strings | `MissedSessionDetector.detectMissedSessions()` returns `[String]` day labels; `ISO_DATE_RE` in Edge Function confirmed; `Calendar(identifier: .iso8601)` already used in AdaptationService |
| FIX-03 | Workout reminder notifications scheduled after plan generation and plan adaptation | `NotificationScheduler.scheduleWorkoutReminders(planDays:currentStreak:)` fully implemented; zero call sites exist; `cancelAllWorkoutReminders()` is available |
| FIX-04 | Weekly progress ring shows user's actual planned days per week, not hardcoded value of 4 | `computeWeeklyRing()` hardcodes `weeklyPlanned = 4`; `WorkoutPlanRepository.fetchActivePlan()` already used elsewhere; `WorkoutPlan.weeklyDays.count` is the correct source |
| FIX-05 | Dead `AppState.isOnboarded` property removed | Property confirmed dead: set in `markOnboardingComplete()` but never read anywhere outside AppState.swift |
</phase_requirements>

---

## Summary

Phase 9 closes five integration gaps identified in the v1.0 milestone audit. All five fixes are targeted wiring tasks — the underlying implementations (CoreData repository, notification scheduler, Calendar helpers) are complete and tested. No new abstractions are needed: the planner can write tasks that connect existing components using patterns already established in the codebase.

The most impactful fix is FIX-01/FIX-03 together: AdaptationService needs one new method that (a) persists the adapted plan to CoreData and (b) calls NotificationScheduler to reschedule reminders. This pattern already exists verbatim in `CoachViewModel.applyPlanUpdate()`. FIX-02 (ISO date conversion in MissedSessionDetector) requires a Calendar computation that AdaptationService already performs for ISO week keys. FIX-04 (ProgressViewModel dynamic ring) is a one-line source-of-truth change. FIX-05 (dead property removal) is a three-line deletion.

No external dependencies, no new packages, no Edge Function changes. Every fix is self-contained inside the iOS codebase.

**Primary recommendation:** Group fixes into two implementation tasks — (1) adaptation service wiring (FIX-01 + FIX-02 + FIX-03) and (2) progress ring + dead code (FIX-04 + FIX-05). Each task has a corresponding test update.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CoreData plan persistence after adaptation | iOS Service (AdaptationService) | CoreData (WorkoutPlanRepository) | AdaptationService owns the adaptation response; repository owns all plan writes |
| ISO date conversion for missed sessions | iOS Service (MissedSessionDetector) | — | Pure local computation; Edge Function contract is fixed |
| Notification rescheduling | iOS Service (AdaptationService + PlanGenerationService) | NotificationScheduler | Services own AI lifecycle events; scheduler is a pure scheduling utility |
| Weekly ring planned-days count | iOS ViewModel (ProgressViewModel) | CoreData (WorkoutPlanRepository) | ViewModel owns all progress metrics; repository is the plan data source |
| Dead state removal | iOS Core (AppState) | — | Property is defined and set only within AppState |

---

## Standard Stack

All work uses the existing project stack — no new dependencies required.

### Core (already installed)
| Library | Version | Purpose | Relevance to Phase 9 |
|---------|---------|---------|----------------------|
| Swift 6 + SwiftUI | iOS 17+ | App language/UI | All fixes are Swift source edits |
| CoreData | iOS 16+ | Local plan persistence | FIX-01 write path, FIX-04 read path |
| UserNotifications | iOS 10+ | Local notification scheduling | FIX-03 call sites |
| Foundation.Calendar | Swift stdlib | Date arithmetic | FIX-02 day-label-to-ISO conversion |

### No New Packages
All required functionality is already present in the codebase. Zero `Package.swift` changes.

---

## Architecture Patterns

### System Architecture: Adaptation Data Flow (FIX-01, FIX-02, FIX-03)

```
App Foreground
     │
     ▼
AdaptationService.checkOnForeground()
     │
     ├─► MissedSessionDetector.detectMissedSessions()   [returns [String] day labels]
     │        │
     │        ▼  [FIX-02: convert labels → ISO dates here]
     │   requestMissedSessionAdaptation(missedDays: [ISO dates])
     │        │
     │        ▼
     │   adapt-plan Edge Function  [validates with /^\d{4}-\d{2}-\d{2}$/]
     │        │
     │        ▼
     │   AdaptedPlanResponse (weeklyDays decoded)
     │        │
     │   [FIX-01: persist weeklyDays to CoreData]  ◄── NEW
     │   [FIX-03: reschedule notifications]        ◄── NEW
     │
     └─► PlanGenerationService (on .completed event)
              │
         [FIX-03: call scheduleWorkoutReminders]   ◄── NEW
```

### System Architecture: Progress Ring (FIX-04)

```
ProgressView.onAppear
     │
     ▼
ProgressViewModel.loadProgress()
     │
     ├─► fetchCompletedSessions()
     │
     └─► computeWeeklyRing(from:)
              │
         weeklyCompleted = count of this-week sessions
         weeklyPlanned = [FIX-04: WorkoutPlanRepository.fetchActivePlan().weeklyDays.count]
              │             instead of hardcoded 4
              ▼
         ProgressView renders ring
```

### Pattern 1: CoreData Plan Write After Adaptation (FIX-01)

**What:** After receiving `AdaptedPlanResponse`, convert `weeklyDays` to a `WorkoutPlan` and persist via `WorkoutPlanRepository`.

**Reference implementation** — `CoachViewModel.applyPlanUpdate()` (lines 411–427):
```swift
// Source: WorkoutApp/Features/Coach/CoachViewModel.swift
private func applyPlanUpdate(planJSON: String, appState: AppState) async {
    guard let jsonData = planJSON.data(using: .utf8) else { return }
    do {
        let updatedPlan = try JSONDecoder().decode(WorkoutPlan.self, from: jsonData)
        let userId = try await supabase.auth.session.user.id.uuidString
        let repo = WorkoutPlanRepository(context: viewContext)
        try repo.deactivateAllPlans(userId: userId)
        try repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)
    } catch {
        print("CoachViewModel: Failed to apply plan update: \(error)")
    }
}
```

**For AdaptationService:** Same pattern, but input is `AdaptedPlanResponse` not JSON string. Map `AdaptedDay` → `WorkoutDay` → `WorkoutPlan` before saving.

**CRITICAL:** `AdaptedDay` maps to `WorkoutDay` but has `exercises: [AdaptedExercise]` while `WorkoutDay` has `exercises: [PlannedExercise]`. Must construct a `WorkoutPlan` from the adapted response, not decode from JSON. The `AdaptedPlanResponse` is not itself a `WorkoutPlan` — it must be assembled.

### Pattern 2: Day-Label-to-ISO-Date Conversion (FIX-02)

**What:** Given a day label ("Monday"), find the most recent past date with that weekday. Return as "YYYY-MM-DD".

**Calendar API approach** (Claude's discretion area — recommended implementation):

```swift
// Source: [VERIFIED: codebase — AdaptationService already uses Calendar(identifier: .iso8601)]
// Called from MissedSessionDetector or AdaptationService before requestMissedSessionAdaptation

static func isoDateString(
    for dayLabel: String,
    relativeTo today: Date = Date(),
    calendar: Calendar = Calendar.current
) -> String? {
    let dayOfWeekMap: [String: Int] = [
        "Sunday": 1, "Monday": 2, "Tuesday": 3,
        "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7
    ]
    guard let targetWeekday = dayOfWeekMap[dayLabel] else { return nil }

    let todayWeekday = calendar.component(.weekday, from: today)
    var daysBack = todayWeekday - targetWeekday
    if daysBack <= 0 { daysBack += 7 }  // wrap to previous week

    guard let targetDate = calendar.date(
        byAdding: .day, value: -daysBack, to: today
    ) else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.string(from: targetDate)
}
```

**Why `daysBack <= 0 { daysBack += 7 }`:** Missed sessions are always in the past. If today is Wednesday (4) and the plan day is Friday (6), `4 - 6 = -2`, which wraps to 5 days back (last Friday). This satisfies D-04 ("most recent past occurrence").

**Edge case — today equals the planned day:** If `daysBack == 0` after the map (e.g., today IS Monday and Monday is the planned day), we want *last* Monday, so `daysBack += 7` gives 7. This is correct: MissedSessionDetector's existing guard `plannedWeekday < todayWeekday` already excludes today's planned day from the missed list, so this edge case should not occur in practice.

**Where to add this:** D-03 says "MissedSessionDetector converts" — add a static helper method on `MissedSessionDetector`. This keeps the conversion co-located with the detection logic and makes it testable in the existing `MissedSessionDetectorTests`.

**Integration point in AdaptationService:** `checkOnForeground()` already calls `MissedSessionDetector.detectMissedSessions()` and passes the result to `requestMissedSessionAdaptation()`. The conversion should happen between these two calls:

```swift
// In AdaptationService.checkOnForeground() — existing code at lines 139–147
let missedDays = MissedSessionDetector.detectMissedSessions(...)
// [FIX-02]: Convert day labels to ISO dates before sending
let missedIsoDates = missedDays.compactMap {
    MissedSessionDetector.isoDateString(for: $0, relativeTo: today, calendar: calendar)
}
if !missedIsoDates.isEmpty {
    await requestMissedSessionAdaptation(missedDays: missedIsoDates)
}
```

### Pattern 3: Notification Scheduling Call Sites (FIX-03)

**What:** `scheduleWorkoutReminders(planDays:currentStreak:)` is complete with zero call sites. Add calls after plan generation and plan adaptation.

**Signature:**
```swift
// Source: WorkoutApp/Core/Notifications/NotificationScheduler.swift line 93
func scheduleWorkoutReminders(
    planDays: [(weekday: Int, workoutType: String)],
    currentStreak: Int
) async
```

**Input mapping** — from `WorkoutPlan.weeklyDays`:
- `weekday`: Map `WorkoutDay.dayLabel` ("Monday") to Calendar weekday int (1–7) using the same `dayOfWeekMap` already in `MissedSessionDetector`
- `workoutType`: Use `WorkoutDay.sessionName`
- `currentStreak`: ProgressViewModel has this value; for the service call sites, pass 0 as a safe default (streak-aware copy is a nice-to-have, not a correctness concern)

**Call site in PlanGenerationService** — add after `state = .completed(plan)` (currently line 120):
```swift
// After state = .completed(plan)
let planDays = plan.weeklyDays.compactMap { day -> (weekday: Int, workoutType: String)? in
    guard let weekday = dayOfWeekMap[day.dayLabel] else { return nil }
    return (weekday: weekday, workoutType: day.sessionName)
}
await NotificationScheduler.shared.scheduleWorkoutReminders(planDays: planDays, currentStreak: 0)
```

**Call site in AdaptationService** — add in the new `persistAdaptedPlan()` method (FIX-01) or in `requestPostSessionAdaptation()` / `requestMissedSessionAdaptation()` after successful response:

D-08 says call sites live inside services. Both `requestPostSessionAdaptation` and `requestMissedSessionAdaptation` receive `AdaptedPlanResponse` (which contains `weeklyDays`) — schedule reminders from the `weeklyDays` in the response.

**D-07 cancel+reschedule:** `scheduleWorkoutReminders` already calls `cancelAllWorkoutReminders()` internally at line 99 before scheduling. No additional cancel call is needed at the call site.

### Pattern 4: Dynamic Weekly Ring (FIX-04)

**What:** Replace hardcoded `weeklyPlanned = max(weeklyPlanned, 4)` with a live count from CoreData.

**Current code in ProgressViewModel.computeWeeklyRing()** (lines 163–179):
```swift
// BUG: This line always resolves to at least 4, ignoring the user's actual plan
weeklyPlanned = max(weeklyPlanned, 4)
```

**Fix:**
```swift
// In ProgressViewModel.loadProgress() — call fetchActivePlan before computeWeeklyRing
// Then pass the count into computeWeeklyRing or set weeklyPlanned separately

func loadProgress() async {
    // ... existing fetch ...
    computeStreak(from: fetchedSessions)
    // FIX-04: fetch planned count from active plan
    if let userId = cachedUserId {
        let repo = WorkoutPlanRepository(context: viewContext)
        let plan = try? repo.fetchActivePlan(userId: userId)
        weeklyPlanned = plan?.weeklyDays.count ?? 3  // 3 is a safer default than 4
    }
    computeWeeklyRing(from: fetchedSessions)
    // ...
}
```

**D-10 mandates** fetching via `WorkoutPlanRepository.fetchActivePlan()` — same pattern as TrainView and HomeView. The `weeklyPlanned` must be set BEFORE `computeWeeklyRing` runs, or `computeWeeklyRing` must accept it as a parameter. Setting it directly in `loadProgress()` before the ring computation is the cleanest approach.

**Note on the existing `max(weeklyPlanned, 4)` line:** After FIX-04, remove this guard entirely — it was protecting against the case where the plan wasn't fetched, which will no longer apply.

### Pattern 5: Dead Property Removal (FIX-05)

**What:** Remove `AppState.isOnboarded` and its single assignment.

**All occurrences** (confirmed via codebase grep — only 3 lines, all in AppState.swift):
- Line 33: Comment `// isOnboarded mirrors onboardingCompleted for SUBS-03 compatibility.`
- Line 35: `var isOnboarded: Bool = false`
- Line 115: `self.isOnboarded = true` (inside `markOnboardingComplete()`)

**No other file references `isOnboarded`** — grep across all `.swift` files confirmed. Safe to delete all three lines.

After removal, `markOnboardingComplete()` remains and just sets `self.onboardingCompleted = true`.

### Anti-Patterns to Avoid

- **Calling supabase.auth.session inside MissedSessionDetector:** The detector is a pure struct. The ISO date conversion should be purely Calendar-based, no async auth.
- **Passing AppState into AdaptationService for notification scheduling:** D-08 says services handle this. `NotificationScheduler.shared` is the singleton — use it directly without needing AppState.
- **Adding a weeklyPlanned parameter to computeWeeklyRing:** The current signature is `computeWeeklyRing(from: [CDSessionLog])`. Avoid changing the signature — set `weeklyPlanned` before calling the method instead, or fetch inside it.
- **Changing the Edge Function** (FIX-02): D-05 is explicit — the ISO regex validation is correct. Only the iOS client changes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Day-name-to-weekday mapping | Custom string parser | Existing `dayOfWeekMap` in MissedSessionDetector (lines 46–55) | Already correct, tested, covers all 7 days |
| ISO date string formatting | Manual string interpolation | `ISO8601DateFormatter` with `.withFullDate` | Handles timezone, leap years, month padding correctly |
| Notification cancel/reschedule | Custom identifier tracking | `cancelAllWorkoutReminders()` (already implemented) | Filters by "workout-reminder-" prefix, safe for concurrent notification types |
| CoreData plan write | Custom CDWorkoutPlan mutation | `WorkoutPlanRepository.save()` + `deactivateAllPlans()` | Handles ordered relationships, rawJSON backup, Int16 clamping |

---

## Common Pitfalls

### Pitfall 1: AdaptedDay is Not WorkoutDay
**What goes wrong:** Attempting to cast or decode `AdaptedPlanResponse.weeklyDays` directly into a `WorkoutPlan` will fail — `AdaptedDay` and `WorkoutDay` are different types with different field names.
**Why it happens:** `AdaptedDay.exercises` is `[AdaptedExercise]` while `WorkoutDay.exercises` is `[PlannedExercise]`. Different structs, different CodingKeys.
**How to avoid:** Construct a `WorkoutPlan` by mapping: `AdaptedDay` → `WorkoutDay`, `AdaptedExercise` → `PlannedExercise`. Both have equivalent fields (`exerciseName`, `sets`, `reps`, `restSeconds`, `rationale`).
**Warning signs:** Compile error "cannot convert value of type 'AdaptedDay' to expected argument type 'WorkoutDay'".

### Pitfall 2: weeklyPlanned Read Before Plan Fetch
**What goes wrong:** `computeWeeklyRing` runs before `fetchActivePlan`, so `weeklyPlanned` is still 0 or the old value.
**Why it happens:** `loadProgress()` calls `computeWeeklyRing` synchronously; plan fetch is async.
**How to avoid:** Set `weeklyPlanned` from the plan fetch result before calling `computeWeeklyRing`. Use sequential `await`, not concurrent.
**Warning signs:** Ring still shows 4 (or 0) regardless of user's plan.

### Pitfall 3: Notification Scheduling Silently Skipped
**What goes wrong:** `scheduleWorkoutReminders` has an internal guard `shouldScheduleNotifications()` that returns early if permission is `.notDetermined` or `.denied`. On simulator/fresh install, notifications are never scheduled even after calling the right method.
**Why it happens:** Permission is requested at first session completion; new installs or test runs haven't triggered the prompt.
**How to avoid:** For testing FIX-03, grant notification permission in device settings or use a device that has already been through onboarding. The fix is correct if the call site is wired — the permission guard is intentional.
**Warning signs:** No notifications appearing in simulator even after fix — check permission status, not the call site.

### Pitfall 4: ISO Date Conversion Timezone Mismatch
**What goes wrong:** `ISO8601DateFormatter` defaults to UTC. If the device is in UTC-5, "Monday" might map to Sunday in UTC.
**Why it happens:** `Date()` is UTC internally; formatter interprets relative to timezone.
**How to avoid:** Use `Calendar.current` (respects locale/timezone) for the weekday arithmetic, not UTC. Format the resulting `Date` with `ISO8601DateFormatter` using `.withFullDate` only — this yields a calendar date ("2026-04-27") that is the same regardless of timezone.
**Warning signs:** Missed session dates are off by one day for users in non-UTC timezones.

### Pitfall 5: isOnboarded Still Referenced in Tests
**What goes wrong:** Removing `isOnboarded` from AppState causes a compile error if any test file references it.
**Why it happens:** Test files can access `@testable import WorkoutApp` properties.
**How to avoid:** Run a project-wide grep for `isOnboarded` before declaring the removal complete.
**Warning signs:** Build failure in test target after property removal.

---

## Code Examples

### FIX-01: Persist Adapted Plan (new method in AdaptationService)

```swift
// Pattern: mirrors CoachViewModel.applyPlanUpdate() exactly
// Source: WorkoutApp/Features/Coach/CoachViewModel.swift lines 411–427

private func persistAdaptedPlan(_ response: AdaptedPlanResponse, userId: String) async {
    // Map AdaptedDay → WorkoutDay
    let weeklyDays = response.weeklyDays.map { adapted in
        WorkoutDay(
            dayLabel: adapted.dayLabel,
            sessionName: adapted.sessionName,
            exercises: adapted.exercises.map { ex in
                PlannedExercise(
                    exerciseName: ex.exerciseName,
                    sets: ex.sets,
                    reps: ex.reps,
                    restSeconds: ex.restSeconds,
                    rationale: ex.rationale
                )
            }
        )
    }

    // Construct a WorkoutPlan — plan metadata preserved where possible
    // Use a placeholder name; the plan content is what matters
    let updatedPlan = WorkoutPlan(
        planName: "Adapted Plan",
        goalSummary: "",
        weeklyDays: weeklyDays
    )

    do {
        let repo = WorkoutPlanRepository()
        try repo.deactivateAllPlans(userId: userId)
        try repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)
    } catch {
        print("AdaptationService: Failed to persist adapted plan: \(error)")
    }
}
```

**Note:** `WorkoutPlan.planName` and `goalSummary` are required fields. Review `WorkoutPlan` struct to confirm field names and initializer before implementing.

### FIX-02: ISO Date Conversion (new static on MissedSessionDetector)

```swift
// Source: [VERIFIED: codebase — Calendar API, Foundation]
static func isoDateString(
    for dayLabel: String,
    relativeTo today: Date = Date(),
    calendar: Calendar = Calendar.current
) -> String? {
    let dayOfWeekMap: [String: Int] = [
        "Sunday": 1, "Monday": 2, "Tuesday": 3,
        "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7
    ]
    guard let targetWeekday = dayOfWeekMap[dayLabel] else { return nil }
    let todayWeekday = calendar.component(.weekday, from: today)
    var daysBack = todayWeekday - targetWeekday
    if daysBack <= 0 { daysBack += 7 }

    guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: today)
    else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    formatter.timeZone = calendar.timeZone  // respect device timezone
    return formatter.string(from: targetDate)
}
```

### FIX-03: Notification Call Site in AdaptationService

```swift
// After successful AdaptedPlanResponse decoding in requestPostSessionAdaptation / requestMissedSessionAdaptation:
private let dayOfWeekMap: [String: Int] = [
    "Sunday": 1, "Monday": 2, "Tuesday": 3,
    "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7
]

private func scheduleReminders(for response: AdaptedPlanResponse) async {
    let planDays = response.weeklyDays.compactMap { day -> (weekday: Int, workoutType: String)? in
        guard let weekday = dayOfWeekMap[day.dayLabel] else { return nil }
        return (weekday: weekday, workoutType: day.sessionName)
    }
    await NotificationScheduler.shared.scheduleWorkoutReminders(
        planDays: planDays,
        currentStreak: 0
    )
}
```

---

## Runtime State Inventory

This is a pure Swift source-code fix phase. No renames, no refactors of identifiers, no migrations.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — no CoreData schema changes; only new records written | None |
| Live service config | None — no Edge Function changes | None |
| OS-registered state | None — FIX-03 adds notification scheduling but does not rename existing identifiers | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

---

## Environment Availability

Phase 9 is iOS source-only — no external tooling dependencies beyond the existing Xcode project.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Build + run tests | Assumed present (project compiles) | — | — |
| iOS Simulator | Test notification call sites | Available via Xcode | — | Physical device |

**Step 2.6: No blocking external dependencies.** All fixes compile and run with existing project infrastructure.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (native Xcode) |
| Config file | WorkoutApp.xcodeproj (scheme: WorkoutApp) |
| Quick run command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests/MissedSessionDetectorTests 2>&1 \| xcpretty` |
| Full suite command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| xcpretty` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FIX-01 | Adapted plan persisted to CoreData after adaptation | Unit | `WorkoutAppTests/AdaptationServiceTests` | ❌ Wave 0 |
| FIX-02 | ISO date strings generated correctly for each day label | Unit | `WorkoutAppTests/MissedSessionDetectorTests` | ✅ (extend existing) |
| FIX-03 | scheduleWorkoutReminders called after plan generation | Unit (mock scheduler) | `WorkoutAppTests/PlanGenerationServiceTests` | ❌ Wave 0 |
| FIX-03 | scheduleWorkoutReminders called after adaptation | Unit (mock scheduler) | `WorkoutAppTests/AdaptationServiceTests` | ❌ Wave 0 |
| FIX-04 | weeklyPlanned reflects active plan day count | Unit | `WorkoutAppTests/ProgressViewModelTests` | ✅ (extend existing) |
| FIX-05 | isOnboarded removed, no compile errors | Build | Full build | N/A (compile check) |

### Sampling Rate

- **Per task commit:** Run the specific test file(s) for that fix
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `WorkoutAppTests/AdaptationServiceTests.swift` — covers FIX-01 (CoreData persist) and FIX-03 (notification call site in AdaptationService)
- [ ] `WorkoutAppTests/PlanGenerationServiceTests.swift` — covers FIX-03 (notification call site in PlanGenerationService)

*(Existing test infrastructure covers ProgressViewModelTests for FIX-04 and MissedSessionDetectorTests for FIX-02 — both need new test cases, not new files.)*

---

## Security Domain

Phase 9 fixes integration wiring. No new security surfaces are introduced.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth changes |
| V3 Session Management | No | No session changes |
| V4 Access Control | No | No new data access patterns |
| V5 Input Validation | Partial (FIX-02) | ISO_DATE_RE validation in Edge Function unchanged; iOS-side conversion must not produce invalid dates |
| V6 Cryptography | No | No crypto changes |

### Known Threat Patterns for This Fix Set

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| FIX-01: New CoreData write path | Tampering | `WorkoutPlanRepository.save()` already enforces Int16 clamping for AI-sourced values (WR-05) — use it, don't bypass |
| FIX-02: Day-label injection | Tampering | MissedSessionDetector only processes strings from the app's own plan data, not user input; no injection surface |
| FIX-03: Notification content | Spoofing | Copy is hardcoded in `scheduleWorkoutReminders` — not AI-generated, no guilt blocklist needed for reminder copy |

---

## Open Questions

1. **WorkoutPlan initializer for FIX-01**
   - What we know: `WorkoutPlan` is a Codable struct with `planName`, `goalSummary`, `weeklyDays`
   - What's unclear: Whether `planName` and `goalSummary` can be sourced from the existing active plan (to avoid placeholder strings) — the active plan is available in CoreData before the adaptation runs
   - Recommendation: In `persistAdaptedPlan()`, fetch the current active plan's metadata before deactivating, then reuse `planName` and `goalSummary` in the new plan. This preserves continuity. If the fetch fails, fall back to "Adapted Plan" / "".

2. **currentStreak for FIX-03 notification scheduling**
   - What we know: `scheduleWorkoutReminders` accepts `currentStreak: Int` for streak-aware copy
   - What's unclear: AdaptationService doesn't have access to ProgressViewModel's computed streak. Passing 0 is safe (produces standard copy, not streak copy).
   - Recommendation: Pass 0 from AdaptationService and PlanGenerationService. Streak-aware copy is a nice-to-have that can be improved in a future phase if desired.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `WorkoutPlan` struct has a memberwise or designated initializer accepting `planName`, `goalSummary`, `weeklyDays` | Code Examples (FIX-01) | Compile error; fix: read WorkoutPlan.swift before implementing |
| A2 | `PlannedExercise` struct fields match `AdaptedExercise` fields 1:1 (exerciseName, sets, reps, restSeconds, rationale) | Pitfall 1, Code Examples | Mapping code won't compile; fix: read PlannedExercise definition |
| A3 | No test file other than AppState.swift references `isOnboarded` | Pitfall 5 | Build failure in test target after removal; fix: grep before deleting |

---

## Sources

### Primary (HIGH confidence)
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` — FIX-01/02/03 target, ISO week Calendar usage
- `WorkoutApp/Features/Coach/CoachViewModel.swift` — `applyPlanUpdate()` reference pattern (lines 411–427)
- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — `scheduleWorkoutReminders` implementation
- `WorkoutApp/Features/Progress/ProgressViewModel.swift` — hardcoded `weeklyPlanned = 4` (line 178)
- `WorkoutApp/Core/AppState.swift` — dead `isOnboarded` property (lines 33–35, 115)
- `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` — returns day labels
- `WorkoutApp/Features/Adaptation/Models/AdaptedPlan.swift` — `AdaptedPlanResponse`, `AdaptedDay`, `AdaptedExercise`
- `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift` — `save()`, `fetchActivePlan()`, `deactivateAllPlans()`
- `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` — FIX-03 call site location
- `supabase/functions/adapt-plan/index.ts` lines 380–383 — `ISO_DATE_RE` contract confirmed

### Secondary (MEDIUM confidence)
- `.planning/v1.0-MILESTONE-AUDIT.md` — root cause documentation for all 5 gaps

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all required tools are already in the project
- Architecture: HIGH — reference patterns (`applyPlanUpdate`, `fetchActivePlan`) exist and were read directly
- Pitfalls: HIGH — derived from direct code inspection of the bug sites
- Code examples: MEDIUM — patterns verified, but A1/A2/A3 above require confirming struct initializers before copying

**Research date:** 2026-04-26
**Valid until:** Stable indefinitely — all findings are based on the local codebase, not external APIs
