# Phase 9: Bug Fixes - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 6 modified files + 2 new test files
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkoutApp/Features/Adaptation/AdaptationService.swift` | service | request-response | `WorkoutApp/Features/Coach/CoachViewModel.swift` (`applyPlanUpdate`) | exact — same CoreData write + auth token pattern |
| `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` | utility | transform | `WorkoutApp/Features/Adaptation/AdaptationService.swift` (`isoWeekString`) | exact — same Calendar(identifier:) + ISO date pattern |
| `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` | service | request-response | `WorkoutApp/Features/Adaptation/AdaptationService.swift` | role-match — same service tier, same notification scheduler target |
| `WorkoutApp/Features/Progress/ProgressViewModel.swift` | viewmodel | CRUD | `WorkoutApp/Features/Main/Tabs/TrainView.swift` + existing ProgressViewModel pattern | role-match — same `WorkoutPlanRepository.fetchActivePlan()` usage |
| `WorkoutApp/Core/AppState.swift` | core/state | — | Self (deletion only) | N/A — dead code removal |
| `WorkoutAppTests/AdaptationServiceTests.swift` | test | — | `WorkoutAppTests/MissedSessionDetectorTests.swift` | exact — same @MainActor + PersistenceController(inMemory:) pattern |
| `WorkoutAppTests/PlanGenerationServiceTests.swift` | test | — | `WorkoutAppTests/ProgressViewModelTests.swift` | role-match — same service test structure |
| `WorkoutAppTests/MissedSessionDetectorTests.swift` (extend) | test | — | Self (extension) | exact — add cases to existing file |

---

## Pattern Assignments

### `WorkoutApp/Features/Adaptation/AdaptationService.swift` (FIX-01 + FIX-02 + FIX-03)

**Analog (FIX-01 CoreData write):** `WorkoutApp/Features/Coach/CoachViewModel.swift` lines 411–427

**Reference CoreData write pattern** (CoachViewModel lines 411–427):
```swift
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

**FIX-01 adaptation:** `AdaptationService` cannot decode `AdaptedPlanResponse` directly as `WorkoutPlan` — the types differ. Map `AdaptedDay` → `WorkoutDay` and `AdaptedExercise` → `PlannedExercise` first, then construct a `WorkoutPlan` before calling the repo. The field mapping is 1:1 confirmed from `AdaptedPlan.swift` lines 20–45 and `WorkoutPlan.swift` lines 21–52:

| AdaptedExercise field | PlannedExercise field |
|-----------------------|-----------------------|
| `exerciseName` | `exerciseName` |
| `sets` | `sets` |
| `reps` | `reps` |
| `restSeconds` | `restSeconds` |
| `rationale` | `rationale` |

**New `persistAdaptedPlan` method to add inside AdaptationService** (after line 203 of the current file):
```swift
private func persistAdaptedPlan(_ response: AdaptedPlanResponse, userId: String) async {
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
    // Preserve metadata from existing active plan where possible (Open Question 1)
    // Fall back to placeholder strings only if fetch fails
    let repo = WorkoutPlanRepository(context: PersistenceController.shared.container.viewContext)
    let existingPlan = try? repo.fetchActivePlan(userId: userId)
    let updatedPlan = WorkoutPlan(
        planName: existingPlan?.planName ?? "Adapted Plan",
        goalSummary: existingPlan?.goalSummary ?? "",
        weeklyDays: weeklyDays
    )
    do {
        try repo.deactivateAllPlans(userId: userId)
        try repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)
    } catch {
        print("AdaptationService: Failed to persist adapted plan: \(error)")
    }
}
```

**Auth token pattern** (AdaptationService lines 163–166, existing — do not change):
```swift
private func fetchAccessToken() async throws -> String {
    let session = try await supabase.auth.session
    return session.accessToken
}
```

**Error handling pattern** (AdaptationService lines 63–66 + 88–90, existing):
```swift
} catch {
    // Non-fatal: adaptation is best-effort. Log for diagnostics.
    print("AdaptationService: post-session adaptation failed: \(error)")
}
```

