# Phase 5: AI Coach Chat - Context

**Gathered:** 2026-04-22
**Updated:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 adds a persistent conversational AI coach to the Coach tab. Users can ask questions, report how they feel, and request plan modifications. The coach knows the user's profile, current plan, and recent session history. Plan changes are proposed inline and require explicit user confirmation before being applied. The coach is reactive only in Phase 5 — proactive messages are deferred to Phase 8.

</domain>

<decisions>
## Implementation Decisions

### Streaming UX
- **D-01:** Token-by-token streaming — words appear as they're generated, reusing the SSE pattern from `generate-plan` Edge Function
- **D-02:** Always auto-scroll — chat sticks to the bottom as tokens arrive, user always sees the latest word
- **D-03:** Input blocked during streaming — send button is disabled while coach is streaming a response. No interruption/cancellation support in Phase 5
- **D-04:** Pulsing cursor at end of streaming text — a blinking cursor appears at the end of the coach's message while tokens arrive, disappears when the response is complete

### Plan Modification Flow
- **D-05:** Coach proposes changes inline in the chat bubble: "I'd swap X for Y — want me to update your plan?"
- **D-06:** Inline confirmation card with before/after diff — compact card below the coach message showing what changes (e.g., "Bench Press 4×8 → Incline DB Press 3×10")
- **D-07:** All modification scopes supported: single exercise swap, multi-exercise changes within a day, and full plan regeneration
- **D-08:** [Confirm] and [Dismiss] buttons on the confirmation card
- **D-09:** On [Confirm]: call GPT-4o with Structured Outputs to regenerate the affected plan section; update `workout_plans` in Supabase and CoreData
- **D-10:** On [Dismiss]: coach acknowledges and continues conversation; no plan change made
- **D-11:** After confirmation, card animates to a compact "Plan updated ✓" state and stays in chat history as a record
- **D-12:** No silent modifications — user always explicitly confirms before plan changes apply

### Model Routing
- **D-13:** GPT-4o mini — all conversational turns (questions, motivation, feedback, general chat)
- **D-14:** GPT-4o — plan modification calls only (triggered by [Confirm] tap, uses Structured Outputs)
- **D-15:** Routing logic lives in the Supabase Edge Function: detect `action: "modify_plan"` in coach response JSON, route accordingly
- **D-16:** Both models called through the existing Edge Function proxy — never directly from iOS client

### Chat History & Sync
- **D-17:** Single ongoing thread per user — one persistent conversation, never reset
- **D-18:** Displayed with date section headers (Yesterday, Today, etc.)
- **D-19:** Load last 50 messages from CoreData on tab open; paginate older messages as user scrolls up (batches of 50)
- **D-20:** Messages sync to Supabase immediately after each exchange — user message + coach response synced right after streaming completes
- **D-21:** No offline message queuing — coach requires network. Offline = read-only history with banner
- **D-22:** Old messages summarized server-side when context window approaches limit — summary injected into system prompt, raw messages pruned from context
- **D-23:** [+] button reserved for future use (not wired in Phase 5)

### Coach Persona & Tone
- **D-24:** Direct expert personality — knowledgeable and efficient, doesn't waste words. Like a pro trainer who respects your time
- **D-25:** Response length: medium (3-5 sentences). Enough to explain reasoning briefly, still compact
- **D-26:** Uses user's name occasionally — not every message, but naturally in greetings and plan change discussions
- **D-27:** Coach has a visible name + icon next to messages (e.g., "Coach" label with an SF Symbol or custom icon). Feels like messaging a person

### Coach Context (System Prompt)
- **D-28:** Always injected per request: fitness profile (goal, level, equipment, injuries) + current workout plan + last 3 session summaries
- **D-29:** Session summaries are compact: date, workout name, exercises completed, sets logged
- **D-30:** Context does not grow unbounded — only last 3 sessions, full plan, profile

### Proactive Messages (CHAT-04)
- **D-31:** CHAT-04 (proactive check-in messages) is deferred to Phase 8 (Adaptive AI)
- Phase 5 is reactive only — user initiates all conversations
- Rationale: Phase 8 has full session history and pattern data needed to make proactive messages meaningful

### Offline Behavior
- **D-32:** Show a non-intrusive banner at the top of the chat: "No connection — coach unavailable"
- Send button is disabled while offline; message history remains readable
- Banner dismisses automatically when connectivity returns (consistent with Phase 4 session sync banner pattern)

### Error States
- **D-33:** Failed coach responses show an inline error bubble in the chat thread: "Something went wrong. Tap to retry."
- Tapping the error bubble resends the last message
- Plan modification failures show an inline error below the confirmation card
- Errors must always be visible and retryable — no silent failures

### Input Field
- **D-34:** Multi-line auto-expanding text input — starts as single line, expands up to 4 lines as user types
- Send button (arrow icon) on the right of the input field
- No character limit
- No voice input placeholder in Phase 5 (voice deferred)
- No suggested prompt chips — clean text + send only

### Claude's Discretion
- Exact system prompt template and coach persona copy (guided by D-24 through D-27)
- SwiftUI chat bubble component design (user vs coach alignment, colors)
- CoreData entity for chat messages (ChatMessage entity)
- `coach_messages` Supabase table schema
- Context summarization trigger threshold (e.g., when message count > 50)
- Coach name label text and icon choice (SF Symbol selection)

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
- `WorkoutApp/Core/Sync/SessionSyncService.swift` — NWPathMonitor connectivity pattern to reuse for offline banner

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
- `SessionSyncService.swift` — NWPathMonitor pattern reusable for chat connectivity detection

### Established Patterns
- Edge Function proxy for all AI calls (Phase 3) — `Authorization: Bearer` header must be sent manually due to Supabase Swift SDK bug #634
- GPT-4o mini for chat / GPT-4o for structured outputs — CLAUDE.md two-model strategy
- CoreData + Supabase dual persistence (Phase 2/3/4)
- NWPathMonitor for connectivity detection (Phase 4 `SessionSyncService`)
- `@Observable` + `@Environment(AppState.self)` for shared state
- MVVM: ViewModels are `@Observable @MainActor final class`

### Integration Points
- `CoachView` in tab bar — replace empty state with full chat interface
- `workout_plans` CoreData/Supabase — plan modifications write here
- Phase 4 session logs — read last 3 for system prompt context
- Phase 8 (Adaptive AI) will extend this with automated proactive messages

</code_context>

<specifics>
## Specific Ideas

- Inline confirmation card for plan changes feels like iMessage-style interactive notifications — native, non-disruptive
- Before/after diff in confirmation card: strikethrough old exercise, arrow to new exercise with updated sets/reps
- Coach persona: direct, knowledgeable, not cheerleader-y — respects the user's time
- Error bubble tap-to-retry follows iMessage / WhatsApp retry conventions — familiar to users
- Pulsing cursor during streaming mirrors ChatGPT conventions — users immediately understand the coach is "typing"

</specifics>

<deferred>
## Deferred Ideas

- Voice input for coach messages — future phase
- Coach-initiated proactive messages ("Your next session is tomorrow — anything to adjust?") — Phase 8 (Adaptive AI) [CHAT-04]
- Multiple conversation threads / topic tagging — v1 is single thread
- Coach memory beyond last 3 sessions (long-term pattern detection) — Phase 8
- Suggested prompt chips on empty state — kept clean for now, could add if users feel lost
- Message interruption/cancellation during streaming — kept simple for Phase 5

</deferred>

---

*Phase: 05-ai-coach-chat*
*Context gathered: 2026-04-22*
*Context updated: 2026-04-23*
