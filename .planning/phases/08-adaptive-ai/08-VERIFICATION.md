---
phase: 08-adaptive-ai
verified: 2026-04-25T16:00:00Z
status: human_needed
score: 18/18 must-haves verified (code-complete); 0/3 roadmap success criteria confirmed (require deployment + human E2E)
overrides_applied: 0
human_verification:
  - test: "Post-session adaptation visible in next workout"
    expected: "After rating a session 'too hard', the next workout in TrainView shows reduced volume (fewer sets or reps) and the AdaptationSummaryBanner explains what changed"
    why_human: "Requires running the app against a live Supabase instance with deployed Edge Functions (Plan 06 tasks pending). Cannot verify network round-trip or GPT-4o response programmatically."
  - test: "Plan evolution over weeks (ADPT-02)"
    expected: "After several weeks of sessions with ratings, the active plan in user_plans shows structural changes reflecting performance data (exercise swaps, volume progression)"
    why_human: "Requires time-passing simulation with live Supabase data. regenerate-plan logic verified in code but outcome requires human observation."
  - test: "Missed session redistribution (ADPT-03)"
    expected: "Skipping a planned Monday session then opening the app triggers the adapt-plan function with trigger_type=missed_session, and the updated plan redistributes compound exercises across remaining days"
    why_human: "Requires Supabase deployment (supabase db push + supabase functions deploy) and live device/simulator testing to observe the plan update."
  - test: "Supabase schema push and Edge Function deployment (Plan 06)"
    expected: "supabase db push succeeds, difficulty_rating column exists on session_logs, plan_adaptations table exists with RLS, both adapt-plan and regenerate-plan appear Active in supabase functions list"
    why_human: "Deployment commands require developer credentials and a live Supabase project. Cannot run supabase CLI in automated verification context."
  - test: "Re-engagement notification copy and tone (D-09)"
    expected: "Notification body text 'Your plan adapted to your schedule — ready when you are.' appears on-device without guilt language and fires only after 2+ missed sessions"
    why_human: "UNUserNotificationCenter behavior requires a running app on device/simulator. Guilt blocklist logic is verified in code; actual notification delivery needs human confirmation."
---

# Phase 8: Adaptive AI Verification Report

**Phase Goal:** The AI actively adapts each user's next workout based on post-session feedback and accumulated performance data; smart notifications re-engage lapsed users
**Verified:** 2026-04-25T16:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

All code for Phase 8 is written, wired, and substantive across Plans 01-05. Plan 06 (Supabase schema push + Edge Function deployment + human E2E verification) is intentionally deferred and marked `human_needed` in its SUMMARY. Automated verification covers the full code layer. The three ROADMAP success criteria cannot be confirmed without the live deployment and human testing called for by Plan 06.

