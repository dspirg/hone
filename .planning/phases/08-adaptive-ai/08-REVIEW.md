---
phase: 08-adaptive-ai
reviewed: 2026-04-25T16:11:49Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - supabase/functions/_shared/adaptedPlanSchema.ts
  - supabase/functions/_shared/planSchema.ts
  - supabase/functions/_shared/promptBuilder.ts
  - supabase/functions/adapt-plan/index.ts
  - supabase/functions/coach-chat/index.ts
  - supabase/functions/generate-plan/index.ts
  - supabase/functions/regenerate-plan/index.ts
  - WorkoutApp/Core/Notifications/NotificationScheduler.swift
  - WorkoutApp/Core/Sync/SessionSyncService.swift
  - WorkoutApp/Features/Adaptation/AdaptationService.swift
  - WorkoutApp/Features/Adaptation/MissedSessionDetector.swift
  - WorkoutApp/Features/Adaptation/Models/AdaptedPlan.swift
  - WorkoutApp/Features/CoreData/SessionRepository.swift
  - WorkoutApp/Features/Main/MainTabView.swift
  - WorkoutApp/Features/Main/Tabs/TrainView.swift
  - WorkoutApp/Features/Models/DifficultyRating.swift
  - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
  - WorkoutApp/Features/Session/SessionView.swift
  - WorkoutApp/Features/Session/SessionViewModel.swift
findings:
  critical: 2
  warning: 6
  info: 4
  total: 12
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-04-25T16:11:49Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

This phase implements the adaptive AI pipeline: post-session adaptation, missed-session detection, weekly regeneration, and re-engagement notifications. The overall architecture is sound — JWT extraction from auth header rather than request body, Zod validation with retry, clinical language sanitization, and guilt-free notification copy all reflect careful threat modeling. The iOS side follows established Swift 6 / `@Observable` / `@MainActor` conventions consistently.

Two critical issues were found: an unauthenticated JWT verification path in `coach-chat` that accepts any well-formed Bearer token without calling `auth.getUser`, and a race condition in `SessionViewModel.completeSet` where the session can be finalized and marked complete before `sessionLog` is set (when CoreData write is slow). Six warnings cover logic gaps that will produce silent incorrect behavior in realistic conditions.

---

## Critical Issues

### CR-01: `coach-chat` Never Verifies the JWT — Any Bearer Token Is Accepted

**File:** `supabase/functions/coach-chat/index.ts:47-53`

**Issue:** `coach-chat` validates that the `Authorization` header starts with `"Bearer "` and rejects requests without a token, but it never calls `anonClient.auth.getUser(token)` to verify the JWT signature or extract the `user_id`. Both `adapt-plan` and `regenerate-plan` correctly call `anonClient.auth.getUser(token)` before touching any data. `coach-chat` skips this step entirely — it passes the raw `authHeader` check and proceeds directly to parsing the payload. A caller with any syntactically valid Bearer string (including a fabricated one) will reach the OpenAI call and have their supplied `profile`, `current_plan`, and `message_history` injected into the prompt, incurring cost and potentially leaking the system prompt response.

**Fix:**
```typescript
// After the authHeader check (line 53), extract and verify the token:
const token = authHeader.slice(7);

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const anonClient = createClient(supabaseUrl, supabaseAnonKey);
const { data: { user }, error: authError } = await anonClient.auth.getUser(token);

if (authError || !user) {
  return new Response(
    JSON.stringify({ error: "Unauthorized: invalid or expired token" }),
    { status: 401, headers: { "Content-Type": "application/json" } }
  );
}
// userId = user.id — use for rate limiting and audit logging
```

---

