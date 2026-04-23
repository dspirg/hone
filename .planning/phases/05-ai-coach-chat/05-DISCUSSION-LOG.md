# Phase 5: AI Coach Chat - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-23 (update session)
**Phase:** 05-ai-coach-chat
**Areas discussed:** Streaming UX, Plan modification UX, Chat history & sync, Coach persona & tone
**Type:** Update to existing context (originally gathered 2026-04-22)

---

## Streaming UX

| Option | Description | Selected |
|--------|-------------|----------|
| Token-by-token streaming | Words appear as generated — like ChatGPT. Reuses SSE pattern from generate-plan Edge Function. | ✓ |
| Typing indicator then full message | Show animated dots while generating, then reveal complete message at once. | |
| You decide | Claude picks based on existing patterns and UX goals | |

**User's choice:** Token-by-token streaming
**Notes:** Reuses existing SSE infrastructure from Phase 3.

| Option | Description | Selected |
|--------|-------------|----------|
| Always auto-scroll | Chat sticks to bottom as tokens arrive | ✓ |
| Auto-scroll unless user scrolled up | Stop auto-scrolling if user scrolled up to read history | |
| You decide | Claude picks based on chat app conventions | |

**User's choice:** Always auto-scroll

| Option | Description | Selected |
|--------|-------------|----------|
| Block input until done | Disable send button while streaming. Simpler, avoids race conditions. | ✓ |
| Allow interruption | User can send new message mid-stream — cancels current response. | |
| You decide | Claude picks based on complexity tradeoffs | |

**User's choice:** Block input until done

| Option | Description | Selected |
|--------|-------------|----------|
| Pulsing cursor at end of text | Blinking cursor at end of streaming text, disappears when complete. | ✓ |
| Subtle glow on coach bubble | Faint animated border/glow while streaming, settles when done. | |
| You decide | Claude picks the visual indicator | |

**User's choice:** Pulsing cursor at end of text

---

## Plan Modification UX

| Option | Description | Selected |
|--------|-------------|----------|
| Inline card with before/after | Compact card showing what changes: "Bench Press 4×8 → Incline DB Press 3×10" | ✓ |
| Text description only | Coach describes change in natural language, no visual diff card | |
| Expandable detail card | "View changes" tap expands to show full before/after | |

**User's choice:** Inline card with before/after

| Option | Description | Selected |
|--------|-------------|----------|
| Single exercise swap | One change at a time — atomic and easy to confirm | ✓ |
| Multi-exercise changes | Several changes at once, multiple before/after rows | ✓ |
| Full plan regeneration | Regenerate entire weekly plan via GPT-4o Structured Outputs | ✓ |

**User's choice:** All three scopes supported
**Notes:** Coach can handle anything from a single swap up to a full plan regeneration.

| Option | Description | Selected |
|--------|-------------|----------|
| Card shows checkmark + collapses | Animates to compact "Plan updated ✓" state, stays in history | ✓ |
| Card disappears | Removed from chat, coach sends new confirmation message | |
| You decide | Claude picks post-confirmation behavior | |

**User's choice:** Card shows checkmark + collapses

---

## Chat History & Sync

| Option | Description | Selected |
|--------|-------------|----------|
| Load last 50 from CoreData, paginate up | Recent messages instantly from local storage, scroll up for older batches | ✓ |
| Load all from CoreData | Entire conversation loaded at once | |
| You decide | Claude picks pagination strategy | |

**User's choice:** Load last 50 from CoreData, paginate up

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately after each exchange | User message + coach response synced right after streaming completes | ✓ |
| Background batch sync | Accumulate locally, sync periodically | |
| You decide | Claude picks sync strategy | |

**User's choice:** Immediately after each exchange

| Option | Description | Selected |
|--------|-------------|----------|
| No — coach requires network | Offline = read-only history with banner. No queuing. | ✓ |
| Yes — queue and retry | Queue message locally, send when network returns | |

**User's choice:** No — coach requires network

---

## Coach Persona & Tone

| Option | Description | Selected |
|--------|-------------|----------|
| Direct expert | Knowledgeable and efficient. Like a pro trainer who respects your time. | ✓ |
| Encouraging mentor | Warm and supportive. Celebrates progress, checks in on feelings. | |
| Balanced | Expert knowledge with human touch, adapts tone to context. | |

**User's choice:** Direct expert

| Option | Description | Selected |
|--------|-------------|----------|
| Short — 2-3 sentences | Concise, get to the point | |
| Medium — 3-5 sentences | Enough to explain reasoning briefly, still compact | ✓ |
| Adaptive | Length dictated by question complexity | |

**User's choice:** Medium — 3-5 sentences

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, occasionally | Use name naturally — greetings, plan changes, not every message | ✓ |
| No | Keep generic, personalization via plan/history knowledge | |
| You decide | Claude picks based on persona | |

**User's choice:** Yes, occasionally

| Option | Description | Selected |
|--------|-------------|----------|
| Icon only | Small SF Symbol next to coach messages, no name label | |
| Name + icon | Coach messages labeled with name plus icon | ✓ |
| No avatar | Left-aligned bubbles with different color, no persona artifacts | |

**User's choice:** Name + icon

---

## Claude's Discretion

- Exact system prompt template text (guided by persona decisions D-24 through D-27)
- SwiftUI chat bubble component design (colors, alignment)
- CoreData ChatMessage entity schema
- `coach_messages` Supabase table schema
- Context summarization trigger threshold
- Coach name label text and SF Symbol icon choice

## Deferred Ideas

- Voice input — future phase
- Proactive messages — Phase 8
- Multiple threads — v1 is single thread
- Long-term memory — Phase 8
- Suggested prompt chips — deferred
- Message interruption during streaming — kept simple for Phase 5
