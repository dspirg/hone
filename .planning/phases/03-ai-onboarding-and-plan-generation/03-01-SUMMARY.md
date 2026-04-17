---
phase: 03-ai-onboarding-and-plan-generation
plan: 01
subsystem: api, database, testing
tags: [supabase, openai, coredata, swift6, deno, sse, structured-outputs, edge-function, postgres]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "Supabase profiles table, RLS patterns, SupabaseClient singleton, AppState, auth JWT flow"

provides:
  - "profiles table with fitness columns (goal, fitness_level, days_per_week, equipment, injuries)"
  - "workout_plans table with RLS (SELECT/INSERT/UPDATE scoped to user_id)"
  - "generate-plan Deno Edge Function: OpenAI GPT-4o SSE streaming + Structured Outputs strict mode"
  - "WorkoutPlan/WorkoutDay/PlannedExercise Codable structs matching Edge Function JSON schema"
  - "UserProfile Encodable struct for Edge Function request body"
  - "PlanPromptBuilder: system prompt construction with equipment + safety guardrails"
  - "CoreData schema (CDWorkoutPlan -> CDWorkoutDay -> CDPlannedExercise, ordered, cascade)"
  - "PersistenceController singleton with in-memory test mode"
  - "WorkoutPlanRepository: save/fetchActivePlan/deactivateAllPlans"
  - "10 passing unit tests covering AIPL-01, AIPL-02, AIPL-04, SAFE-02"

affects:
  - 03-02-onboarding-ui
  - 03-03-plan-preview
  - 03-04-plan-generation-viewmodel
  - 04-workout-session
  - 05-ai-coach-chat

# Tech tracking
tech-stack:
  added:
    - "Deno Edge Function (generate-plan) on Supabase Edge Runtime"
    - "OpenAI GPT-4o-2024-08-06 Structured Outputs strict mode"
    - "CoreData NSPersistentContainer with NSPersistentStoreDescription"
  patterns:
    - "OpenAI Structured Outputs strict schema: additionalProperties:false at every object level, all fields in required[]"
    - "injuries as required String with empty-string sentinel (Structured Outputs cannot have nullable fields in strict mode)"
    - "rawJSON binary blob in CDWorkoutPlan as defensive fallback for decode resilience"
    - "PlanPromptBuilder mirrors Edge Function prompt logic for unit-testable prompt construction"
    - "API key via Deno.env.get only -- fail-fast on startup if missing"

key-files:
  created:
    - supabase/migrations/00000001000000_add_profile_fitness_columns.sql
    - supabase/migrations/00000002000000_create_workout_plans.sql
    - supabase/functions/generate-plan/index.ts
    - WorkoutApp/Core/Models/WorkoutPlan.swift
    - WorkoutApp/Core/Models/UserProfile.swift
    - WorkoutApp/Core/CoreData/WorkoutApp.xcdatamodeld/WorkoutApp.xcdatamodel/contents
    - WorkoutApp/Core/CoreData/CoreDataStack.swift
    - WorkoutApp/Core/CoreData/WorkoutPlanRepository.swift
    - WorkoutAppTests/WorkoutPlanDecodingTests.swift
    - WorkoutAppTests/PlanPromptBuilderTests.swift
  modified:
    - WorkoutApp.xcodeproj/project.pbxproj

key-decisions:
  - "injuries field is required String with empty-string sentinel in both Swift UserProfile and Edge Function -- OpenAI Structured Outputs strict mode cannot have nullable/optional schema fields"
  - "rawJSON binary stored in CDWorkoutPlan alongside entity graph -- defensive fallback: fetchActivePlan decodes from rawJSON to avoid entity graph corruption issues"
  - "PlanPromptBuilder defined in Swift (not just Deno) so it can be unit-tested without Edge Function deployment"
  - "Edge Function uses deno.land/std@0.224.0 (latest) instead of deprecated 0.168.0 from research doc"
  - "All 4 injuries prompt cases handled: injuries injected into structured slot only when non-empty, never in output schema"

patterns-established:
  - "Pattern: OpenAI Structured Outputs schema must have additionalProperties:false and all fields in required[] at every object level -- omitting any level causes 400 error"
  - "Pattern: Edge Function API key guard -- Deno.env.get at top of serve(), return 500 immediately if not set"
  - "Pattern: Edge Function returns non-200 JSON error on OpenAI API error, not a 200 with error text in the stream"
  - "Pattern: CoreData ordered relationships (NSOrderedSet) for day/exercise sequence preservation"
  - "Pattern: PersistenceController(inMemory: true) for test isolation -- /dev/null store prevents disk writes"

requirements-completed: [AIPL-01, AIPL-02, AIPL-04]

# Metrics
duration: 14min
completed: 2026-04-17
---

# Phase 3 Plan 01: Data Foundation for AI Plan Generation Summary

