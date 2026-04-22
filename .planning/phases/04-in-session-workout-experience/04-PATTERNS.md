# Phase 4: In-Session Workout Experience - Pattern Map

**Mapped:** 2026-04-22
**Files analyzed:** 11 new/modified files
**Analogs found:** 10 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkoutApp/Features/Session/SessionView.swift` | component (root view) | request-response | `WorkoutApp/Features/Onboarding/OnboardingView.swift` | role-match (ZStack card switching, progress bar, flow container) |
| `WorkoutApp/Features/Session/SessionViewModel.swift` | service/view-model | event-driven | `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` | role-match (@Observable @MainActor, Task lifecycle, state enum) |
| `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` | component | request-response | `WorkoutApp/Features/Train/ExerciseDetailView.swift` | exact (video top + metadata/logging below, VideoPlayerView embed) |
| `WorkoutApp/Features/Session/Components/SetLogRow.swift` | component | event-driven | `WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift` | partial-match (row component with tappable controls) |
| `WorkoutApp/Features/Session/Components/RestTimerOverlay.swift` | component | event-driven | `WorkoutApp/Features/Onboarding/OnboardingView.swift` | partial-match (ZStack overlay pattern, no fullScreenCover) |
| `WorkoutApp/Features/Session/Components/SessionProgressBar.swift` | component | request-response | `WorkoutApp/Core/Components/OnboardingProgressView.swift` | exact (segmented progress bar, "N of M" pill, spring animation) |
| `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` | component | request-response | `WorkoutApp/Features/PlanPreview/PlanPreviewView.swift` | partial-match (end-of-flow completion screen) |
| `WorkoutApp/Features/CoreData/SessionRepository.swift` | service | CRUD | `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift` | exact (CoreData CRUD, @MainActor, performBackgroundTask, NSPredicate) |
| `WorkoutApp/Core/Sync/SessionSyncService.swift` | service | event-driven | `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` | role-match (@Observable @MainActor, async Task, retry logic) |
| `supabase/migrations/YYYYMMDDHHMMSS_create_session_logs.sql` | migration | CRUD | `supabase/migrations/00000002000000_create_workout_plans.sql` | exact (UUID PK, RLS pattern, CASCADE FK) |
| `WorkoutApp/Features/Main/Tabs/TrainView.swift` | component | request-response | `WorkoutApp/Features/Main/Tabs/TrainView.swift` | self (modification — add active plan + Start Workout button) |

---

## Pattern Assignments

### `WorkoutApp/Features/Session/SessionView.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Onboarding/OnboardingView.swift`

**Imports pattern** (lines 1-2):
```swift
import SwiftUI
```

**Core ZStack card-switching pattern** (lines 7-57 of OnboardingView):
```swift
// Root container: ZStack background + VStack(top bar, card area)
struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: back control + progress indicator + trailing control
                HStack { ... }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Card area — ZStack with transition
                ZStack {
                    cardForCurrentStep
                        .id(viewModel.currentStep)
                        .transition(cardTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
```

**Card transition pattern** (lines 78-93 of OnboardingView):
```swift
private var cardTransition: AnyTransition {
    if reduceMotion { return .opacity }
    return viewModel.isGoingForward
        ? .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
          )
        : .asymmetric(
            insertion: .move(edge: .leading),
            removal: .move(edge: .trailing)
          )
}
```

**Adaptation note for SessionView:** Replace `cardForCurrentStep` with `exercises[currentExerciseIndex]` driven by `SessionViewModel.currentExerciseIndex`. Replace `OnboardingProgressView` with `SessionProgressBar`. Wrap `RestTimerOverlay` as a ZStack layer above `ExerciseCardView` (NOT `.fullScreenCover` — see Pitfall 2 in RESEARCH.md). The `ZStack overlay` approach keeps `VideoPlayerView` alive in the hierarchy.

---

### `WorkoutApp/Features/Session/SessionViewModel.swift` (view-model, event-driven)

**Analog:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift`

**Class declaration pattern** (lines 37-65 of PlanGenerationService):
```swift
@Observable
@MainActor
final class PlanGenerationService {
    var state: GenerationState = .idle

    // @ObservationIgnored prevents @Observable from double-tracking
    // persisted properties (AppStorage, etc.)
    @ObservationIgnored
    @AppStorage("regenCountUsed") private var regenCountUsed: Int = 0

    // Track current task so it can be cancelled
    @ObservationIgnored private var currentStreamTask: Task<Void, Never>?
```

**Task lifecycle + cancellation pattern** (lines 77-137 of PlanGenerationService):
```swift
func generatePlan(profile: UserProfile, isRetry: Bool = false) {
    currentStreamTask?.cancel()
    state = .streaming(partialText: "")

    currentStreamTask = Task {
        do {
            // ... async work
        } catch {
            if Task.isCancelled { return }
            // error handling
        }
    }
}
```

**Supabase insert pattern** (lines 186-233 of PlanGenerationService):
```swift
private func savePlanToSupabase(plan: WorkoutPlan, profile: UserProfile) async throws -> String {
    let userId = try await supabase.auth.session.user.id

    struct PlanRow: Encodable {
        let user_id: String
        let plan_name: String
        // ... fields
    }

    let response = try await supabase
        .from("workout_plans")
        .insert(row)
        .select("id")
        .single()
        .execute()
}
```

**Adaptation note for SessionViewModel:** State enum should be `SessionState: idle | active | restTimer(endDate: Date) | complete`. Replace `currentStreamTask` with `@ObservationIgnored private var syncTask: Task<Void, Never>?`. Add `currentExerciseIndex: Int`, `timerEndDate: Date?`, `isRestTimerActive: Bool` as `@Observable`-tracked properties. Owns `SessionRepository` and `SessionSyncService` instances.

---

### `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Train/ExerciseDetailView.swift`

**Imports pattern** (lines 1-2 of ExerciseDetailView):
```swift
import SwiftUI
```

**VideoPlayerView embed pattern** (lines 15-29 of ExerciseDetailView):
```swift
// Video player or placeholder based on exercise.hasVideo
if let playbackId = exercise.muxPlaybackId {
    VideoPlayerView(
        muxPlaybackId: playbackId,
        localAssetURL: exercise.localAssetURL.flatMap { URL(string: $0) }
    )
    .aspectRatio(16 / 9, contentMode: .fit)
} else if let videoUrl = exercise.videoUrl, let url = URL(string: videoUrl) {
    VideoPlayerView(
        muxPlaybackId: "",
        localAssetURL: url
    )
    .aspectRatio(16 / 9, contentMode: .fit)
} else {
    ExercisePlaceholderView(exerciseName: exercise.name)
}
```

**Content layout pattern** (lines 12-93 of ExerciseDetailView):
```swift
ScrollView {
    VStack(spacing: 0) {
        // Video/placeholder at top
        // ... (video block above)

        // Content below video
        VStack(alignment: .leading, spacing: 16) {
            Text(exercise.name)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            // ... additional content
        }
        .padding(.horizontal, 32)  // xl spacing per UI-SPEC
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
```

**Adaptation note for ExerciseCardView:** Replace the "How To" / "Form Tips" section below the video with `SetLogRow` views (one per planned set). Add a "Next Exercise" / "Finish" primary button at the bottom. The `ScrollView` wrapper remains — set logging rows may overflow on small devices. Look up `muxPlaybackId` from the `Exercise` CoreData entity by matching `PlannedExercise.exerciseName` string; fall back to `ExercisePlaceholderView` if not found.

---

### `WorkoutApp/Features/Session/Components/SetLogRow.swift` (component, event-driven)

**Analog:** `WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift`

**Row component pattern** (lines 1-50 of ExerciseRowView):
```swift
import SwiftUI

struct ExerciseRowView: View {
    let exercise: PlannedExercise

    var body: some View {
        HStack(spacing: 12) {
            // Leading label content
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(exercise.sets) sets · \(exercise.reps) reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // Trailing control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

**Adaptation note for SetLogRow:** Replace trailing content with a `Stepper`-style +/- control and rep count display. Add a checkmark `Button` (SF Symbol `checkmark.circle` / `checkmark.circle.fill`) that triggers `sessionViewModel.completeSet(index:repsLogged:)`. Tap on rep number opens number pad (`.keyboardType(.numberPad)`). Completed sets show filled checkmark + dimmed row styling.

---

### `WorkoutApp/Features/Session/Components/RestTimerOverlay.swift` (component, event-driven)

**Analog:** `WorkoutApp/Features/Onboarding/OnboardingView.swift` (ZStack overlay structure)

**ZStack overlay pattern** (lines 12-58 of OnboardingView):
```swift
// ZStack as overlay container — no fullScreenCover
// Keeps underlying view (ExerciseCardView + VideoPlayerView) alive in hierarchy
ZStack {
    Color("AppBackground").ignoresSafeArea()  // full-bleed background layer

    VStack(spacing: 0) {
        // ... content
    }
}
```

**Sensory feedback pattern** (from RESEARCH.md Pattern 5):
```swift
// iOS 17+ declarative haptic — no UIKit import needed
.sensoryFeedback(.success, trigger: timerExpired)
```

**Timer expiry detection** (from RESEARCH.md Pattern 1):
```swift
// Lightweight expire check while overlay is on screen
.onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
    if !expired && now >= timerEndDate {
        expired = true
        onSkip()  // auto-dismiss when expired
    }
}
```

**ProgressView timer ring** (from RESEARCH.md Pattern 1):
```swift
// Date-anchored circular ring — auto-corrects on foreground resume
ProgressView(timerInterval: Date()...endDate, countsDown: true) {
    EmptyView()
} currentValueLabel: {
    Text(endDate, style: .timer)
        .font(.system(size: 64, weight: .bold, design: .rounded))
        .monospacedDigit()
}
.progressViewStyle(.circular)
.tint(Color("AccentColor"))
.frame(width: 200, height: 200)
```

**Adaptation note for RestTimerOverlay:** Rendered as a ZStack layer inside `SessionView` (above `ExerciseCardView`), controlled by `sessionViewModel.isRestTimerActive`. Use `Color.black.opacity(0.85).ignoresSafeArea()` as the backdrop. Show "Next: [exercise name]" or "Next: [set number]" as context text below the ring. Schedule `UNUserNotificationCenter` notification at timer start in `SessionViewModel`, not in the overlay — overlay is display-only.

---

### `WorkoutApp/Features/Session/Components/SessionProgressBar.swift` (component, request-response)

**Analog:** `WorkoutApp/Core/Components/OnboardingProgressView.swift`

**Full implementation** (lines 7-43 of OnboardingProgressView):
```swift
struct OnboardingProgressView: View {
    let currentStep: Int   // 0-indexed
    let totalSteps: Int
    let progress: Double   // 0.0 to 1.0

