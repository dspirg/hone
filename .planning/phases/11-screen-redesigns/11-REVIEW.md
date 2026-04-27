---
phase: 11-screen-redesigns
reviewed: 2026-04-27T00:00:00Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - WorkoutApp/Core/AppState.swift
  - WorkoutApp/Features/Adaptation/AdaptationService.swift
  - WorkoutApp/Features/CoreData/SessionRepository.swift
  - WorkoutApp/Features/Main/Components/AdaptationBannerView.swift
  - WorkoutApp/Features/Main/Components/HomeExerciseRowView.swift
  - WorkoutApp/Features/Main/Components/StatPillView.swift
  - WorkoutApp/Features/Main/Components/WeekStreakBar.swift
  - WorkoutApp/Features/Main/HomeViewModel.swift
  - WorkoutApp/Features/Main/Tabs/HomeView.swift
  - WorkoutApp/Features/Main/MainTabView.swift
  - WorkoutApp/Features/Session/Components/ContextCardView.swift
  - WorkoutApp/Features/Session/Components/ExerciseCardView.swift
  - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
  - WorkoutApp/Features/Session/SessionView.swift
  - WorkoutApp/Features/Session/SessionViewModel.swift
  - WorkoutAppTests/HomeViewModelTests.swift
  - WorkoutAppTests/SessionRepositoryTests.swift
  - WorkoutAppTests/SessionViewModelTests.swift
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-04-27
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

This review covers the Phase 11 screen redesign work: the rebuilt HomeView card-stack layout, the new ExerciseCardView compact 2:1 video layout with context cards, SessionSummaryView consolidations, and supporting ViewModels and repositories. The code is generally well-structured with clear MVVM separation and good threat-model annotations.

One critical bug was found: an unfiltered CoreData fetch in `HomeViewModel.loadStats` loads all `CDSetLog` records from the store before filtering in memory, which is both a correctness risk (leaks cross-user data into the in-memory filter window if the predicate logic has any gap) and is architecturally inconsistent with the explicit userId-scoping pattern the codebase applies everywhere else.

Five warnings cover real logic gaps: a race condition in `completeSet` that can lose a set completion silently, a misleading "Good night" time window, a force-unwrap on an optional that could crash, a non-atomic weekly-regen dedup that can duplicate calls across concurrent foreground activations, and a missing `await` on the background task in `completeSet` that discards errors silently.

---

## Critical Issues

### CR-01: Unscoped CDSetLog Fetch Loads All Users' Set Data

**File:** `WorkoutApp/Features/Main/HomeViewModel.swift:151-153`

**Issue:** `loadStats` constructs `sessions` with a `userId` predicate and then builds `userSessionIds` from those sessions. However, the `CDSetLog` fetch on line 152 has **no predicate at all** — it fetches every `CDSetLog` record in the store, regardless of user. The in-memory filter on line 153 (`userSessionIds.contains($0.sessionId)`) is the only gate preventing cross-user set data from being processed. If a session UUID from user A happens to collide with a session UUID stored for a different user (impossible with UUIDs in practice, but the architectural gap remains), or if the `sessionIds` set is somehow over-populated, all other users' set logs are loaded into memory and iterated. On a shared test device or simulator with multiple signed-in test accounts this is a real data leakage surface.

The pattern used by `SessionRepository.fetchBestReps` (which does the same scoping correctly) applies the predicate at the CoreData layer, not in memory. `HomeViewModel` should follow the same pattern.

**Fix:**
```swift
// Replace the unscoped fetch:
let setRequest = CDSetLog.fetchRequest()
let allSets = try context.fetch(setRequest)
let userSets = allSets.filter { userSessionIds.contains($0.sessionId ?? UUID()) }

// With a predicate-scoped fetch:
let setRequest = CDSetLog.fetchRequest()
setRequest.predicate = NSPredicate(
    format: "sessionId IN %@", userSessionIds as CVarArg
)
let userSets = try context.fetch(setRequest)
```

---

## Warnings

### WR-01: Race Condition — completeSet Silently Drops When sessionLog Is Nil

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:124-126`

**Issue:** `completeSet` guards on `sessionLog != nil` and returns silently if it is nil. `sessionLog` is set asynchronously in `startSession()`, and `SessionView.setupSession()` correctly `await`s `startSession()` before assigning `viewModel`. However, `ExerciseCardView.SetLogRow` can call `viewModel.completeSet(...)` immediately after the view appears. Because `SessionView` shows the card view only after `viewModel` is non-nil (set after `await vm.startSession()`), this should be safe in the normal path. The risk is that `startSession()` can fail (the CoreData write throws), leaving `sessionLog = nil` permanently. The guard on line 126 then silently swallows every subsequent `completeSet` call — the user taps "Complete Set" and nothing is recorded, with no error shown.

**Fix:** Track the CoreData failure and surface it to the user rather than silently no-opping all future set completions. At minimum, set a flag that `SessionView` can observe to show an error banner:
```swift
// In SessionViewModel
private(set) var sessionSetupFailed: Bool = false

