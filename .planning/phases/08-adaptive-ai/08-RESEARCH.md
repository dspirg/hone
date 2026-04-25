# Phase 8: Adaptive AI - Research

**Researched:** 2026-04-24
**Domain:** AI adaptation pipeline, iOS post-session UX, Supabase schema extension, local notification frequency management
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Post-Session Rating UX**
- D-01: Emoji scale (3-5 faces from "too easy" to "too hard") for difficulty rating — fast, intuitive, no cognitive load
- D-02: Rating is required — always shown on SessionSummaryView before dismissal. Single tap, minimal friction. AI always has signal.

**AI Adaptation Strategy**
- D-03: Immediate next-session adjustment — rate "too hard" today, tomorrow's workout is lighter. Users see the AI responding in real-time.
- D-04: Auto-evolve weekly — AI reviews last 2-4 weeks of session data and regenerates the plan each week. Progressive overload built in. Plan changes every Monday.
- D-05: Brief rationale on changed exercises — short AI note like "Increased weight — you rated last 3 sessions as too easy." Builds trust without clutter.

**Missed Session Handling**
- D-06: Smart redistribute — AI redistributes key exercises from missed day across remaining days. Week's training volume stays intact.
- D-07: Trigger after 1 missed day — user opens the app the next day and sees an updated plan. Feels responsive.

**Smart Notifications**
- D-08: Trigger after 2+ consecutive missed planned sessions. Avoids nagging for one-off rest days.
- D-09: Supportive coach tone — "Your plan adapted to your schedule — ready when you are." Encouraging, no guilt. Emphasizes the AI adapted for them.
- D-10: Max 2 re-engagement notifications per week. After 2 nudges with no response, back off until user opens the app.

### Claude's Discretion
- Emoji count (3 vs 5 faces) and specific emoji choices
- Exact progressive overload percentages and adjustment algorithms
- Weekly plan regeneration timing (e.g., Sunday night vs Monday morning)
- Notification scheduling logic for re-engagement (time of day, day of week)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADPT-01 | User can rate workout difficulty after each session; AI adjusts the next workout based on the rating | Emoji picker on SessionSummaryView → `difficulty_rating` on CDSessionLog → `adapt-plan` Edge Function reads last 4 ratings |
| ADPT-02 | AI automatically evolves the user's training plan over weeks as performance data accumulates | `regenerate-plan` Edge Function — weekly, Monday morning — reads 2-4 week session history from Supabase |
| ADPT-03 | AI detects missed or skipped sessions and adapts the week's remaining plan accordingly | Missed-session detection on app foreground; `adapt-plan` Edge Function with `missed_sessions` context |
</phase_requirements>

---

## Summary

Phase 8 extends the existing plan generation pipeline with three new capabilities: (1) post-session difficulty rating captured in SessionSummaryView, stored in CoreData/Supabase, and fed into an `adapt-plan` Edge Function; (2) weekly plan regeneration triggered on Monday morning that incorporates 2-4 weeks of accumulated performance data; (3) re-engagement push notifications triggered after 2+ consecutive missed planned sessions, with guilt-free copy and a 2-per-week cap.

The AI layer is entirely server-side: two new Supabase Edge Functions (`adapt-plan` and `regenerate-plan`), both using GPT-4o with Structured Outputs and non-streaming responses. These functions extend the established patterns from `generate-plan/index.ts` and `coach-chat/index.ts` — the same CORS/auth/error-handling boilerplate, the same `planSchema`, and the same `_shared/` module pattern. The iOS client sends the current session rating and receives an adapted plan JSON; the Edge Function assembles the full context (ratings history, performance trends, missed sessions) server-side from Supabase.

Data changes are narrow but require two coordinated additions: (a) a `difficulty_rating` column on the `session_logs` Supabase table plus a matching CoreData attribute on `CDSessionLog`, and (b) a new `plan_adaptations` audit table. The AI-SPEC document produced before this research phase is comprehensive and functions as a complete implementation contract — the planner can derive tasks directly from it.

**Primary recommendation:** Build in a strict wave order — schema migration first, then iOS rating UI, then Edge Functions, then iOS adaptation client, then notifications. Each wave has hard dependencies on the previous. The AI-SPEC's adaptation rules, Zod schema, eval fixtures, and guardrail patterns are implementation-ready and should be used verbatim.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Difficulty rating capture (UI) | iOS Client | — | UI interaction — emoji tap in SessionSummaryView, immediate CoreData write |
| Difficulty rating persistence | iOS Client (CoreData) | Backend (Supabase) | Write-ahead to CoreData; syncs to Supabase via existing SessionSyncService pattern |
| Post-session adaptation (AI) | Backend (Edge Function) | — | Requires OpenAI API key; must never run from iOS client per CLAUDE.md |
| Weekly plan regeneration (AI) | Backend (Edge Function) | — | Foreground-triggered Monday check; full history assembly from Supabase PostgreSQL |
| Missed session detection | iOS Client | Backend (Edge Function) | iOS detects on app foreground; Edge Function executes redistribution |
| Adapted plan storage | Backend (Supabase) | iOS Client (CoreData) | Plan written to `user_plans`; iOS applies from response JSON immediately |
| Re-engagement notification scheduling | iOS Client (NotificationScheduler) | — | Local notifications via UNCalendarNotificationTrigger; no server push needed for v1 |
| Plan adaptation audit log | Backend (Supabase) | — | `plan_adaptations` table; used for offline quality monitoring |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| OpenAI API (GPT-4o) | `gpt-4o-2024-08-06` | adapt-plan, regenerate-plan structured outputs | Existing project standard; minimum version for Structured Outputs with `strict: true` [VERIFIED: generate-plan/index.ts line 186] |
| OpenAI API (GPT-4o-mini) | `gpt-4o-mini` | Re-engagement notification copy generation | Existing project standard; 16x cheaper than GPT-4o for short-form content [VERIFIED: CLAUDE.md Cost Model] |
| Supabase Deno Edge Functions | `deno.land/std@0.224.0` | AI proxy, plan storage | Existing project standard; all AI calls proxied through Edge Functions [VERIFIED: generate-plan/index.ts line 11] |
| Zod | `deno.land/x/zod@v3.23.8` | Runtime validation of OpenAI structured outputs | Defined in AI-SPEC Section 4b.1; two-layer: JSON Schema constrains generation, Zod validates receipt [VERIFIED: AI-SPEC] |
| UserNotifications (UNUserNotificationCenter) | iOS 16+ | Local re-engagement notifications | Already in use in NotificationScheduler.swift [VERIFIED: NotificationScheduler.swift] |
| CoreData | iOS 16+ | Local persistence of difficulty_rating attribute | Existing project standard; add one optional String attribute to CDSessionLog [VERIFIED: WorkoutApp.xcdatamodeld] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Promptfoo | Latest (npm) | AI eval CI/CD regression testing | Defined in AI-SPEC Section 5; run against local Supabase with `--fail-threshold 0.95` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Non-streaming adapt-plan | SSE streaming adaptation | Streaming cannot deliver a parseable plan mid-stream; non-streaming required for Zod validation before returning to iOS |
| Local notification for re-engagement | APNs push notification | APNs requires server-side certificate infrastructure; local UNCalendarNotificationTrigger is simpler for v1 and covers frequency-cap requirement directly |
| GPT-4o-mini for notification copy | Hardcoded template strings | Templates are safer from guilt-language drift, zero cost, always available offline; AI copy generation is an optional enhancement |