    var body: some View {
        VStack(spacing: 8) {
            // "2 of 5" pill
            Text("\(currentStep + 1) of \(totalSteps)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color("CardBackground"))
                .clipShape(Capsule())

            // 3pt animated progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiaryLabel).opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color("AccentColor"))
                        .frame(width: geometry.size.width * progress, height: 3)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .accessibilityHidden(true)
        }
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}
```

**Adaptation note for SessionProgressBar:** This is a near-direct copy. Rename to `SessionProgressBar`, change parameter names to `currentExercise`/`totalExercises`. Change pill copy from "N of M" to "Exercise N of M". The segmented bar visual is identical. The `OnboardingProgressView` is being deleted (per git status) so there is no source conflict — copy the implementation directly.

---

### `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/PlanPreview/PlanPreviewView.swift` (completion/summary screen pattern)

**Imports pattern** (lines 1-2 of PlanPreviewView):
```swift
import SwiftUI
```

**Full-screen summary layout pattern** — use `WorkoutDayCardView` as structural reference (lines 13-49):
```swift
struct WorkoutDayCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header text — .title2 semibold
            Text(day.sessionName)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)

            // Secondary label
            Text(day.dayLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            Spacer().frame(height: 8)
            Divider().padding(.leading, 16)

            // Row list
            ForEach(day.exercises) { exercise in
                ExerciseRowView(exercise: exercise)
                if exercise.id != day.exercises.last?.id {
                    Divider().padding(.leading, 16)
                }
            }

            Spacer().frame(height: 8)
        }
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}
```

**Adaptation note for SessionSummaryView:** Layout: `Color("AppBackground").ignoresSafeArea()` background, centered `VStack` with large title ("Great work."), stat rows (exercises completed, total sets, total reps, duration), a `CardBackground` card wrapping the stats, and a "Done" primary button at the bottom that pops the navigation stack. Stats are read from `CDSessionLog` passed in on init — no async fetch needed.

---

### `WorkoutApp/Features/CoreData/SessionRepository.swift` (service, CRUD)

**Analog:** `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift`

**Full class pattern** (lines 1-96 of WorkoutPlanRepository):
```swift
import CoreData
import Foundation