**Analog (FIX-02 ISO date conversion):** `WorkoutApp/Features/Adaptation/AdaptationService.swift` lines 197–202 — existing `isoWeekString` method already uses `Calendar(identifier: .iso8601)` and ISO formatting.

**FIX-02 conversion to add as static method on `MissedSessionDetector`** (copy `dayOfWeekMap` from lines 46–54 of the same file, already tested and correct):
```swift
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
    if daysBack <= 0 { daysBack += 7 }  // wrap to previous week — missed days are in the past
    guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: today)
    else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    formatter.timeZone = calendar.timeZone  // device timezone, not UTC
    return formatter.string(from: targetDate)
}
```

**FIX-02 call site in `AdaptationService.checkOnForeground()`** (replace lines 140–148 in current file):
```swift
// Existing
let missedDays = MissedSessionDetector.detectMissedSessions(
    activePlanDayLabels: activePlanDayLabels,
    completedSessions: completedSessions,
    today: today,
    calendar: calendar
)
// FIX-02: convert day labels to ISO dates before sending to Edge Function
let missedIsoDates = missedDays.compactMap {
    MissedSessionDetector.isoDateString(for: $0, relativeTo: today, calendar: calendar)
}
if !missedIsoDates.isEmpty {
    await requestMissedSessionAdaptation(missedDays: missedIsoDates)
}
```

**Analog (FIX-03 notification call site):** `WorkoutApp/Core/Notifications/NotificationScheduler.swift` lines 93–142 — `scheduleWorkoutReminders` signature confirmed:
```swift
func scheduleWorkoutReminders(
    planDays: [(weekday: Int, workoutType: String)],
    currentStreak: Int
) async
```

**FIX-03 helper method to add in AdaptationService** (D-08: call site lives inside service):
```swift
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
        currentStreak: 0  // streak not available in service; 0 = standard copy (safe default)
    )
}
```

**Call `persistAdaptedPlan` + `scheduleReminders` inside both adaptation methods.** Pattern: update `requestPostSessionAdaptation` (lines 49–67) and `requestMissedSessionAdaptation` (lines 73–91) after the `lastAdjustmentSummary` assignment:
```swift
// After: lastAdjustmentSummary = response.adjustmentSummary
let userId = try await fetchAccessToken()  // Note: fetch userId separately
// Simpler: userId is available from the session fetched for the access token
// Refactor: capture userId at top of method alongside accessToken
await persistAdaptedPlan(response, userId: userId)
await scheduleReminders(for: response)
```

**Note on userId in requestPostSessionAdaptation/requestMissedSessionAdaptation:** These methods currently only call `fetchAccessToken()` which returns the token string, not the userId. The userId must be fetched from the session. Add a `fetchUserId()` helper or expand `fetchAccessToken()` to return both — follow the pattern in `CoachViewModel.applyPlanUpdate()` line 416:
```swift
let userId = try await supabase.auth.session.user.id.uuidString
```

---

### `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` (FIX-02)

**Analog:** Self (adding a static method to the existing pure struct)

**Existing struct declaration** (line 14 — new method adds after line 64):
```swift
struct MissedSessionDetector {
    static func detectMissedSessions(...) -> [String] { ... }
    // FIX-02: add isoDateString static method here
}
```

**Existing `dayOfWeekMap`** (lines 46–54) — the new `isoDateString` method should declare its own local copy of this map (same values) to keep the method self-contained and testable in isolation. The existing map in `detectMissedSessions` is inside a function body and is not reusable.

**File-level pattern** (lines 1–13): Pure struct, no imports beyond Foundation and CoreData. No `@Observable`, no `@MainActor`. The new static method follows this same pure-function style.

---

### `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` (FIX-03)

**Analog:** `WorkoutApp/Features/Adaptation/AdaptationService.swift` — same service tier, same notification scheduler target.

