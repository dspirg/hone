# Home Screen Exercise Swap

**Date:** 2026-05-12
**Status:** Approved

## Problem

Users can't swap exercises from the Home screen's "Today's Workout" card before starting a session. If equipment is taken at a public gym or they want to avoid an exercise, they have no pre-session option to substitute.

## Approach

Add a labeled "Swap" button to each exercise row on the Home workout card. Reuse the existing `ExerciseSwapSheet` (already built for the session view). Persist swaps to CoreData so they survive app restart.

## UI Changes

### Hint Text
Below the exercise count ("5 exercises") in the workout card, add:
- Text: *"Tap swap to replace with a similar movement"*
- Style: `.caption`, `.secondary` color, italic
- Always visible (not conditional)

### Swap Button (per exercise row)
Added to trailing edge of each `HomeExerciseRowView`:
- Layout: `HStack` with `arrow.triangle.swap` icon (12pt) + "Swap" text (`.caption`)
- Colors: `.secondary` foreground
- Background: `Theme.surfaceElevated` with 1pt `Theme.borderSubtle` border, `cornerRadius: 8`
- Tap action: fires `onSwap` callback, which presents `ExerciseSwapSheet`

### ExerciseSwapSheet
Already exists at `WorkoutApp/Features/Session/Components/ExerciseSwapSheet.swift`. No changes needed — it accepts a `PlannedExercise` and returns a replacement via `onSwap` callback. The replacement inherits the original's sets, reps, and rest.

## Persistence

Swaps must be persisted to the active plan in CoreData so they survive app restart.

### WorkoutPlanRepository.swapExercise
New method that:
1. Fetches the active plan's `CDWorkoutPlan` entity
2. Decodes `rawJSON` to `WorkoutPlan`
3. Finds the matching `WorkoutDay` by `dayLabel`
4. Replaces the exercise at the given index with the replacement
5. Re-encodes the modified plan to JSON
6. Updates `rawJSON` on the CoreData entity
7. Saves context

Since `WorkoutPlan`/`WorkoutDay`/`PlannedExercise` use `let` properties (immutable Codable structs), the method rebuilds the struct chain with the replacement exercise using new instances.

### HomeViewModel.swapExercise
New method that:
1. Calls `WorkoutPlanRepository.swapExercise` to persist
2. Reloads the active plan to refresh the view

## Files Changed

1. **`HomeExerciseRowView.swift`** — add `onSwap` callback parameter + trailing swap button
2. **`HomeView.swift`** — add hint text in workout card, pass `onSwap` to each row, present `ExerciseSwapSheet` on tap, handle swap completion
3. **`HomeViewModel.swift`** — add `swapExercise(dayLabel:exerciseIndex:replacement:context:)` method
4. **`WorkoutPlanRepository.swift`** — add `swapExercise(userId:dayLabel:exerciseIndex:replacement:)` method

## Out of Scope

- Changes to `ExerciseSwapSheet` (reused as-is)
- Changes to session-view swap behavior
- Undo/revert swap functionality
- Tracking swap history