@MainActor
final class WorkoutPlanRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Save
    func save(plan: WorkoutPlan, supabaseId: String, userId: String) throws {
        let cdPlan = CDWorkoutPlan(context: context)
        cdPlan.id = UUID()
        cdPlan.userId = userId
        // ... field assignment
        try context.save()
    }

    // MARK: - Fetch
    func fetchActivePlan(userId: String) throws -> WorkoutPlan? {
        let request = CDWorkoutPlan.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1
        guard let cdPlan = try context.fetch(request).first else { return nil }
        return try JSONDecoder().decode(WorkoutPlan.self, from: cdPlan.rawJSON!)
    }
}
```

**Background context write pattern** (lines 13-15 of PersistenceController + RESEARCH.md Pattern 2):
```swift
// Background save — mirrors existing PersistenceController threading model
container.performBackgroundTask { backgroundContext in
    let setLog = CDSetLog(context: backgroundContext)
    setLog.id = UUID()
    setLog.sessionId = sessionLog.id
    setLog.exerciseName = exercise.exerciseName
    setLog.setNumber = Int16(setIndex + 1)
    setLog.targetReps = exercise.reps
    setLog.repsLogged = Int16(repsLogged)
    setLog.completedAt = Date()
    setLog.syncedToSupabase = false
    try? backgroundContext.save()
}
```

**Fetch unsynced records pattern** (based on WorkoutPlanRepository.fetchActivePlan lines 68-79):
```swift
// Fetch all unsynced session logs for sync pass
func fetchUnsyncedSessionLogs() throws -> [CDSessionLog] {
    let request = CDSessionLog.fetchRequest()
    request.predicate = NSPredicate(format: "syncedToSupabase == NO")
    request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
    return try context.fetch(request)
}
```

**Adaptation note for SessionRepository:** Add three public methods: `createSessionLog(userId:planId:workoutDayLabel:exercises:) -> CDSessionLog`, `completeSet(sessionLog:exercise:setIndex:repsLogged:)` (background context write), and `completeSession(sessionLog:)` (sets `completedAt`, computes totals, saves). Add `fetchUnsyncedSessionLogs()` and `fetchUnsyncedSetLogs(sessionId:)` for sync pass. Add `markSynced(sessionLog:)` and `markSynced(setLog:)` to flip `syncedToSupabase = true` after successful Supabase upsert.

---

### `WorkoutApp/Core/Sync/SessionSyncService.swift` (service, event-driven)

**Analog:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift`

