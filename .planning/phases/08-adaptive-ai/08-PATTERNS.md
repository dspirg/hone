# Phase 8: Adaptive AI - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 10 new/modified files
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `supabase/functions/_shared/planSchema.ts` | utility | transform | `supabase/functions/generate-plan/index.ts` (lines 17–52) | exact |
| `supabase/functions/adapt-plan/index.ts` | service | request-response | `supabase/functions/coach-chat/index.ts` (execute_modify path) | exact |
| `supabase/functions/regenerate-plan/index.ts` | service | request-response | `supabase/functions/generate-plan/index.ts` | exact |
| `supabase/migrations/20260424000000_phase8_adaptive.sql` | migration | CRUD | `supabase/migrations/20260422000000_create_session_logs.sql` | exact |
| `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` | component | event-driven | self (modify in place — Phase 8 placeholder already present line 8) | exact |
| `WorkoutApp/Features/Session/SessionViewModel.swift` | view-model | CRUD | self (extend — add `difficultyRating` property) | exact |
| `WorkoutApp/Core/Data/SessionRepository.swift` (CoreData migration) | model | CRUD | self (extend — add `difficulty_rating` attribute) | exact |
| `WorkoutApp/Core/Sync/SessionSyncService.swift` | service | CRUD | self (extend — include `difficulty_rating` in SessionLogRow) | exact |
| `WorkoutApp/Features/Adaptation/AdaptationService.swift` | service | request-response | `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` | role-match |
| `WorkoutApp/Core/Notifications/NotificationScheduler.swift` | service | event-driven | self (extend — add re-engagement category) | exact |

---

## Pattern Assignments

### `supabase/functions/_shared/planSchema.ts` (utility, transform)

**Analog:** `supabase/functions/generate-plan/index.ts` lines 17–52 (identical copy also in `coach-chat/index.ts` lines 21–56)

**Core pattern — the schema to extract** (generate-plan lines 17–52):
```typescript
export const planSchema = {
  type: "object" as const,
  properties: {
    plan_name: { type: "string" as const },
    goal_summary: { type: "string" as const },
    weekly_days: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          day_label: { type: "string" as const },
          session_name: { type: "string" as const },
          exercises: {
            type: "array" as const,
            items: {
              type: "object" as const,
              properties: {
                exercise_name: { type: "string" as const },
                sets: { type: "integer" as const },
                reps: { type: "string" as const },
                rest_seconds: { type: "integer" as const },
                rationale: { type: "string" as const },
              },
              required: ["exercise_name", "sets", "reps", "rest_seconds", "rationale"],
              additionalProperties: false,
            },
          },
        },
        required: ["day_label", "session_name", "exercises"],
        additionalProperties: false,
      },
    },
  },
  required: ["plan_name", "goal_summary", "weekly_days"],
  additionalProperties: false,
};
```

**Note:** Both `generate-plan/index.ts` and `coach-chat/index.ts` carry identical copies of this schema. The shared file replaces both. After extraction, update each consumer to:
```typescript
import { planSchema } from "../_shared/planSchema.ts";
```

---

### `supabase/functions/adapt-plan/index.ts` (service, request-response)

**Analog:** `supabase/functions/coach-chat/index.ts` — specifically the `execute_modify` path (lines 129–188) plus the surrounding boilerplate.

**Imports pattern** (coach-chat lines 1–15):
```typescript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { planSchema } from "../_shared/planSchema.ts";  // Phase 8: from shared module
```

**CORS + auth boilerplate** (coach-chat lines 58–93 — copy verbatim):
```typescript
serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
      },
    });
  }

  const openAIKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAIKey) {
    return new Response(
      JSON.stringify({ error: "OPENAI_API_KEY is not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }
```

**Core non-streaming GPT-4o + Structured Outputs pattern** (coach-chat lines 148–188):
```typescript
  const adaptResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-2024-08-06",
      stream: false,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "workout_plan",
          strict: true,
          schema: planSchema,
        },
      },
      messages: [
        { role: "system", content: adaptationSystemPrompt },
        { role: "user", content: "Generate the adapted workout plan." },
      ],
    }),
  });

  if (!adaptResponse.ok) {
    const errorBody = await adaptResponse.text();
    console.error(`adapt-plan: OpenAI error ${adaptResponse.status}: ${errorBody}`);
    return new Response(
      JSON.stringify({ error: "Plan adaptation failed", status: adaptResponse.status }),
      { status: adaptResponse.status, headers: { "Content-Type": "application/json" } }
    );
  }

  const result = await adaptResponse.json();

  // finish_reason guard — "content_filter" or "length" means invalid output
  const finishReason = result.choices?.[0]?.finish_reason;
  if (finishReason !== "stop") {
    return new Response(
      JSON.stringify({ error: "Unexpected finish_reason", finish_reason: finishReason }),
      { status: 422, headers: { "Content-Type": "application/json" } }
    );
  }

  const adaptedPlanJson = result.choices?.[0]?.message?.content;

  return new Response(
    JSON.stringify({ adapted_plan: adaptedPlanJson, adaptation_summary: "..." }),
    { status: 200, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
  );
```

