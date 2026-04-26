# Phase 6: Progress Tracking - Pattern Map

**Mapped:** 2026-04-23
**Files analyzed:** 11 new/modified files
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkoutApp/Features/Progress/ProgressView.swift` | view (root tab) | request-response | `WorkoutApp/Features/Main/Tabs/CoachView.swift` | exact |
| `WorkoutApp/Features/Progress/ProgressViewModel.swift` | viewmodel | CRUD + transform | `WorkoutApp/Features/Coach/CoachViewModel.swift` | exact |
| `WorkoutApp/Features/Progress/Components/StreakCard.swift` | component | request-response | `WorkoutApp/Features/Main/Tabs/HomeView.swift` (card block) | role-match |
| `WorkoutApp/Features/Progress/Components/WeeklyRingView.swift` | component | transform | `WorkoutApp/Core/Components/OnboardingProgressView.swift` | role-match |
| `WorkoutApp/Features/Progress/Components/SessionHistoryRow.swift` | component | request-response | `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` | exact |
| `WorkoutApp/Features/Progress/Components/SessionDetailView.swift` | view | CRUD | `WorkoutApp/Features/Train/ExerciseDetailView.swift` | role-match |
| `WorkoutApp/Features/Progress/Components/ChartSectionView.swift` | component | transform | `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` (card container) | partial-match |
| `WorkoutApp/Features/Progress/Components/PRBadgeView.swift` | component | request-response | `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (StatCell) | role-match |
| `WorkoutApp/Core/Notifications/NotificationScheduler.swift` | service | event-driven | `WorkoutApp/Core/Sync/SessionSyncService.swift` | role-match |
| `WorkoutApp/Features/Main/MainTabView.swift` (modified) | view | request-response | self | self |
| `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (modified) | view | request-response | self | self |

---

## Pattern Assignments

### `WorkoutApp/Features/Progress/ProgressView.swift` (view, request-response)

**Analog:** `WorkoutApp/Features/Main/Tabs/CoachView.swift`

**Imports pattern** (lines 1-2):
```swift
import SwiftUI
```

**ViewModel ownership pattern** (CoachView lines 4-6):
```swift
struct CoachView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CoachViewModel()
```

**NavigationStack + ScrollView structure** (HomeView lines 14-16):
```swift
NavigationStack {
    ScrollView {
        VStack(spacing: 16) {
```

**onAppear/onDisappear lifecycle** (CoachView lines 126-128):
```swift
.onAppear { viewModel.onAppear(appState: appState) }
.onDisappear { viewModel.onDisappear() }
```

**NavigationLink row pattern** (ExerciseLibraryView lines 39-43):
```swift
NavigationLink {
    ExerciseDetailView(exercise: exercise)
} label: {
    ExerciseLibraryRowView(exercise: exercise)
}
```

**navigationTitle** (ExerciseLibraryView line 52):
```swift
.navigationTitle("Progress")
```

---

### `WorkoutApp/Features/Progress/ProgressViewModel.swift` (viewmodel, CRUD + transform)

**Analog:** `WorkoutApp/Features/Coach/CoachViewModel.swift` + `WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift`

**Class declaration pattern** (CoachViewModel lines 30-32):
```swift
@Observable
@MainActor
final class CoachViewModel {
```

**Cached userId pattern** (CoachViewModel lines 61-63, 88):
```swift
// Cached user ID — set from AppState.currentUser on onAppear
private var cachedUserId: String?

// In onAppear:
cachedUserId = appState.currentUser?.id.uuidString
```

**NSManagedObjectContext init pattern** (CoachViewModel lines 80-82):
```swift
init(context: NSManagedObjectContext? = nil) {
    self.viewContext = context ?? PersistenceController.shared.container.viewContext
}
```

**NSFetchRequest with predicate pattern** (CoachViewModel lines 165-176):
```swift
let request = NSFetchRequest<CDChatMessage>(entityName: "CDChatMessage")
request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
request.fetchLimit = limit
request.fetchOffset = offset

if let userId = getCurrentUserId() {
    request.predicate = NSPredicate(format: "userId == %@", userId)
}

do {
    let cdMessages = try viewContext.fetch(request)
    // ...
} catch {
    print("CoachViewModel: Failed to load messages: \(error)")
}
```

**completedAt != nil predicate** (SessionRepository lines 137-141 — the established project convention):
```swift
req.predicate = NSPredicate(
    format: "syncedToSupabase == NO AND completedAt != nil"
)
req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
```

**isLoading + defer pattern** (ExerciseLibraryViewModel lines 81-84):
```swift
isLoading = true
loadError = nil
defer { isLoading = false }
do {
    // ...
} catch {
    // ...
}
```

**Task { } in onAppear** (CoachViewModel lines 92):
```swift
Task { await fetchUserProfile(appState: appState) }
```

**Testing helper methods** (CoachViewModel lines 663-683):
```swift
/// For unit tests only — set internal state directly for state machine testing
func setChatStateForTesting(_ state: ChatState) {
    chatState = state
}
```

---

### `WorkoutApp/Features/Progress/Components/StreakCard.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Main/Tabs/HomeView.swift` (card block, lines 18-35)

**Card container pattern** (HomeView lines 30-35):
```swift
.frame(maxWidth: .infinity, alignment: .leading)
.padding(16)
.background(Color("CardBackground"))
.clipShape(RoundedRectangle(cornerRadius: 16))
.padding(.horizontal, 16)
```

**Prominent stat display** (SessionSummaryView StatCell, lines 87-100):
```swift
struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
```

**Streak number should use `.font(.largeTitle.weight(.bold))` or `.font(.system(size: 48, weight: .bold))` to be visually prominent (D-07). Copy StatCell's VStack(spacing: 4) + .accessibilityElement(children: .combine) pattern.**

---

### `WorkoutApp/Features/Progress/Components/WeeklyRingView.swift` (component, transform)

**Analog:** Research Pattern 3 (Circle.trim) — no existing ring in codebase. Use RESEARCH.md Pattern 3 directly.

**Note:** `WorkoutApp/Core/Components/OnboardingProgressView.swift` provides the closest structural reference for a progress indicator component, but WeeklyRingView uses `Circle().trim()` as specified in RESEARCH.md Pattern 3.

**AccentColor tint token** (consistent across codebase):
```swift
.stroke(Color("AccentColor"), style: StrokeStyle(lineWidth: 10, lineCap: .round))
```

**AccessibilityLabel pattern** (ExerciseLibraryRowView line 60):
```swift
.accessibilityLabel("Weekly completion: \(completed) of \(planned) sessions done")
```

---

### `WorkoutApp/Features/Progress/Components/SessionHistoryRow.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift`

**HStack row layout** (ExerciseLibraryRowView lines 21-61):
```swift
struct ExerciseLibraryRowView: View {
    let exercise: ExerciseModel

    var body: some View {
        HStack(spacing: 12) {
            // leading content
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(exercise.primaryMuscle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()
        }
        .accessibilityLabel("\(exercise.name), \(exercise.primaryMuscle)")
    }
}
```

**SessionHistoryRow adapts this to:** date (`.subheadline.weight(.semibold)`), workout name + exercise/set counts (`.subheadline`, `.secondary`), trailing chevron implied by NavigationLink wrapper in ProgressView.

**Minimum 44pt touch target:** The row is wrapped in NavigationLink which handles this automatically.

---

### `WorkoutApp/Features/Progress/Components/SessionDetailView.swift` (view, CRUD)

**Analog:** `WorkoutApp/Features/Train/ExerciseDetailView.swift`

**Navigation push destination pattern** (ExerciseLibraryView lines 39-43):
```swift
NavigationLink {
    ExerciseDetailView(exercise: exercise)
} label: { ... }
```

**NavigationStack with ScrollView + VStack** (HomeView lines 14-16):
```swift
NavigationStack {
    ScrollView {
        VStack(spacing: 16) {
```

**Background token** (SessionSummaryView line 69):
```swift
.background(Color("AppBackground").ignoresSafeArea())
```

**SessionDetailView receives a `CDSessionLog` and displays its set logs via the `setLogs` ordered relationship. Iterate with `(sessionLog.setLogs?.array as? [CDSetLog]) ?? []` — the same pattern used in `SessionRepository.finalizeSession()` (line 123).**

---

### `WorkoutApp/Features/Progress/Components/ChartSectionView.swift` (component, transform)

**Analog:** `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` (card container pattern)

**Card container with VStack** (PricingCardView lines 55-82):
```swift
VStack(alignment: .leading, spacing: 4) {
    // title
    // content
}
.frame(maxWidth: .infinity, alignment: .leading)
.padding(16)
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(Color("CardBackground"))
)
```

**ChartSectionView wraps each chart in a card matching this container. Title uses `.font(.headline)`, chart uses RESEARCH.md Pattern 1 (BarMark) or Pattern 2 (LineMark+AreaMark). Import `Charts` at the top of the file.**

**AccentColor for chart foreground** (RESEARCH.md Pattern 2):
```swift
.foregroundStyle(Color("AccentColor").opacity(0.7))
```

---

### `WorkoutApp/Features/Progress/Components/PRBadgeView.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — StatCell (lines 87-101)

**Inline badge pattern — VStack(spacing: 4)** (StatCell lines 89-98):
```swift
VStack(spacing: 4) {
    Text(value)
        .font(.title2.weight(.semibold))
    Text(label)
        .font(.subheadline)
        .foregroundStyle(.secondary)
}
.accessibilityElement(children: .combine)
```

**CardBackground + RoundedRectangle padding** (HomeView card block lines 30-34):
```swift
.padding(16)
.background(Color("CardBackground"))
.clipShape(RoundedRectangle(cornerRadius: 16))
```

**PRBadgeView is an inline badge (not a full card). It receives `[PRResult]` and renders one row per PR with exercise name, new record, and previous best. Inject below the HStack stats block in SessionSummaryView when `prs.isEmpty == false`.**

---

### `WorkoutApp/Core/Notifications/NotificationScheduler.swift` (service, event-driven)

**Analog:** `WorkoutApp/Core/Sync/SessionSyncService.swift`

**Service class declaration** (SessionSyncService lines 24-26):
```swift
@Observable
@MainActor
final class SessionSyncService {
```

**Dependency-injected init for testability** (SessionSyncService lines 41-43):
```swift
init(repository: SessionRepository = SessionRepository()) {
    self.repository = repository
}
```

**Injected NSManagedObjectContext for CoreData queries** (CoachViewModel lines 80-82):
```swift
init(context: NSManagedObjectContext? = nil) {
    self.viewContext = context ?? PersistenceController.shared.container.viewContext
}
```

**isSyncing guard to prevent concurrent operations** (SessionSyncService lines 54):
```swift
guard let self, !self.isSyncing else { return }
```

**NSFetchRequest predicate for user-scoped query** (CoachViewModel lines 170-172):
```swift
if let userId = getCurrentUserId() {
    request.predicate = NSPredicate(format: "userId == %@", userId)
}
```

**do/catch with print on failure** (CoachViewModel lines 141-145):
```swift
} catch {
    // Fallback: non-fatal failure
    print("NotificationScheduler: [operation] failed: \(error)")
}
```

**NotificationScheduler does NOT need `@Observable` if it has no published UI state. Use `final class` with injected context only. Expose async methods: `scheduleWorkoutReminders(planDays:currentStreak:)`, `cancelAllWorkoutReminders()`, `hasLoggedSessionToday() -> Bool`.**

---

### `WorkoutApp/Features/Main/MainTabView.swift` (modified)

**Analog:** self (lines 1-34)

**Current tab item pattern** (MainTabView lines 11-14):
```swift
HomeView()
    .tabItem {
        Label("Home", systemImage: "house")
    }
```

**Add Progress tab between Coach and Profile** (D-01, D-02):
```swift
ProgressView()
    .tabItem {
        Label("Progress", systemImage: "chart.bar.fill")
    }
```

**AccentColor tint** (MainTabView line 32-33):
```swift
// Active tab icon + label tint (UI-SPEC Color Token: Accent)
.tint(Color("AccentColor"))
```

---

### `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (modified)

**Analog:** self (lines 1-118)

**Existing stats HStack** (SessionSummaryView lines 46-51):
```swift
HStack(spacing: 32) {
    StatCell(label: "Exercises", value: "\(totalExercises)")
    StatCell(label: "Sets", value: "\(totalSets)")
    StatCell(label: "Reps", value: "\(totalReps)")
}
.accessibilityElement(children: .combine)
```

**Injection site:** Add `let prs: [PRResult]` parameter (default `[]`) and inject PRBadgeView below the duration StatCell and above the `Spacer()`. Guard with `if !prs.isEmpty`.

**Caller update:** `SessionViewModel` will pass detected PRs to `SessionSummaryView` after `finalizeSession()` runs PR detection.

---

## Shared Patterns

### @Observable @MainActor ViewModel
**Source:** `WorkoutApp/Features/Coach/CoachViewModel.swift` lines 30-32, `WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift` lines 16-18
**Apply to:** `ProgressViewModel.swift`
```swift
@Observable
@MainActor
final class ProgressViewModel {
    // All state mutations are on @MainActor
    // NSFetchRequest used directly — NOT @FetchRequest property wrapper
}
```

### User-Scoped CoreData Queries
**Source:** `WorkoutApp/Features/Coach/CoachViewModel.swift` lines 170-172
**Apply to:** `ProgressViewModel.swift`, `NotificationScheduler.swift`
```swift
request.predicate = NSPredicate(format: "userId == %@", cachedUserId ?? "")
```
All NSFetchRequests for progress data must include `userId` predicate. Fail silently (empty result) if userId is nil.

### completedAt != nil Guard
**Source:** `WorkoutApp/Features/CoreData/SessionRepository.swift` lines 137-139
**Apply to:** Every NSFetchRequest in `ProgressViewModel.swift` that reads CDSessionLog
```swift
req.predicate = NSPredicate(format: "completedAt != nil AND userId == %@", userId)
```
In-progress sessions have `completedAt == nil`. All progress features must exclude them.

### CardBackground Token
**Source:** `WorkoutApp/Features/Main/Tabs/HomeView.swift` lines 33-34
**Apply to:** `StreakCard.swift`, `ChartSectionView.swift`, `PRBadgeView.swift`
```swift
.background(Color("CardBackground"))
.clipShape(RoundedRectangle(cornerRadius: 16))
```

### AccentColor Token
**Source:** `WorkoutApp/Features/Main/MainTabView.swift` line 32
**Apply to:** `WeeklyRingView.swift`, `ChartSectionView.swift`
```swift
Color("AccentColor")
```

### Non-Fatal Error Handling (print, no crash)
**Source:** `WorkoutApp/Features/Coach/CoachViewModel.swift` lines 141-145
**Apply to:** `ProgressViewModel.swift`, `NotificationScheduler.swift`
```swift
} catch {
    print("ProgressViewModel: fetchCompletedSessions failed: \(error)")
    // Leave state as-is (empty array) — view shows empty state
}
```

### AppBackground for Full-Screen Views
**Source:** `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` line 69
**Apply to:** `ProgressView.swift`, `SessionDetailView.swift`
```swift
.background(Color("AppBackground").ignoresSafeArea())
```

### Dependency-Injected Context for Tests
**Source:** `WorkoutApp/Features/Coach/CoachViewModel.swift` lines 80-82
**Apply to:** `ProgressViewModel.swift`, `NotificationScheduler.swift`
```swift
init(context: NSManagedObjectContext? = nil) {
    self.viewContext = context ?? PersistenceController.shared.container.viewContext
}
```

---

## Test File Patterns

### In-Memory CoreData Setup
**Source:** `WorkoutApp/WorkoutAppTests/SessionRepositoryTests.swift` lines 55-60
**Apply to:** `WorkoutAppTests/ProgressViewModelTests.swift`, `WorkoutAppTests/NotificationSchedulerTests.swift`
```swift
override func setUpWithError() throws {
    persistenceController = PersistenceController(inMemory: true)
    context = persistenceController.container.viewContext
    repository = SessionRepository(
        context: context,
        container: persistenceController.container
    )
}
```

### @MainActor test class
**Source:** `WorkoutApp/WorkoutAppTests/SessionRepositoryTests.swift` lines 14-15
**Apply to:** Both new test files
```swift
@MainActor
final class ProgressViewModelTests: XCTestCase {
```

### Fixture helpers as static funcs
**Source:** `WorkoutApp/WorkoutAppTests/SessionViewModelTests.swift` lines 16-36
**Apply to:** `ProgressViewModelTests.swift` — create `makeSessions(dates:)` helper that inserts CDSessionLog records with specified `completedAt` dates into the in-memory context.

---

## No Analog Found

All files have analogs. No entries.

---

## Metadata

**Analog search scope:** `WorkoutApp/Features/`, `WorkoutApp/Core/`, `WorkoutAppTests/`
**Files scanned:** 21 Swift source files + 21 test files
**Pattern extraction date:** 2026-04-23
