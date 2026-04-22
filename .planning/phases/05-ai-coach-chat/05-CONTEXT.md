# Phase 5: AI Coach Chat - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 adds a persistent conversational AI coach to the Coach tab. Users can ask questions, report how they feel, and request plan modifications. The coach knows the user's profile, current plan, and recent session history. Plan changes are proposed inline and require explicit user confirmation before being applied. The coach is reactive only in Phase 5 — proactive messages are deferred to Phase 8.

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

### Proactive Messages (CHAT-04)
- **D-04:** CHAT-04 (proactive check-in messages) is deferred to Phase 8 (Adaptive AI)
- Phase 5 is reactive only — user initiates all conversations
- Rationale: Phase 8 has full session history and pattern data needed to make proactive messages meaningful

### Offline Behavior
- **D-05:** Show a non-intrusive banner at the top of the chat: "No connection — coach unavailable"
- Send button is disabled while offline; message history remains readable
- Banner dismisses automatically when connectivity returns (consistent with Phase 4 session sync banner pattern)

### Error States
- **D-06:** Failed coach responses show an inline error bubble in the chat thread: "Something went wrong. Tap to retry."
- Tapping the error bubble resends the last message
- Plan modification failures show an inline error below the confirmation card
- Errors must always be visible and retryable — no silent failures

### Input Field
- **D-07:** Multi-line auto-expanding text input — starts as single line, expands up to 4 lines as user types
- Send button (arrow icon) on the right of the input field
- No character limit
- No voice input placeholder in Phase 5 (voice deferred)
- No suggested prompt chips — clean text + send only

### Claude's Discretion
- Exact system prompt template and coach persona copy
- SwiftUI chat bubble component design (user vs coach alignment, colors)
- Streaming vs non-streaming coach responses (streaming strongly preferred for perceived speed — SSE pattern from Phase 3 is available)
- CoreData entity for chat messages (ChatMessage entity)
- `coach_messages` Supabase table schema
- Context summarization trigger threshold (e.g., when message count > 50)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### AI & Edge Function Patterns
- `supabase/functions/generate-plan/index.ts` — SSE streaming pattern, auth header workaround (Supabase Swift SDK bug #634 requires manual `Authorization: Bearer` header), OpenAI Structured Outputs schema shape

### Existing Integration Points
- `WorkoutApp/Features/Main/Tabs/CoachView.swift` — Empty state shell to replace with chat UI
- `WorkoutApp/Core/AppState.swift` — User profile and current plan available here for system prompt injection
- `WorkoutApp/Features/Session/SessionViewModel.swift` — Session data structure (last 3 sessions read from CoreData for coach context)
- `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` — CoreData schema (ChatMessage entity to add)

### Requirements
- `CHAT-01`: User can ask the AI coach any fitness-related question at any time
- `CHAT-02`: User can modify their workout plan by talking to the AI coach in natural conversation
- `CHAT-03`: AI coach has full context of user profile, goals, and workout history when responding
- `CHAT-04`: Deferred to Phase 8

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Supabase Edge Function pattern (`generate-plan/index.ts`) — SSE client, auth header injection, and OpenAI Structured Outputs reusable for coach Edge Function
- `AppState.swift` — user profile and current plan already available here
- Phase 4 `CDSessionLog` / `CDSetLog` CoreData entities — read last 3 sessions for system prompt injection
- Coach tab (`CoachView.swift`) — empty state shell ready to be replaced with chat interface

### Established Patterns
- Edge Function proxy for all AI calls (Phase 3) — `Authorization: Bearer` header must be sent manually due to Supabase Swift SDK bug #634
- GPT-4o mini for chat / GPT-4o for structured outputs — CLAUDE.md two-model strategy
- CoreData + Supabase dual persistence (Phase 2/3/4)
- NWPathMonitor for connectivity detection (Phase 4 `SessionSyncService`)

### Integration Points
- `CoachView` in tab bar — replace empty state with full chat interface
- `workout_plans` CoreData/Supabase — plan modifications write here
- Phase 4 session logs — read last 3 for system prompt context
- Phase 8 (Adaptive AI) will extend this with automated proactive messages

</code_context>

<specifics>
## Specific Ideas

- Inline confirmation card for plan changes feels like iMessage-style interactive notifications — native, non-disruptive
- Coach persona should match the Hone brand: direct, knowledgeable, not cheerleader-y
- Error bubble tap-to-retry follows iMessage / WhatsApp retry conventions — familiar to users

</specifics>

<deferred>
## Deferred Ideas

- Voice input for coach messages — future phase
- Coach-initiated proactive messages ("Your next session is tomorrow — anything to adjust?") — Phase 8 (Adaptive AI) [CHAT-04]
- Multiple conversation threads / topic tagging — v1 is single thread
- Coach memory beyond last 3 sessions (long-term pattern detection) — Phase 8
- Suggested prompt chips on empty state — kept clean for now, could add if users feel lost

</deferred>

---

*Phase: 05-ai-coach-chat*
*Context gathered: 2026-04-22*
