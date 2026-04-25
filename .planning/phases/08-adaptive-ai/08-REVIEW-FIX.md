---
phase: 08-adaptive-ai
fixed_at: 2026-04-25T16:30:00Z
review_path: .planning/phases/08-adaptive-ai/08-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 8: Code Review Fix Report

**Fixed at:** 2026-04-25T16:30:00Z
**Source review:** .planning/phases/08-adaptive-ai/08-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (2 Critical, 6 Warning)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: `coach-chat` Never Verifies the JWT — Any Bearer Token Is Accepted

**Files modified:** `supabase/functions/coach-chat/index.ts`
**Commit:** 1c1ce62
**Applied fix:** Added `import { createClient }` from the Supabase JS SDK and inserted a `anonClient.auth.getUser(token)` call immediately after the Bearer header check. Returns 401 with `"Unauthorized: invalid or expired token"` if the JWT is invalid or expired. Matches the pattern already used in `adapt-plan` and `regenerate-plan`.

---

### CR-02: Race Condition — `completeSet` Can Finalize Session Before `sessionLog` Is Set

**Files modified:** `WorkoutApp/Features/Session/SessionViewModel.swift`, `WorkoutApp/Features/Session/SessionView.swift`
**Commit:** 1c0c109
**Applied fix:** Changed `startSession()` from a synchronous method that spawned an internal `Task { }` to an `async` function that directly `await`s the CoreData write. Updated `SessionView.setupSession()` to call `await vm.startSession()` before assigning `viewModel = vm`, ensuring `sessionLog` is set before the session UI appears and `completeSet` can be called.

---

### WR-01: `coach-chat` `execute_modify` Path Returns Raw JSON String Instead of Parsed Object

**Files modified:** `supabase/functions/coach-chat/index.ts`
**Commit:** 0b834a4
**Applied fix:** Replaced the single-line `const updatedPlan = modifyResult.choices?.[0]?.message?.content` assignment with a null-check guard and a `JSON.parse()` call (with try/catch returning 500 on failure). The parsed object — not the raw string — is now placed into `plan_delta`, eliminating the double-encoding. Also added a guard for empty content from OpenAI.

---

### WR-02: `regenerate-plan` ISO Week Key Is Computed Incorrectly

**Files modified:** `supabase/functions/regenerate-plan/index.ts`
**Commit:** c7b1726
**Applied fix:** Replaced the custom approximation formula with a correct ISO 8601 algorithm: finds the Thursday of the input week, uses that Thursday's year as the ISO year, locates the first ISO week's Thursday for that year, then computes the week number via integer division of the millisecond difference by 604800000. This produces correct keys at year boundaries (e.g., Dec 29–31 that belong to ISO week 1 of the following year) and matches the iOS-side `Calendar(identifier: .iso8601)` implementation.

---

### WR-03: `adapt-plan` Injects User-Controlled `missed_sessions` Array Directly Into Prompt Without Validation

**Files modified:** `supabase/functions/adapt-plan/index.ts`
**Commit:** 3f709a8
**Applied fix:** Added ISO date validation regex (`/^\d{4}-\d{2}-\d{2}$/`) and filter pipeline before `missedSessions` is used. The array is sliced to a maximum of 7 entries (one per day of the week) and each element is tested against the regex — only strings matching `YYYY-MM-DD` pass. Arbitrary strings including prompt injection payloads are silently dropped.

---

### WR-04: `MainTabView` Fetches All Session Logs With No Date Bound — Grows Unbounded

**Files modified:** `WorkoutApp/Features/Main/MainTabView.swift`
**Commit:** ddf0741
**Applied fix:** Added `weekStart` computed via `Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start` and appended `AND completedAt >= %@` to the NSPredicate. This restricts the CoreData fetch to the current calendar week, matching what `MissedSessionDetector` actually needs and preventing the fetch and serialization cost from growing with session history.

---

### WR-05: `SessionViewModel` Uses Deprecated `UIScreen.main.bounds.width`

**Files modified:** `WorkoutApp/Features/Session/SessionView.swift`
**Commit:** 19ea7be
**Applied fix:** Wrapped the exercise card ZStack in a `GeometryReader { geometry in ... }` block. The `.offset(x:)` modifier now uses `geometry.size.width` instead of `UIScreen.main.bounds.width`. The `.animation` and inner `.frame` modifiers remain on the ZStack inside the reader; an outer `.frame(maxWidth: .infinity, maxHeight: .infinity)` is applied to the GeometryReader to preserve layout behavior.

---

### WR-06: `SessionViewModel.completeSet` Starts Rest Timer After Last Set of Non-Last Exercise — Stale Notification

**Files modified:** `WorkoutApp/Features/Session/SessionViewModel.swift`
**Commit:** d1a54a8
**Applied fix:** Added `cancelRestNotification()` call to `advanceExercise()`, between clearing `timerEndDate` and incrementing `currentExerciseIndex`. This cancels the pending `UNNotificationRequest` for the current rest period when the user taps "Next Exercise" during a rest, preventing the stale "Rest complete" push notification from firing after the user has already moved on.

---

_Fixed: 2026-04-25T16:30:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