**Input validation pattern** (generate-plan lines 122–148 — apply same length-cap approach):
```typescript
  const MAX_RATING_VALUES = ["too_easy", "just_right", "too_hard"] as const;
  // Validate difficulty_rating is one of the allowed enum values
  if (payload.difficulty_rating && !MAX_RATING_VALUES.includes(payload.difficulty_rating)) {
    return new Response(
      JSON.stringify({ error: "Invalid difficulty_rating value" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
```

---

### `supabase/functions/regenerate-plan/index.ts` (service, request-response)

**Analog:** `supabase/functions/generate-plan/index.ts` — same non-streaming GPT-4o + Structured Outputs structure, adapted for weekly evolution context.

**Imports + boilerplate** (generate-plan lines 1–15 and 54–89): Copy CORS preflight, env key guard, and auth header guard verbatim.

**Core pattern — system prompt injection** (generate-plan lines 149–175):
```typescript
  // Weekly regeneration uses same prompt injection pattern as generate-plan
  // but substitutes performance history context for the initial onboarding profile
  let systemPrompt = `You are a professional fitness coach evolving a user's weekly workout plan.

User profile:
- Goal: ${safeGoal}
- Fitness Level: ${safeLevel}
- Equipment: ${equipmentList}

Current plan:
${JSON.stringify(payload.current_plan)}

Recent performance (last ${payload.session_history.length} sessions):
${payload.session_history.map(s =>
  `- ${s.date}: ${s.workout_name} — difficulty: ${s.difficulty_rating ?? "not rated"}`
).join("\n")}

SAFETY: You are not a medical professional. ...`;
```