**FIX-03 call site location:** After `state = .completed(plan)` on line 120. The `plan` variable (`WorkoutPlan`) is in scope. Use the same `dayOfWeekMap` + `scheduleWorkoutReminders` pattern:
```swift
// After: state = .completed(plan)
let planDays = plan.weeklyDays.compactMap { day -> (weekday: Int, workoutType: String)? in
    let dayOfWeekMap: [String: Int] = [
        "Sunday": 1, "Monday": 2, "Tuesday": 3,
        "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7
    ]
    guard let weekday = dayOfWeekMap[day.dayLabel] else { return nil }
    return (weekday: weekday, workoutType: day.sessionName)
}
await NotificationScheduler.shared.scheduleWorkoutReminders(planDays: planDays, currentStreak: 0)
```

**Existing service patterns to preserve** (PlanGenerationService lines 77–143):
- `currentStreamTask = Task { ... }` — fire-and-forget task wrapping. The notification call happens inside the Task body where `plan` is available.
- Error handling: `print("PlanGenerationService error ...")` style, no throws to caller
- `@Observable @MainActor` class declaration — notification scheduler call must be `await`ed (already a `@MainActor` context)

---

### `WorkoutApp/Features/Progress/ProgressViewModel.swift` (FIX-04)

**Analog:** `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift` (`fetchActivePlan`) — already used in TrainView and HomeView.

**Existing `loadProgress()` method** (lines 56–71) — the fix inserts a `fetchActivePlan` call here, before `computeWeeklyRing`:
```swift
func loadProgress() async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }

    do {
        let fetchedSessions = try fetchCompletedSessions()
        sessions = fetchedSessions
        computeStreak(from: fetchedSessions)
        // FIX-04: fetch active plan weeklyDays count before ring computation
        if let userId = cachedUserId {
            let repo = WorkoutPlanRepository(context: viewContext)
            let plan = try? repo.fetchActivePlan(userId: userId)
            weeklyPlanned = plan?.weeklyDays.count ?? 3  // 3 = safer default than 4
        }
        computeWeeklyRing(from: fetchedSessions)
        weekBuckets = computeWeekBuckets(from: fetchedSessions)
    } catch {
        print("ProgressViewModel: loadProgress failed: \(error)")
        loadError = "Couldn't load your progress. Pull down to try again."
    }
}
```

**Bug line to remove** (line 179 in current file):
```swift
// REMOVE THIS LINE:
weeklyPlanned = max(weeklyPlanned, 4)
```

**Existing `viewContext` property** (line 39): `private let viewContext: NSManagedObjectContext` — pass it to `WorkoutPlanRepository(context: viewContext)` exactly as `CoachViewModel` does on line 418.

**Existing `cachedUserId` property** (line 38): Set in `onAppear(appState:)` at line 50 — always populated by the time `loadProgress()` runs.

---

### `WorkoutApp/Core/AppState.swift` (FIX-05)

**Analog:** N/A — deletion only.

**Three lines to delete** (confirmed no other file references `isOnboarded`):

Line 33 (comment):
```swift
// isOnboarded mirrors onboardingCompleted for SUBS-03 compatibility.
// Phase 3 populates this; Phase 7 gates paywall on authenticated + onboarded + !isSubscribed
```

Line 35 (property declaration):
```swift
var isOnboarded: Bool = false
```

Line 115 (assignment inside `markOnboardingComplete()`):
```swift
self.isOnboarded = true
```

**After deletion** `markOnboardingComplete()` (lines 113–116) becomes:
```swift
func markOnboardingComplete() {
    self.onboardingCompleted = true
}
```

**Verification required before deletion:** Run project-wide grep for `isOnboarded` across all `.swift` files to confirm no test target references it. If a compile error appears in a test file, remove that reference too.

---

### `WorkoutAppTests/AdaptationServiceTests.swift` (new file — Wave 0)

**Analog:** `WorkoutAppTests/MissedSessionDetectorTests.swift` — exact structure match

**Test file boilerplate pattern** (MissedSessionDetectorTests lines 1–24):
```swift
import XCTest
import CoreData
@testable import WorkoutApp

@MainActor
final class AdaptationServiceTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
    }
```