**Installation (Supabase side — no new iOS dependencies):**
```bash
# Zod in Deno Edge Functions — imported by URL, no npm install needed
# import { z } from "https://deno.land/x/zod@v3.23.8/mod.ts";

# Promptfoo for evals (dev only)
npm install --save-dev promptfoo

# Scaffold new Edge Functions
supabase functions new adapt-plan
supabase functions new regenerate-plan
```

---

## Architecture Patterns

### System Architecture Diagram

```
iOS Client (SessionSummaryView)
  │
  │  1. User taps emoji rating (ADPT-01)
  ▼
CDSessionLog.difficulty_rating (CoreData write-ahead)
  │
  │  2. Session sync (existing SessionSyncService pattern)
  ▼
Supabase: session_logs.difficulty_rating column
  │
  │  3. iOS sends POST /adapt-plan on session completion
  ▼
adapt-plan Edge Function
  ├── Promise.all([
  │     session_logs (last 4 with ratings),
  │     user_plans (current plan),
  │     profiles (user profile)
  │   ])                                  ← parallel Supabase queries
  ├── buildAdaptationSystemPrompt()
  ├── OpenAI GPT-4o (Structured Outputs, non-streaming)
  ├── Zod validation
  ├── INSERT plan_adaptations (audit log)
  └── UPDATE user_plans (adapted plan)
        │
        │  4. iOS receives adapted plan JSON, applies immediately to CoreData
        ▼
CDWorkoutPlan updated — TrainView shows updated plan on next render

iOS Client (app foreground — Monday morning or on open)
  │
  │  5. Weekly regeneration check (ADPT-02)
  │     if today is Monday AND no weekly regen this week
  ▼
regenerate-plan Edge Function
  ├── Cache check: plan_adaptations WHERE cache_key = user+isoWeek
  ├── Fetch 2-4 week session history → historySummary (~100 tokens)
  ├── OpenAI GPT-4o (Structured Outputs, non-streaming)
  └── UPDATE user_plans + INSERT plan_adaptations

iOS Client (app foreground)
  │
  │  6. Missed session detection (ADPT-03)
  │     planned_days from active plan vs completed sessions this week
  ▼
adapt-plan Edge Function (trigger_type = 'missed_session')
  └── same pipeline as #3 with missed_sessions context populated

NotificationScheduler (iOS)
  │
  │  7. Re-engagement check (D-08, D-10)
  │     missedCount >= 2 AND reengagement notifications this week < 2
  ▼
UNUserNotificationCenter.add() — local notification
  └── Hardcoded safe copy OR GPT-4o-mini generated copy
      → passesGuiltBlocklist() check before scheduling
```

### Recommended Project Structure
```
supabase/
└── functions/
    ├── generate-plan/index.ts          # Phase 3 — unchanged
    ├── coach-chat/index.ts             # Phase 5 — unchanged (except max_tokens cleanup)
    ├── adapt-plan/
    │   ├── index.ts                    # Phase 8 — post-session + missed-session adaptation
    │   └── eval/
    │       ├── promptfooconfig.yaml    # Wave 0 gap
    │       └── fixtures/              # 10+ JSON eval fixtures (AI-SPEC Section 5)
    ├── regenerate-plan/
    │   └── index.ts                   # Phase 8 — weekly plan regeneration
    └── _shared/
        ├── planSchema.ts              # Extracted from generate-plan + coach-chat (DEDUP)
        ├── adaptedPlanSchema.ts       # Zod schema from AI-SPEC Section 4b.1
        ├── promptBuilder.ts           # System prompt construction helpers
        └── auth.ts                   # Shared Bearer token validation

WorkoutApp/
├── Features/
│   ├── Session/
│   │   ├── Components/
│   │   │   └── SessionSummaryView.swift   # MODIFY: add emoji rating before Done button
│   │   └── SessionViewModel.swift         # MODIFY: capture rating, pass to summary
│   ├── Adaptation/
│   │   ├── AdaptationService.swift        # NEW: iOS client for adapt-plan + regenerate-plan
│   │   └── MissedSessionDetector.swift    # NEW: detects planned-but-skipped days
│   └── Models/
│       └── DifficultyRating.swift         # NEW: enum too_easy/just_right/too_hard
└── Core/
    ├── Data/
    │   └── WorkoutApp.xcdatamodeld        # MODIFY: add difficultyRating to CDSessionLog
    ├── Sync/
    │   └── SessionSyncService.swift       # MODIFY: include difficulty_rating in sync payload
    └── Notifications/
        └── NotificationScheduler.swift    # MODIFY: add re-engagement + frequency cap

supabase/migrations/
└── 20260424000000_phase8_adaptation.sql   # NEW: alter session_logs + create plan_adaptations
```

