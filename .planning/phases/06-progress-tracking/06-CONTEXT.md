# Phase 6: Progress Tracking - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 adds a Progress tab where users can see their consistency streak, weekly completion, session history, and personal records. Re-engagement notifications fire on planned workout days when no session has been logged. No charts or volume analytics in v1 — the focus is consistency visibility and natural PR discovery.

</domain>

<decisions>
## Implementation Decisions

### Primary Progress View
- Top: current streak (consecutive days with a logged session) + weekly completion ring ("3/4 done this week")
- Below: scrollable chronological session history list — date, workout name, exercise count, set count
- Tapping a session row expands or navigates to a session detail view (exercises, sets, reps logged)
- No charts or volume trend graphs in v1 — streak and history are sufficient for the target user

### Personal Records
- PR detection runs at session completion: compare each exercise's max reps logged against all prior sessions
- PRs displayed inline on the session completion summary screen (Phase 4 screen, extended here)
- PR badge shows exercise name, new record, and previous best
- No dedicated PR history screen in v1 — PRs surface at the moment they happen
- PR data stored in CoreData as a derived value (recalculate from session logs, or store max per exercise)

### Re-engagement Notifications
- Local notifications only — no server push, no APNs certificates required
- Scheduled via `UNUserNotificationCenter` based on user's workout plan schedule (days of week)
- Fires at 7pm on each planned workout day if no session has been logged that day
- Copy is plan-aware: references the specific workout type ("Ready for your Push day?")
- Notification permission requested once, after first session is completed (earned moment)
- No notification if session already logged that day (checked via CoreData query)

### Claude's Discretion
- Exact streak calculation logic (calendar day vs 24-hour window)
- Weekly ring implementation (SwiftUI shape or custom drawing)
- Session history row design details
- PR storage strategy (derived vs stored in CoreData)
- Notification copy variants per workout type

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Session log CoreData entities (Phase 4) — primary data source for all Progress features
- `PersistenceController.swift` — CoreData stack already set up
- Tab bar already has a Home tab that could surface streak — Progress tab is separate

### Established Patterns
- CoreData for local data (established Phase 2) — session history read from here
- Supabase sync (Phase 4) — progress data already synced; no new sync logic needed
- MVVM pattern — ProgressViewModel owns streak/history/PR logic

### Integration Points
- Phase 4 session completion screen — PR badge injected here (Phase 6 extends the Phase 4 summary)
- Phase 8 (Adaptive AI) reads session history for smart plan adaptation — Progress tab data feeds this
- `UNUserNotificationCenter` — new in Phase 6, requires Info.plist permission strings

</code_context>

<specifics>
## Specific Ideas

- Streak number should be visually prominent — it's the primary motivational hook for consistency
- PR moment on session completion should feel earned but understated (matches Hone's non-gamified tone)
- Notification copy referencing the specific workout type ("Push day", "Leg day") makes it feel personal, not generic

</specifics>

<deferred>
## Deferred Ideas

- Volume trend charts (sets/reps over time) — future phase when users have enough history to make charts meaningful
- Muscle group heatmap (body diagram showing what's been trained) — visually compelling but complex to build
- Server-push notifications for lapsed users (not just scheduled) — Phase 8 Adaptive AI handles re-engagement
- Workout history export (CSV, Apple Health) — post-v1

</deferred>
