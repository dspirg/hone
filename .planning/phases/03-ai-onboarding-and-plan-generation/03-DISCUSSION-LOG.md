# Phase 3: AI Onboarding and Plan Generation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 03-ai-onboarding-and-plan-generation
**Areas discussed:** HomeView post-onboarding

---

## HomeView Post-Onboarding

| Option | Description | Selected |
|--------|-------------|----------|
| Today's session | Show today's scheduled workout — exercise list, estimated duration, muscle groups. One focused CTA: "Start Today's Workout" | ✓ |
| Weekly overview | Show all 5 days at a glance — same as plan preview screen, but condensed. User taps a day to drill in. | |
| Minimal | Simple card: "Your 4-day muscle building plan" + Start Training button. Details live in the Train tab. | |

**User's choice:** Today's session
**Notes:** HomeView shows today's scheduled workout with exercise list, estimated duration, and primary muscle groups.

---

## CTA Behavior (Phase 3 stub)

| Option | Description | Selected |
|--------|-------------|----------|
| Disabled / greyed out | "Start Workout" button visible but disabled with subtitle "Session tracking coming soon" | ✓ |
| Hidden until Phase 4 | Only show exercise list, no CTA | |
| Goes to exercise detail | Tapping navigates to first exercise's detail page | |

**User's choice:** Disabled / greyed out
**Notes:** Makes it feel real without needing Phase 4. Button activates in Phase 4.

---

## Claude's Discretion

- Exact exercise list display format within the today card
- Whether "today" defaults to Day 1 or uses schedule logic
- Estimated duration calculation (sum of exercise time estimates)

## Deferred Ideas

- Post-onboarding plan regeneration from HomeView/ProfileView — deferred to Phase 8
- Plan day labels (Day 1 vs. weekday names) — left to Claude's discretion
- "Start Training" stub navigation details — left to Claude's discretion