**@Observable @MainActor service class pattern** (lines 37-65 of PlanGenerationService):
```swift
@Observable
@MainActor
final class PlanGenerationService {
    var state: GenerationState = .idle
    @ObservationIgnored private var currentStreamTask: Task<Void, Never>?
```

**Retry loop pattern** (lines 121-136 of PlanGenerationService):
```swift
// D-16: Auto-retry once on first failure
if !isRetry {
    generatePlan(profile: profile, isRetry: true)
} else {
    state = .error("Something went wrong...")
}
```

**Supabase upsert pattern** (from RESEARCH.md Pattern 4):
```swift
struct SetLogRow: Encodable {
    let id: String
    let sessionId: String
    let userId: String
    let exerciseName: String
    let setNumber: Int
    let targetReps: String
    let repsLogged: Int
    let completedAt: Date
}

try await supabase
    .from("set_logs")
    .upsert(rows, onConflict: "id")
    .execute()
```

**Adaptation note for SessionSyncService:** `@Observable @MainActor final class`. Public properties: `syncBannerVisible: Bool`, `isSyncing: Bool`. Private: `monitor = NWPathMonitor()`, `monitorQueue = DispatchQueue(label: "com.workoutapp.network-monitor")`. `startMonitoring()` sets `monitor.pathUpdateHandler` — guard `!isSyncing` before launching sync Task (Pitfall 4 in RESEARCH.md). `stopMonitoring()` calls `monitor.cancel()`. `syncPendingLogs()` is `private async` with `defer { isSyncing = false }` and `retryCount < 3` loop. On final failure sets `syncBannerVisible = true`.

