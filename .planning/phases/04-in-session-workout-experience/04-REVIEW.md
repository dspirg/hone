---
phase: 04-in-session-workout-experience
reviewed: 2026-04-23T12:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - supabase/migrations/20260422000000_create_session_logs.sql
  - WorkoutApp/Core/Sync/SessionSyncService.swift
  - WorkoutApp/Features/CoreData/SessionRepository.swift
  - WorkoutApp/Features/Main/Tabs/TrainView.swift
  - WorkoutApp/Features/Session/Components/ExerciseCardView.swift
  - WorkoutApp/Features/Session/Components/RestTimerOverlay.swift
  - WorkoutApp/Features/Session/Components/SessionProgressBar.swift
  - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
  - WorkoutApp/Features/Session/Components/SetLogRow.swift
  - WorkoutApp/Features/Session/SessionView.swift
  - WorkoutApp/Features/Session/SessionViewModel.swift
  - WorkoutAppTests/SessionRepositoryTests.swift
  - WorkoutAppTests/SessionSyncServiceTests.swift
  - WorkoutAppTests/SessionViewModelTests.swift
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-04-23T12:00:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

The in-session workout experience implementation is well-structured with clear separation of concerns (SessionViewModel, SessionRepository, SessionSyncService) and good threat mitigation documentation. The CoreData write-ahead pattern with Supabase sync is sound in design. However, there are two critical issues: a force-unwrap crash risk in the background CoreData write path, and invalid data being silently sent to Supabase when required fields are nil. There are also several warnings around silent error swallowing and a race condition between async session creation and set completion.

## Critical Issues

### CR-01: Force-unwrap of session.id in background context will crash

**File:** `WorkoutApp/Features/CoreData/SessionRepository.swift:86`
**Issue:** `sessionId!` force-unwraps the optional UUID captured from `session.id` on line 71. If `session.id` is ever nil (e.g., CoreData object not yet saved, or context reset), the app will crash on the background queue with no recovery path. This is in the `completeSet` hot path called every time a user logs a set.
**Fix:**
```swift
func completeSet(
    session: CDSessionLog,
    exercise: PlannedExercise,
    setNumber: Int,
    repsLogged: Int
) {
    let clampedReps = min(max(repsLogged, 0), 999)
    guard let sessionId = session.id else { return }

    container.performBackgroundTask { bgCtx in
        let setLog = CDSetLog(context: bgCtx)
        setLog.id = UUID()
        setLog.sessionId = sessionId
        setLog.exerciseName = exercise.exerciseName
        setLog.setNumber = Int16(min(setNumber, Int(Int16.max)))
        setLog.targetReps = exercise.reps
        setLog.repsLogged = Int16(clampedReps)
        setLog.completedAt = Date()
        setLog.syncedToSupabase = false

        let req = CDSessionLog.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        req.fetchLimit = 1
        if let bgSession = (try? bgCtx.fetch(req))?.first {
            bgSession.addToSetLogs(setLog)
        }
        try? bgCtx.save()
    }
}
```

### CR-02: Empty strings sent to Supabase for required fields (userId, planId)

**File:** `WorkoutApp/Core/Sync/SessionSyncService.swift:103-104`
**Issue:** When `s.userId` or `s.planId` are nil, empty strings are sent to Supabase via the `?? ""` fallback. The `session_logs` table has `user_id UUID NOT NULL` which means an empty string will either fail the UUID cast at the database level (causing a sync error that triggers the retry loop) or, worse, insert invalid data. The same pattern appears for `SetLogPayload` on lines 129-132 where `sessionId`, `userId`, and `exerciseName` all fall back to empty strings.
**Fix:**
```swift
let sessionRows = sessions.compactMap { s -> SessionLogRow? in
    guard let id = s.id,
          let userId = s.userId, !userId.isEmpty,
          let planId = s.planId,
          let completedAt = s.completedAt,
          let startedAt = s.startedAt else { return nil }
    return SessionLogRow(
        id: id.uuidString,
        userId: userId,
        planId: planId,
        workoutDayLabel: s.workoutDayLabel ?? "",
        startedAt: startedAt,
        completedAt: completedAt,
        totalExercises: Int(s.totalExercises),
        totalSets: Int(s.totalSets),
        totalReps: Int(s.totalReps)
    )
}
```
Apply the same guard pattern for `SetLogPayload` construction on lines 126-138.

## Warnings

### WR-01: Silent error swallowing on background context save

