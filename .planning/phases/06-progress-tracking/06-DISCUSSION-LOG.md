# Phase 6: Progress Tracking - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-23
**Phase:** 06-progress-tracking
**Areas discussed:** PROG-04 charts gap, Tab placement, PR detection scope, Notification timing

---

## PROG-04 Charts Gap

| Option | Description | Selected |
|--------|-------------|----------|
| Include basic charts | Add simple charts (sessions/week bar, volume line) — satisfies PROG-04 | ✓ |
| Keep deferred | Formally descope PROG-04 from Phase 6, move to later phase | |
| Minimal visualization | SwiftUI shapes for sparklines, lightweight alternative | |

**User's choice:** Include basic charts
**Notes:** ROADMAP success criterion #4 requires charts; previous context deferred them. User chose to include.

### Chart Types

| Option | Description | Selected |
|--------|-------------|----------|
| Sessions/week + volume | Bar chart for sessions per week, line chart for total volume over time | ✓ |
| Sessions/week only | Single bar chart showing workout frequency | |
| Full dashboard | Sessions/week, volume, plus per-exercise performance trends | |

**User's choice:** Sessions/week + volume

### Chart Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Swift Charts | Apple's native Charts framework (iOS 16+), SwiftUI-native | ✓ |
| Custom SwiftUI shapes | Hand-drawn using Path/Shape, full control | |
| You decide | Claude picks best approach | |

**User's choice:** Swift Charts (Recommended)

---

## Tab Placement

| Option | Description | Selected |
|--------|-------------|----------|
| New 5th tab | Add Progress tab between Coach and Profile | ✓ |
| Inside Home tab | Surface streak on Home, drill into full progress | |
| Inside Profile tab | Progress as section within Profile | |

**User's choice:** New 5th tab (Recommended)

### Tab Icon and Position

| Option | Description | Selected |
|--------|-------------|----------|
| chart.bar.fill after Coach | Home — Train — Coach — Progress — Profile | ✓ |
| flame.fill after Train | Home — Train — Progress — Coach — Profile | |
| You decide | Claude picks icon and position | |

**User's choice:** chart.bar.fill after Coach

---

## PR Detection Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Reps only (current) | PR = most reps in a single set. Simple, works for bodyweight | ✓ |
| Reps + total volume | Max reps per set AND total session volume | |
| Add weight tracking | Log weight per set, PRs include heaviest weight | |

**User's choice:** Reps only (current)

### PR Celebration Prominence

| Option | Description | Selected |
|--------|-------------|----------|
| Inline badge on summary | PR badge on session completion summary, understated | ✓ |
| Animated overlay | Confetti/glow animation during session | |
| Both summary + in-session | Subtle animation during session plus badge on summary | |

**User's choice:** Inline badge on summary

---

## Notification Timing

### Permission Request Timing

| Option | Description | Selected |
|--------|-------------|----------|
| After first session (current) | Request after completing first workout, earned moment | ✓ |
| During onboarding | Higher impression rate but lower grant rate | |
| After third session | Strongest engagement signal but delays benefit | |

**User's choice:** After first session (current)

### Notification Copy Style

| Option | Description | Selected |
|--------|-------------|----------|
| Plan-aware + motivational | References specific workout type, feels personal | ✓ |
| Streak-aware | Uses streak count as primary motivation lever | |
| Simple reminder | Neutral, no pressure | |
| You decide | Claude picks based on coach persona | |

**User's choice:** Plan-aware + motivational

### Streak Info in Notifications

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, combine both | Plan-aware primary, streak as bonus when streak >= 3 | ✓ |
| No, keep it clean | Only reference workout type, streak stays in-app | |

**User's choice:** Yes, combine both

---

## Claude's Discretion

- Exact streak calculation logic (calendar day vs 24-hour window)
- Weekly ring implementation
- Session history row design
- PR storage strategy (derived vs stored)
- Chart styling, colors, axis formatting
- Chart interaction (tap for detail vs static)

## Deferred Ideas

- Per-exercise performance trend charts — future phase
- Muscle group heatmap — complex to build
- Server-push notifications — Phase 8
- Workout history export (CSV, Apple Health) — post-v1
- Weight tracking + weight-based PRs — post-v1
- Animated PR celebration overlay — considered, decided against
