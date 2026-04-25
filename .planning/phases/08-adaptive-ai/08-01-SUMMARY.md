---
phase: 08-adaptive-ai
plan: 01
subsystem: database
tags: [coredata, supabase, migrations, edge-functions, typescript, zod, swift]

# Dependency graph
requires:
  - phase: 06-progress-tracking
    provides: session_logs table and CDSessionLog CoreData entity that this plan extends
  - phase: 05-ai-coach-chat
    provides: generate-plan and coach-chat Edge Functions that this plan refactors
provides:
  - difficulty_rating column on session_logs with CHECK constraint
  - plan_adaptations audit table with RLS and service-role-only writes
  - DifficultyRating Swift enum matching DB CHECK values exactly
  - difficultyRating attribute on CDSessionLog CoreData entity
  - planSchema single source of truth in supabase/functions/_shared/
  - AdaptedPlanSchema Zod validation module
  - promptBuilder helpers (estimateTokens, stripRationale, passesLanguageGuardrail)
  - SessionSyncService extended to carry difficultyRating in sync payload
affects: [08-02-adapt-plan, 08-03-regenerate-plan, 08-04-difficulty-rating-ui, 08-05-adaptation-pipeline, 08-06-background-notifications]

# Tech tracking
tech-stack:
  added: [Zod v3.23.8 (via Deno import in Edge Functions)]
  patterns:
    - _shared/ directory for Edge Function shared modules — single source of truth pattern
    - Zod for runtime validation of AI-generated JSON responses (two-layer: JSON Schema constrains generation, Zod validates receipt)
    - CHECK constraint at DB layer enforcing enum values matches Swift enum raw values exactly

key-files:
  created:
    - supabase/migrations/20260425000000_phase8_adaptation.sql
    - WorkoutApp/Features/Models/DifficultyRating.swift
    - supabase/functions/_shared/planSchema.ts
    - supabase/functions/_shared/adaptedPlanSchema.ts
    - supabase/functions/_shared/promptBuilder.ts
  modified:
    - WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld/WorkoutApp.xcdatamodel/contents
    - WorkoutApp/Core/Sync/SessionSyncService.swift
    - supabase/functions/generate-plan/index.ts
    - supabase/functions/coach-chat/index.ts

key-decisions:
  - "planSchema extracted from both generate-plan and coach-chat to _shared/planSchema.ts — prevents 4-way drift as adapt-plan and regenerate-plan are added in later plans"
  - "DifficultyRating Swift enum raw values (too_easy/just_right/too_hard) match DB CHECK constraint values exactly — enforces consistency at compile time"
  - "plan_adaptations has no client INSERT policy — only service role (Edge Functions) can write, enforcing server-side adaptation audit trail"
  - "difficultyRating is optional String? in CoreData and SessionLogRow — nil for pre-Phase 8 sessions and sessions where user skips rating"

patterns-established:
  - "Pattern: _shared/ Edge Function modules — import shared TypeScript from ../: prevents schema drift across multiple Edge Functions"
  - "Pattern: Two-layer AI output validation — JSON Schema constrains OpenAI generation, Zod validates the received response before use"
  - "Pattern: DB CHECK constraint mirrors Swift enum raw values — type safety bridging iOS client to Supabase schema"

requirements-completed: [ADPT-01, ADPT-02]

# Metrics
duration: 15min
completed: 2026-04-25
---

# Phase 8 Plan 01: Adaptive AI Data Foundation Summary

**Supabase migration with difficulty_rating and plan_adaptations, CoreData model extension, DifficultyRating Swift enum, planSchema extracted to _shared/ with Zod validation and prompt builder helpers**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-25T00:00:00Z
- **Completed:** 2026-04-25T00:15:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Created Supabase migration adding `difficulty_rating` TEXT column (CHECK constraint: too_easy/just_right/too_hard) to `session_logs` and `plan_adaptations` audit table with RLS (SELECT-only for authenticated users, service role for writes)
- Extended CDSessionLog CoreData entity with optional `difficultyRating` String attribute (lightweight migration — no mapping file needed) and updated SessionSyncService to carry the value in sync payloads
- Extracted `planSchema` from duplicate inline definitions in generate-plan and coach-chat to `supabase/functions/_shared/planSchema.ts` (single source of truth); created `adaptedPlanSchema.ts` Zod module and `promptBuilder.ts` with token budget, stripRationale, and clinical language guardrail helpers

