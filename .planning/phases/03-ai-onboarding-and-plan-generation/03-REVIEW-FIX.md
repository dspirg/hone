---
phase: 03-ai-onboarding-and-plan-generation
fixed_at: 2026-04-22T00:00:00Z
review_path: .planning/phases/03-ai-onboarding-and-plan-generation/03-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-04-22
**Source review:** .planning/phases/03-ai-onboarding-and-plan-generation/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 9 (3 Critical, 6 Warning)
- Fixed: 9
- Skipped: 0

## Fixed Issues

### CR-01: Edge Function does not reject unauthenticated requests

**Files modified:** `supabase/functions/generate-plan/index.ts`
**Commit:** 36a148b
**Applied fix:** Replaced the warn-and-continue block with a hard `return new Response(..., { status: 401 })` when the `Authorization` header is missing or does not start with `Bearer `. Added a comment explaining that Supabase Edge Functions do not auto-verify JWTs unless `verify_jwt = true` is set in `config.toml`.

---

### CR-02: No server-side input length limits — prompt injection and cost abuse

**Files modified:** `supabase/functions/generate-plan/index.ts`
**Commit:** b26a8dc
**Applied fix:** Added `MAX_GOAL_LEN = 100`, `MAX_LEVEL_LEN = 50`, `MAX_INJURIES_LEN = 500` constants. Added a validation block that returns HTTP 400 when any string field exceeds its limit, `days_per_week` is outside 1–7, or `equipment` has more than 20 items. Added `safeGoal`, `safeLevel`, `safeInjuries` truncated variables used in the prompt interpolation instead of the raw `profile.*` fields. Equipment array is also sliced to 20 entries as defense-in-depth. The `safeInjuries` variable replaces the previous `profile.injuries` reference in the conditional prompt append.

---

### CR-03: Supabase plan ID fallback silently breaks plan linkage

**Files modified:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift`
**Commit:** c81f48b
**Applied fix:** Removed the `if let result = try? ...` optional decode and the `return UUID().uuidString` fallback. Replaced with `let result = try JSONDecoder().decode(InsertResult.self, from: response.data)` so a decode failure throws and propagates to the caller's retry path rather than silently writing a phantom UUID to CoreData.

---

### WR-01: Auto-retry spawns a new Task while the original Task is still running

**Files modified:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift`
**Commit:** 6afc197
**Applied fix:** Changed the direct recursive call `generatePlan(profile: profile, isRetry: true)` to `Task { self.generatePlan(profile: profile, isRetry: true) }`. The new Task is scheduled to run after the current task's catch block unwinds, ensuring `currentStreamTask` is not overwritten while the original task is still live on the call stack.

---

### WR-02: PlanPreviewView.onAppear can trigger duplicate generation

**Files modified:** `WorkoutApp/Features/PlanPreview/PlanPreviewView.swift`
**Commit:** e9fab10
**Applied fix:** Added `&& !viewModel.isStreaming` to the `onAppear` guard condition. This prevents a second `startGeneration()` call if the view disappears and reappears (e.g., app backgrounding) while the first stream is still in progress — at that point `plan` is still nil and `errorMessage` is still nil, so the old guard would have incorrectly allowed a second request.

---

### WR-03: Timer is not invalidated when error view replaces loading view

**Files modified:** `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift`
**Commit:** 81f6b75
**Applied fix:** Added `guard errorMessage == nil else { return }` at the top of the timer callback's `Task { @MainActor in ... }` block. When `errorMessage` becomes non-nil the view body switches to `errorOverlay` without triggering `onDisappear`, so the timer keeps firing. The guard ensures neither the phase text nor the VoiceOver accessibility announcement updates while the error overlay is visible.

---

### WR-04: InjuriesCardView can call completeOnboarding() twice

**Files modified:** `WorkoutApp/Features/Onboarding/OnboardingViewModel.swift`
**Commit:** 63c6562
**Applied fix:** Added `guard !isOnboardingComplete else { return }` as the first line of `completeOnboarding()`. The `isOnboardingComplete` property already existed on the view model and is set to `true` inside the same method, making the guard a clean idempotency fence against rapid double-taps or concurrent button activations on the injuries card.

---

### WR-05: Int16 overflow for sets/sortOrder in CoreData save

**Files modified:** `WorkoutApp/Features/CoreData/WorkoutPlanRepository.swift`
**Commit:** e3a3a06
**Applied fix:** Replaced bare `Int16(index)`, `Int16(exercise.sets)`, and `Int16(exIndex)` casts with `Int16(min(value, Int(Int16.max)))` for all three sites. This prevents silent truncation/wrap if the AI model returns an unexpectedly large integer for `sets` or if a plan somehow has an extreme number of days or exercises.

---

### WR-06: workout_plans table has no DELETE RLS policy

**Files modified:** `supabase/migrations/00000002000000_create_workout_plans.sql`
**Commit:** 1020130
**Applied fix:** Appended a `CREATE POLICY "Users can delete own plans" ON public.workout_plans FOR DELETE USING (auth.uid() = user_id);` statement to the migration, consistent with the existing SELECT and UPDATE policies. Added a comment explaining the context: v1 uses `is_active = false` for deactivation, but the missing DELETE policy would silently block any future client-side delete feature at the database layer.

---

_Fixed: 2026-04-22_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
