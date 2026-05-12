# Home Exercise Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Swap" button to each exercise on the Home screen's workout card, allowing users to replace exercises with alternatives before starting a session.

**Architecture:** Add `onSwap` callback to `HomeExerciseRowView`, wire `ExerciseSwapSheet` (already built) in `HomeView`, persist swaps by re-encoding the plan's `rawJSON` in CoreData via a new `WorkoutPlanRepository.swapExercise` method, and reload the view.

**Tech Stack:** SwiftUI, CoreData, `@Observable`

**Spec:** `docs/superpowers/specs/2026-05-12-home-exercise-swap-design.md`

---

### Task 1: Add swapExercise method to WorkoutPlanRepository

**Files:**
- Modify: `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift`

This method decodes the active plan from `rawJSON`, rebuilds the struct chain with the replacement exercise, re-encodes, and saves. Since all model types use `let` properties, we construct new instances.

- [ ] **Step 1: Add swapExercise method**

Add the following method after the `deactivateAllPlans` method (after line 98):

```swift
// MARK: - Swap Exercise

/// Replaces a single exercise in the active plan and persists the change.
/// Rebuilds the immutable WorkoutPlan/WorkoutDay/PlannedExercise chain and re-encodes rawJSON.
func swapExercise(userId: String, dayLabel: String, exerciseIndex: Int, replacement: PlannedExercise) throws {
    let request = CDWorkoutPlan.fetchRequest()
    request.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
    request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
    request.fetchLimit = 1

    guard let cdPlan = try context.fetch(request).first,
          let rawJSON = cdPlan.rawJSON else { return }

    let plan = try JSONDecoder().decode(WorkoutPlan.self, from: rawJSON)

    let updatedDays = plan.weeklyDays.map { day -> WorkoutDay in
        guard day.dayLabel == dayLabel else { return day }
        var updatedExercises = day.exercises
        guard exerciseIndex >= 0, exerciseIndex < updatedExercises.count else { return day }
        updatedExercises[exerciseIndex] = replacement
        return WorkoutDay(dayLabel: day.dayLabel, sessionName: day.sessionName, exercises: updatedExercises)
    }

    let updatedPlan = WorkoutPlan(planName: plan.planName, goalSummary: plan.goalSummary, weeklyDays: updatedDays)
    cdPlan.rawJSON = try JSONEncoder().encode(updatedPlan)
    try context.save()
}
```

- [ ] **Step 2: Make WorkoutDay and WorkoutPlan have memberwise inits accessible**

The `WorkoutDay` and `WorkoutPlan` structs use `let` properties with `CodingKeys`. Swift auto-generates memberwise inits for structs, but since they conform to `Codable` with custom `CodingKeys`, the memberwise init uses the Swift property names (not the JSON keys). The code in Step 1 calls `WorkoutDay(dayLabel:sessionName:exercises:)` and `WorkoutPlan(planName:goalSummary:weeklyDays:)` — these are the auto-generated memberwise inits and should work. However, `WorkoutDay.exercises` is declared as `let exercises: [PlannedExercise]` — we need to verify this compiles.

Read `WorkoutApp/Features/Models/WorkoutPlan.swift` and confirm:
- `WorkoutDay` has `let dayLabel: String`, `let sessionName: String`, `let exercises: [PlannedExercise]` — memberwise init works.
- `WorkoutPlan` has `let planName: String`, `let goalSummary: String`, `let weeklyDays: [WorkoutDay]` — memberwise init works.

No changes needed to `WorkoutPlan.swift` — the auto-generated memberwise inits accept the property names.

- [ ] **Step 3: Commit**

```bash
git add WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift
git commit -m "feat: add swapExercise method to WorkoutPlanRepository"
```

---

### Task 2: Add swapExercise to HomeViewModel

**Files:**
- Modify: `WorkoutApp/Features/Main/HomeViewModel.swift`

- [ ] **Step 1: Add swapExercise method**

Add the following method after `load(appState:adaptationService:context:)` (after line 70):

```swift
// MARK: - Swap Exercise

/// Persists an exercise swap to CoreData and reloads the plan.
func swapExercise(
    dayLabel: String,
    exerciseIndex: Int,
    replacement: PlannedExercise,
    appState: AppState,
    adaptationService: AdaptationService,
    context: NSManagedObjectContext
) async {
    guard let userId = appState.currentUser?.id.uuidString else { return }
    do {
        let repo = WorkoutPlanRepository(context: context)
        try repo.swapExercise(userId: userId, dayLabel: dayLabel, exerciseIndex: exerciseIndex, replacement: replacement)
        await load(appState: appState, adaptationService: adaptationService, context: context)
    } catch {
        loadError = "Couldn't swap exercise"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WorkoutApp/Features/Main/HomeViewModel.swift
git commit -m "feat: add swapExercise method to HomeViewModel"
```

