# AI Workout App

## What This Is

An AI-powered iPhone workout app that delivers fully personalized training programs to users of all fitness levels. The app combines clean exercise animatic videos with a conversational AI coach that builds custom plans, adapts in real-time, and guides users through every session. Users specify what equipment they have — from nothing to a full gym — and the AI handles the rest.

## Core Value

A conversational AI personal trainer in your pocket — one that knows you, builds your program, coaches you through sessions, and evolves with you as you improve.

## Requirements

### Validated

- [x] Disclaimer modal with physician-consult hard-block required before app access (SAFE-01) — Validated in Phase 1: Foundation
- [x] Email/password account creation and sign-in (AUTH-01) — Validated in Phase 1: Foundation
- [x] Persistent login via Keychain/Supabase session (AUTH-02) — Validated in Phase 1: Foundation
- [x] Password reset via email link (AUTH-03) — Validated in Phase 1: Foundation
- [x] Apple Sign-In as primary CTA (AUTH-04) — Validated in Phase 1: Foundation
- [x] AI safety guardrail system prompt + red-team test documentation (SAFE-02) — Validated in Phase 1: Foundation

### Active

*(All v1.0 requirements validated — see Validated section)*

### Validated (continued)

- [x] Exercise library with animatic-style instructional videos showing proper form (EXRC-01–04) — Validated in Phase 2: Exercise Library
- [x] AI onboarding that captures fitness level, goals, and available equipment (ONBD-01–02) — Validated in Phase 3: AI Onboarding
- [x] AI-generated workout plans with rationale and regeneration (AIPL-01–04) — Validated in Phase 3: AI Onboarding
- [x] In-session workout experience with videos, timers, rep/set tracking (SESS-01–04) — Validated in Phase 4: In-Session
- [x] Conversational AI coach for questions, plan modifications, and motivation (CHAT-01–04) — Validated in Phase 5: AI Coach Chat
- [x] Progress tracking — workout history, streaks, volume, PR notifications (PROG-01–04) — Validated in Phase 6: Progress Tracking
- [x] Monthly and annual subscription billing with annual discount (SUBS-01–04) — Validated in Phase 7: Subscriptions
- [x] Real-time adaptive workouts that adjust difficulty based on session performance (ADPT-01–02) — Validated in Phase 8: Adaptive AI
- [x] Smart re-engagement notifications for lapsed users (ADPT-03) — Validated in Phase 8: Adaptive AI
- [x] Support for all equipment contexts: bodyweight, home gym, full gym — Validated across Phases 3–8

### Out of Scope

- Social/community features — v1 focuses on the individual coaching experience; community adds complexity
- Live video coaching with real trainers — AI-only for scalability and margin
- Android version — iPhone first to maintain quality and iteration speed
- Nutrition tracking — keep focus on training; nutrition is a separate product area
- Wearable integrations (Apple Watch deep integration) — v1 iPhone app only

## Context

- **Platform**: iOS (iPhone) only for v1
- **Content**: Exercise animatic videos need to be sourced/licensed — not owned yet; this is a key early dependency
- **AI**: Full AI stack — personalized plan generation, adaptive real-time adjustments, and conversational coaching chat
- **Revenue model**: Monthly + annual subscriptions; annual plan offered at a discount to maximize LTV and improve cash flow predictability
- **Competitive landscape**: Competing against Nike Training Club, Fitbod, Peloton, and others; differentiators are superior AI personalization + clean animatic visuals + real conversational coaching interaction
- **Target user**: Everyone — all fitness levels, the app adapts to the user's situation

## Constraints

- **Platform**: iOS only — no Android in v1; keeps scope manageable and allows polish
- **Content dependency**: Exercise animatic videos must be sourced/licensed before the exercise library phase can complete
- **AI cost**: Per-user AI inference costs factor into pricing — subscription pricing must account for LLM costs at scale

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| iPhone only for v1 | Focus on one platform to ship faster and iterate | — Pending |
| Annual + monthly subscriptions | Maximizes LTV with annual discount; predictable revenue | — Pending |
| Animatic videos over live footage | Cleaner, more professional, avoids real-person production costs | — Pending |
| AI-only coaching (no live trainers) | Scales without headcount; consistent quality | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

## Current State

v1.0 milestone code-complete (2026-04-25). All 8 phases executed across 40 plans. Phase 8 human UAT pending (Supabase deployed, Edge Functions live, Xcode build passing). Code review issues resolved (12 findings: 2 critical, 6 warning, 4 info — all fixed).

---
*Last updated: 2026-04-25 after Phase 8: Adaptive AI complete (v1.0 milestone)*