**File:** `WorkoutApp/Features/CoreData/SessionRepository.swift:91`
**Issue:** `try? bgCtx.save()` silently discards CoreData save errors in the `completeSet` background task. If the save fails (e.g., validation error, store conflict), the user's set completion data is permanently lost with no indication. This is the primary write path for workout data.
**Fix:** At minimum, log the error so it can be diagnosed. Consider adding an error callback or publishing a notification:
```swift
do {
    try bgCtx.save()
} catch {
    // Log for diagnostics — consider surfacing to the user in a future iteration
    print("[SessionRepository] Background save failed for set log: \(error)")
}
```

### WR-02: Race condition between async session creation and set completion

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:91-101, 113-114`
**Issue:** `startSession()` creates `sessionLog` inside a `Task` (line 91), but `completeSet` guards on `sessionLog` being non-nil (line 114). If the user taps the checkmark to complete a set before the `Task` in `startSession()` finishes, the `guard` fails silently and the set is never recorded. The test file acknowledges this race on line 94: "sessionLog may not be created yet due to async init." This is a real user-facing data loss scenario on slower devices.
**Fix:** Make `startSession()` async and await the CoreData write before allowing interaction, or make `sessionLog` creation synchronous since it is already on `@MainActor` and uses the view context:
```swift
func startSession() {
    sessionStartDate = Date()
    do {
        sessionLog = try repository.startSession(
            day: workoutDay,
            planId: planId,
            userId: userId
        )
    } catch {
        // CoreData write failure is non-fatal — session continues in memory
    }
    requestNotificationPermission()
}
```
This is safe because `SessionRepository.startSession` already runs on `@MainActor` with the view context.

### WR-03: Deprecated UIScreen.main usage

**File:** `WorkoutApp/Features/Session/SessionView.swift:105`
**Issue:** `UIScreen.main.bounds.width` is deprecated in iOS 16+. It also does not account for multi-scene (iPad split view) contexts correctly, though this is iOS-only for now.
**Fix:** Use `GeometryReader` to get the actual container width:
```swift
GeometryReader { geometry in
    ZStack {
        ForEach(Array(vm.exercises.enumerated()), id: \.offset) { index, exercise in
            ExerciseCardView(
                exercise: exercise,
                exerciseIndex: index,
                viewModel: vm
            )
            .offset(x: CGFloat(index - vm.currentExerciseIndex) * geometry.size.width)
        }
    }
}
```

### WR-04: NWPathMonitor cannot be restarted after cancel

**File:** `WorkoutApp/Core/Sync/SessionSyncService.swift:62-63`
**Issue:** `stopMonitoring()` calls `monitor.cancel()`, but `NWPathMonitor` cannot be restarted after cancellation. If `startMonitoring()` is called again on the same `SessionSyncService` instance (e.g., navigating back into a session), the monitor will silently fail to produce path updates. The `monitor` is initialized once as a `let` property on line 35.
**Fix:** Either create a new `NWPathMonitor` instance in `startMonitoring()`, or document that `SessionSyncService` instances are single-use:
```swift
private var monitor: NWPathMonitor?

func startMonitoring() {
    let newMonitor = NWPathMonitor()
    newMonitor.pathUpdateHandler = { [weak self] path in
        guard path.status == .satisfied else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.isSyncing else { return }
            await self.syncPendingLogs()
        }
    }
    newMonitor.start(queue: monitorQueue)
    monitor = newMonitor
}

func stopMonitoring() {
    monitor?.cancel()
    monitor = nil
}
```

## Info

### IN-01: Duplicated "Browse Exercises" NavigationLink in TrainView

**File:** `WorkoutApp/Features/Main/Tabs/TrainView.swift:42-56, 74-88`
**Issue:** The "Browse Exercises" NavigationLink is duplicated verbatim between the active-plan branch and the empty-state branch of the `if/else` in `body`. This is 14 lines of identical code.
**Fix:** Extract into a computed property:
```swift
private var browseExercisesLink: some View {
    NavigationLink(destination: ExerciseLibraryView()) {
        HStack {
            Label("Browse Exercises", systemImage: "list.bullet")
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
    .buttonStyle(.plain)
}
```

### IN-02: RestTimerOverlay ProgressView uses stale start date

**File:** `WorkoutApp/Features/Session/Components/RestTimerOverlay.swift:41`
**Issue:** `ProgressView(timerInterval: Date()...endDate, countsDown: true)` captures `Date()` at view body evaluation time. If SwiftUI re-evaluates `body` (e.g., after `extendRest()` updates `endDate`), the progress ring's start date resets to the current time, making the visual ring inaccurate relative to the original rest period start. This is a minor visual inconsistency rather than a functional bug.
**Fix:** Consider passing the rest start date from `SessionViewModel` alongside `endDate` to preserve the original timer interval across re-renders.

---

_Reviewed: 2026-04-23T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