---

### Task 3: Add swap button to HomeExerciseRowView

**Files:**
- Modify: `WorkoutApp/Features/Main/Components/HomeExerciseRowView.swift`

- [ ] **Step 1: Add onSwap callback parameter**

Add a new property after line 16 (`let exercise: PlannedExercise`):

```swift
var onSwap: (() -> Void)? = nil
```

- [ ] **Step 2: Add swap button to the row**

Replace the `Spacer()` at line 73 with:

```swift
Spacer()

if let onSwap {
    Button(action: onSwap) {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 12))
            Text("Swap")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 3: Update Preview to include onSwap**

In the `#Preview` block, add `onSwap: {}` to both `HomeExerciseRowView` instances. Change:

```swift
HomeExerciseRowView(exercise: PlannedExercise(
```

to:

```swift
HomeExerciseRowView(exercise: PlannedExercise(
```

Actually, since `onSwap` defaults to `nil`, the preview doesn't need changes. But to see the button in preview, optionally add `onSwap: {}`.

- [ ] **Step 4: Commit**

```bash
git add WorkoutApp/Features/Main/Components/HomeExerciseRowView.swift
git commit -m "feat: add swap button to HomeExerciseRowView"
```

---

### Task 4: Wire swap sheet and hint text in HomeView

**Files:**
- Modify: `WorkoutApp/Features/Main/Tabs/HomeView.swift`

This is the integration task — add hint text, pass `onSwap` to each row, present `ExerciseSwapSheet`, handle swap completion.

- [ ] **Step 1: Add state for swap sheet**

Add after `@State private var pendingSessionDay: WorkoutDay? = nil` (line 31):

```swift
@State private var swapTarget: (dayLabel: String, exerciseIndex: Int, exercise: PlannedExercise)? = nil
```

- [ ] **Step 2: Add hint text in workout card**

In the `workoutCard` function, after the exercise count text (line 253):

```swift
Text("\(day.exercises.count) exercises")
    .font(.body)
    .foregroundStyle(.secondary)
```

Add the hint text:

```swift
Text("Tap swap to replace with a similar movement")
    .font(.caption)
    .foregroundStyle(.secondary)
    .italic()
```

- [ ] **Step 3: Update exercise ForEach to pass onSwap**

Replace the exercise `ForEach` block (lines 257-262):

```swift
ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, exercise in
    HomeExerciseRowView(exercise: exercise)
    if index < day.exercises.count - 1 {
        Divider()
    }
}
```

with:

```swift
ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, exercise in
    HomeExerciseRowView(exercise: exercise) {
        swapTarget = (dayLabel: day.dayLabel, exerciseIndex: index, exercise: exercise)
    }
    if index < day.exercises.count - 1 {
        Divider()
    }
}
```

- [ ] **Step 4: Add swap sheet presentation**

Add a `.sheet` modifier after the existing `.sheet(isPresented: $showTimePicker)` block (after line 197):

```swift
.sheet(item: $swapTarget) { target in
    ExerciseSwapSheet(currentExercise: target.exercise) { replacement in
        Task {
            await viewModel.swapExercise(
                dayLabel: target.dayLabel,
                exerciseIndex: target.exerciseIndex,
                replacement: replacement,
                appState: appState,
                adaptationService: adaptationService,
                context: context
            )
        }
    }
    .presentationDetents([.large])
}
```

- [ ] **Step 5: Make swapTarget tuple conform to Identifiable for .sheet(item:)**

The `.sheet(item:)` modifier requires the binding to be `Identifiable`. A tuple can't conform to `Identifiable`. Add a small wrapper struct inside `HomeView` (before `var body`):

Replace the `@State private var swapTarget` declaration from Step 1 with:

```swift
@State private var swapTarget: SwapTarget? = nil

struct SwapTarget: Identifiable {
    let dayLabel: String
    let exerciseIndex: Int
    let exercise: PlannedExercise
    var id: String { "\(dayLabel)-\(exerciseIndex)" }
}
```

And update Step 3 to use:

```swift
swapTarget = SwapTarget(dayLabel: day.dayLabel, exerciseIndex: index, exercise: exercise)
```

And update Step 4 `.sheet` to use:

```swift
.sheet(item: $swapTarget) { target in
    ExerciseSwapSheet(currentExercise: target.exercise) { replacement in
        Task {
            await viewModel.swapExercise(
                dayLabel: target.dayLabel,
                exerciseIndex: target.exerciseIndex,
                replacement: replacement,
                appState: appState,
                adaptationService: adaptationService,
                context: context
            )
        }
    }
    .presentationDetents([.large])
}
```

- [ ] **Step 6: Build to verify**

Run: `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "BUILD|error:" | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add WorkoutApp/Features/Main/Tabs/HomeView.swift
git commit -m "feat: wire exercise swap sheet on Home workout card with hint text"
```