## Task Commits

Each task was committed atomically:

1. **Task 1: Supabase migration, CoreData model, DifficultyRating enum, SessionSyncService extension** - `9b53558` (feat)
2. **Task 2: Extract planSchema to _shared/, create adaptedPlanSchema + promptBuilder, update imports** - `d97851f` (feat)

## Files Created/Modified

- `supabase/migrations/20260425000000_phase8_adaptation.sql` — ALTER TABLE session_logs + CREATE TABLE plan_adaptations with RLS
- `WorkoutApp/Features/Models/DifficultyRating.swift` — Swift enum with raw values matching DB CHECK constraint
- `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld/WorkoutApp.xcdatamodel/contents` — Added difficultyRating optional String to CDSessionLog entity
- `WorkoutApp/Core/Sync/SessionSyncService.swift` — Added difficultyRating: String? to SessionLogRow struct and construction site
- `supabase/functions/_shared/planSchema.ts` — Extracted planSchema (single source of truth for all 4 Edge Functions)
- `supabase/functions/_shared/adaptedPlanSchema.ts` — Zod schema for adapted plan validation (ExerciseSchema, TrainingDaySchema, AdaptedPlanSchema)
- `supabase/functions/_shared/promptBuilder.ts` — estimateTokens, assertPromptBudget, stripRationale, passesLanguageGuardrail, sanitizeRationale helpers
- `supabase/functions/generate-plan/index.ts` — Removed inline planSchema, added import from _shared/
- `supabase/functions/coach-chat/index.ts` — Removed inline planSchema, added import from _shared/, fixed max_tokens → max_completion_tokens

## Decisions Made

- planSchema extracted to `_shared/` rather than keeping separate copies — prevents silent drift as adapt-plan and regenerate-plan Edge Functions are added in plans 02–03
- DifficultyRating enum raw values chosen to exactly match the DB CHECK constraint — if they ever diverge the sync payload would be rejected at DB layer with a clear error
- plan_adaptations has no client INSERT/UPDATE/DELETE policies — only service role (Edge Functions) can write, ensuring the adaptation audit trail is server-authoritative

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deprecated max_tokens in coach-chat summarization call**
- **Found during:** Task 2 (coach-chat import update)
- **Issue:** The summarization call at line 235 used `max_tokens: 300` which is deprecated in newer OpenAI API versions; the plan's acceptance criteria explicitly required `max_completion_tokens`
- **Fix:** Changed `max_tokens` to `max_completion_tokens` in the summarization fetch body
- **Files modified:** `supabase/functions/coach-chat/index.ts`
- **Verification:** grep confirms `max_completion_tokens` present, `max_tokens` absent
- **Committed in:** `d97851f` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix was already listed in plan acceptance criteria — not scope creep.

## Issues Encountered

None — both tasks executed cleanly.

## Threat Surface Scan

All security surfaces were in-plan:

| Flag | File | Description |
|------|------|-------------|
| T-08-01 mitigated | supabase/migrations/20260425000000_phase8_adaptation.sql | CHECK constraint on difficulty_rating limits to 3 valid enum values |
| T-08-02 mitigated | supabase/migrations/20260425000000_phase8_adaptation.sql | RLS enabled on plan_adaptations; SELECT policy for auth.uid() = user_id; no client INSERT policy |

No new security surfaces introduced beyond those in the plan's threat model.

## Known Stubs

None — this plan is entirely data layer (migration SQL, CoreData model, Swift enum, TypeScript modules). No UI rendering paths and no stubs that block the plan's goal.

## Next Phase Readiness

- Migration SQL ready to push to Supabase (requires `supabase db push` or Supabase dashboard apply)
- `_shared/` modules available for import by adapt-plan (plan 02) and regenerate-plan (plan 03)
- DifficultyRating enum ready for use in difficulty rating UI (plan 04)
- SessionSyncService will carry difficulty ratings to Supabase as soon as iOS UI populates CDSessionLog.difficultyRating

---
*Phase: 08-adaptive-ai*
*Completed: 2026-04-25*