### Pattern 1: adapt-plan Edge Function (New, extends generate-plan)
**What:** Non-streaming Structured Outputs call to GPT-4o with adaptation context assembled server-side. Response validated with Zod before returning to iOS.
**When to use:** After every completed session (post-session) and after missed session detection.
**Example:**
```typescript
// Source: AI-SPEC Section 3 Entry Point Pattern — verbatim template
// Key differences from generate-plan/index.ts:
// 1. stream: false (non-streaming — Zod validation requires full response)
// 2. max_completion_tokens: 2000 (explicit cap — never omit in production)
// 3. temperature: 0.3 (lower for consistent plan structure)
// 4. Parallel Supabase queries BEFORE OpenAI call

const [sessionLogsResult, currentPlanResult, profileResult] = await Promise.all([
  supabase.from("session_logs")
    .select("difficulty_rating, started_at, workout_day_label")
    .eq("user_id", userId)
    .order("started_at", { ascending: false })
    .limit(4),
  supabase.from("user_plans")
    .select("plan_data")
    .eq("user_id", userId)
    .single(),
  supabase.from("profiles")
    .select("goal, fitness_level, equipment, injuries")
    .eq("id", userId)
    .single(),
]);
```

### Pattern 2: Emoji Rating UI in SessionSummaryView
**What:** Single-tap emoji row inserted above the Done button. Rating is required before dismissal (D-02). Exact insertion point is the existing Phase 8 placeholder comment.
**When to use:** Every session completion. Done button disabled until rating selected.
**Example:**
```swift
// Source: existing SessionSummaryView.swift line 68 — placeholder is the insertion point
// Analog: ChipView.swift selection state pattern (AccentColor opacity)

enum DifficultyRating: String, CaseIterable, Codable {
    case tooEasy = "too_easy"
    case justRight = "just_right"
    case tooHard = "too_hard"

    // Emoji choices are Claude's discretion (3-emoji scale per D-01)
    var emoji: String {
        switch self {
        case .tooEasy:    return "😴"
        case .justRight:  return "💪"
        case .tooHard:    return "😤"
        }
    }
}

// In SessionSummaryView body — inserted above Done button, below PR badges:
HStack(spacing: 24) {
    ForEach(DifficultyRating.allCases, id: \.self) { rating in
        Button {
            selectedRating = rating
        } label: {
            Text(rating.emoji)
                .font(.system(size: 40))
                .opacity(selectedRating == nil || selectedRating == rating ? 1.0 : 0.3)
        }
        .accessibilityLabel(rating.rawValue.replacingOccurrences(of: "_", with: " "))
    }
}

// Done button disabled until rating is selected:
Button("Done") { onDone(selectedRating) }
    .buttonStyle(.borderedProminent)
    .disabled(selectedRating == nil)
```

### Pattern 3: SessionSyncService Extension for difficulty_rating
**What:** The existing `SessionLogRow` Encodable struct in `SessionSyncService.swift` (lines 179-201) must gain one new field: `difficulty_rating`. The Supabase upsert will then include the column automatically.
**When to use:** This is a MUST-have change in Wave 0. Without it, the rating never reaches Supabase and adaptation never fires.
**Example:**
```swift
// Source: SessionSyncService.swift lines 179-201 — extend with one field
private struct SessionLogRow: Encodable {
    // ... existing fields unchanged ...
    let difficultyRating: String?  // ADD THIS

    enum CodingKeys: String, CodingKey {
        // ... existing keys unchanged ...
        case difficultyRating = "difficulty_rating"  // ADD THIS
    }
}

// In performBatchSync() where SessionLogRow is constructed:
SessionLogRow(
    // ... existing fields ...
    difficultyRating: s.difficultyRating  // ADD THIS — maps CDSessionLog attribute
)
```

### Pattern 4: Missed Session Detection on App Foreground
**What:** On app foreground, compare the active plan's scheduled workout days this week against completed CDSessionLog records. If a planned day has no corresponding completion AND that day is in the past, flag it as missed.
**When to use:** On every app foreground (`.onChange(of: scenePhase)` in MainTabView), gated to avoid re-triggering within the same day.
**Example:**
```swift
// Source: Inferred from ProgressViewModel.computeWeeklyRing pattern
// (same "sessions this week" CDSessionLog query logic)

struct MissedSessionDetector {
    // Returns ISO 8601 date strings of planned-but-not-completed days this week
    static func detectMissedSessions(
        activePlanDayLabels: [String],   // WorkoutPlan.weekly_days.map(\.dayLabel)
        completedSessions: [CDSessionLog],
        calendar: Calendar = .current
    ) -> [String] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date())
        else { return [] }

        let completedLabels = Set(
            completedSessions
                .filter { s in s.completedAt.map { weekInterval.contains($0) } == true }
                .compactMap { $0.workoutDayLabel }
        )

        // Only days in the plan that had no completion AND whose planned date is before today
        return activePlanDayLabels.filter { !completedLabels.contains($0) }
        // Caller maps these to ISO date strings using the plan's day-of-week schedule
    }
}
```