**Tests to write:**
- FIX-01: `testPersistAdaptedPlanWritesToCoreData` — call `persistAdaptedPlan` with a mock `AdaptedPlanResponse`, then call `WorkoutPlanRepository.fetchActivePlan(userId:)` and assert weeklyDays count matches
- FIX-03 (AdaptationService): Verify `scheduleReminders` is called — use a mock or subclass of `NotificationScheduler`; or verify via side-effect (check `UNUserNotificationCenter.current().pendingNotificationRequests()` after granting permission)

---

### `WorkoutAppTests/PlanGenerationServiceTests.swift` (new file — Wave 0)

**Analog:** `WorkoutAppTests/ProgressViewModelTests.swift` lines 1–33 — same setup/teardown pattern

**Test file boilerplate:**
```swift
import XCTest
import CoreData
@testable import WorkoutApp

@MainActor
final class PlanGenerationServiceTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var service: PlanGenerationService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        service = PlanGenerationService()
    }

    override func tearDownWithError() throws {
        service = nil
        context = nil
        persistenceController = nil
    }
```

**Test to write:**
- FIX-03 (PlanGenerationService): `testScheduleWorkoutRemindersCalledAfterCompletion` — mock `NotificationScheduler` or assert call side-effect

---

### `WorkoutAppTests/MissedSessionDetectorTests.swift` (extend existing)

**Analog:** Self (existing file) — add test cases after line 167.

**Existing test helper to reuse** (lines 42–50 — `makeDate(weekday:hour:)`):
```swift
private func makeDate(weekday: Int, hour: Int = 12) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 1
    let now = Date()
    let currentWeekday = calendar.component(.weekday, from: now)
    let diff = weekday - currentWeekday
    return calendar.date(byAdding: .day, value: diff, to: now)!
}
```

**New test cases to add (FIX-02):**
```swift
// Test: isoDateString returns correct YYYY-MM-DD for "Monday" when today is Wednesday
func testIsoDateStringForMonday() {
    // Wednesday (weekday 4), so Monday (weekday 2) is 2 days back
    let wednesday = makeDate(weekday: 4)
    let result = MissedSessionDetector.isoDateString(for: "Monday", relativeTo: wednesday)
    let expected: String = {
        var calendar = Calendar.current
        let monday = calendar.date(byAdding: .day, value: -2, to: wednesday)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: monday)
    }()
    XCTAssertEqual(result, expected)
}

// Test: isoDateString wraps to previous week when day is in the future
func testIsoDateStringWrapsToLastWeek() {
    // Today is Monday (weekday 2); "Friday" (weekday 6) must wrap to last Friday (4 days ago)
    let monday = makeDate(weekday: 2)
    let result = MissedSessionDetector.isoDateString(for: "Friday", relativeTo: monday)
    XCTAssertNotNil(result, "Should return a date string even when day wraps to previous week")
    // Verify date is in the past relative to monday
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    if let result, let resultDate = formatter.date(from: result) {
        XCTAssertLessThan(resultDate, monday, "Wrapped day should be before today (monday)")
    }
}

// Test: isoDateString returns nil for unknown day label
func testIsoDateStringNilForUnknownLabel() {
    let result = MissedSessionDetector.isoDateString(for: "Funday")
    XCTAssertNil(result)
}
```

---

### `WorkoutAppTests/ProgressViewModelTests.swift` (extend existing)

**Analog:** Self (existing file) — add test case after line 283.

**Existing setUp to note** (lines 22–27): `viewModel = ProgressViewModel(context: context)` — the FIX-04 test must also insert a `CDWorkoutPlan` into the same `context`.