---

### `supabase/migrations/YYYYMMDDHHMMSS_create_session_logs.sql` (migration, CRUD)

**Analog:** `supabase/migrations/00000002000000_create_workout_plans.sql`

**Full migration structure** (lines 1-29 of create_workout_plans.sql):
```sql
-- Phase N: Create table with RLS
-- Requirements: [requirement IDs]

CREATE TABLE public.workout_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    -- ... columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own plans"
    ON public.workout_plans FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own plans"
    ON public.workout_plans FOR INSERT
    WITH CHECK (auth.uid() = user_id);
```

**Adaptation note for session_logs migration:** Use device-generated UUID as PK (no `DEFAULT gen_random_uuid()` — the iOS client sends the UUID). Two tables in one migration file: `session_logs` then `set_logs`. `set_logs` references `session_logs(id) ON DELETE CASCADE` and also has `user_id` denormalized for direct RLS without join (standard Supabase pattern per RESEARCH.md). Add `UPDATE` policy only to `session_logs` (needed for `completed_at` backfill); `set_logs` is insert-only. Full schema is specified in RESEARCH.md Supabase Table Schema section.

---

### `WorkoutApp/Features/Main/Tabs/TrainView.swift` (modification)

**Self-analog:** Current file (lines 1-10):
```swift
import SwiftUI

// Current state — just wraps ExerciseLibraryView
struct TrainView: View {
    var body: some View {
        ExerciseLibraryView()
    }
}
```

**Target pattern — NavigationLink to SessionView** (from MainTabView / navigation patterns established in Phase 1-3):
```swift
// Pattern: NavigationStack with destination push (established throughout codebase)
NavigationStack {
    // ... active plan display
    NavigationLink(destination: SessionView(workoutDay: selectedDay)) {
        // "Start Workout" button
    }
}
```

**Adaptation note for TrainView:** Add `@Environment(AppState.self) var appState`. Fetch active plan from `WorkoutPlanRepository` on `.task`. Show active plan summary with a "Start Workout" `NavigationLink` that passes the selected `WorkoutDay` to `SessionView`. Retain `ExerciseLibraryView` as a secondary section below the plan. Follow the same `.task { }` async fetch pattern established in `ExerciseLibraryViewModel`.

---

## Shared Patterns

### @Observable @MainActor ViewModel Declaration
**Source:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` lines 37-64
**Apply to:** `SessionViewModel.swift`, `SessionSyncService.swift`
```swift
@Observable
@MainActor
final class MyService {
    // UI-bound state — tracked by @Observable
    var someState: Bool = false

