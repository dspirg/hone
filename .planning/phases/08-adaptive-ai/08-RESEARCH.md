# Phase 8: Adaptive AI - Research

**Researched:** 2026-04-24
**Phase Goal:** The AI actively adapts each user's next workout based on post-session feedback and accumulated performance data; smart notifications re-engage lapsed users

## Requirements Coverage

| REQ-ID | Requirement | Implementation Approach |
|--------|-------------|------------------------|
| ADPT-01 | Difficulty rating + AI adjusts next workout | Emoji rating on SessionSummaryView → CDSessionLog.difficulty_rating → adapt-plan Edge Function |
| ADPT-02 | Plan evolves over weeks with accumulated data | Weekly cron-triggered regenerate-plan Edge Function using performance trends |
| ADPT-03 | Missed sessions redistribute instead of stack | Missed-session detection in adapt-plan + smart redistribution logic in system prompt |

## Existing Codebase Analysis

### Key Integration Points

#### 1. SessionSummaryView (Rating Drop-in Point)
- **File:** `WorkoutApp/Features/Session/Components/SessionSummaryView.swift`
- **Status:** Has explicit Phase 8 placeholder: "No difficulty rating — deferred to Phase 8 per CONTEXT.md"
- **Action:** Insert emoji rating picker between PR badges section and Done button
- **Pattern:** The Done button already calls `onDone` closure — intercept to require rating first
- **Constraint:** Rating is required per D-02 — Done button must be disabled until rating selected

#### 2. CDSessionLog CoreData Entity
- **Current schema:** id, user_id, plan_id, workout_day_label, started_at, completed_at, total_exercises, total_sets, total_reps
- **Missing field:** `difficulty_rating` (String, optional) — needs CoreData model migration
- **Supabase migration needed:** `ALTER TABLE session_logs ADD COLUMN difficulty_rating TEXT CHECK (...)`
- **Sync:** SessionSyncService already syncs CDSessionLog → Supabase via upsert. Adding difficulty_rating to the sync payload is straightforward.

#### 3. Edge Functions (Existing)
- `supabase/functions/generate-plan/index.ts` — GPT-4o + Structured Outputs + SSE streaming. Contains `planSchema` definition.
- `supabase/functions/coach-chat/index.ts` — GPT-4o mini for chat, GPT-4o for plan modification (`execute_modify` path). **Duplicates `planSchema`** from generate-plan.
- `supabase/functions/revenuecat-webhook/index.ts` — Subscription webhook.
- **Schema duplication risk:** `planSchema` is defined identically in generate-plan and coach-chat. Phase 8 adds a third consumer (adapt-plan). Extract to `_shared/planSchema.ts` first to prevent drift.

#### 4. NotificationScheduler
- **File:** `WorkoutApp/Core/Notifications/NotificationScheduler.swift`
- **Status:** Handles workout reminders with streak-aware copy. Uses `UNCalendarNotificationTrigger`.
- **Action:** Add re-engagement notification category with frequency cap (max 2/week per D-10)
- **Pattern:** Uses earned-moment permission pattern — extend for re-engagement

#### 5. ProgressViewModel
- **File:** `WorkoutApp/Features/Progress/ProgressViewModel.swift`
- **Status:** Has streak tracking, weekly session data, PR detection
- **Data source for:** Missed session detection (compare planned days vs completed sessions)

#### 6. SessionViewModel
- **File:** `WorkoutApp/Features/Session/SessionViewModel.swift`
- **Status:** State machine managing session flow, creates CDSessionLog, manages rest timer
- **Action:** Add difficulty_rating property, pass to SessionSummaryView, persist to CDSessionLog on completion

### Supabase Schema (Current)

**session_logs table:**
```sql
id UUID PRIMARY KEY,
user_id UUID REFERENCES auth.users(id),
plan_id UUID REFERENCES workout_plans(id),
workout_day_label TEXT NOT NULL,
started_at TIMESTAMPTZ NOT NULL,
completed_at TIMESTAMPTZ,
total_exercises INT DEFAULT 0,
total_sets INT DEFAULT 0,
total_reps INT DEFAULT 0,
created_at TIMESTAMPTZ DEFAULT NOW()
```

**set_logs table:**
```sql
id UUID PRIMARY KEY,
session_id UUID REFERENCES session_logs(id),
user_id UUID REFERENCES auth.users(id),
exercise_name TEXT NOT NULL,
set_number INT NOT NULL,
target_reps TEXT NOT NULL,
reps_logged INT NOT NULL CHECK (>= 0 AND <= 999),
completed_at TIMESTAMPTZ,
created_at TIMESTAMPTZ DEFAULT NOW()
```

## New Infrastructure Required