**New test case to add (FIX-04):**
```swift
// Test: weeklyPlanned reads from active plan's weeklyDays count, not hardcoded 4
func testWeeklyPlannedReflectsActivePlanDayCount() async throws {
    // Save an active plan with 5 days via WorkoutPlanRepository
    let repo = WorkoutPlanRepository(context: context)
    let plan = WorkoutPlan(
        planName: "Test Plan",
        goalSummary: "Test",
        weeklyDays: [
            WorkoutDay(dayLabel: "Monday", sessionName: "Push", exercises: []),
            WorkoutDay(dayLabel: "Tuesday", sessionName: "Pull", exercises: []),
            WorkoutDay(dayLabel: "Wednesday", sessionName: "Legs", exercises: []),
            WorkoutDay(dayLabel: "Friday", sessionName: "Push", exercises: []),
            WorkoutDay(dayLabel: "Saturday", sessionName: "Pull", exercises: [])
        ]
    )
    try repo.save(plan: plan, supabaseId: UUID().uuidString, userId: "test-user-id")

    await viewModel.loadProgress()

    XCTAssertEqual(viewModel.weeklyPlanned, 5,
                   "weeklyPlanned should reflect the active plan's 5 days, not a hardcoded value")
}
```

---

## Shared Patterns

### @Observable @MainActor Service Pattern
**Source:** `WorkoutApp/Features/Adaptation/AdaptationService.swift` lines 18–20
**Apply to:** All modified service files and new test files (test files use `@MainActor` on the class)
```swift
@Observable
@MainActor
final class ServiceName {
```

### CoreData Write: deactivate-then-save
**Source:** `WorkoutApp/Features/Coach/CoachViewModel.swift` lines 420–423 and `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift` lines 88–98
**Apply to:** `AdaptationService.persistAdaptedPlan` (FIX-01)
```swift
try repo.deactivateAllPlans(userId: userId)
try repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)
```
Note: `WorkoutPlanRepository.deactivateAllPlans` saves the context internally (line 97). `save()` saves again at line 63. No manual `context.save()` needed at the call site.

### Non-fatal Error Logging
**Source:** `WorkoutApp/Features/Adaptation/AdaptationService.swift` lines 63–66
**Apply to:** All new catch blocks in AdaptationService and PlanGenerationService
```swift
} catch {
    print("ServiceName: operation description failed: \(error)")
}
```
Adaptation and notification scheduling are best-effort. Never throw to the caller; log and return.

### Fire-and-Forget Task
**Source:** `WorkoutApp/Features/Adaptation/AdaptationService.swift` lines 150–155 (re-engagement notification call)
**Apply to:** FIX-03 notification call sites if needed outside async contexts
```swift
Task {
    await NotificationScheduler.shared.scheduleWorkoutReminders(planDays: planDays, currentStreak: 0)
}
```
Note: Since `AdaptationService` and `PlanGenerationService` are both `@MainActor async` contexts, a bare `await` is preferred over wrapping in `Task`. Use `Task {}` only if the call site is in a non-async scope.

### In-Memory CoreData for Tests
**Source:** `WorkoutAppTests/MissedSessionDetectorTests.swift` lines 16–24
**Apply to:** All new test files (AdaptationServiceTests, PlanGenerationServiceTests)
```swift
override func setUpWithError() throws {
    persistenceController = PersistenceController(inMemory: true)
    context = persistenceController.container.viewContext
}
override func tearDownWithError() throws {
    context = nil
    persistenceController = nil
}
```

### WorkoutPlanRepository Instantiation
**Source:** `WorkoutApp/Features/Coach/CoachViewModel.swift` line 418
**Apply to:** FIX-01 (`AdaptationService.persistAdaptedPlan`), FIX-04 (`ProgressViewModel.loadProgress`)
```swift
let repo = WorkoutPlanRepository(context: viewContext)
```
Use `PersistenceController.shared.container.viewContext` when `viewContext` is not a stored property (AdaptationService currently has no stored `viewContext`). Follow `NotificationScheduler.init` pattern at line 36 for singleton context access:
```swift
private let context = PersistenceController.shared.container.viewContext
```

---

## No Analog Found

No files in this phase lack an analog. All fix patterns have direct reference implementations in the codebase.

---

## Metadata

**Analog search scope:** `WorkoutApp/Features/`, `WorkoutApp/Core/`, `WorkoutAppTests/`
**Files read:** 12 source files + 2 test files
**Pattern extraction date:** 2026-04-26