### CR-02: Race Condition — `completeSet` Can Finalize Session Before `sessionLog` Is Set

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:91-107` and `115-117`

**Issue:** `startSession()` launches a `Task { }` to call `repository.startSession(...)` asynchronously and assigns the result to `sessionLog`. `completeSet(setIndex:repsLogged:)` immediately guards on `sessionLog` being non-nil — `guard let session = sessionLog else { return }`. If the CoreData write in `startSession` is slow (e.g., first launch, cold disk), a rapid user tap can reach `completeSet` while `sessionLog` is still `nil`, and the guard will silently discard the set. The set is lost: not written to CoreData, not tracked in `completedSets` state. Because `completedSets` is also not updated, the session can never reach `isLastSetOfCurrentExercise && isLastExercise` for the last exercise, leaving the session in a permanent non-complete state if the first set of the first exercise is dropped.

`startSession()` is called synchronously from `SessionView.setupSession()` which itself is `async` — `startSession()` could simply be `async throws` to eliminate the race.

**Fix:**
```swift
// Make startSession async so setupSession can await it before setting viewModel
func startSession() async {
    sessionStartDate = Date()
    do {
        sessionLog = try repository.startSession(
            day: workoutDay,
            planId: planId,
            userId: userId
        )
    } catch {
        // Non-fatal: session continues in memory without a log reference.
        print("SessionViewModel: startSession CoreData write failed: \(error)")
    }
}

