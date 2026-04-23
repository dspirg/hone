# Phase 6: Progress Tracking - Context

**Gathered:** 2026-04-16
**Updated:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 adds a dedicated Progress tab where users can see their consistency streak, weekly completion ring, session history, personal records, and basic performance charts. Re-engagement notifications fire on planned workout days when no session has been logged. The focus is consistency visibility, natural PR discovery, and lightweight trend visualization.

</domain>

<decisions>
## Implementation Decisions

### Tab Placement
- **D-01:** New 5th tab added to MainTabView: Home — Train — Coach — Progress — Profile
- **D-02:** Progress tab uses `chart.bar.fill` SF Symbol
- **D-03:** ProgressView is the root view for the Progress tab; owns streak, history, charts, and PR display

### Primary Progress View
- **D-04:** Top section: current streak (consecutive days with a logged session) + weekly completion ring ("3/4 done this week")
- **D-05:** Below streak: scrollable chronological session history list — date, workout name, exercise count, set count
- **D-06:** Tapping a session row expands or navigates to a session detail view (exercises, sets, reps logged)
- **D-07:** Streak number should be visually prominent — it's the primary motivational hook for consistency

### Charts (PROG-04)
- **D-08:** Two charts included in Phase 6: sessions/week bar chart + total volume (sets x reps) over time line chart
- **D-09:** Implementation: Apple Swift Charts framework (iOS 16+, native, no dependencies)
- **D-10:** Charts appear below the session history section on the Progress tab
- **D-11:** Default time range for charts: last 8 weeks

### Personal Records
- **D-12:** PR detection runs at session completion: compare each exercise's max reps logged in a single set against all prior sessions
- **D-13:** PR = most reps completed for an exercise in a single set (reps only, no weight tracking in v1)
- **D-14:** PRs displayed as inline badge on the session completion summary screen (Phase 4 SessionSummaryView, extended here)
- **D-15:** PR badge shows exercise name, new record, and previous best
- **D-16:** No animated overlay or in-session celebration — understated, matches non-gamified tone
- **D-17:** No dedicated PR history screen in v1 — PRs surface at the moment they happen
- **D-18:** PR data stored in CoreData as derived value (recalculate from session logs, or store max per exercise)

### Re-engagement Notifications
- **D-19:** Local notifications only — no server push, no APNs certificates required
- **D-20:** Scheduled via `UNUserNotificationCenter` based on user's workout plan schedule (days of week)
- **D-21:** Fires at 7pm on each planned workout day if no session has been logged that day
- **D-22:** Copy is plan-aware + motivational: references the specific workout type ("Ready for your Push day? Your plan is waiting.")
- **D-23:** When streak >= 3 days, append streak info: "Push day is waiting — you're on a 5-day streak!"
- **D-24:** Notification permission requested once, after first session is completed (earned moment)
- **D-25:** No notification if session already logged that day (checked via CoreData query)

### Claude's Discretion
- Exact streak calculation logic (calendar day vs 24-hour window)
- Weekly ring implementation (SwiftUI shape or custom drawing)
- Session history row design details
- PR storage strategy (derived vs stored max in CoreData)
- Notification copy variants per workout type
- Chart styling, colors, and axis formatting
- Chart interaction (tap for detail vs static display)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Session Data (Phase 4)
- `WorkoutApp/Features/CoreData/SessionRepository.swift` — CDSessionLog/CDSetLog CRUD, write-ahead pattern, sync flags
- `WorkoutApp/Features/Session/SessionViewModel.swift` — Session lifecycle, set completion tracking
- `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — Completion summary screen where PR badges will be injected

### Tab Structure
- `WorkoutApp/Features/Main/MainTabView.swift` — Current 4-tab layout; Progress tab added here as 5th tab

### Requirements
- `.planning/REQUIREMENTS.md` §Progress Tracking — PROG-01 through PROG-04 requirements
- `.planning/ROADMAP.md` §Phase 6 — Success criteria and dependencies

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SessionRepository` — CoreData CRUD for CDSessionLog/CDSetLog; primary data source for all Progress features
- `PersistenceController.swift` — CoreData stack already set up; no new persistence setup needed
- `SessionSummaryView` — Phase 4 completion summary; PR badges injected here
- `SessionSyncService` — Handles CoreData → Supabase sync; progress data already synced

### Established Patterns
- CoreData for local data (Phase 2+) — session history reads from CDSessionLog entities
- MVVM with @Observable — ProgressViewModel will own streak/history/PR/chart logic
- Supabase sync (Phase 4) — progress data already synced; no new sync logic needed for history
- Tab bar uses `.tint(Color("AccentColor"))` for active state

### Integration Points
- `MainTabView.swift` — Add Progress tab between Coach and Profile
- `SessionSummaryView` — Extend with PR badge display (Phase 6 modifies Phase 4 screen)
- Phase 8 (Adaptive AI) reads session history for smart plan adaptation — Progress tab data feeds this
- `UNUserNotificationCenter` — New in Phase 6, requires Info.plist permission strings

</code_context>

<specifics>
## Specific Ideas

- Streak number should be visually prominent — it's the primary motivational hook for consistency
- PR moment on session completion should feel earned but understated (matches the app's non-gamified tone)
- Notification copy referencing the specific workout type ("Push day", "Leg day") makes it feel personal, not generic
- Streak info in notifications when streak >= 3 adds a subtle motivation lever without being pushy
- Charts should feel clean and informative, not dashboard-heavy — two simple charts are enough for v1

</specifics>

<deferred>
## Deferred Ideas

- Per-exercise performance trend charts — future phase when users have enough history
- Muscle group heatmap (body diagram showing what's been trained) — visually compelling but complex to build
- Server-push notifications for lapsed users (not just scheduled) — Phase 8 Adaptive AI handles re-engagement
- Workout history export (CSV, Apple Health) — post-v1
- Weight tracking per set + weight-based PRs — post-v1, requires session flow UI changes
- Animated PR celebration overlay during session — considered, decided against for non-gamified tone

</deferred>

---

*Phase: 06-progress-tracking*
*Context gathered: 2026-04-16*
*Context updated: 2026-04-23*