func startSession() async {
    sessionStartDate = Date()
    do {
        sessionLog = try repository.startSession(...)
    } catch {
        sessionSetupFailed = true
        print("SessionViewModel: startSession CoreData write failed: \(error)")
    }
}

// In completeSet — distinguish "not yet set" from "permanently failed"
func completeSet(setIndex: Int, repsLogged: Int) {
    guard let exercise = currentExercise else { return }
    guard let session = sessionLog else {
        // Surface error if setup definitively failed
        if sessionSetupFailed { /* show error banner */ }
        return
    }
    // ...
}
```

---

### WR-02: "Good Night" Greeting Fires at Hour 0 (Midnight to 4 AM)

**File:** `WorkoutApp/Features/Main/HomeViewModel.swift:74-82`

**Issue:** The `timeOfDayGreeting` computed property covers hours 5–11 (morning), 12–16 (afternoon), 17–20 (evening), and falls through to `default` for everything else. The `default` branch covers hours 0–4 (midnight to just before 5 AM) and hour 21–23. Returning "Good night" at midnight is expected. Returning "Good night" at 2 AM is surprising but debatable. The real gap is that the switch exhausts on a 24-hour clock but hour 21, 22, and 23 (9 PM to midnight) also hit `default` and get "Good night." Whether a user opening the app at 9:15 PM should see "Good night" rather than "Good evening" is a product decision, but the current boundary at `17..<21` (cuts off at 9 PM) is likely unintentional.

**Fix:**
```swift
var timeOfDayGreeting: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"   // extend to 10 PM
    default:      return "Good night"
    }
}
```

---

### WR-03: Force-Unwrap Crash Risk on Optional sessionId in completeSet Background Context

**File:** `WorkoutApp/Features/CoreData/SessionRepository.swift:86`

**Issue:** The background context fetch predicate uses `sessionId! as CVarArg` where `sessionId` is typed as `UUID?` (captured from `session.id`). If `session.id` is nil at the call site — which can happen if the CoreData object was not fully initialized before `completeSet` was called — the force-unwrap crashes. The `startSession` function sets `session.id = UUID()` before save so this is normally populated, but defensive code should not force-unwrap optionals in background tasks where the failure cannot be caught.

**Fix:**
```swift
// Replace:
req.predicate = NSPredicate(format: "id == %@", sessionId! as CVarArg)

// With:
guard let safeSessionId = sessionId else {
    try? bgCtx.save()
    return
}
req.predicate = NSPredicate(format: "id == %@", safeSessionId as CVarArg)
```

---

### WR-04: Weekly Regen Dedup Not Concurrency-Safe — Multiple Foreground Calls Can Race

**File:** `WorkoutApp/Features/Adaptation/AdaptationService.swift:149-151`

**Issue:** `checkOnForeground` checks `isoWeekKey != lastWeeklyCheckKey`, then immediately sets `lastWeeklyCheckKey = isoWeekKey` before `await requestWeeklyRegeneration()`. Because `AdaptationService` is `@MainActor`, sequential `await` calls serialize correctly. However, `MainTabView.onChange(of: scenePhase)` wraps the call in an unstructured `Task { await runForegroundCheck() }` (line 64-66 of `MainTabView.swift`). If `scenePhase` transitions to `.active` twice in rapid succession (a known iOS behavior when a phone call interrupts the app or a notification arrives), two `Task` closures can be created. On `@MainActor`, both tasks run cooperatively, but the check-then-set is not atomic across suspension points: the first task sets `lastWeeklyCheckKey` synchronously, which does protect against the second task in the same cooperative scheduler. However, this relies on the implicit guarantee that `lastWeeklyCheckKey = isoWeekKey` runs before the first `await` in `requestWeeklyRegeneration`. If the implementation of `requestWeeklyRegeneration` is ever restructured to `await` before the check, the dedup fails.

More concretely: if `checkOnForeground` is ever called concurrently from a different non-`@MainActor` context (e.g., a background URLSession delegate, or a future refactor), the dedup breaks entirely.

**Fix:** Add an explicit guard to make the dedup atomic even if called reentrantly:
```swift
// Add a separate flag for in-progress weekly check
private var isWeeklyCheckInProgress: Bool = false