### Observable Truths (Must-Haves from Plan Frontmatter)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | difficulty_rating column exists on session_logs table with CHECK constraint | VERIFIED | `supabase/migrations/20260425000000_phase8_adaptation.sql` line 9: `ADD COLUMN difficulty_rating TEXT CHECK (difficulty_rating IN ('too_easy', 'just_right', 'too_hard'))` |
| 2 | plan_adaptations audit table exists with RLS and index | VERIFIED | Migration SQL lines 14-37: CREATE TABLE with 9 columns, index on (user_id, adapted_at DESC), ENABLE ROW LEVEL SECURITY, SELECT policy for auth.uid() |
| 3 | CDSessionLog CoreData entity has difficultyRating optional String attribute | VERIFIED | `WorkoutApp.xcdatamodel/contents` line 53: `<attribute name="difficultyRating" optional="YES" attributeType="String"/>` |
| 4 | DifficultyRating Swift enum exists with raw values matching DB CHECK constraint | VERIFIED | `DifficultyRating.swift`: enum with `tooEasy="too_easy"`, `justRight="just_right"`, `tooHard="too_hard"` — exact match to DB constraint |
| 5 | planSchema extracted to _shared/ and imported by generate-plan and coach-chat | VERIFIED | `_shared/planSchema.ts` exports `planSchema`; generate-plan line 12 and coach-chat line 16 both import from `"../_shared/planSchema.ts"`; no local `const planSchema` in either file |
| 6 | adaptedPlanSchema Zod validation exists in _shared/ | VERIFIED | `_shared/adaptedPlanSchema.ts` imports Zod v3.23.8, exports `ExerciseSchema`, `TrainingDaySchema`, `AdaptedPlanSchema`, `AdaptedPlan` type |
| 7 | SessionSyncService includes difficultyRating in sync payload | VERIFIED | `SessionSyncService.swift` lines 190+202: `let difficultyRating: String?` and `case difficultyRating = "difficulty_rating"` in `SessionLogRow`; constructed at line 111 from `s.difficultyRating` |
| 8 | User sees 3 emoji buttons on session summary screen before Done button | VERIFIED | `SessionSummaryView.swift`: `ForEach(DifficultyRating.allCases, id: \.self)` renders 3 emoji buttons in "How was that?" section |
| 9 | Done button is disabled until user taps a difficulty rating | VERIFIED | `SessionSummaryView.swift`: `.disabled(selectedRating == nil)` on Done button |
| 10 | Rating value flows from SessionSummaryView through SessionViewModel to CoreData | VERIFIED | Full chain: `onDone: (DifficultyRating) -> Void` → `SessionView` line 77-78 calls `vm.saveDifficultyRating(rating)` → `SessionViewModel.saveDifficultyRating` calls `repository.saveDifficultyRating` → `SessionRepository` writes `session.difficultyRating = rating.rawValue` |
| 11 | adapt-plan Edge Function receives POST, queries Supabase in parallel, calls GPT-4o, validates with Zod, writes audit log, updates user_plans | VERIFIED | `supabase/functions/adapt-plan/index.ts`: Promise.all for session_logs/user_plans/profiles, `model: "gpt-4o-2024-08-06"`, `stream: false`, `max_completion_tokens: 2000`, `temperature: 0.3`, `AdaptedPlanSchema.safeParse`, INSERT to `plan_adaptations`, UPDATE `user_plans` |
| 12 | adapt-plan handles both post_session and missed_session trigger types | VERIFIED | Lines 295-309: validates `allowedTriggers = ["post_session", "missed_session"]`; separate handling paths for each trigger |
| 13 | regenerate-plan checks cache by ISO week key | VERIFIED | `getISOWeekKey()` function, cache query against `plan_adaptations` with `trigger_type="weekly"` and `cache_key=${userId}-${isoWeek}`; returns `X-Cache: HIT` on hit |
| 14 | AdaptationService calls adapt-plan/regenerate-plan with Bearer auth | VERIFIED | `AdaptationService.swift`: `request.setValue("Bearer \(accessToken)", ...)` in `callEdgeFunction`; fetches token internally via `supabase.auth.session` |
| 15 | MissedSessionDetector only flags planned training days, not rest days | VERIFIED | `MissedSessionDetector.swift`: filters against `activePlanDayLabels` (caller-supplied planned days only); day-of-week map used only for "is this day in the past?" check |
| 16 | AdaptationService injected via @Environment at MainTabView level | VERIFIED | `MainTabView.swift`: `@State private var adaptationService = AdaptationService()`, `.environment(adaptationService)` applied to TabView; scenePhase `.onChange` calls `checkOnForeground` |
| 17 | NotificationScheduler has scheduleReengagementNotificationIfNeeded with 2+ miss guard and 2/week cap | VERIFIED | `NotificationScheduler.swift`: `guard missedSessionCount >= 2`, `guard reengagementPending.count < 2`, guilt blocklist (`guiltPatterns`: 9 NSRegularExpression patterns), `safeFallbackBody`, `passesGuiltBlocklist()` |
| 18 | AdaptationService.checkOnForeground calls scheduleReengagementNotificationIfNeeded after missed detection | VERIFIED | `AdaptationService.swift` lines 151-153: `if missedDays.count >= 2 { await NotificationScheduler.shared.scheduleReengagementNotificationIfNeeded(missedSessionCount: missedDays.count) }` |