    // Properties that must NOT be double-tracked
    @ObservationIgnored private var backgroundTask: Task<Void, Never>?
}
```

### CoreData Background Context Write
**Source:** `WorkoutApp/Core/Data/PersistenceController.swift` lines 44-46 + `WorkoutPlanRepository.swift` lines 28-60
**Apply to:** `SessionRepository.swift` (all write operations)
```swift
// Write-ahead: always background context, never viewContext for writes
container.performBackgroundTask { ctx in
    let entity = CDEntity(context: ctx)
    entity.id = UUID()
    // ... field assignments
    try? ctx.save()
}
// viewContext picks up changes via automaticallyMergesChangesFromParent = true
```

### Supabase Table + RLS Policy
**Source:** `supabase/migrations/00000002000000_create_workout_plans.sql` lines 1-29
**Apply to:** `create_session_logs.sql` migration
```sql
ALTER TABLE public.my_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own records"
    ON public.my_table FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own records"
    ON public.my_table FOR INSERT
    WITH CHECK (auth.uid() = user_id);
```

### ZStack Card Navigation with Asymmetric Transition
**Source:** `WorkoutApp/Features/Onboarding/OnboardingView.swift` lines 51-57, 78-93
**Apply to:** `SessionView.swift` (exercise card switching)
```swift
ZStack {
    cardForCurrentStep
        .id(viewModel.currentStep)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        )
}
.animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentIndex)
```

### VideoPlayerView Embed with Placeholder Fallback
**Source:** `WorkoutApp/Features/Train/ExerciseDetailView.swift` lines 15-29
**Apply to:** `ExerciseCardView.swift`
```swift
if let playbackId = exercise.muxPlaybackId {
    VideoPlayerView(muxPlaybackId: playbackId, localAssetURL: ...)
        .aspectRatio(16 / 9, contentMode: .fit)
} else {
    ExercisePlaceholderView(exerciseName: exercise.name)
}
```

### Color + Typography Tokens
**Source:** `WorkoutApp/Features/PlanPreview/Components/WorkoutDayCardView.swift` lines 18-48
**Apply to:** All Phase 4 views
```swift
// Established semantic colors — copy exactly
Color("AppBackground")     // screen background
Color("CardBackground")    // card fill, pill background
Color("AccentColor")       // primary action, progress fill
// Established type scale
.font(.title2.weight(.semibold))   // section headers
.font(.body)                        // primary content
.font(.subheadline).foregroundStyle(.secondary)  // secondary labels
// Established spacing
.padding(.horizontal, 16)  // md — standard horizontal padding
.padding(.vertical, 12)    // standard row padding
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | — | — | All files have at least a partial-match analog in the codebase |

**Note on RestTimerOverlay:** No existing overlay-within-ZStack component exists yet, but the structural pattern is derived from `OnboardingView`'s ZStack + the `ProgressView(timerInterval:)` approach documented in RESEARCH.md. The anti-pattern to avoid (`.fullScreenCover`) is explicitly established in RESEARCH.md Pitfall 2 and Pitfall section of CLAUDE.md constraints.

---

## Metadata

**Analog search scope:** `WorkoutApp/Features/`, `WorkoutApp/Core/`, `supabase/migrations/`
**Files scanned:** 44 Swift files + 5 SQL migration files
**Key structural decisions confirmed by codebase reading:**
- `@Observable @MainActor` is the established ViewModel pattern (PlanGenerationService, AppState, PlanPreviewViewModel)
- `container.performBackgroundTask` + `automaticallyMergesChangesFromParent = true` is the established CoreData write pattern (PersistenceController line 45)
- `NSMigratePersistentStoresAutomaticallyOption` + `NSInferMappingModelAutomaticallyOption` are already set — adding new CoreData entities is safe lightweight migration
- Supabase RLS uses `auth.uid() = user_id` pattern consistently across all existing migrations
- ZStack card switching with asymmetric `.move` transitions is the established flow navigation pattern (OnboardingView)
- `ExercisePlaceholderView` exists and is already used — carry forward as fallback in ExerciseCardView
- `OnboardingProgressView` is being deleted (git status shows D) — `SessionProgressBar` is a clean re-implementation of the same visual
- `VideoPlayerView` is the only video component — reuse directly; do not create a new one
**Pattern extraction date:** 2026-04-22
