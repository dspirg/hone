---
status: partial
phase: 11-screen-redesigns
source: [11-VERIFICATION.md]
started: 2026-04-27T20:40:00Z
updated: 2026-04-27T20:40:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Home screen layout on device
expected: Five-section card-stack layout (greeting, adaptation banner, workout card with exercise rows, weekly streak bar, quick stats). Start Workout launches SessionView via fullScreenCover. After session dismiss, tab routes back to Home and stats refresh.
result: [pending]

### 2. Session screen 2:1 video + context cards
expected: Compact 2:1 aspect ratio video area with tap-to-expand overlay. Previous/Best context cards display below set rows with real rep data from SessionRepository. Three-state CTA button cycles correctly (Complete Set → Next Exercise → Finish Session).
result: [pending]

### 3. Summary screen emoji picker fits without scrolling
expected: On iPhone SE (3rd gen, 375x667pt) or any standard iPhone, the emoji difficulty picker is fully visible without scrolling. Stats show 4 items (Exercises, Sets, Reps, Duration). PR section capped at 80pt with internal scroll if needed.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
