# Phase 4: In-Session Workout Experience - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 delivers the core workout execution experience: a user can open an AI-generated workout plan, execute the session exercise by exercise, log their sets and reps, rest between sets with a guided timer, and complete the session with a summary — entirely offline, with data syncing automatically when connectivity returns.

</domain>

<decisions>
## Implementation Decisions

### Session Navigation
- Linear, one-at-a-time exercise flow — full-screen card per exercise, swipe or tap Next to advance
- Progress indicator at top: "Exercise 2 of 6" + segmented progress bar at N% fill
- No jumping between exercises mid-session — user moves through the AI plan in order
- Video player lives at the top of the exercise card; set logging rows below it

### Set & Rep Logging
- +/− stepper per set row — pre-filled with target reps from the AI plan
- Tap the rep number to open a number pad for direct input (override stepper)
- Checkmark taps to confirm set complete and triggers rest timer automatically
- Sets display in order (Set 1, Set 2, etc.) with target reps shown as placeholder until logged

### Rest Timer
- Auto-starts as a full-screen overlay when a set is marked complete
- Countdown timer (circular progress ring) with next set/exercise context shown below
- Controls: [+30s] to extend, [Skip Rest] to dismiss immediately
- Default durations: 60s for strength exercises, 30s for cardio/bodyweight (set in plan metadata)
- Haptic feedback + soft sound when timer expires; notification if app is backgrounded

### Offline & Sync
- Write-ahead local: all set logs written to CoreData immediately, regardless of connectivity
- On reconnect, CoreData → Supabase sync runs silently in background — no user-visible action
- No conflict resolution needed — session data is append-only (past sessions are never edited)
- Sync status not surfaced to user unless sync fails after 3 retries (then show subtle banner)

### Session Completion
- Summary screen shown at end of session: exercises completed, total sets, total reps, duration
- "Great work" moment — simple, non-gamified. Shows what was done, not a score
- Data saved before summary shown — session is committed to CoreData on last set logged

### Claude's Discretion
- Exact CoreData entity schema for session logs (SessionLog, SetLog entities)
- Supabase `session_logs` and `set_logs` table column details
- SwiftUI transition animation between exercise cards (slide, scale, etc.)
- Circular progress ring implementation for rest timer
- Background sync implementation (NWPathMonitor vs URLSession background configuration)
- Exact copy for rest timer screen and session completion summary

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PersistenceController.swift` (Phase 2) — CoreData stack already set up; new entities added here
- `ExerciseDetailView.swift` / `VideoPlayerView.swift` (Phase 2) — video playback patterns reusable for in-session video
- `AppState.swift` — session state can live here or in a dedicated SessionViewModel
- `workout_plans` CoreData entity (Phase 3) — session starts from a stored plan

### Established Patterns
- CoreData for local persistence, Supabase for remote sync (established Phase 2)
- MVVM: ViewModels own business logic, Views are thin (established Phase 1)
- NWPathMonitor or `.task` async for connectivity detection
- SwiftUI `.fullScreenCover` for full-screen overlays (established Phase 1)

### Integration Points
- Train tab (`TrainView`) — session launches from here; active plan displayed
- `workout_plans` table / CoreData — session reads the plan to know exercises, sets, reps
- Phase 5 (AI Coach Chat) will consume session logs for adaptive coaching
- Phase 6 (Progress Tracking) will read session logs for history/streaks

</code_context>

<specifics>
## Specific Ideas

- Full-screen card per exercise is the right container — video top, logging bottom, clean separation
- Rest timer overlay matches the dark/premium aesthetic — large countdown number, minimal chrome
- Session summary should feel like a "moment" — not a score screen, just clean acknowledgment of work done

</specifics>

<deferred>
## Deferred Ideas

- Weight logging per set (e.g., "135 lbs × 8 reps") — Phase 4 logs reps only; weight tracking considered for Phase 6 (Progress Tracking) or a future phase
- Workout modification mid-session (swap exercise, skip exercise) — deferred; Phase 5 AI Coach handles plan changes via chat
- Apple Watch companion for timer/logging — out of scope for v1 (CLAUDE.md constraint)
- Social sharing of session summary — v1 is individual-focused; community features out of scope

</deferred>