// In SessionView.setupSession():
let vm = SessionViewModel(...)
await vm.startSession()   // await ensures sessionLog is set before view is shown
viewModel = vm
```

---

## Warnings

### WR-01: `coach-chat` `execute_modify` Path Returns Raw JSON String Instead of Parsed Object

**File:** `supabase/functions/coach-chat/index.ts:142-148`

**Issue:** For the `execute_modify` action, `updatedPlan` is assigned from `modifyResult.choices?.[0]?.message?.content` — this is the raw JSON string from the OpenAI structured output, not a parsed object. The response body is `JSON.stringify({ action: "execute_modify", plan_delta: updatedPlan })` which double-encodes the plan: the client receives `plan_delta` as a JSON string inside a JSON object. The iOS client would need to `JSONDecoder` twice to extract the plan, and there is no Zod validation of the plan shape before it is returned. Contrast with `adapt-plan` which parses and validates before returning.

**Fix:**
```typescript
const updatedPlanRaw = modifyResult.choices?.[0]?.message?.content;
if (!updatedPlanRaw) {
  return new Response(JSON.stringify({ error: "Empty plan response" }), { status: 500, ... });
}
let updatedPlan: unknown;
try {
  updatedPlan = JSON.parse(updatedPlanRaw);
} catch {
  return new Response(JSON.stringify({ error: "Plan JSON parse failed" }), { status: 500, ... });
}
// Optionally validate with planSchema Zod equivalent here
return new Response(
  JSON.stringify({ action: "execute_modify", plan_delta: updatedPlan }),  // object, not string
  { status: 200, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
);
```

---

### WR-02: `regenerate-plan` ISO Week Key Is Computed Incorrectly — Can Produce Week 53 When Week 1 Is Expected

**File:** `supabase/functions/regenerate-plan/index.ts:36-43`

**Issue:** `getISOWeekKey` computes the week number as:
```ts
Math.ceil(((date - startOfYear) / 86400000 + startOfYear.getUTCDay() + 1) / 7)
```
This is a custom approximation, not ISO 8601 week numbering. ISO 8601 defines week 1 as the week containing the first Thursday. The formula here will produce incorrect results around year boundaries — e.g., December 29–31 of a year where those days fall in ISO week 1 of the next year will get the wrong key, potentially causing the weekly cache check to either miss or double-fire. By contrast, `AdaptationService.isoWeekString` on the iOS client correctly uses `Calendar(identifier: .iso8601)` with `.weekOfYear` and `.yearForWeekOfYear`. If the two implementations disagree on a boundary week, the cache key will never match, and the user gets a redundant regeneration call every Monday in that week.

**Fix:**
```typescript
function getISOWeekKey(date: Date): string {
  // Use Temporal or a reliable ISO week algorithm
  const thursday = new Date(date);
  thursday.setUTCDate(date.getUTCDate() - ((date.getUTCDay() + 6) % 7) + 3);
  const year = thursday.getUTCFullYear();
  const startOfYear = new Date(Date.UTC(year, 0, 1));
  const startOfYearThursday = new Date(startOfYear);
  startOfYearThursday.setUTCDate(1 + ((4 - startOfYear.getUTCDay() + 7) % 7));
  const weekNum = Math.round((thursday.getTime() - startOfYearThursday.getTime()) / 604800000) + 1;
  return `${year}-W${String(weekNum).padStart(2, "0")}`;
}
```

---

### WR-03: `adapt-plan` Injects User-Controlled `missed_sessions` Array Directly Into Prompt Without Validation

**File:** `supabase/functions/adapt-plan/index.ts:416` and `169-170`

**Issue:** `missedSessions` comes from `body.missed_sessions` — a user-controlled array of strings from the request body. These strings are joined with `", "` and embedded verbatim into the system prompt (`"Missed planned training days: ${missedSessions.join(", ")}"`) with no length cap on the array, no length cap per string, and no character sanitization. A caller can send `["Ignore all previous instructions and ..."]` as a missed session date and have it appear in the system prompt. The array is also unbounded — no limit on the number of elements means the user can balloon the prompt well past the 1400-token budget.

**Fix:**
```typescript
// Validate and sanitize missed_sessions before use
const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const safeMissedSessions = (body.missed_sessions ?? [])
  .slice(0, 7)                               // max 7 (one per day of week)
  .filter((s): s is string => typeof s === "string" && ISO_DATE_RE.test(s));
```

---

### WR-04: `MainTabView` Fetches All Session Logs With No Date Bound — Grows Unbounded

**File:** `WorkoutApp/Features/Main/MainTabView.swift:82-91`

**Issue:** The `CDSessionLog` fetch predicate in `runForegroundCheck` is `"completedAt != nil AND userId == %@"` with no date filter. This fetches the entire session history for the user to pass to `MissedSessionDetector`, which only cares about sessions in the current week. For a user who has been on the app for six months with three sessions per week, this loads ~75 CDSessionLog objects on every app foreground. `MissedSessionDetector` already filters to `weekInterval` internally, so the extra data is discarded — but the fetch, faulting, and memory cost grow with usage. More critically, when the `completedSessions` array is large, it is passed to `AdaptationService.checkOnForeground`, serialized to the Edge Function body, and could exceed reasonable request sizes.

**Fix:**
```swift
// Add a date bound to the fetch — only need sessions from the current week
let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
request.predicate = NSPredicate(
    format: "completedAt != nil AND userId == %@ AND completedAt >= %@",
    userId,
    weekStart as CVarArg
)
```

---

### WR-05: `SessionViewModel` Uses Deprecated `UIScreen.main.bounds.width`

**File:** `WorkoutApp/Features/Session/SessionView.swift:115`

**Issue:** `UIScreen.main.bounds.width` is deprecated in iOS 16+ and will return incorrect values on Stage Manager (iPad multitasking) and in future window-based layouts. The correct pattern for SwiftUI is to use a `GeometryReader` or `@Environment(\.horizontalSizeClass)` / `.containerRelativeFrame`. With deprecation warnings active in Xcode 16+, this will produce a compile-time warning that makes the deprecated API visible in CI logs and could break if Apple removes it.

**Fix:**
```swift
// In sessionContent(vm:), wrap the ZStack in a GeometryReader:
GeometryReader { geometry in
    ZStack {
        ForEach(Array(vm.exercises.enumerated()), id: \.offset) { index, exercise in
            ExerciseCardView(exercise: exercise, exerciseIndex: index, viewModel: vm)
                .offset(x: CGFloat(index - vm.currentExerciseIndex) * geometry.size.width)
        }
    }
}
```

---

### WR-06: `SessionViewModel.completeSet` Starts Rest Timer After Last Set of Non-Last Exercise — Timer Runs But No Next Set Exists

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:133-161`

**Issue:** The rest timer is triggered in the `else` branch: when `isLastSetOfCurrentExercise && isLastExercise` is false, a rest timer is started. This means the rest timer fires after the last set of a non-last exercise (e.g., finishing all sets of exercise 2 of 5). The user must manually call `advanceExercise()` by tapping "Next Exercise" to proceed — but `advanceExercise()` does not check whether a rest timer is active. If the user taps "Next Exercise" during the rest period, `isRestTimerActive` is set to false and `currentExerciseIndex` advances, but `timerEndDate` is cleared without canceling the scheduled `UNNotificationRequest`. The push notification for "Rest complete" will still fire, confusing the user who has already moved to the next exercise.

`advanceExercise()` should cancel the rest notification when the user skips ahead manually.

**Fix:**
```swift
func advanceExercise() {
    guard currentExerciseIndex < exercises.count - 1 else { return }
    isRestTimerActive = false
    timerEndDate = nil
    cancelRestNotification()   // add this — prevents stale "Rest complete" notification
    currentExerciseIndex += 1
}
```

---

## Info

### IN-01: `coach-chat` Uses `any` Types for `current_plan` and `pending_modification`

**File:** `supabase/functions/coach-chat/index.ts:66, 75`

**Issue:** `current_plan: any` and `pending_modification: any` bypass TypeScript's type system entirely. Since `planSchema` is already defined in `_shared/planSchema.ts`, these fields should be typed as `Record<string, unknown>` at minimum, or a typed interface matching the schema. The `any` types suppress type errors on downstream access (e.g., `JSON.stringify(payload.current_plan)` at line 99 — no type error if `current_plan` is undefined).

**Fix:** Type as `Record<string, unknown>` and add a null guard before `JSON.stringify(payload.current_plan)`.

---

### IN-02: `adapt-plan` Sort Comment Says "by volume" But Sorts by `average_completion_rate`

**File:** `supabase/functions/adapt-plan/index.ts:129-132`

**Issue:** The comment at line 129 says "Return top 5 by volume (number of logged sets)" but the `.sort()` at line 131 sorts by `average_completion_rate` descending, not by volume. The top 5 returned are the exercises with the highest completion rate, not the most frequently logged ones. This means low-volume exercises that happen to be completed at 100% will displace high-volume exercises with 90% completion from the trend context sent to the AI. The comment is misleading, and the intent (most frequently performed exercises) may differ from the implementation (best-completed exercises).

**Fix:** Either fix the sort to use set count (volume) as intended, or update the comment to match the actual behavior.

---

### IN-03: `SessionViewModel` Contains a Dead Private Method `requestNotificationPermission`

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:214-219`

**Issue:** `requestNotificationPermission()` is a private method that calls `UNUserNotificationCenter.current().requestAuthorization` with a completion handler. It is never called anywhere in the file — the actual permission request goes through `notificationScheduler.requestPermissionIfNeeded()` at line 150. This dead method uses the old completion-handler API (not async/await) and will never fire. It should be removed to avoid confusion.

---

### IN-04: `adaptedPlanSchema` JSON Schema Is Duplicated Inline in `adapt-plan/index.ts`

**File:** `supabase/functions/adapt-plan/index.ts:51-85`

**Issue:** A complete `adaptedPlanSchema` JSON Schema object is defined inline in `adapt-plan/index.ts` (lines 51–85) even though `_shared/adaptedPlanSchema.ts` exists and is imported for Zod validation. The `planSchema` in `_shared/planSchema.ts` is the established shared pattern. Having the JSON Schema inline means it can drift from the Zod schema in `_shared/adaptedPlanSchema.ts`, creating a situation where OpenAI generates output constrained by one schema but validated by a slightly different one. `regenerate-plan` correctly imports and reuses `planSchema` from shared.

---

_Reviewed: 2026-04-25T16:11:49Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