### 1. Supabase Migrations
```sql
-- Add difficulty_rating to session_logs
ALTER TABLE session_logs ADD COLUMN difficulty_rating TEXT
  CHECK (difficulty_rating IN ('too_easy', 'just_right', 'too_hard'));

-- Immutable audit log for plan adaptations
CREATE TABLE plan_adaptations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  adapted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  trigger_type TEXT NOT NULL CHECK (trigger_type IN ('post_session', 'weekly', 'missed_session')),
  adaptation_summary TEXT NOT NULL,
  previous_plan JSONB NOT NULL,
  adapted_plan JSONB NOT NULL,
  cache_key TEXT UNIQUE,
  prompt_tokens INTEGER,
  completion_tokens INTEGER
);
CREATE INDEX idx_plan_adaptations_user_id ON plan_adaptations (user_id, adapted_at DESC);
```

### 2. New Edge Functions

#### adapt-plan (Post-Session Adaptation)
- **Trigger:** iOS client calls after user rates session difficulty
- **Model:** GPT-4o with Structured Outputs (non-streaming)
- **Input:** userId + current_session_rating → Edge Function fetches history from Supabase
- **Logic:** Builds adaptation system prompt with recent ratings + performance trends + current plan
- **Output:** Adapted plan JSON matching `planSchema` + `adjustment_summary`
- **Guardrails:** Zod validation, finish_reason check, clinical language blocklist

#### regenerate-plan (Weekly Plan Evolution)
- **Trigger:** Weekly cron or on app open if plan is stale
- **Model:** GPT-4o with Structured Outputs (non-streaming)
- **Input:** 2-4 weeks of session history summary + current plan
- **Output:** Evolved plan with progressive overload adjustments
- **Cache:** Deduplicate by `${userId}-${isoWeek}-v${planVersion}` cache_key

### 3. iOS-Side Services

#### AdaptationService
- Calls adapt-plan Edge Function after session completion + rating
- Receives adapted plan, validates, stores to CoreData
- Updates plan display in HomeView / TrainView

#### MissedSessionDetector
- Compares planned training days (from current plan's weekly_days) against session_logs
- Triggers adapt-plan with missed_session context when user opens app after missing a planned day

### 4. Shared Schema Extraction
- Extract `planSchema` from generate-plan and coach-chat to `supabase/functions/_shared/planSchema.ts`
- Both existing functions + adapt-plan + regenerate-plan import from shared location
- Prevents schema drift across 4 consumers

## Adaptation Rules (from AI-SPEC)

The system prompt enforces these rules:
1. **2+ consecutive "too hard"**: Reduce volume 10-15% (remove set or reduce reps). Never increase.
2. **3+ consecutive "too easy"**: Increase volume 10-15%. Never increase for exercises with <80% completion rate.
3. **"Just right" or mixed**: Maintain volume. Fine-tune rest periods.
4. **Missed sessions**: Redistribute compound movements from missed day across remaining days at reduced volume. Drop isolation work.
5. **Exercise continuity**: Don't replace exercises the user completes at 80%+ unless adaptation rules require it.

## Smart Notifications Design

### Re-engagement Triggers
- **When:** 2+ consecutive missed planned sessions (D-08)
- **Frequency cap:** Max 2 per week (D-10). Back off after 2 unanswered.
- **Tone:** Supportive coach — "Your plan adapted to your schedule — ready when you are." (D-09)
- **Implementation:** Extend NotificationScheduler with re-engagement category
- **Copy generation:** GPT-4o mini (negligible cost) or hardcoded templates with personalization

### Notification Copy Guardrails
- Regex blocklist for guilt patterns (from AI-SPEC Section 5, Dimension 4)
- Fallback to safe default on blocklist match
- 15-word maximum

## Risk Analysis

### Technical Risks
1. **CoreData migration with existing data** — Adding `difficulty_rating` column requires proper CoreData versioned migration. Lightweight migration should suffice (adding optional attribute).
2. **Schema duplication** — Must extract shared planSchema before adding adapt-plan to prevent 3-way drift.
3. **Plan state consistency** — When adapt-plan returns a new plan, both CoreData and Supabase must update atomically. Use the existing SessionSyncService pattern.
4. **Token budget** — System prompt with plan JSON + adaptation context must stay under 1400 tokens. `stripRationale()` is mandatory.

### Dependency Risks
1. Phase 8 depends on Phase 6 (Progress Tracking) — streak data and session history are inputs to adaptation.
2. Uses patterns from Phase 3 (plan generation), Phase 4 (session logging), Phase 5 (coach chat).

## Validation Architecture

### Testable Assertions
1. **Directional correctness:** "too_hard" ratings → adapted plan has fewer total sets (code-based comparison)
2. **Volume bounds:** Week-over-week volume per muscle group ≤ 10% increase (SQL query)
3. **Exercise continuity:** ≥ 60% compound exercise retention across regenerations (set intersection)
4. **Notification tone:** Passes guilt blocklist regex + word count ≤ 20
5. **Schema compliance:** 100% Zod validation pass rate
6. **Safety:** No clinical language in rationale fields (regex blocklist)

### Eval Tooling
- Promptfoo for CI-level eval against adapt-plan Edge Function
- 25-example reference dataset (detailed in AI-SPEC Section 5)
- 95% pass threshold for CI gate

## RESEARCH COMPLETE
