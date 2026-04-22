# Phase 5: AI Coach Chat - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 05-ai-coach-chat
**Areas discussed:** CHAT-04 scoping, Offline behavior, Error states, Input field UX

---

## CHAT-04 Scoping

| Option | Description | Selected |
|--------|-------------|----------|
| Defer to Phase 8 | Phase 5 reactive only; Phase 8 adds proactive messages when full session history available | ✓ |
| Basic trigger in Phase 5 | Post-session automatic message "Great session! Anything feel off?" | |

**User's choice:** Defer to Phase 8
**Notes:** Phase 5 is reactive only. CHAT-04 requirement explicitly deferred — Phase 8 has the pattern data needed to make proactive messages meaningful.

---

## Offline Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Banner + disabled input | Non-intrusive top banner "No connection — coach unavailable", send button disabled, history readable | ✓ |
| Allow queuing | Messages queue locally and deliver on reconnect | |
| Silent disable | Send button does nothing / brief toast | |

**User's choice:** Banner + disabled input
**Notes:** Consistent with Phase 4 session sync banner pattern.

---

## Error States

| Option | Description | Selected |
|--------|-------------|----------|
| Inline error bubble + retry | Error bubble in chat thread, tap to retry; plan mod errors inline below confirm card | ✓ |
| Toast + manual retry | Toast/snackbar at bottom, user re-sends manually | |
| Claude's discretion | Planner decides exact error UX | |

**User's choice:** Inline error bubble + retry
**Notes:** Follows iMessage/WhatsApp retry conventions. Both coach response failures and plan modification failures handled inline.

---

## Input Field UX

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-line auto-expand | Starts single line, expands to 4 lines; send button right | ✓ |
| Single-line only | Fixed single-line, scrolls horizontally | |

**User's choice:** Multi-line auto-expand, no character limit, no voice placeholder, no suggested chips — clean text + send only.

---

## Claude's Discretion

- System prompt template and coach persona copy
- Chat bubble design (alignment, colors)
- Streaming implementation (SSE from Phase 3 is available and preferred)
- CoreData ChatMessage entity design
- `coach_messages` Supabase table schema
- Context summarization trigger threshold

## Deferred Ideas

- Voice input — future phase
- Proactive messages (CHAT-04) — Phase 8
- Multiple threads / topic tagging — v2
- Long-term coach memory — Phase 8
- Suggested prompt chips — deferred, keep clean for now
