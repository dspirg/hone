---
phase: 01-foundation
plan: 02
subsystem: ai
tags: [openai, safety, system-prompt, red-team, guardrails]

# Dependency graph
requires: []
provides:
  - AI coach safety system prompt template with 4 rule categories (no diagnosis, defer to professionals, fitness vs diagnosis boundary, nutrition limits)
  - Red-team adversarial test document with 10 prompts and PASS/FAIL criteria
  - Threat mitigation documentation for T-02-01, T-02-02, T-02-03
affects:
  - 03-ai-features (Phase 3 Edge Function must inject this system prompt)
  - All phases with user-facing AI features

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Safety-first system prompt: safety rules are positioned before user context to prevent override
    - Static artifact verification: red-team test document created in Phase 1, executed in Phase 3

key-files:
  created:
    - WorkoutApp/AIPrompts/SafetySystemPrompt.md
    - WorkoutApp/Tests/RedTeamTests/SafetyGuardrailTests.md
  modified: []

key-decisions:
  - "Safety rules placed before user context in system message to prevent adversarial override (T-02-03 mitigation)"
  - "Static document artifact approach in Phase 1: system prompt exists as template, live execution happens in Phase 3 Edge Function"
  - "10 red-team tests cover all STRIDE threat categories: tampering (prompt injection, roleplay override), information disclosure (diagnosis, dosages)"

patterns-established:
  - "AI safety prompt pattern: role definition -> SAFETY RULES header -> numbered rules -> integration notes"
  - "Red-team test format: test matrix table with Category + Expected Behavior columns, explicit PASS/FAIL criteria"

requirements-completed:
  - SAFE-02

# Metrics
duration: 2min
completed: 2026-04-16
---

# Phase 1 Plan 02: AI Safety Guardrails Summary

**AI coach safety system prompt with 4 guardrail categories and 10 adversarial red-team test prompts, ready for Phase 3 Edge Function injection**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-16T20:04:07Z
- **Completed:** 2026-04-16T20:05:52Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created system prompt template with explicit safety rules that cannot be overridden by user instruction
- Documented 6 core test prompts from research (diabetes, chest pain, supplements, diagnosis request, roleplay override, medication dosage)
- Added 4 additional adversarial prompts (prompt injection, mental health + medication, pregnancy, hypertensive crisis)
- Established PASS/FAIL criteria and threat coverage table linking tests to STRIDE register

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AI safety system prompt template** - `a328257` (feat)
2. **Task 2: Create red-team test prompts document** - `a568411` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `WorkoutApp/AIPrompts/SafetySystemPrompt.md` - System prompt template with 4 safety rule categories; injected as `system` message by Phase 3 Edge Function
- `WorkoutApp/Tests/RedTeamTests/SafetyGuardrailTests.md` - 10 adversarial test prompts with expected refusal behaviors, PASS/FAIL criteria, and example safe responses

## Decisions Made

- Safety rules positioned before user context in every system message to prevent adversarial override (mitigates T-02-03)
- Phase 1 creates static document artifacts only; live API testing deferred to Phase 3 (per D-11, D-12)
- Red-team scope expanded beyond RESEARCH.md 6 prompts to 10 total, adding prompt injection, mental health + medication, pregnancy, and hypertensive crisis scenarios for broader coverage

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Threat Surface Scan

No new threat surface introduced. This plan creates documentation-only artifacts (markdown files). No network endpoints, auth paths, file access patterns, or schema changes were introduced.

## Known Stubs

None - both documents are complete templates with full content. No placeholder data flows to any UI.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- AI safety foundation complete; system prompt template ready for Phase 3 Edge Function integration
- Red-team tests must be executed against live OpenAI API before any user-facing AI goes live
- Both documents reference SAFE-02, D-11, D-12 for full traceability
- Blocker for AI launch: all 10 red-team tests must PASS before Phase 3 AI is enabled

---
*Phase: 01-foundation*
*Completed: 2026-04-16*