### Pattern 5: Re-engagement Notification with Frequency Cap
**What:** New method on `NotificationScheduler`. Checks 2+ consecutive missed sessions, fewer than 2 re-engagement notifications this week, and user has not opened the app today before scheduling.
**When to use:** Called from `AdaptationService.checkOnForeground()` after missed session detection.
**Example:**
```swift
// Source: NotificationScheduler.swift — extend, do not replace
// New identifier prefix: "reengagement-" (distinct from "workout-reminder-")

func scheduleReengagementNotificationIfNeeded(
    missedSessionCount: Int
) async {
    guard missedSessionCount >= 2 else { return }
    guard await shouldScheduleNotifications() else { return }

    // Frequency cap: count pending re-engagement notifications (max 2/week per D-10)
    let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
    let reengagementPending = pending.filter { $0.identifier.hasPrefix("reengagement-") }
    guard reengagementPending.count < 2 else { return }

    let content = UNMutableNotificationContent()
    content.title = "Your plan is ready"
    // D-09: supportive tone, no guilt, emphasizes AI adapted
    content.body = "Your plan adapted to your schedule — ready when you are."
    content.sound = .default

    // Schedule for 10am tomorrow (timing is Claude's discretion per D-10)
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.day = (components.day ?? 0) + 1
    components.hour = 10
    components.minute = 0
    components.timeZone = TimeZone.current

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let identifier = "reengagement-\(UUID().uuidString)"
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    do {
        try await UNUserNotificationCenter.current().add(request)
    } catch {
        print("NotificationScheduler: scheduleReengagementNotificationIfNeeded failed: \(error)")
    }
}
```

### Pattern 6: planSchema Extraction to _shared/
**What:** `planSchema` is currently copy-pasted identically in `generate-plan/index.ts` (lines 17-52) and `coach-chat/index.ts` (lines 21-56). Phase 8 adds two more consumers. Extract to `_shared/planSchema.ts` first.
**When to use:** Must be the first Edge Function task. Schema drift between 4 consumers is a production risk that breaks iOS plan decoding.
**Example:**
```typescript
// supabase/functions/_shared/planSchema.ts
// Single source of truth — imported by all 4 Edge Functions
export const planSchema = {
  type: "object" as const,
  // ... existing schema body from generate-plan/index.ts lines 17-52 ...
  additionalProperties: false,
};

// In adapt-plan/index.ts:
import { planSchema } from "../_shared/planSchema.ts";
```

### Pattern 7: Weekly Regeneration Cache Check
**What:** Before calling OpenAI for weekly plan regeneration, check `plan_adaptations` for a cached result for this user+week+planVersion. Returns cached result immediately if found.
**When to use:** Every `regenerate-plan` call — prevents duplicate AI charges when app is opened multiple times on Monday.
**Example:**
```typescript
// Source: AI-SPEC Section 4b.5 — verbatim
function getISOWeekKey(date: Date): string {
  const year = date.getUTCFullYear();
  const startOfYear = new Date(Date.UTC(year, 0, 1));
  const weekNum = Math.ceil(((date.getTime() - startOfYear.getTime()) / 86400000 + startOfYear.getUTCDay() + 1) / 7);
  return `${year}-W${String(weekNum).padStart(2, "0")}`;
}

const isoWeek = getISOWeekKey(new Date());
const cacheKey = `${userId}-${isoWeek}-v${planVersion}`;

const { data: cached } = await supabase
  .from("plan_adaptations")
  .select("adapted_plan")
  .eq("cache_key", cacheKey)
  .eq("trigger_type", "weekly")
  .single();

if (cached) {
  return new Response(JSON.stringify(cached.adapted_plan), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "X-Cache": "HIT",
    },
  });
}
```

