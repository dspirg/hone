# Phase 8: Adaptive AI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 08-adaptive-ai
**Areas discussed:** Post-session rating UX, AI adaptation strategy, Missed session handling, Smart notifications

---

## Post-Session Rating UX

| Option | Description | Selected |
|--------|-------------|----------|
| Emoji scale | 3-5 emoji faces (too easy to too hard) — fast, intuitive, no cognitive load | ✓ |
| 1-5 star scale | Traditional star rating — familiar but conflates quality with difficulty | |
| Simple 3-option | Three buttons: Too Easy / Just Right / Too Hard — minimal friction | |

**User's choice:** Emoji scale
**Notes:** Common in fitness apps like Fitbod and WHOOP

| Option | Description | Selected |
|--------|-------------|----------|
| Required | Always shown on SessionSummaryView before dismissing | ✓ |
| Optional with nudge | Shown but skippable with Skip button | |
| Optional, hidden | Available in session history but not prompted | |

**User's choice:** Required
**Notes:** Ensures AI always has signal. Single tap, minimal friction.

---

## AI Adaptation Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Immediate next session | Rate today → tomorrow adjusted. Real-time feedback. | ✓ |
| Weekly plan refresh | Ratings accumulate, full plan regen weekly | |
| Both micro + macro | Immediate light + weekly full evolution | |

**User's choice:** Immediate next session

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-evolve weekly | AI reviews 2-4 weeks, regenerates plan each Monday | ✓ |
| Milestone-triggered | Plan stays until plateau detected | |
| User-initiated | User taps "Refresh my plan" when ready | |

**User's choice:** Auto-evolve weekly

| Option | Description | Selected |
|--------|-------------|----------|
| Brief rationale | Short AI note on changed exercises | ✓ |
| Coach chat message | Proactive chat message explaining changes | |
| No explanation | Plan changes silently | |

**User's choice:** Brief rationale

---

## Missed Session Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Smart redistribute | AI redistributes missed exercises across remaining days | ✓ |
| Drop and continue | Missed day is gone, next day proceeds as planned | |
| Stack on next day | Missed exercises added to next session | |

**User's choice:** Smart redistribute

| Option | Description | Selected |
|--------|-------------|----------|
| After 1 missed day | Immediate redistribution next day | ✓ |
| After 2 missed days | Waits to see pattern | |
| End of week | Reviews at week's end | |

**User's choice:** After 1 missed day

---

## Smart Notifications

| Option | Description | Selected |
|--------|-------------|----------|
| Missed 2+ consecutive days | Nudge after 2 missed planned sessions | ✓ |
| Missed 3+ days | More conservative, 3 missed days | |
| Streak about to break | Notify when streak at risk | |

**User's choice:** Missed 2+ consecutive days

| Option | Description | Selected |
|--------|-------------|----------|
| Supportive coach | "Your plan adapted — ready when you are." No guilt. | ✓ |
| Streak/gamification | "Don't lose your streak!" Motivating but pressuring. | |
| Informational | "Your updated plan is ready." Neutral. | |

**User's choice:** Supportive coach

| Option | Description | Selected |
|--------|-------------|----------|
| Max 2 per week | Prevents fatigue, back off after 2 | ✓ |
| Max 1 per week | Very conservative | |
| No cap, daily | Persistent but risks disabling | |

**User's choice:** Max 2 per week

---

## Claude's Discretion

- Emoji count and specific emoji choices
- Progressive overload percentages and adjustment algorithms
- Weekly plan regeneration timing
- Notification scheduling logic for re-engagement

## Deferred Ideas

None
