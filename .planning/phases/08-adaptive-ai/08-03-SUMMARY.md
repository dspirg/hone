---
phase: 08-adaptive-ai
plan: "03"
subsystem: backend-ai
tags: [edge-functions, openai, adaptation, supabase, deno]
dependency_graph:
  requires: [08-01]
  provides: [adapt-plan-function, regenerate-plan-function]
  affects: [plan_adaptations-table, user_plans-table]
tech_stack:
  added: []
  patterns:
    - Non-streaming GPT-4o with Structured Outputs (json_schema strict mode)
    - ISO week cache key for idempotent weekly regeneration
    - Parallel Supabase data assembly with Promise.all
    - Zod two-layer validation with one retry on schema failure
    - Clinical language sanitization via sanitizeRationale
key_files:
  created:
    - supabase/functions/regenerate-plan/index.ts
  modified:
    - supabase/functions/adapt-plan/index.ts  # already existed from prior commit
decisions:
  - "regenerate-plan uses planSchema (not adaptedPlanSchema) for OpenAI response_format — full plan includes plan_name/goal_summary; weekly_days inner structure validated by AdaptedPlanSchema"
  - "historySummary object is injected rather than raw session logs — ~100 tokens vs 2000+ tokens for raw data"
  - "cache_key format: {userId}-{isoWeek} — unique per user per week, prevents duplicate Monday calls"
metrics:
  duration: "25min"
  completed_date: "2026-04-25"
  tasks_completed: 2
  files_created: 1
  files_modified: 0
---

# Phase 8 Plan 03: AI Adaptation Edge Functions Summary

**One-liner:** Non-streaming GPT-4o adaptation pipeline — adapt-plan handles post-session and missed-session triggers, regenerate-plan adds ISO-week cache deduplication and 4-week history summarization before calling GPT-4o with exercise continuity rules.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create adapt-plan Edge Function | 1f95754 | supabase/functions/adapt-plan/index.ts |
| 2 | Create regenerate-plan Edge Function | c3a9ecf | supabase/functions/regenerate-plan/index.ts |

## Decisions Made

1. **regenerate-plan uses `planSchema` for OpenAI Structured Outputs** — the full plan response includes `plan_name` and `goal_summary` which `AdaptedPlanSchema` does not cover. The weekly_days inner structure is validated via `AdaptedPlanSchema.safeParse({ adjustment_summary: ..., weekly_days: parsed.weekly_days })` — this gives Zod coverage on the structure that matters without requiring a separate combined schema.

2. **History summary compresses 4 weeks of session data into ~100 tokens** — `historySummary` contains total sessions, average completion rate, top 3 strongest exercises, bottom 2 weakest, and a ratings trend string. Raw set_logs would be 2000+ tokens; the summary is ~100 tokens while preserving all signal the AI needs.

3. **`cache_key` format is `{userId}-{isoWeek}`** — regeneration is idempotent per user per ISO week. On cache HIT, the function returns the stored `adapted_plan` JSONB with `X-Cache: HIT` header immediately, skipping all data assembly and the OpenAI call.

## Deviations from Plan

None — plan executed exactly as written.

## Implementation Notes

**adapt-plan (`1f95754`)** — was created in a prior commit in this plan phase (git log shows `feat(08-03): create adapt-plan Edge Function`). The file was already complete when this execution started, satisfying all acceptance criteria.

**regenerate-plan (`c3a9ecf`)** — created from scratch. Key implementation details:
- `getISOWeekKey()` computes ISO week number from a Date using UTC arithmetic
- `computeAvgCompletionRate()`, `topNByCompletionRate()`, `bottomNByCompletionRate()`, `summarizeRatingsTrend()` are local helpers that produce the `historySummary` object
- Zod validates the inner `weekly_days` structure via `AdaptedPlanSchema` wrapping; full plan object (including `plan_name`, `goal_summary`) is returned as-is from OpenAI
- `assertPromptBudget(systemPrompt, 1800, "regenerate-plan")` enforces the looser 1800-token budget specified in AI-SPEC for regeneration
- `sanitizeRationale` applied to all exercise rationale fields before INSERT and UPDATE

## Threat Model Coverage

| Threat | Mitigation | Applied |
|--------|-----------|---------|
| T-08-06: user_id spoofing | `auth.getUser(token)` on anon client; user_id from JWT only | Both functions |
| T-08-07: rating enum tampering | N/A (regenerate-plan has no rating input); adapt-plan validates enum | adapt-plan |
| T-08-08: DoS via unbounded calls | `console.warn` rate log per invocation; placeholder for future rate limiting | Both functions |
| T-08-09: clinical language in rationale | `sanitizeRationale()` applied to adjustment_summary and per-exercise rationale | Both functions |
| T-08-10: prompt injection via rating | Rating is an enum; cannot inject into system prompt | adapt-plan |

## Self-Check: PASSED

- `/Users/Fish/Desktop/workout/supabase/functions/adapt-plan/index.ts` — exists, commit `1f95754`
- `/Users/Fish/Desktop/workout/supabase/functions/regenerate-plan/index.ts` — exists, commit `c3a9ecf`
- Both commits verified in git log
