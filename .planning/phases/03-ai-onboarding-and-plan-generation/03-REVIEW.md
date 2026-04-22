---
phase: 03-ai-onboarding-and-plan-generation
reviewed: 2026-04-22T00:00:00Z
depth: standard
files_reviewed: 27
files_reviewed_list:
  - supabase/functions/generate-plan/index.ts
  - supabase/migrations/00000001000000_add_profile_fitness_columns.sql
  - supabase/migrations/00000002000000_create_workout_plans.sql
  - WorkoutApp/Core/AppState.swift
  - WorkoutApp/Features/Main/Tabs/HomeView.swift
  - WorkoutApp/Features/Models/UserProfile.swift
  - WorkoutApp/Features/Models/WorkoutPlan.swift
  - WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift
  - WorkoutApp/Features/Onboarding/Cards/DaysPerWeekCardView.swift
  - WorkoutApp/Features/Onboarding/Cards/EquipmentCardView.swift
  - WorkoutApp/Features/Onboarding/Cards/FitnessLevelCardView.swift
  - WorkoutApp/Features/Onboarding/Cards/GoalCardView.swift
  - WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift
  - WorkoutApp/Features/Onboarding/OnboardingView.swift
  - WorkoutApp/Features/Onboarding/OnboardingViewModel.swift
  - WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift
  - WorkoutApp/Features/PlanPreview/Components/WorkoutDayCardView.swift
  - WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift
  - WorkoutApp/Features/PlanPreview/PlanGenerationService.swift
  - WorkoutApp/Features/PlanPreview/PlanPreviewView.swift
  - WorkoutApp/Features/PlanPreview/PlanPreviewViewModel.swift
  - WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift
  - WorkoutApp/WorkoutApp.swift
  - WorkoutAppTests/AppStateRoutingTests.swift
  - WorkoutAppTests/OnboardingViewModelTests.swift
  - WorkoutAppTests/PlanPreviewViewModelTests.swift
  - WorkoutAppTests/PlanPromptBuilderTests.swift
  - WorkoutAppTests/WorkoutPlanDecodingTests.swift
  - WorkoutAppTests/WorkoutPlanParserTests.swift
  - WorkoutAppTests/WorkoutPlanServiceTests.swift
findings:
  critical: 3
  warning: 6
  info: 4
  total: 13
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-22
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

