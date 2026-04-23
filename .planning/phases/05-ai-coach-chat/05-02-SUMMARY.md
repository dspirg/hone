---
phase: 05-ai-coach-chat
plan: "02"
subsystem: backend-edge-functions
tags: [openai, supabase-edge-functions, streaming, sse, coach-chat, ai-proxy]

dependency_graph:
  requires:
    - supabase/functions/generate-plan/index.ts   # planSchema copied verbatim; CORS/auth patterns mirrored
  provides:
    - supabase/functions/coach-chat/index.ts      # SSE streaming AI proxy for coach chat
  affects:
    - WorkoutApp/Features/Coach/SSE/CoachSSEClient.swift  # consumes SSE stream from this function (plan 05-03)
    - WorkoutApp/Features/Coach/CoachViewModel.swift      # drives execute_modify flow (plan 05-03)

tech_stack:
  added:
    - Deno/TypeScript Edge Function for coach-chat AI proxy
    - GPT-4o mini streaming for conversational chat (D-13)
    - GPT-4o-2024-08-06 Structured Outputs for plan modification (D-14)
    - D-22 context summarization via preliminary GPT-4o mini call
  patterns:
    - ReadableStream SSE forwarding with token accumulation (not pure passthrough)
    - [MODIFICATION] intent detection regex in accumulated response text
    - [ACTION] envelope event injection before [DONE] for iOS client routing
    - execute_modify branch: non-streaming GPT-4o with planSchema for plan updates
    - Graceful summarization fallback on API failure

key_files:
  created:
    - supabase/functions/coach-chat/index.ts

decisions:
  - "SUMMARIZATION_THRESHOLD set to 50 messages per CONTEXT.md guidance (D-22)"
  - "Rate limiting implemented as console.warn only (MVP) — KV store deferred per T-05-07 accept disposition"
  - "SSE forwarding reads+accumulates tokens (not pure passthrough) to enable [MODIFICATION] detection at end of stream"
  - "safeHistory capped at 20 messages (slice(-20)) before context summarization threshold check"

metrics:
  duration: "~5 minutes"
  completed_date: "2026-04-23"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 05 Plan 02: Coach-Chat Edge Function Summary

**One-liner:** SSE streaming Supabase Edge Function proxying GPT-4o mini chat with [ACTION] envelope injection, [MODIFICATION] intent detection, GPT-4o Structured Outputs for plan modification, and D-22 context summarization via preliminary GPT-4o mini call.

## What Was Built

Created `supabase/functions/coach-chat/index.ts` — the backend AI proxy for the coach chat feature. This Edge Function:

1. **Conversational chat path** (GPT-4o mini, streaming): Assembles a personalized system prompt from user profile (name, goal, fitness level, equipment, injuries), current workout plan (JSON-injected), and last 3 session summaries (D-29/D-30). Forwards SSE tokens to the iOS client via `ReadableStream`, accumulating the full response text to detect `[MODIFICATION]` intent at stream end.

2. **[ACTION] envelope injection**: After all prose tokens are forwarded, injects a `data: [ACTION]{...}\n\n` event containing `{ action: "chat"|"modify_plan", plan_delta: null|string }` before `data: [DONE]\n\n`. The iOS `CoachSSEClient` parses this to route the response (show plan modification card vs. plain chat bubble).

3. **Plan modification execution path** (GPT-4o, non-streaming): When `payload.action === "execute_modify"`, calls `gpt-4o-2024-08-06` with Structured Outputs (`planSchema` — copied verbatim from `generate-plan/index.ts`) to generate the updated plan JSON. Returns non-streaming JSON response `{ action: "execute_modify", plan_delta: string }`.

4. **D-22 context summarization**: When `payload.message_count > 50` and `safeHistory.length > 5`, makes a preliminary GPT-4o mini call (max 300 tokens) to summarize older messages. On success, injects the summary into the system prompt and reduces `safeHistory` to the 5 most recent messages. On failure, falls back to the capped 20-message raw history with `console.warn`.

5. **Security mitigations** (all STRIDE threats addressed):
   - T-05-04: `MAX_MESSAGE_LEN = 2000`, truncated via `slice`
   - T-05-05: System prompt placed before user content in messages array; history capped at 20
   - T-05-06: SAFETY block in system prompt — "not a medical professional"
   - T-05-07: Rate limit `console.warn` logging (KV store deferred, accepted disposition)
   - T-05-08: Bearer token validation — 401 on missing/invalid
   - T-05-09: `Deno.env.get("OPENAI_API_KEY")` — never hardcoded

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — the Edge Function is complete and deployable. Rate limiting is intentionally minimal (console.warn only) per the threat model's `accept` disposition for T-05-07, which explicitly defers full implementation to a future KV store addition.

## Threat Flags

No new threat surface introduced beyond what the plan's threat model already covers. All six STRIDE threats (T-05-04 through T-05-09) have mitigations implemented in the code.

## Self-Check: PASSED

- `supabase/functions/coach-chat/index.ts` — EXISTS (422 lines)
- Commit `ca80135` — EXISTS
- All 20 acceptance criteria verified via grep — PASSED
- No unexpected file deletions — CONFIRMED
