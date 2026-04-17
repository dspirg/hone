# Phase 5: AI Coach Chat - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 adds a persistent conversational AI coach to the Coach tab. Users can ask questions, report how they feel, and request plan modifications. The coach knows the user's profile, current plan, and recent session history. Plan changes are proposed inline and require explicit user confirmation before being applied.

</domain>

<decisions>
## Implementation Decisions

### Conversation Persistence
- Single ongoing thread per user — one persistent conversation, never reset
- Displayed with date section headers (Yesterday, Today, etc.)
- Old messages summarized server-side when context window approaches limit — summary injected into system prompt, raw messages pruned from context
- [+] button reserved for future use (not wired in Phase 5)

### Plan Modification Flow
- Coach proposes changes inline in the chat bubble: "I'd swap X for Y — want me to update your plan?"
- Inline confirmation card appears below the coach message with [Confirm] and [Dismiss] buttons
- On [Confirm]: call GPT-4o with Structured Outputs to regenerate the affected plan section; update `workout_plans` in Supabase and CoreData
- On [Dismiss]: coach acknowledges and continues conversation; no plan change made
- No silent modifications — user always explicitly confirms before plan changes apply

### Model Routing
- GPT-4o mini — all conversational turns (questions, motivation, feedback, general chat)
- GPT-4o — plan modification calls only (triggered by [Confirm] tap, uses Structured Outputs)
- Routing logic lives in the Supabase Edge Function: detect `action: "modify_plan"` in coach response JSON, route accordingly
- Both models called through the existing Edge Function proxy — never directly from iOS client

### Coach Context (System Prompt)
- Always injected per request: fitness profile (goal, level, equipment, injuries) + current workout plan + last 3 session summaries
- Session summaries are compact: date, workout name, exercises completed, sets logged
- Context does not grow unbounded — only last 3 sessions, full plan, profile

### Claude's Discretion
- Exact system prompt template and coach persona copy
- SwiftUI chat bubble component design (user vs coach alignment, colors)
- Streaming vs non-streaming coach responses (streaming preferred for perceived speed)
- CoreData entity for chat messages (ChatMessage entity)
- `coach_messages` Supabase table schema
- Context summarization trigger threshold (e.g., when message count > 50)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Supabase Edge Function pattern (Phase 3) — SSE client and auth header pattern reusable for coach streaming
- `AppState.swift` — user profile and plan already available here
- Session log data (Phase 4) — last 3 sessions fetched from CoreData for system prompt injection
- Coach tab already exists as empty state in tab bar (Phase 1)

### Established Patterns
- Edge Function proxy for all AI calls (established Phase 3)
- GPT-4o mini for chat / GPT-4o for structured outputs (CLAUDE.md two-model strategy)
- CoreData + Supabase dual persistence (established Phase 2/3)

### Integration Points
- Coach tab (`CoachView`) — replace empty state with chat interface
- `workout_plans` CoreData/Supabase — plan modifications write here
- Phase 4 session logs — read last 3 for system prompt context
- Phase 8 (Adaptive AI) will extend this with automated plan adaptation

</code_context>

<specifics>
## Specific Ideas

- Inline confirmation card for plan changes feels like iMessage-style interactive notifications — native, non-disruptive
- Coach persona should match the Hone brand: direct, knowledgeable, not cheerleader-y

</specifics>

<deferred>
## Deferred Ideas

- Voice input for coach messages — future phase
- Coach-initiated proactive messages ("Your next session is tomorrow — anything to adjust?") — Phase 8 (Adaptive AI)
- Multiple conversation threads / topic tagging — v1 is single thread
- Coach memory beyond last 3 sessions (long-term pattern detection) — Phase 8

</deferred>
