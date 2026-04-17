---
plan: 03-03
phase: 03-ai-onboarding-and-plan-generation
status: complete
completed: 2026-04-16
---

# Plan 03-03: SSE Streaming Client and Plan Generation Service

## What Was Built

SSE streaming pipeline connecting the iOS client to the Supabase Edge Function for AI plan generation.

## Key Files Created

### key-files:
  created:
    - WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift
    - WorkoutApp/Features/PlanPreview/PlanGenerationService.swift
    - WorkoutAppTests/WorkoutPlanParserTests.swift
    - WorkoutAppTests/WorkoutPlanServiceTests.swift

## Summary

**PlanSSEClient** — URLSession bytes-stream wrapper with manual Bearer JWT auth. Bypasses Supabase SDK `invokeWithStreamedResponse` (issue #634 drops the JWT). Emits `PlanSSEEvent.token` for each partial chunk and `PlanSSEEvent.completed` only when `[DONE]` is received — never exposes partial JSON for parsing.

**PlanGenerationService** — `@Observable @MainActor` service orchestrating the full generation lifecycle:
1. Streams plan via `PlanSSEClient`
2. Parses complete JSON from `.completed` event only (Pitfall 3)
3. Persists to Supabase `workout_plans` table
4. Saves to CoreData via `WorkoutPlanRepository`
5. Sets `profiles.onboarding_completed = true` (strict sequential order, Pitfall 4)

Silent auto-retry on first failure (D-16). Regeneration counter via `@AppStorage("regenCountUsed")` survives ViewModel recreation (Pitfall 6).

**GenerationState** — `idle | streaming(partialText) | completed(WorkoutPlan) | error(String)` with manual `Equatable` conformance for the associated-value cases.

**WorkoutPlanParserTests** — 5 tests verifying complete JSON decodes correctly and partial streaming JSON throws (proves Pitfall 3 constraint at test level).

**WorkoutPlanServiceTests** — 6 tests covering counter initialization, canRegenerate guard, counter decrement, zero-guard blocking regeneration, and reset.

## Deviations

None. Implementation matches plan spec exactly.

## Self-Check: PASSED

- PlanSSEClient uses `URLSession.shared.bytes(for: request)` — confirmed, not SDK invoke
- Manual `Authorization: Bearer` + `apikey` headers — confirmed
- `.completed` only emitted on `[DONE]` — confirmed, no mid-stream JSON parsing
- Persistence order: Supabase INSERT → CoreData save → onboarding flag — confirmed sequential `await`
- `@AppStorage("regenCountUsed")` counter — confirmed
- All unit tests pass