**Cache deduplication pattern** (new — no existing analog, but mirrors the caching guard in NotificationScheduler's `shouldScheduleNotifications`):
```typescript
  // Deduplicate by userId + ISO week + planVersion cache_key
  const cacheKey = `${userId}-${isoWeek}-v${payload.plan_version}`;
  // Insert into plan_adaptations with cache_key UNIQUE constraint — duplicate will error
```

---

### `supabase/migrations/20260424000000_phase8_adaptive.sql` (migration, CRUD)

**Analog:** `supabase/migrations/20260422000000_create_session_logs.sql`

**Structure pattern** (create_session_logs lines 1–56):
```sql
-- Phase 8: Add difficulty_rating to session_logs + create plan_adaptations audit table
-- Requirements: ADPT-01, ADPT-02, ADPT-03

-- 1. Add difficulty_rating column (lightweight migration — optional attribute)
ALTER TABLE public.session_logs
  ADD COLUMN difficulty_rating TEXT
    CHECK (difficulty_rating IN ('too_easy', 'just_right', 'too_hard'));

-- 2. Create plan_adaptations immutable audit log
CREATE TABLE public.plan_adaptations (
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

ALTER TABLE public.plan_adaptations ENABLE ROW LEVEL SECURITY;

-- RLS pattern mirrors session_logs (create_session_logs lines 18–30)
CREATE POLICY "Users can view own plan adaptations"
  ON public.plan_adaptations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own plan adaptations"
  ON public.plan_adaptations FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

---

### `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (component, event-driven)

**Analog:** Self — modify in place. The Phase 8 drop-in point is explicitly marked at line 8 and lines 68–74.

**Insertion point** (lines 64–74 — replace "Done button" section):
```swift
// Phase 8 drop-in: Replace lines 68-74 with emoji rating picker + gated Done button

// MARK: - Difficulty Rating (Phase 8 — D-01, D-02)
// Emoji scale: 😌 too easy / 😊 just right / 😤 too hard
// Rating is required — Done button disabled until selection made (D-02)
VStack(spacing: 12) {
    Text("How was that?")
        .font(.subheadline)
        .foregroundStyle(.secondary)

    HStack(spacing: 24) {
        ForEach(DifficultyRating.allCases, id: \.self) { rating in
            Button(action: { selectedRating = rating }) {
                Text(rating.emoji)
                    .font(.system(size: 44))
                    .scaleEffect(selectedRating == rating ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: selectedRating)
            }
            .accessibilityLabel(rating.accessibilityLabel)
        }
    }
}

Button("Done", action: { onDone(selectedRating) })
    .buttonStyle(.borderedProminent)
    .disabled(selectedRating == nil)    // D-02: required rating gate
    .frame(maxWidth: .infinity)
    .frame(height: 52)
    .padding(.horizontal, 16)
    .padding(.bottom, 32)
```

**State additions to struct** (lines 14–22 pattern — add `@State` before `var body`):
```swift
struct SessionSummaryView: View {
    // existing parameters...
    let onDone: (DifficultyRating) -> Void  // Phase 8: signature change — passes rating

    @State private var selectedRating: DifficultyRating? = nil
```

**DifficultyRating enum** (new, follows `PRResult.swift` pattern in `WorkoutApp/Features/Progress/Models/`):
```swift
// WorkoutApp/Features/Session/Models/DifficultyRating.swift
enum DifficultyRating: String, CaseIterable, Codable {
    case tooEasy    = "too_easy"
    case justRight  = "just_right"
    case tooHard    = "too_hard"

    var emoji: String {
        switch self {
        case .tooEasy:   return "😌"
        case .justRight: return "😊"
        case .tooHard:   return "😤"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .tooEasy:   return "Too easy"
        case .justRight: return "Just right"
        case .tooHard:   return "Too hard"
        }
    }
}
```

---

### `WorkoutApp/Features/Session/SessionViewModel.swift` (view-model, CRUD)

**Analog:** Self — extend. Pattern reference is the existing `detectedPRs` property and `finalizeSession` flow (lines 30, 138–153).

**Property addition** (after line 30 — mirrors `detectedPRs: [PRResult] = []` pattern):
```swift
// Phase 8: difficulty rating captured at summary screen, persisted on finalize
private(set) var difficultyRating: DifficultyRating? = nil
```

**Method addition** — called by SessionSummaryView `onDone` closure:
```swift
/// Called when user taps Done on SessionSummaryView with selected difficulty rating.
/// Persists rating to CDSessionLog and triggers adaptation service call.
func finalizeWithRating(_ rating: DifficultyRating) {
    difficultyRating = rating
    Task {
        if let session = sessionLog {
            try? repository.setDifficultyRating(session, rating: rating)
        }
        // AdaptationService call — async, non-blocking, non-fatal
        // Mirror the pattern from startSession() lines 92-106: Task + non-fatal catch
    }
}
```

**Init signature** stays unchanged — `difficultyRating` is set post-session, not at init.

---

### `WorkoutApp/Core/Data/SessionRepository.swift` (CoreData model extension, CRUD)

**Analog:** Self — extend. Pattern reference is `finalizeSession` (lines 122–130) and `completeSet` (lines 63–93).

**New method** (follows `finalizeSession` style — synchronous, throws, saves context):
```swift
/// Sets the difficulty rating on an existing session log. Called from SessionViewModel after
/// the user submits the rating on SessionSummaryView.
func setDifficultyRating(_ session: CDSessionLog, rating: DifficultyRating) throws {
    session.difficultyRating = rating.rawValue
    try context.save()
}
```

**CoreData model migration:** Add `difficultyRating` (String, optional) attribute to `CDSessionLog` entity in the `.xcdatamodeld` file. Create a new model version — lightweight migration applies automatically for optional attribute additions.

---

### `WorkoutApp/Core/Sync/SessionSyncService.swift` (service extension, CRUD)

**Analog:** Self — extend. The `SessionLogRow` struct (lines 179–201) needs one additional field.

**SessionLogRow extension** (lines 179–201 — add `difficultyRating` field):
```swift
private struct SessionLogRow: Encodable {
    let id: String
    let userId: String
    let planId: String
    let workoutDayLabel: String
    let startedAt: Date
    let completedAt: Date
    let totalExercises: Int
    let totalSets: Int
    let totalReps: Int
    let difficultyRating: String?  // Phase 8 addition — optional, matches DB column

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planId = "plan_id"
        case workoutDayLabel = "workout_day_label"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case totalExercises = "total_exercises"
        case totalSets = "total_sets"
        case totalReps = "total_reps"
        case difficultyRating = "difficulty_rating"  // Phase 8 addition
    }
}
```

**performBatchSync update** (lines 99–112 — add `difficultyRating` to mapping):
```swift
return SessionLogRow(
    // ... existing fields ...
    difficultyRating: s.difficultyRating   // Phase 8: nil if not yet rated
)
```

---

### `WorkoutApp/Features/Adaptation/AdaptationService.swift` (service, request-response)

**Analog:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` — same `@Observable @MainActor` pattern, same Edge Function call pattern, same non-streaming result handling.

**Imports + declaration pattern** (PlanGenerationService lines 1–3, 37–39):
```swift
import Foundation
import Supabase

@Observable
@MainActor
final class AdaptationService {
```

**State enum pattern** (PlanGenerationService lines 7–22 — create parallel enum):
```swift
enum AdaptationState: Equatable {
    case idle
    case adapting
    case completed(WorkoutPlan, adaptationSummary: String)
    case error(String)
}
```

**Core call pattern** (PlanGenerationService lines 77–143 — but non-streaming, no SSE):
```swift
func adaptPlan(rating: DifficultyRating, userId: String) {
    state = .adapting

    Task {
        do {
            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(supabaseURL)/functions/v1/adapt-plan") else {
                state = .error("Invalid Edge Function URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // CRITICAL: Manual auth header — SDK streaming path drops JWT (issue #634)
            // Same pattern as PlanSSEClient lines 82-87
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.httpBody = try JSONEncoder().encode(AdaptPayload(
                userId: userId,
                difficultyRating: rating.rawValue
            ))

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                state = .error("Adaptation request failed")
                return
            }

            let result = try JSONDecoder().decode(AdaptationResult.self, from: data)

            // Persist adapted plan — same sequential order as PlanGenerationService lines 108-118
            let planRepo = WorkoutPlanRepository()
            try planRepo.deactivateAllPlans(userId: userId)
            try planRepo.save(plan: result.adaptedPlan, supabaseId: result.planId, userId: userId)

            state = .completed(result.adaptedPlan, adaptationSummary: result.adaptationSummary)

        } catch {
            // Non-fatal: adaptation failure should not crash session flow
            // Mirror PlanGenerationService lines 123-140 error handling
            state = .error("Couldn't adapt your plan right now. It will update next session.")
        }
    }
}
```

**MissedSessionDetector** (companion struct — follows ProgressViewModel's `fetchCompletedSessions` pattern, lines 76–86):
```swift
// WorkoutApp/Features/Adaptation/MissedSessionDetector.swift
@MainActor
struct MissedSessionDetector {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    /// Returns true when the user had a planned session yesterday and no completed session exists.
    /// Uses same userId-scoped predicate as ProgressViewModel.fetchCompletedSessions (T-06-01).
    func hasMissedSessionYesterday(userId: String, plannedWeekdays: [Int]) -> Bool {
        // Compare Calendar.current.dateComponents weekday against plannedWeekdays
        // Then query CDSessionLog for completedAt within yesterday's calendar day
        // Pattern: NotificationScheduler.hasLoggedSessionToday lines 131-153
    }
}
```

---

### `WorkoutApp/Core/Notifications/NotificationScheduler.swift` (service extension, event-driven)

**Analog:** Self — extend with re-engagement category. Pattern reference is `scheduleWorkoutReminders` (lines 61–110) and `hasLoggedSessionToday` (lines 131–153).

**New method** (follows `scheduleWorkoutReminders` method structure — same `UNCalendarNotificationTrigger` + frequency guard):
```swift
// MARK: - Re-engagement Notifications (Phase 8 — D-08, D-09, D-10)

/// Schedules a supportive re-engagement notification when 2+ planned sessions are missed.
/// Frequency cap: max 2 per week. Backs off after 2 unanswered nudges (D-10).
/// Identifier pattern "reengagement-{yyyy-MM-dd}" allows cancel-per-day.
func scheduleReengagementIfNeeded(userId: String, missedCount: Int) async {
    guard await shouldScheduleNotifications() else { return }
    guard missedCount >= 2 else { return }  // D-08: threshold

    // Frequency cap: count pending reengagement notifications (D-10)
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
    let reengagementPending = pending.filter { $0.identifier.hasPrefix("reengagement-") }
    guard reengagementPending.count < 2 else { return }  // max 2/week

    let content = UNMutableNotificationContent()
    content.sound = .default
    // D-09: supportive coach tone — no guilt language
    content.title = "Your plan adapted to your schedule"
    content.body = "Ready when you are."

    // Schedule for next morning at 9am (avoids late-night guilt push)
    var components = DateComponents()
    components.hour = 9
    components.minute = 0
    components.timeZone = TimeZone.current

    // PITFALL: Use TimeInterval trigger for "tomorrow morning" not Calendar trigger
    // to avoid scheduling in the past if it's already past 9am today
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilTomorrowMorning(), repeats: false)

    let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
    let request = UNNotificationRequest(
        identifier: "reengagement-\(today)",
        content: content,
        trigger: trigger
    )

    do {
        try await center.add(request)
    } catch {
        print("NotificationScheduler: scheduleReengagementIfNeeded failed: \(error)")
    }
}

func cancelAllReengagementNotifications() async {
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
    let ids = pending.map { $0.identifier }.filter { $0.hasPrefix("reengagement-") }
    center.removePendingNotificationRequests(withIdentifiers: ids)
}

// Mirrors hasLoggedSessionToday pattern (lines 131-153) — private helper
private func secondsUntilTomorrowMorning() -> TimeInterval {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
    components.hour = 9
    components.minute = 0
    let tomorrowMorning = calendar.date(from: components) ?? tomorrow
    return max(tomorrowMorning.timeIntervalSinceNow, 60)
}
```

---

## Shared Patterns

### Authentication Header (Manual JWT — SDK Bug #634)
**Source:** `WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift` lines 82–87
**Apply to:** `AdaptationService.swift` — all Edge Function calls
```swift
// CRITICAL: Manual auth header — SDK streaming path drops JWT (issue #634)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
```

### Edge Function CORS + Auth Guard
**Source:** `supabase/functions/generate-plan/index.ts` lines 54–93
**Apply to:** `adapt-plan/index.ts`, `regenerate-plan/index.ts` — copy verbatim
```typescript
// OPTIONS preflight, OPENAI_API_KEY env guard, Bearer header validation
// These three blocks are identical across all Edge Functions in this project.
```

### OpenAI Non-Streaming Structured Outputs Call
**Source:** `supabase/functions/coach-chat/index.ts` lines 148–188 (execute_modify path)
**Apply to:** `adapt-plan/index.ts`, `regenerate-plan/index.ts`
```typescript
model: "gpt-4o-2024-08-06",  // minimum for Structured Outputs
stream: false,
response_format: { type: "json_schema", json_schema: { name: "workout_plan", strict: true, schema: planSchema } }
```

### @Observable + @MainActor ViewModel
**Source:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` lines 37–39
**Apply to:** `AdaptationService.swift`
```swift
@Observable
@MainActor
final class AdaptationService { ... }
```

### CoreData userId Scoping (T-06-01)
**Source:** `WorkoutApp/Features/Progress/ProgressViewModel.swift` lines 76–86
**Apply to:** `MissedSessionDetector.swift` — all CoreData fetch predicates must include `userId == %@`
```swift
request.predicate = NSPredicate(
    format: "completedAt != nil AND userId == %@",
    userId
)
```

### Notification Identifier Prefix Convention
**Source:** `WorkoutApp/Core/Notifications/NotificationScheduler.swift` lines 97, 120–122
**Apply to:** Re-engagement notifications in Phase 8 NotificationScheduler extension
```swift
// Prefix convention: "workout-reminder-{n}", "rest-timer-{sessionId}", "reengagement-{date}"
// Cancel filters by hasPrefix() — never remove notifications from other categories
let ids = pending.map { $0.identifier }.filter { $0.hasPrefix("reengagement-") }
```

### Supabase upsert with snake_case CodingKeys
**Source:** `WorkoutApp/Core/Sync/SessionSyncService.swift` lines 179–225
**Apply to:** Any new Encodable structs that map to Supabase columns
```swift
enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case difficultyRating = "difficulty_rating"
    // All Swift camelCase properties map to snake_case DB column names
}
```

### Non-Fatal Error Handling for Background Services
**Source:** `WorkoutApp/Features/Session/SessionViewModel.swift` lines 91–107
**Apply to:** `AdaptationService` calls from SessionViewModel — adaptation failure must not block session completion
```swift
Task {
    do {
        // ... service call ...
    } catch {
        // CoreData/network failure is non-fatal — session state continues in memory
        // Log but never throw to caller
    }
}
```

---

## No Analog Found

All Phase 8 files have close analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

| File | Note |
|------|------|
| `WorkoutApp/Features/Session/Models/DifficultyRating.swift` | New enum — no existing analog, but follows `PRResult.swift` model file structure in `WorkoutApp/Features/Progress/Models/` |
| `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift` | New struct — combines ProgressViewModel's CoreData fetch pattern with NotificationScheduler's session-guard pattern |

---

## Metadata

**Analog search scope:** `WorkoutApp/` (all Swift files), `supabase/functions/` (all Edge Functions), `supabase/migrations/` (all SQL files)
**Files scanned:** 11 Swift files read in full, 3 Edge Functions read in full, 2 migration files read in full
**Pattern extraction date:** 2026-04-24