**Score:** 18/18 must-haves verified (code layer complete)

### ROADMAP Success Criteria

| # | Success Criterion | Status | Evidence |
|---|------------------|--------|----------|
| 1 | After rating a session's difficulty, the user's next workout visibly reflects the adjustment | NEEDS HUMAN | Code path exists end-to-end; requires live Supabase deployment and device testing (Plan 06) |
| 2 | After several weeks of sessions, the user's training plan has evolved to reflect accumulated performance data | NEEDS HUMAN | regenerate-plan history summarization and OpenAI call verified in code; runtime outcome requires weeks of data + deployed environment |
| 3 | When a user skips sessions, the remaining plan updates rather than stacking missed work | NEEDS HUMAN | adapt-plan missed_session handling and MissedSessionDetector verified in code; runtime behavior requires deployment and manual test |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/20260425000000_phase8_adaptation.sql` | DB schema for Phase 8 | VERIFIED | Contains difficulty_rating ALTER, plan_adaptations CREATE, RLS, index |
| `WorkoutApp/Features/Models/DifficultyRating.swift` | DifficultyRating enum | VERIFIED | 3 cases with rawValues matching DB constraint exactly |
| `supabase/functions/_shared/planSchema.ts` | Shared plan schema | VERIFIED | Exports `planSchema` — imported by generate-plan, coach-chat, adapt-plan, regenerate-plan |
| `supabase/functions/_shared/adaptedPlanSchema.ts` | Zod validation schema | VERIFIED | Exports ExerciseSchema, TrainingDaySchema, AdaptedPlanSchema, AdaptedPlan |
| `supabase/functions/_shared/promptBuilder.ts` | Prompt helpers | VERIFIED | Exports estimateTokens, assertPromptBudget, stripRationale, passesLanguageGuardrail, sanitizeRationale |
| `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` | Emoji rating UI | VERIFIED | 3 emoji buttons via ForEach(DifficultyRating.allCases), Done disabled until rated |
| `WorkoutApp/Features/Session/SessionViewModel.swift` | Rating persistence | VERIFIED | `func saveDifficultyRating(_ rating: DifficultyRating)` present |
| `WorkoutApp/Features/CoreData/SessionRepository.swift` | CoreData write | VERIFIED | `func saveDifficultyRating` writes `session.difficultyRating = rating.rawValue` |
| `supabase/functions/adapt-plan/index.ts` | Post/missed session adaptation | VERIFIED | GPT-4o non-streaming, 5 adaptation rules, Zod validation, plan_adaptations INSERT, user_plans UPDATE |
| `supabase/functions/regenerate-plan/index.ts` | Weekly plan regeneration | VERIFIED | ISO week cache, historySummary, GPT-4o call, plan_adaptations with cache_key, X-Cache headers |
| `WorkoutApp/Features/Adaptation/AdaptationService.swift` | iOS adaptation client | VERIFIED | @Observable @MainActor, all 3 Edge Function call methods, checkOnForeground, Bearer auth |
| `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` | Missed session detection | VERIFIED | Pure static struct, only flags activePlanDayLabels vs completed sessions in current ISO week |
| `WorkoutApp/Features/Adaptation/Models/AdaptedPlan.swift` | Response model | VERIFIED | AdaptedPlanResponse, AdaptedDay, AdaptedExercise, AdaptPlanRequest with snake_case CodingKeys |
| `WorkoutApp/Core/Notifications/NotificationScheduler.swift` | Re-engagement notifications | VERIFIED | scheduleReengagementNotificationIfNeeded, guiltPatterns, 2+ guard, 2/week cap |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `SessionSummaryView` | `SessionViewModel` | `onDone: (DifficultyRating) -> Void` | WIRED | `SessionView.swift` line 77: `onDone: { rating in vm.saveDifficultyRating(rating) }` |
| `SessionViewModel` | `SessionRepository` | `saveDifficultyRating call` | WIRED | `SessionViewModel.swift` line 250 calls `repository.saveDifficultyRating` |
| `generate-plan/index.ts` | `_shared/planSchema.ts` | import | WIRED | Line 12: `import { planSchema } from "../_shared/planSchema.ts"` |
| `coach-chat/index.ts` | `_shared/planSchema.ts` | import | WIRED | Line 16: `import { planSchema } from "../_shared/planSchema.ts"` |
| `adapt-plan/index.ts` | `_shared/adaptedPlanSchema.ts` | import | WIRED | Line 8: `import { AdaptedPlanSchema } from "../_shared/adaptedPlanSchema.ts"` |
| `adapt-plan/index.ts` | `plan_adaptations` table | INSERT after adaptation | WIRED | Lines 540-544: `supabase.from("plan_adaptations").insert(...)` |
| `AdaptationService` | `/functions/v1/adapt-plan` | URLSession POST with Bearer auth | WIRED | `callEdgeFunction(path: "adapt-plan", ...)` with `Bearer \(accessToken)` header |
| `AdaptationService` | `/functions/v1/regenerate-plan` | URLSession POST with Bearer auth | WIRED | `callEdgeFunction(path: "regenerate-plan", ...)` |
| `MainTabView` | `AdaptationService` | @Environment injection + scenePhase | WIRED | `.environment(adaptationService)`, `.onChange(of: scenePhase)` calling `runForegroundCheck` |
| `SessionView` | `AdaptationService` | @Environment + requestPostSessionAdaptation | WIRED | `@Environment(AdaptationService.self)`, line 82: `await adaptationService.requestPostSessionAdaptation(rating: rating)` |
| `AdaptationService.checkOnForeground` | `NotificationScheduler.scheduleReengagementNotificationIfNeeded` | called after missed detection | WIRED | Lines 151-153: `if missedDays.count >= 2 { await NotificationScheduler.shared.scheduleReengagementNotificationIfNeeded(...) }` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `TrainView.swift` — AdaptationSummaryBanner | `adaptationService.lastAdjustmentSummary` | Set in AdaptationService from `response.adjustmentSummary` on successful Edge Function call | Yes — populated from real GPT-4o API response | FLOWING |
| `SessionSummaryView.swift` — emoji buttons | `DifficultyRating.allCases` | Swift enum `CaseIterable` — 3 static cases | Yes — renders all 3 enum values | FLOWING |
| `adapt-plan/index.ts` — adaptation response | `parsedJson` from OpenAI | GPT-4o API call with `stream: false`; Zod-validated before use | Yes — real API response, not static | FLOWING |
| `regenerate-plan/index.ts` — plan update | `historySummary` | Computed from live Supabase queries (session_logs, set_logs, profiles) | Yes — DB queries with `.limit()` and `.order()` | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — Supabase Edge Functions require a live deployed environment (Plan 06 pending). Swift files require Xcode build + simulator. Neither can be invoked in an automated verification context without external service access.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ADPT-01 | 08-01, 08-02, 08-04 | User can rate workout difficulty after each session; AI adjusts next workout based on rating | IMPLEMENTED (human needed for E2E confirmation) | DifficultyRating enum, emoji picker UI, CoreData persistence, SessionSyncService sync, AdaptationService post-session call, adapt-plan Edge Function — all wired end-to-end. Deployment required for runtime confirmation. |
| ADPT-02 | 08-01, 08-03, 08-04 | AI automatically evolves training plan over weeks as performance data accumulates | IMPLEMENTED (human needed for E2E confirmation) | regenerate-plan Edge Function with historySummary, cache deduplication, progressive overload rules; Monday trigger in AdaptationService.checkOnForeground. Runtime outcome requires weeks of data. |
| ADPT-03 | 08-03, 08-04, 08-05 | AI detects missed/skipped sessions and adapts the week's remaining plan | IMPLEMENTED (human needed for E2E confirmation) | MissedSessionDetector, adapt-plan missed_session handler, re-engagement notifications in NotificationScheduler — all wired. Runtime behavior requires deployment and device testing. |

No orphaned requirements: REQUIREMENTS.md maps exactly ADPT-01, ADPT-02, ADPT-03 to Phase 8. All three are claimed and implemented across Plans 01-05.

### Anti-Patterns Found

No anti-patterns detected in Phase 8 artifacts.

Scanned files:
- `supabase/migrations/20260425000000_phase8_adaptation.sql` — no TODOs/stubs
- `WorkoutApp/Features/Models/DifficultyRating.swift` — no stubs
- `supabase/functions/_shared/planSchema.ts`, `adaptedPlanSchema.ts`, `promptBuilder.ts` — no stubs
- `supabase/functions/adapt-plan/index.ts` — complete implementation, all 5 adaptation rules present
- `supabase/functions/regenerate-plan/index.ts` — complete implementation, cache + history summary + exercise continuity rules
- `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — emoji picker fully rendered, Done gate active
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` — all public methods implemented
- `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` — pure function, no stubs
- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — guilt blocklist + frequency cap implemented

### Human Verification Required

#### 1. Supabase Schema Push and Edge Function Deployment

**Test:** Run `supabase db push` and `supabase functions deploy adapt-plan && supabase functions deploy regenerate-plan`
**Expected:** No migration errors; `supabase functions list` shows both functions as Active; `supabase db diff` shows no pending changes
**Why human:** Requires Supabase CLI with developer credentials and a live project. Cannot automate without production credentials.

#### 2. Post-Session Adaptation End-to-End (ADPT-01 — ROADMAP SC #1)

**Test:** Complete a workout in the app, rate it "too hard" on the session summary screen. Check TrainView for the next session.
**Expected:** (a) Done button is disabled until emoji tapped; (b) on Done, AdaptationSummaryBanner appears in TrainView with a 1-2 sentence explanation of what changed; (c) the next session shows reduced volume (fewer sets or reps)
**Why human:** Requires a live Supabase instance with deployed adapt-plan Edge Function and an active user plan. The adjusted plan content is AI-generated; cannot verify without a real OpenAI call.

#### 3. Weekly Plan Evolution (ADPT-02 — ROADMAP SC #2)

**Test:** Open the app on a Monday after having completed 2+ weeks of sessions. Observe TrainView and check plan_adaptations table in Supabase for a trigger_type="weekly" row.
**Expected:** A new row in plan_adaptations with trigger_type="weekly" and the current ISO week's cache_key; the active plan in user_plans reflects the regenerated content; X-Cache: MISS on first Monday call, X-Cache: HIT on subsequent calls
**Why human:** Requires time-passing simulation and a live database. Weekly evolution cannot be verified instantaneously.

#### 4. Missed Session Redistribution (ADPT-03 — ROADMAP SC #3)

**Test:** Have an active 3-day plan (Mon/Wed/Fri). Skip Monday. Open the app on Tuesday.
**Expected:** AdaptationService.checkOnForeground detects Monday as missed; adapt-plan is called with trigger_type="missed_session"; the updated plan redistributes compound movements from Monday across remaining days
**Why human:** Requires a real device/simulator with live Edge Functions, active plan data in Supabase, and date-manipulation to simulate a skipped day.

#### 5. Re-engagement Notification (ADPT-03 — D-08, D-09, D-10)

**Test:** Skip 2 planned training days. Open the app on the third day. Check device notification queue.
**Expected:** One pending notification with identifier prefix "reengagement-"; body text contains no guilt language; notification is scheduled for 10am next day; a second open-without-workout does not add a third notification (cap at 2)
**Why human:** UNUserNotificationCenter requires a running app on device/simulator. Notification delivery and scheduling cannot be verified without app execution.

### Gaps Summary

No code-level gaps. All 18 must-haves from Plan frontmatter are verified at levels 1-4 (existence, substantive implementation, wiring, data flow). The three ROADMAP success criteria require human verification through Plan 06 tasks: Supabase schema push, Edge Function deployment, and device E2E testing.

Plan 06 is marked `autonomous: false` and `status: human_needed` by design — this is not a gap but a planned human gate. All prerequisite code is production-ready.

---

_Verified: 2026-04-25T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