This phase implements the AI onboarding flow and plan generation pipeline: a 5-step onboarding wizard, an SSE streaming client for GPT-4o plan generation via a Supabase Edge Function, CoreData persistence, and a plan preview screen. The architecture is well-structured and the deliberate design decisions (sequential persistence, `@AppStorage` for regen counter, manual JWT auth bypassing SDK bug #634) are clearly documented.

Three critical issues were found:

1. The Edge Function performs no server-side input validation or length limits on user-supplied strings before injecting them into the OpenAI prompt — a prompt-injection and abuse vector.
2. The Authorization header check in the Edge Function warns but does not reject unauthenticated requests, making the documented "JWT auth enforcement" a false guarantee.
3. The Supabase ID fallback in `savePlanToSupabase` silently discards the plan-to-Supabase linkage on decode failure, making future plan management (update/delete by ID) unreliable.

Six warnings cover logic gaps including: a race condition in the auto-retry flow, a `Timer` leak on rapid view cycling, a `completeOnboarding()` double-fire risk on the injuries card, an unguarded `onAppear` re-trigger in `PlanPreviewView`, an `Int16` overflow risk in `WorkoutPlanRepository`, and a missing `DELETE` RLS policy in the `workout_plans` migration.

---

## Critical Issues

### CR-01: Edge Function does not reject unauthenticated requests

**File:** `supabase/functions/generate-plan/index.ts:82`

**Issue:** The authorization check logs a warning and continues execution when the `Authorization` header is missing or malformed. The comment says "Supabase JWT verification middleware handles actual auth enforcement," but Supabase Edge Functions do NOT automatically verify JWTs unless the function is deployed with `verify_jwt = true` in `config.toml` (disabled by default in self-hosted and often in managed deployments). Without an explicit rejection here, any caller who omits the header can invoke the function and consume OpenAI quota.

**Fix:** Reject the request immediately when no valid Bearer token is present:
```typescript
const authHeader = req.headers.get("Authorization");
if (!authHeader || !authHeader.startsWith("Bearer ")) {
  return new Response(
    JSON.stringify({ error: "Unauthorized" }),
    { status: 401, headers: { "Content-Type": "application/json" } }
  );
}
```
Additionally, verify the JWT against Supabase's JWKS endpoint (or enable `verify_jwt = true` in `supabase/config.toml`) to confirm the token is valid and not expired before calling OpenAI.

---

### CR-02: No server-side input length limits — prompt injection and cost abuse

**File:** `supabase/functions/generate-plan/index.ts:122-145`

**Issue:** The `goal`, `fitness_level`, and `injuries` strings from the request body are interpolated directly into the OpenAI system prompt without any length validation or sanitisation. A malicious or misbehaving client can send arbitrarily large strings (e.g., a `goal` field containing 100 KB of text) or craft strings designed to override prompt instructions (prompt injection). This inflates token costs and may cause the model to ignore the schema constraint.

The iOS client itself does not allow this today, but the Edge Function is an independent API surface — any HTTP client can call it.

**Fix:** Add length caps and basic sanitisation before using the values in the prompt:
```typescript
const MAX_GOAL_LEN = 100;
const MAX_INJURIES_LEN = 500;
const MAX_LEVEL_LEN = 50;

if (
  profile.goal.length > MAX_GOAL_LEN ||
  profile.fitness_level.length > MAX_LEVEL_LEN ||
  profile.injuries.length > MAX_INJURIES_LEN ||
  profile.days_per_week < 1 || profile.days_per_week > 7 ||
  !Array.isArray(profile.equipment) || profile.equipment.length > 20
) {
  return new Response(
    JSON.stringify({ error: "Profile field exceeds allowed length or range" }),
    { status: 400, headers: { "Content-Type": "application/json" } }
  );
}
```
Strip or truncate at the limit before interpolation even if validated, as defense in depth.

---

### CR-03: Supabase plan ID fallback silently breaks plan linkage

**File:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift:229-233`

**Issue:** When `JSONDecoder().decode(InsertResult.self, from: response.data)` fails, the code falls back to `UUID().uuidString` — a randomly generated ID that has no corresponding row in the Supabase `workout_plans` table. The plan is still saved to CoreData with this phantom ID as `supabaseId`. Any future feature that uses `supabaseId` to look up, update, or delete the plan in Supabase (e.g., plan history, cross-device sync, deactivating old plans) will silently fail or corrupt state.

The silent fallback also means this decode failure is invisible in production; there is no log or error surfaced.

**Fix:** Treat the decode failure as a hard error rather than silently substituting a random ID:
```swift
struct InsertResult: Decodable { let id: String }
let result = try JSONDecoder().decode(InsertResult.self, from: response.data)
return result.id
// Remove the fallback UUID — let the error propagate so the retry path handles it.
```
If a soft fallback is truly needed for resilience, at minimum log the failure prominently so it is visible in Supabase logs.

---

## Warnings

### WR-01: Auto-retry spawns a new Task while the original Task is still running

**File:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift:131`

**Issue:** When `isRetry == false` and an error occurs, `generatePlan(profile:isRetry:)` is called recursively inside the `catch` block. This call sets `currentStreamTask` to a new `Task` and returns. However, the original `Task` that caught the error has not yet returned — it is still on the call stack in the `catch` block. The old task object is now overwritten in `currentStreamTask`, so it cannot be cancelled if the user taps "Regenerate" before the retry completes. This can lead to two concurrent streaming tasks writing to `state` simultaneously.

**Fix:** Use `Task { generatePlan(...) }` to ensure the retry starts asynchronously after the current task's frame unwinds, and consider a dedicated retry flag rather than recursion to make the flow clearer. Alternatively, after assigning the new task, immediately `return` to ensure the outer task body terminates before the retry proceeds.

---

### WR-02: PlanPreviewView.onAppear can trigger duplicate generation

**File:** `WorkoutApp/Features/PlanPreview/PlanPreviewView.swift:43`

**Issue:** `startGeneration()` is guarded by `viewModel.plan == nil && viewModel.errorMessage == nil`. However, immediately after `startGeneration()` is called, `service.state` transitions to `.streaming(partialText: "")`, which means `viewModel.plan` is still `nil` and `viewModel.errorMessage` is still `nil`. If the view disappears and reappears (e.g., the user backgrounds the app during generation), `onAppear` fires again, the guard evaluates true again (plan is still nil, no error yet), and `startGeneration()` is called a second time — starting a second network request while the first is still streaming.

**Fix:** Add an `isStreaming` guard to the condition:
```swift
.onAppear {
    if viewModel.plan == nil && viewModel.errorMessage == nil && !viewModel.isStreaming {
        viewModel.startGeneration()
    }
}
```

---

### WR-03: Timer is not invalidated when error view replaces loading view

**File:** `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift:169`

**Issue:** The cycling `Timer` is started in `onAppear` and stopped in `onDisappear`. However, when `errorMessage` becomes non-nil, `PlanGenerationLoadingView` switches its body from `loadingContent` to `errorOverlay`. The view itself does not disappear — only its subviews change. The `Timer` therefore keeps firing and posting `UIAccessibility.announcement` notifications with loading-phase text ("Analyzing your goals…") while the error UI is visible, which is incorrect and confusing for VoiceOver users.

**Fix:** Guard the timer callback against the error state, or stop the timer when transitioning to the error overlay:
```swift
private func startCycling() {
    cycleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
        Task { @MainActor in
            guard errorMessage == nil else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                currentPhase = (currentPhase + 1) % phases.count
            }
            UIAccessibility.post(notification: .announcement, argument: phases[currentPhase])
        }
    }
}
```
A cleaner solution is to observe changes to `errorMessage` via `.onChange` and call `cycleTimer?.invalidate()` when it becomes non-nil.

---

### WR-04: InjuriesCardView can call completeOnboarding() twice

**File:** `WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift:16-17`

**Issue:** Both the "Skip" button and the "Save & Continue" button call `viewModel.completeOnboarding()`. If a user taps "Skip" while a keyboard is visible and the tap is registered twice (a known iOS double-tap edge case with certain keyboard dismiss timing), or if both buttons are somehow activated rapidly, `completeOnboarding()` can fire twice. Each call invokes `onComplete?(profile)`, which in `OnboardingFlowView` sets `userProfile` and `showPlanPreview = true`. The second call would also attempt to set `showPlanPreview = true` again while `PlanPreviewView` is already presented. More critically, the second `onComplete` call triggers a second `startGeneration()` path (via the `onAppear` guard noted in WR-02).

**Fix:** Add an idempotency guard in `completeOnboarding()`:
```swift
func completeOnboarding() {
    guard !isOnboardingComplete else { return }
    // ... rest of implementation
}
```

---

### WR-05: Int16 overflow for sets/sortOrder in CoreData save

**File:** `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift:44,54`

**Issue:** `exercise.sets` and `exIndex` are cast to `Int16` without bounds checking. `Int16` has a maximum value of 32,767, which is safe for exercise counts and sort orders in practice. However, `exercise.sets` comes from an AI-generated integer field — if the model returns an unexpectedly large value (e.g., due to a schema bug or an unusual response), the truncation is silent and produces incorrect data. The same applies to `cdDay.sortOrder = Int16(index)` if a plan somehow has more than 32,767 days.

**Fix:** Add a guard or clamping before the cast:
```swift
cdExercise.sets = Int16(min(exercise.sets, Int(Int16.max)))
cdExercise.sortOrder = Int16(min(exIndex, Int(Int16.max)))
```
For production robustness, also consider validating the decoded plan's field ranges before persisting (e.g., `sets > 0 && sets <= 100`).

---

### WR-06: workout_plans table has no DELETE RLS policy

**File:** `supabase/migrations/00000002000000_create_workout_plans.sql:19-29`

**Issue:** The migration creates SELECT, INSERT, and UPDATE policies for `workout_plans`, but no DELETE policy. With RLS enabled, the absence of a DELETE policy means no user (including the row owner) can delete their own plan rows through the Supabase client. This is safe from a data-loss perspective today, but it means the deactivation strategy (setting `is_active = false` via UPDATE) is the only cleanup path — users who want to delete their plan history in a future feature will be blocked at the database layer unexpectedly.

**Fix:** Add a DELETE policy consistent with the SELECT/UPDATE policies:
```sql
CREATE POLICY "Users can delete own plans"
    ON public.workout_plans FOR DELETE
    USING (auth.uid() = user_id);
```
If plan deletion is intentionally not supported in v1, add a comment to the migration explaining this so future engineers do not add a client-side delete that silently fails.

---

## Info

### IN-01: startGeneration silently swallows profile save failure

**File:** `WorkoutApp/Features/PlanPreview/PlanPreviewViewModel.swift:73-75`

**Issue:** `try? await service.saveProfile(userProfile)` discards any error from the profile UPSERT. If the Supabase write fails (network error, RLS violation, etc.), the profile is not persisted to the `profiles` table, but plan generation proceeds anyway. The generated plan will then reference stale or missing profile data in Supabase, and the plan's `days_per_week` stored in the Edge Function call will be correct, but `profiles.goal/fitness_level/etc.` will be stale or empty.

**Fix:** Either propagate the error to the user or log it explicitly so failures are observable:
```swift
func startGeneration() {
    Task {
        do {
            try await service.saveProfile(userProfile)
        } catch {
            // Log for observability; generation can still proceed with the in-memory profile
            print("Warning: profile save failed — \(error). Proceeding with in-memory profile.")
        }
        service.generatePlan(profile: userProfile)
    }
}
```

---

### IN-02: DaysPerWeekCardView parses days from label string with a fragile prefix(1) pattern

**File:** `WorkoutApp/Features/Onboarding/Cards/DaysPerWeekCardView.swift:33`

**Issue:** `Int(option.prefix(1))` extracts the training day count by taking the first character of the label string (e.g., "4 days" → "4"). This works for the current 4 options ("2 days", "3 days", "4 days", "5 days") but is fragile: if any option label is ever changed or if a two-digit option (e.g., "10 days") is added, parsing will silently fail and the `selectDaysPerWeek` call will not be made. The user's tap is then silently ignored with no feedback.

**Fix:** Store the day count as a typed value alongside the display label, or use a dictionary/enum mapping:
```swift
private let options: [(label: String, days: Int)] = [
    ("2 days", 2), ("3 days", 3), ("4 days", 4), ("5 days", 5)
]
```
Then pass `option.days` directly to `viewModel.selectDaysPerWeek`.

---

### IN-03: Accessibility label mismatch on the quit button in OnboardingView

**File:** `WorkoutApp/Features/Onboarding/OnboardingView.swift:46`

**Issue:** The "X" dismiss button has `.accessibilityLabel("Sign out")`. The confirmation dialog shown by `requestQuitConfirmation()` offers two options: "Sign Out" (destructive) and "Continue Setup" (cancel). The button's accessibility label implies that tapping it will immediately sign the user out, when in fact it shows a confirmation dialog. VoiceOver users will be misled about the immediate action.

**Fix:** Change the label to accurately describe the action:
```swift
.accessibilityLabel("Quit setup")
// or
.accessibilityLabel("Exit onboarding")
```

---

### IN-04: WorkoutDay and PlannedExercise use non-unique id properties

**File:** `WorkoutApp/Features/Models/WorkoutPlan.swift:27,44`

**Issue:** `WorkoutDay.id` is `dayLabel` and `PlannedExercise.id` is `exerciseName`. These are not guaranteed to be unique within a plan — the AI could return two days with the same label (e.g., "Rest Day") or two exercises in the same day with the same name (e.g., two sets of "Plank" listed as separate rows). When used as `ForEach` identifiers, non-unique IDs produce SwiftUI rendering bugs (incorrect view identity, broken animations, potential crashes in diffing).

The divider logic in `WorkoutDayCardView` also uses `exercise.id != day.exercises.last?.id` which will display no divider between exercises that share the same name — a silent layout bug.

**Fix:** Use a stable UUID that is assigned at decode time:
```swift
struct PlannedExercise: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let exerciseName: String
    // ...

    init(id: UUID = UUID(), exerciseName: String, ...) { ... }
}
```
Alternatively, use `.enumerated()` with explicit index-based IDs in `ForEach` since the structures come from a single, non-interactive list.

---

_Reviewed: 2026-04-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
