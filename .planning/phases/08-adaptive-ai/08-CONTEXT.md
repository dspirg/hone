# Phase 8: Adaptive AI - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

The AI actively adapts each user's next workout based on post-session feedback and accumulated performance data. Smart notifications re-engage lapsed users. This phase makes the training plan a living document that evolves with the user.

</domain>

<decisions>
## Implementation Decisions

### Post-Session Rating UX
- **D-01:** Emoji scale (3-5 faces from "too easy" to "too hard") for difficulty rating — fast, intuitive, no cognitive load
- **D-02:** Rating is required — always shown on SessionSummaryView before dismissal. Single tap, minimal friction. AI always has signal.

### AI Adaptation Strategy
- **D-03:** Immediate next-session adjustment — rate "too hard" today, tomorrow's workout is lighter. Users see the AI responding in real-time.
- **D-04:** Auto-evolve weekly — AI reviews last 2-4 weeks of session data and regenerates the plan each week. Progressive overload built in. Plan changes every Monday.
- **D-05:** Brief rationale on changed exercises — short AI note like "Increased weight — you rated last 3 sessions as too easy." Builds trust without clutter.

### Missed Session Handling
- **D-06:** Smart redistribute — AI redistributes key exercises from missed day across remaining days. Week's training volume stays intact.
- **D-07:** Trigger after 1 missed day — user opens the app the next day and sees an updated plan. Feels responsive.

### Smart Notifications
- **D-08:** Trigger after 2+ consecutive missed planned sessions. Avoids nagging for one-off rest days.
- **D-09:** Supportive coach tone — "Your plan adapted to your schedule — ready when you are." Encouraging, no guilt. Emphasizes the AI adapted for them.
- **D-10:** Max 2 re-engagement notifications per week. After 2 nudges with no response, back off until user opens the app.

### Claude's Discretion
- Emoji count (3 vs 5 faces) and specific emoji choices
- Exact progressive overload percentages and adjustment algorithms
- Weekly plan regeneration timing (e.g., Sunday night vs Monday morning)
- Notification scheduling logic for re-engagement (time of day, day of week)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### AI Layer
- `supabase/functions/generate-plan/index.ts` — Existing plan generation Edge Function (GPT-4o with structured outputs)
- `supabase/functions/coach-chat/index.ts` — Coach chat with plan modification routing (GPT-4o mini)
- `CLAUDE.md` §AI Layer — Two-model strategy, system prompt architecture, cost model

### Session Data
- `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — Deferred rating placeholder ("no difficulty rating — Phase 8")
- `WorkoutApp/Features/Session/SessionViewModel.swift` — Session state machine, rest timer
- `WorkoutApp/Core/Data/SessionRepository.swift` — CDSessionLog, CDSetLog CoreData entities

### Notifications
- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — Existing local notification infrastructure (streak-aware, UNCalendarNotificationTrigger, earned moment permission pattern)

### Progress & History
- `WorkoutApp/Features/Progress/ProgressViewModel.swift` — Streak, weekly ring, chart data, PR detection

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **NotificationScheduler**: Already handles workout reminders with streak-aware copy (Phase 6). Extend for re-engagement notifications.
- **SessionSummaryView**: Has explicit Phase 8 placeholder for difficulty rating — drop-in point ready.
- **coach-chat Edge Function**: Already has plan modification routing via `execute_modify` path — can be extended for adaptation.
- **generate-plan Edge Function**: Plan generation with structured outputs — base for weekly regeneration.
- **ProgressViewModel**: Has streak tracking, session history queries — data source for adaptation decisions.

### Established Patterns
- **System prompt injection**: User profile + history summary injected per AI request (CLAUDE.md pattern)
- **SSE streaming**: PlanSSEClient for plan generation, CoachSSEClient for chat — reuse for adaptation responses
- **CoreData + Supabase sync**: SessionSyncService pattern for offline-first with background sync
- **Edge Function proxy**: All AI calls go through Supabase Edge Functions (never client-direct)

### Integration Points
- SessionSummaryView.swift — Add emoji rating before "Done" button
- CDSessionLog — Add difficulty_rating field to CoreData entity + Supabase migration
- generate-plan Edge Function — Add adaptation context (ratings, performance trends) to system prompt
- NotificationScheduler — Add re-engagement notification category with frequency cap

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-adaptive-ai*
*Context gathered: 2026-04-24*