func checkOnForeground(...) async {
    let isoWeekKey = isoWeekString(for: today)
    if weekday == 2 && isoWeekKey != lastWeeklyCheckKey && !isWeeklyCheckInProgress {
        isWeeklyCheckInProgress = true
        lastWeeklyCheckKey = isoWeekKey
        await requestWeeklyRegeneration()
        isWeeklyCheckInProgress = false
    }
    // ...
}
```

---

### WR-05: HomeExerciseRowView Always Passes url: nil to AsyncImage — Success Branch Is Dead Code

**File:** `WorkoutApp/Features/Main/Components/HomeExerciseRowView.swift:18-39`

**Issue:** `AsyncImage(url: nil)` always enters the `default` branch. The `case .success(let image)` branch on line 23 is dead code — `AsyncImage` with a nil URL never succeeds. This is documented in the comment on lines 19-21, but the dead success branch adds noise and will mislead anyone who adds thumbnail support later. When the ExerciseRepository lookup is wired up, the dead branch will need to be replaced rather than enabled. Having dead code in a code path that is explicitly slated for future completion is a maintenance hazard.

**Fix:** Replace the phase-switching `AsyncImage` with a simple conditional that directly renders the placeholder, and add a `TODO` comment indicating where the real URL should be threaded in:
```swift
// TODO: Replace with real thumbnailURL from ExerciseRepository once wired up (D-04 full rebuild)
Theme.surface
    .frame(width: 40, height: 40)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay {
        Image(systemName: "dumbbell")
            .font(.body)
            .foregroundStyle(Color(UIColor.tertiaryLabel))
    }
```

---

## Info

### IN-01: AdaptationService.requestWeeklyRegeneration Does Not Persist the Adapted Plan

**File:** `WorkoutApp/Features/Adaptation/AdaptationService.swift:111-128`

**Issue:** `requestPostSessionAdaptation` and `requestMissedSessionAdaptation` both call `persistAdaptedPlan` and `scheduleReminders` after receiving the edge function response. `requestWeeklyRegeneration` does not — it only sets `lastAdjustmentSummary` and `lastAdjustmentDate`. If the weekly regen response includes an updated plan (same `AdaptedPlanResponse` type), the updated plan is never written to CoreData. The user would see the banner but their local plan would not update until the next session loads from the server.

**Fix:** Add persistence and reminder scheduling to the weekly regeneration path, mirroring the post-session path:
```swift
func requestWeeklyRegeneration() async {
    do {
        let accessToken = try await fetchAccessToken()
        let response = try await callEdgeFunction(...)
        lastAdjustmentSummary = response.adjustmentSummary
        lastAdjustmentDate = Date()
        let userId = try await supabase.auth.session.user.id.uuidString
        await persistAdaptedPlan(response, userId: userId)   // add this
        await scheduleReminders(for: response)               // add this
    } catch { ... }
}
```

---

### IN-02: HomeViewModelTests.testTimeOfDayGreeting_morning Does Not Test the Mapping

**File:** `WorkoutAppTests/HomeViewModelTests.swift:9-16`

**Issue:** The test comment acknowledges it cannot test the actual hour-to-greeting mapping. It only asserts the property returns a non-empty string — which would pass even if `timeOfDayGreeting` always returned "Hello". The test provides almost no value. A clock injection or a direct test of the switch logic would be more useful.

**Fix:** Extract the mapping into a testable static helper:
```swift
// In HomeViewModel
static func greeting(for hour: Int) -> String {
    switch hour {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"
    default:      return "Good night"
    }
}

// In test
func testGreeting_morning() {
    XCTAssertEqual(HomeViewModel.greeting(for: 7), "Good morning")
    XCTAssertEqual(HomeViewModel.greeting(for: 11), "Good morning")
    XCTAssertEqual(HomeViewModel.greeting(for: 12), "Good afternoon")
    XCTAssertEqual(HomeViewModel.greeting(for: 21), "Good evening")
    XCTAssertEqual(HomeViewModel.greeting(for: 2),  "Good night")
}
```

---

### IN-03: SessionViewModelTests.testSessionCompleteOnLastSetOfLastExercise Uses a Fixed Sleep

**File:** `WorkoutAppTests/SessionViewModelTests.swift:184`

**Issue:** `try? await Task.sleep(nanoseconds: 200_000_000)` (200ms) is used to wait for the `Task { ... }` finalization block inside `completeSet`. This is a timing-dependent test pattern that can produce false passes on a fast device and false failures under CI load. The test comment acknowledges this but accepts it.

**Fix:** Extract the session finalization logic out of an unstructured `Task` so it is directly `await`able from the caller, or expose a test hook that returns when finalization is complete.

---

### IN-04: PR Badge Section Header Uses "New Record" (Singular) When Multiple PRs Are Possible

**File:** `WorkoutApp/Features/Session/Components/SessionSummaryView.swift:66`

**Issue:** The section header `Text("New Record")` does not pluralize when `prs.count > 1`. A session with 3 PRs shows "New Record" rather than "New Records". Minor copy issue.

**Fix:**
```swift
Text(prs.count == 1 ? "New Record" : "New Records")
    .font(.title2.weight(.semibold))
    .padding(.horizontal, 16)
```

---

_Reviewed: 2026-04-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