**GPT-4o SSE streaming Edge Function with Structured Outputs, CoreData WorkoutPlan persistence, and Swift Codable models with 10 passing tests covering rationale, equipment prompt injection, and safety guardrails**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-04-17T00:39:41Z
- **Completed:** 2026-04-17T00:53:00Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Deno Edge Function proxies OpenAI GPT-4o with SSE passthrough and Structured Outputs strict mode -- `additionalProperties: false` at all 3 object levels (root, day, exercise) as required by the spec
- CoreData 3-entity schema (CDWorkoutPlan -> CDWorkoutDay -> CDPlannedExercise) with ordered relationships, cascade deletes, and rawJSON blob for decode resilience -- wired into Xcode project
- Swift Codable contract with snake_case CodingKeys exactly matching the Edge Function JSON schema; PlanPromptBuilder includes equipment list and safety guardrail in every generated prompt
- 10 unit tests pass: 4 decoding tests (AIPL-01, AIPL-02, CoreData round-trip) + 6 prompt tests (AIPL-04, SAFE-02, injuries conditional)

## Task Commits

1. **Task 1: Supabase migrations and Edge Function** - `0f272ad` (feat)
2. **Task 2: Swift data models, CoreData schema, repository, and tests** - `2191404` (feat)

## Files Created/Modified

- `supabase/migrations/00000001000000_add_profile_fitness_columns.sql` - Adds goal, fitness_level, days_per_week, equipment, injuries columns to profiles
- `supabase/migrations/00000002000000_create_workout_plans.sql` - Creates workout_plans table with RLS (SELECT/INSERT/UPDATE per user_id)
- `supabase/functions/generate-plan/index.ts` - Deno Edge Function: profile input -> system prompt -> OpenAI GPT-4o SSE -> passthrough stream
- `WorkoutApp/Core/Models/WorkoutPlan.swift` - WorkoutPlan/WorkoutDay/PlannedExercise Codable structs + PlanPromptBuilder
- `WorkoutApp/Core/Models/UserProfile.swift` - UserProfile Encodable struct with snake_case CodingKeys
- `WorkoutApp/Core/CoreData/WorkoutApp.xcdatamodeld/WorkoutApp.xcdatamodel/contents` - CoreData model XML: 3 entities with ordered relationships
- `WorkoutApp/Core/CoreData/CoreDataStack.swift` - PersistenceController singleton with inMemory test mode
- `WorkoutApp/Core/CoreData/WorkoutPlanRepository.swift` - save/fetchActivePlan/deactivateAllPlans CRUD
- `WorkoutAppTests/WorkoutPlanDecodingTests.swift` - 4 tests: decode, rationale, round-trip, CoreData save+fetch
- `WorkoutAppTests/PlanPromptBuilderTests.swift` - 6 tests: equipment, goal, injuries conditional, daysPerWeek, safety disclaimer
- `WorkoutApp.xcodeproj/project.pbxproj` - Added all new Swift files, CoreData model, and test files to Xcode project

## Decisions Made

- **injuries as required String with empty sentinel:** OpenAI Structured Outputs strict mode rejects nullable/optional fields in the schema. Both `UserProfile.injuries` (Swift) and the Edge Function use `""` as the sentinel for "no injuries". The injuries section in the system prompt is conditionally included only when non-empty.
- **rawJSON blob in CDWorkoutPlan:** `fetchActivePlan` decodes from the stored `rawJSON` Data blob rather than reassembling from the entity graph. This is more resilient to partial entity graph issues and easier to maintain.
- **PlanPromptBuilder in Swift:** Mirrors the Edge Function prompt logic so it can be unit tested without deploying the Edge Function. The two are intentionally kept in sync.
- **Updated std version to 0.224.0:** Research doc referenced `deno.land/std@0.168.0` (2022); used `0.224.0` (current stable) to avoid deprecated import paths.

## Deviations from Plan

None - plan executed exactly as written. The only adjustment was using Deno std@0.224.0 instead of the research doc's example @0.168.0, which is a version update not a deviation.

## Issues Encountered

- iPhone 16 simulator not available on this machine -- tests run on iPhone 17 Pro simulator. All 10 tests passed.

## User Setup Required

**External services require manual configuration before plan generation works:**

1. Set the OpenAI API key as a Supabase Edge Function secret:
   ```bash
   supabase secrets set OPENAI_API_KEY=sk-...
   ```
   - Location: OpenAI Dashboard -> API keys -> Create new secret key
   - This is required before `generate-plan` Edge Function will return plans

2. Deploy migrations to Supabase:
   ```bash
   supabase db push
   ```

3. Deploy the Edge Function:
   ```bash
   supabase functions deploy generate-plan
   ```

## Next Phase Readiness

- Data layer is complete: all contracts established for Wave 2 plans to build on
- Wave 2 (plans 02-05) can consume: WorkoutPlan struct, UserProfile struct, PlanPromptBuilder, WorkoutPlanRepository, PersistenceController
- The SSE client pattern (manual URLRequest with Bearer token) is documented in RESEARCH.md and ready for PlanSSEClient implementation in plan 02
- Blocker: OpenAI API key must be set as Edge Function secret before end-to-end plan generation can be tested

## Self-Check: PASSED

All created files confirmed present on disk. Git commits:
- `0f272ad` feat(03-01): Supabase migrations and generate-plan Edge Function
- `2191404` feat(03-01): Swift data models, CoreData schema, repository, and tests
- `740c78a` docs(03-01): complete data foundation for AI plan generation plan

---
*Phase: 03-ai-onboarding-and-plan-generation*
*Completed: 2026-04-17*