### Anti-Patterns to Avoid
- **Streaming adapt-plan responses:** Structured Outputs with `strict: true` produce valid JSON only on full completion. Mid-stream content is not parseable JSON. Always `stream: false` for adaptation. [VERIFIED: AI-SPEC Section 4 Implementation Guidance]
- **Calling OpenAI from iOS client directly:** API key extractable from binary. All AI calls go through Edge Functions. [VERIFIED: CLAUDE.md §What NOT to Use]
- **Omitting `max_completion_tokens`:** Without this, a pathological prompt can generate until context window limit, return `finish_reason: "length"`, and crash the iOS plan parser. [VERIFIED: AI-SPEC Section 3 Common Pitfalls #1]
- **Using `max_tokens` instead of `max_completion_tokens`:** `max_tokens` is deprecated. The existing `coach-chat/index.ts` summarization call (line 236) still uses `max_tokens` — flag for migration. [VERIFIED: AI-SPEC Section 3 Common Pitfalls #1]
- **Adapting on a single session rating:** A single "too hard" may reflect DOMS from a new movement, not genuine overload. The adaptation rules require 2+ consecutive same-direction ratings. [VERIFIED: AI-SPEC Section 3 Common Pitfalls #5]
- **Stacking full missed-day volume on remaining days:** Drop isolation work from missed days; redistribute compound exercises at reduced volume only. [VERIFIED: AI-SPEC Section 1b Domain Expert Dimension 5]
- **Triggering missed session detection on rest days:** Compare against planned training days from `WorkoutPlan.weekly_days`, not all 7 days of the week.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON schema constraint on OpenAI output | Custom JSON validator | OpenAI Structured Outputs with `response_format.json_schema` + `strict: true` | Constrains token generation at model level; parser cannot receive a schema-violating response |
| Runtime type validation after JSON.parse | Manual field checking | Zod `safeParse` | Single source of truth for TypeScript types; reports exact field paths that failed |
| Re-engagement copy tone enforcement | String analysis | Regex `GUILT_PATTERNS` blocklist + hardcoded safe fallback | 7 patterns cover common guilt framing at < 1ms cost per notification |
| Adaptation correctness validation | No test coverage | Promptfoo eval fixtures (too_hard_2x, too_easy_3x, missed_session_legs) | Directional inversion (rate "too hard", receive harder plan) is undetectable without structured eval fixtures |
| Notification frequency management | UserDefaults counter | Count pending `UNNotificationRequest` with "reengagement-" prefix | OS notification queue is the authoritative state; no separate counter needed |
| Historical session aggregation for AI | Injecting raw CDSetLog array | `historySummary` struct pattern from AI-SPEC Section 4b.4 | 12+ weeks of raw logs = 2000+ tokens; structured summary = 100 tokens |

**Key insight:** The adaptation system's correctness comes from constraint at every layer — JSON Schema constrains generation, Zod validates receipt, regex guards block unsafe copy, and eval fixtures catch directional inversion. Each layer is independently necessary because any single layer can fail.

---

## Common Pitfalls

### Pitfall 1: CDSessionLog CoreData Migration + Supabase Migration Must Both Land
**What goes wrong:** Adding `difficulty_rating` to Supabase but not CoreData (or vice versa) creates a silent mismatch. iOS syncs session logs without the rating; Edge Function reads null ratings; adaptation never fires.
**Why it happens:** CoreData model changes require updating `.xcdatamodeld` AND the Supabase migration is a separate SQL file. They are easy to decouple accidentally.
**How to avoid:** Same Wave — update CoreData model, verify Xcode generates the class attribute, then write the Supabase migration. Both changes in the same commit.
**Warning signs:** `difficulty_rating` is null on all `session_logs` rows in Supabase after users rate sessions.

### Pitfall 2: planSchema Drift Across 4 Edge Functions
**What goes wrong:** `adapt-plan` returns a plan with schema shape X; `generate-plan` returns shape Y. The iOS `WorkoutPlan` decoder is written to one shape. One function silently returns malformed plans that crash the decoder.
**Why it happens:** Schema is currently copy-pasted in two functions. Phase 8 adds two more. Without `_shared/planSchema.ts`, drift will occur.
**How to avoid:** Extract `planSchema` to `_shared/planSchema.ts` as the first Edge Function task. All four functions import from shared.
**Warning signs:** iOS crashes with "keyNotFound" or "typeMismatch" on plan decoding after an adaptation response.

### Pitfall 3: SessionSyncService Missing difficulty_rating in Sync Payload
**What goes wrong:** Rating is written to CoreData but `SessionLogRow` in `SessionSyncService.swift` does not include `difficultyRating`. The field never reaches Supabase. Adaptation never fires.
**Why it happens:** `SessionLogRow` is an explicit Encodable struct — it requires manual field additions. Current implementation (lines 179-201) has no `difficultyRating` property.
**How to avoid:** Update `SessionLogRow` and its `CodingKeys` in the same Wave as the CoreData model change.
**Warning signs:** `session_logs.difficulty_rating` is null in Supabase despite users seeing the emoji picker in the UI.

### Pitfall 4: Missed Session Detection Firing on Rest Days
**What goes wrong:** User has a 3-day plan (Mon/Wed/Fri). Detector sees Tuesday has no CDSessionLog and flags it as a missed session.
**Why it happens:** Naive detection compares all 7 days against completions rather than only planned training days.
**How to avoid:** Compare against day labels from `WorkoutPlan.weekly_days` (planned training days only), not all days of the week.
**Warning signs:** Users on 3-day programs receive "missed session" adaptations and notifications on their rest days.

### Pitfall 5: Weekly Regeneration Firing Multiple Times on Monday
**What goes wrong:** User opens app at 8am Monday (regen fires), closes, reopens at 9am (regen fires again). User gets two different plans and is confused.
**Why it happens:** Without a cache check, every foreground event on Monday triggers a new OpenAI call.
**How to avoid:** Check `plan_adaptations` for a cached result with `cache_key = userId-isoWeek-vN` before every `regenerate-plan` call.
**Warning signs:** Multiple rows in `plan_adaptations` with `trigger_type = 'weekly'` for the same user on the same ISO week.

### Pitfall 6: Notification Copy Failing Guilt Blocklist
**What goes wrong:** GPT-4o-mini generates "It's been 3 days since your last workout" — factually neutral but guilt-adjacent. User feels pressured, not invited.
**Why it happens:** Even with explicit "no guilt" instructions, the model occasionally frames absence in terms of time elapsed.
**How to avoid:** Run `passesGuiltBlocklist()` (AI-SPEC Section 5) on every generated notification string before scheduling. If any pattern matches, substitute the hardcoded safe default ("Your plan is ready — see you when you're ready.").
**Warning signs:** Users report feeling "shamed" by push notifications.

### Pitfall 7: Adapting on a Single Session Rating
**What goes wrong:** User rates one session "too hard" (DOMS from a new exercise). Plan gets lighter. User rates lighter plan "too easy." Oscillation begins.
**Why it happens:** Single session ratings are noisy signals. The adaptation prompt rules require 2+ consecutive same-direction ratings to prevent this.
**How to avoid:** Prompt rules are already in AI-SPEC Section 4. The Edge Function does NOT need extra client-side gating — the prompt handles this. The iOS client should still call `adapt-plan` after every session (for the audit log), trusting the prompt rules.
**Warning signs:** Users report the plan oscillates week-to-week.

---

## Code Examples

Verified patterns from official sources and the AI-SPEC:

### CDSessionLog CoreData Model Extension
```xml
<!-- ADD to CDSessionLog entity in WorkoutApp.xcdatamodeld -->
<!-- New optional String attribute — lightweight migration supported -->
<attribute name="difficultyRating"
           optional="YES"
           attributeType="String"/>
<!-- Valid non-nil values: "too_easy" | "just_right" | "too_hard" -->
<!-- nil = session predates Phase 8, or user dismissed without rating -->
```

### Supabase Migration SQL
```sql
-- supabase/migrations/20260424000000_phase8_adaptation.sql

-- Extend session_logs with difficulty rating
ALTER TABLE public.session_logs
  ADD COLUMN difficulty_rating TEXT
  CHECK (difficulty_rating IN ('too_easy', 'just_right', 'too_hard'));

-- Adaptation audit log (AI-SPEC Section 4 State Management — verbatim)
CREATE TABLE public.plan_adaptations (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  adapted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  trigger_type    TEXT        NOT NULL
    CHECK (trigger_type IN ('post_session', 'weekly', 'missed_session')),
  adaptation_summary TEXT     NOT NULL,
  previous_plan   JSONB       NOT NULL,
  adapted_plan    JSONB       NOT NULL,
  cache_key       TEXT        UNIQUE,
  prompt_tokens   INTEGER,
  completion_tokens INTEGER
);

CREATE INDEX idx_plan_adaptations_user_id
  ON plan_adaptations (user_id, adapted_at DESC);

ALTER TABLE public.plan_adaptations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own adaptations"
    ON public.plan_adaptations FOR SELECT USING (auth.uid() = user_id);

-- Edge Functions use service role key for writes — no INSERT RLS policy needed
-- (service role bypasses RLS by default in Supabase)
```

### Adaptation Context Interface (TypeScript, from AI-SPEC Section 4)
```typescript
// Source: AI-SPEC Section 4 Core Pattern — verbatim
interface DifficultyRatingEntry {
  session_date: string;             // ISO 8601 date
  workout_name: string;
  rating: "too_easy" | "just_right" | "too_hard";
}

interface PerformanceTrend {
  exercise_name: string;
  average_completion_rate: number;  // 0.0–1.0
  trend: "improving" | "plateau" | "declining";
}

interface AdaptationContext {
  recent_ratings: DifficultyRatingEntry[]; // hard cap at 4 sessions
  performance_trends: PerformanceTrend[]; // top 5 exercises by volume
  missed_sessions: string[];              // ISO dates of planned-but-skipped days
  weeks_on_current_plan: number;
}
```

### Zod Schema for Adapted Plan (from AI-SPEC Section 4b.1)
```typescript
// Source: AI-SPEC Section 4b.1 — verbatim
// supabase/functions/_shared/adaptedPlanSchema.ts
import { z } from "https://deno.land/x/zod@v3.23.8/mod.ts";

export const ExerciseSchema = z.object({
  exercise_name: z.string().min(1),
  sets:          z.number().int().min(1).max(10),
  reps:          z.string().min(1),
  rest_seconds:  z.number().int().min(15).max(600),
  rationale:     z.string().min(1),
});

export const AdaptedPlanSchema = z.object({
  adjustment_summary: z.string().min(10).max(500),
  weekly_days: z.array(z.object({
    day_label:    z.string().min(1),
    session_name: z.string().min(1),
    exercises:    z.array(ExerciseSchema).min(1).max(15),
  })).min(1).max(7),
});

export type AdaptedPlan = z.infer<typeof AdaptedPlanSchema>;
```

### iOS AdaptationService Request (non-streaming URLSession)
```swift
// Source: [ASSUMED] — follows PlanSSEClient pattern but uses data(for:) not AsyncBytes
// Analog: PlanGenerationService.generatePlan() non-streaming variant

func requestAdaptation(
    userId: String,
    currentRating: DifficultyRating
) async throws -> AdaptedPlan {
    guard let url = URL(string: "\(supabaseURL)/functions/v1/adapt-plan") else {
        throw AdaptationError.invalidURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    // CRITICAL: Manual auth headers — same Supabase SDK bug #634 as PlanSSEClient
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
        AdaptPlanRequest(userId: userId, currentRating: currentRating)
    )
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw AdaptationError.serverError
    }
    return try JSONDecoder().decode(AdaptedPlan.self, from: data)
}
```

### Token Budget Guard (from AI-SPEC Section 4)
```typescript
// Source: AI-SPEC Section 4 Context Window Strategy — verbatim
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

function assertPromptBudget(prompt: string, budgetTokens: number, fnName: string): void {
  const estimate = estimateTokens(prompt);
  if (estimate > budgetTokens) {
    console.warn(
      `${fnName}: system prompt ~${estimate} tokens exceeds budget of ${budgetTokens}`
    );
  }
}
// Call before every OpenAI fetch in adapt-plan and regenerate-plan
// Budget: 1400 tokens for adaptation system prompt
```

### Guilt Language Blocklist (from AI-SPEC Section 5)
```typescript
// Source: AI-SPEC Section 5 Dimension 4 — verbatim
// Run on every generated re-engagement notification string before scheduling
const GUILT_PATTERNS = [
  /you missed/i,
  /you (haven't|have not)/i,
  /you skipped/i,
  /you (failed|didn't|did not)/i,
  /\d+ (days?|sessions?|workouts?) (missed|skipped|without)/i,
  /don't break/i,
  /falling behind/i,
];

function passesGuiltBlocklist(notification: string): boolean {
  return !GUILT_PATTERNS.some(pattern => pattern.test(notification));
}

// If check fails, use hardcoded fallback — never deliver guilt-adjacent copy
const SAFE_FALLBACK = "Your plan is ready — see you when you're ready.";
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `max_tokens` parameter | `max_completion_tokens` parameter | OpenAI API 2024 | `max_tokens` silently ignored for o-series models; Phase 8 must use `max_completion_tokens`. The existing `coach-chat/index.ts` line 236 summarization call should be migrated as part of Phase 8 shared-code cleanup. |
| SSE streaming for all plan operations | Non-streaming for adaptation, streaming for chat | Phase 8 design decision | Adaptation responses must be fully assembled for Zod validation; streaming would produce mid-JSON character streams unusable by iOS |
| Duplicated planSchema in each Edge Function | Single `_shared/planSchema.ts` | Phase 8 refactor | Required before adding adapt-plan and regenerate-plan to prevent 4-way drift |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | iOS `AdaptationService` uses `URLSession.data(for:)` for non-streaming Edge Function calls | Code Examples | Low — either approach works; `data(for:)` is simpler for non-streaming; planner can choose AsyncBytes for pattern consistency |
| A2 | Missed session detection and weekly regeneration check run on iOS app foreground (`scenePhase == .active`) rather than a Supabase cron job | Architecture | Low — foreground check satisfies D-07 ("user opens the app the next day and sees an updated plan") and is simpler for v1; Supabase cron would require APNs push infrastructure |
| A3 | Re-engagement notification copy uses hardcoded safe defaults rather than GPT-4o-mini generation | Standard Stack | Low — hardcoded defaults eliminate guilt-drift risk and are always available offline; AI-generated copy is an optional enhancement |

---

## Open Questions

1. **Where does AdaptationService attach in the iOS app lifecycle?**
   - What we know: Must be called after session completion and on every app foreground.
   - What's unclear: Whether AdaptationService is injected via `@Environment` (like AppState) or owned by a specific ViewModel.
   - Recommendation: Make AdaptationService a standalone `@Observable @MainActor final class` injected via `@Environment` at the MainTabView level. Call `adaptationService.checkOnForeground()` in `.onChange(of: scenePhase)`. This mirrors the SessionSyncService pattern exactly.

2. **How does the iOS client receive and apply the adapted plan?**
   - What we know: `adapt-plan` writes the updated plan to Supabase `user_plans`. The iOS client's TrainView fetches the active plan from CoreData on appear.
   - What's unclear: Whether the adaptation response is applied immediately from the response JSON or deferred to a Supabase re-fetch.
   - Recommendation: Apply the adapted plan JSON directly from the `adapt-plan` response body — same as how `generate-plan` response is applied in `PlanGenerationService`. Avoids an extra Supabase fetch round-trip and gives instant visual feedback. Store the new plan to both CoreData and propagate via AppState.

3. **Does plan_adaptations use Supabase service role key for writes?**
   - What we know: Edge Functions that write to Supabase can use either the anon key (limited by RLS) or the service role key (bypasses RLS).
   - What's unclear: Whether inserting into `plan_adaptations` from an Edge Function requires the service role key.
   - Recommendation: Use the service role key for Edge Function writes to `plan_adaptations` (same pattern as other Edge Functions in this project that write to backend tables). Never expose the service role key to the iOS client.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI | adapt-plan function deploy | ✓ | existing (functions already deployed) | — |
| OpenAI API key (OPENAI_API_KEY secret) | adapt-plan, regenerate-plan | ✓ | configured in project | — |
| Deno Edge Function runtime | Supabase functions | ✓ | deno.land/std@0.224.0 (pinned, existing) | — |
| Zod (Deno URL import) | adapt-plan Zod validation | ✓ | deno.land/x/zod@v3.23.8 (pinned in AI-SPEC) | — |
| UserNotifications framework | NotificationScheduler | ✓ | iOS 16+ (existing, Phase 6) | — |
| Promptfoo | Eval CI/CD | Not yet installed | — | Install via `npm install --save-dev promptfoo` in Wave 0 |

**Missing dependencies with fallback:**
- Promptfoo: dev-time tool only; install during eval setup wave. No production blocker.

**Missing dependencies with no fallback:**
- None — all production dependencies are already available.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (iOS) + Promptfoo (Edge Function eval) |
| Config file | `supabase/functions/adapt-plan/eval/promptfooconfig.yaml` (Wave 0 gap) |
| Quick run command | `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/AdaptationServiceTests` |
| Full suite command | `xcodebuild test -scheme WorkoutApp && promptfoo eval --config supabase/functions/adapt-plan/eval/promptfooconfig.yaml` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADPT-01 | difficulty_rating written to CDSessionLog after rating tap | Unit | `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/SessionRepositoryTests` | ❌ Wave 0 — add test case |
| ADPT-01 | difficulty_rating included in Supabase sync payload | Unit | `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/SessionSyncServiceTests` | ❌ Wave 0 — add test case |
| ADPT-01 | adapt-plan directional correctness: too_hard reduces volume | Eval | `promptfoo eval --config supabase/functions/adapt-plan/eval/promptfooconfig.yaml` | ❌ Wave 0 — create config + fixtures |
| ADPT-01 | adapt-plan schema compliance: Zod pass on all fixture responses | Eval | Same Promptfoo config | ❌ Wave 0 |
| ADPT-01 | No clinical language in adjustment_summary or rationale fields | Eval | Same Promptfoo config | ❌ Wave 0 |
| ADPT-02 | Weekly regeneration cache prevents duplicate calls same week | Unit | `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/AdaptationServiceTests` | ❌ Wave 0 — create test file |
| ADPT-02 | Exercise continuity score >= 0.60 across weekly regeneration | Eval | Promptfoo fixture: weekly_regeneration_4wk.json | ❌ Wave 0 |
| ADPT-03 | Missed session detection identifies correct days (not rest days) | Unit | `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/MissedSessionDetectorTests` | ❌ Wave 0 — create test file |
| ADPT-03 | Missed session redistribution: no full-volume stacking | Eval | Promptfoo fixture: missed_session_legs.json | ❌ Wave 0 |
| D-10 | Re-engagement notifications capped at 2/week | Unit | `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/NotificationSchedulerTests` | ❌ Wave 0 — add test cases |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme WorkoutApp -only-testing WorkoutAppTests/<relevant test class>`
- **Per wave merge:** `xcodebuild test -scheme WorkoutApp` (full iOS suite)
- **Phase gate:** Full iOS suite + Promptfoo eval suite (95% pass threshold) green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `supabase/functions/adapt-plan/eval/promptfooconfig.yaml` — Promptfoo config for adapt-plan eval
- [ ] `supabase/functions/adapt-plan/eval/fixtures/` — minimum 10 JSON fixtures: `too_hard_2x.json`, `too_easy_3x.json`, `just_right_mixed.json`, `missed_session_legs.json`, `missed_session_upper.json`, `weekly_regeneration_4wk.json`, `safety_injury.json`, `reengagement_notification_x4.json` (4 files)
- [ ] `WorkoutAppTests/AdaptationServiceTests.swift` — covers ADPT-02 cache logic, plan apply logic
- [ ] `WorkoutAppTests/MissedSessionDetectorTests.swift` — covers ADPT-03 missed day identification
- [ ] Add difficulty_rating test cases to `WorkoutAppTests/SessionRepositoryTests.swift`
- [ ] Add difficulty_rating sync test cases to `WorkoutAppTests/SessionSyncServiceTests.swift`
- [ ] Add re-engagement frequency cap test cases to `WorkoutAppTests/NotificationSchedulerTests.swift`
- [ ] `npm install --save-dev promptfoo` (dev dependency for eval runner)

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing Bearer token validation — copy verbatim to adapt-plan and regenerate-plan |
| V3 Session Management | no | No session state changes in Phase 8 |
| V4 Access Control | yes | `user_id` check in all Supabase queries; RLS on `plan_adaptations` table; Edge Functions use service role for writes |
| V5 Input Validation | yes | Length limits on all user-supplied fields (same defense-in-depth as generate-plan); `difficulty_rating` validated as enum at DB level (CHECK constraint) |
| V6 Cryptography | no | No new cryptographic operations |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection via difficulty_rating field | Tampering | Rating is an enum constraint (too_easy/just_right/too_hard); validated at CoreData, Supabase CHECK constraint, and Edge Function input validation — not a freeform string |
| User ID spoofing in adapt-plan request body | Spoofing | Edge Function extracts user ID from verified Supabase JWT, never from the request body — same pattern as all existing Edge Functions |
| Token cost abuse via unbounded adapt-plan calls | Denial of Service | Rate limiting placeholder in coach-chat; same pattern should be added to adapt-plan and regenerate-plan with `console.warn` placeholder |
| Clinical language in AI rationale text | Regulatory (App Store 1.4.1) | `CLINICAL_LANGUAGE_PATTERNS` blocklist (AI-SPEC Section 6) runs on every adapted plan before return; non-blocking (strips field, returns plan with generic replacement copy) |
| Guilt-inducing re-engagement notifications | User harm | `GUILT_PATTERNS` blocklist (AI-SPEC Section 5) discards generated copy and falls back to hardcoded safe default before scheduling |

---

## Project Constraints (from CLAUDE.md)

The following CLAUDE.md directives are binding for this phase:

1. **Never call OpenAI API from iOS client directly** — all AI calls go through Supabase Edge Functions. Both `adapt-plan` and `regenerate-plan` must follow this pattern.
2. **Never use `max_tokens`** (deprecated) — use `max_completion_tokens` on all Phase 8 Edge Function OpenAI calls. The existing `coach-chat/index.ts` summarization call (line 236) uses `max_tokens` and should be migrated as part of Phase 8 shared-code cleanup.
3. **Never use third-party OpenAI Swift SDKs** — iOS client calls Edge Functions via URLSession only.
4. **Two-model strategy** — GPT-4o for plan adaptation (complex structured JSON), GPT-4o-mini for notification copy generation (short-form, cost-sensitive).
5. **Swift 6 / async-await** — no Combine; async/await throughout. `AdaptationService` must be `@Observable @MainActor`.
6. **CoreData (not SwiftData)** — add `difficultyRating` optional String attribute to `CDSessionLog`; lightweight migration supported for new optional attributes.
7. **SPM only** — no CocoaPods. Promptfoo is a dev-time npm tool, not an iOS SPM dependency.
8. **System prompt architecture** — user profile + history summary injected on every AI request from Supabase; never rely on conversation history alone for state.

---

## Sources

### Primary (HIGH confidence)
- `supabase/functions/generate-plan/index.ts` — existing Edge Function pattern; auth, CORS, Structured Outputs, planSchema [VERIFIED: codebase read]
- `supabase/functions/coach-chat/index.ts` — non-streaming GPT-4o path (execute_modify); schema reuse; max_tokens deprecation issue at line 236 [VERIFIED: codebase read]
- `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — exact Phase 8 placeholder at line 68 [VERIFIED: codebase read]
- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — existing notification infrastructure; UNCalendarNotificationTrigger pattern [VERIFIED: codebase read]
- `WorkoutApp/Core/Sync/SessionSyncService.swift` — SessionLogRow struct (lines 179-201); missing difficulty_rating [VERIFIED: codebase read]
- `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` — CDSessionLog schema; confirmed no difficulty_rating attribute [VERIFIED: codebase read]
- `supabase/migrations/20260422000000_create_session_logs.sql` — session_logs schema; confirmed no difficulty_rating column [VERIFIED: codebase read]
- `.planning/phases/08-adaptive-ai/08-AI-SPEC.md` — AI design contract; Sections 3, 4, 4b, 5, 6 [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- `WorkoutApp/Features/Progress/ProgressViewModel.swift` — computeWeeklyRing pattern informs missed session detection logic [VERIFIED: codebase read]
- `.planning/phases/05-ai-coach-chat/05-PATTERNS.md` — established project patterns for new service classes [VERIFIED: codebase read]

### Tertiary (LOW confidence)
- None — all factual claims verified against codebase or AI-SPEC.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing project stack confirmed from CLAUDE.md and codebase; no new dependencies beyond Zod (pinned Deno URL import, free) and Promptfoo (dev tool)
- Architecture: HIGH — all integration points confirmed by reading actual source files; data flow verified against existing sync patterns
- Pitfalls: HIGH — each pitfall identified from concrete code inspection (SessionLogRow missing field, planSchema duplication) or AI-SPEC domain research

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (stable stack — OpenAI API, CoreData, Supabase patterns unlikely to change in 30 days)
