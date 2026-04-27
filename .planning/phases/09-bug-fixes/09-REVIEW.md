---
phase: 09-bug-fixes
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - WorkoutApp/Core/AppState.swift
  - WorkoutApp/Features/Adaptation/AdaptationService.swift
  - WorkoutApp/Features/Adaptation/MissedSessionDetector.swift
  - WorkoutApp/Features/PlanPreview/PlanGenerationService.swift
  - WorkoutApp/Features/Progress/ProgressViewModel.swift
  - WorkoutAppTests/MissedSessionDetectorTests.swift
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-04-26T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Six files were reviewed covering the app's auth/subscription root state, adaptation pipeline (post-session, missed-session, weekly regen), plan generation service, progress metrics, and the missed-session detector unit tests. The code is generally well-structured with good inline comments. Several correctness issues were found, ranging from a critical missed-session mismatch bug introduced by the `isoDateString` wrapping logic to multiple unguarded state-mutation paths and a missing test.

---

## Critical Issues

### CR-01: `isoDateString` wraps same-day label to prior week, producing wrong dates sent to Edge Function

**File:** `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift:85-86`

**Issue:** The formula `daysBack = todayWeekday - targetWeekday` yields `0` when the missed day equals today's weekday (e.g., today is Monday and the planned Monday session is undetected by `detectMissedSessions` because `plannedWeekday < todayWeekday` is false). However `isoDateString` is called independently in `AdaptationService.checkOnForeground` on the list already returned by `detectMissedSessions`. The real problem is subtler: `daysBack <= 0` triggers `daysBack += 7`, so if `targetWeekday == todayWeekday` (daysBack = 0), the function wraps back 7 days and returns *last week's* date for that day label. If a caller ever passes a label that equals today's weekday, the Edge Function receives a date 7 days in the past and redistributes a session that was never actually missed this week. The guard `daysBack <= 0` should be `daysBack < 0` so that `daysBack == 0` (same-day) maps to today (0 days back), not 7 days back.

**Fix:**
```swift
// MissedSessionDetector.swift line 86
// Before:
if daysBack <= 0 { daysBack += 7 }

// After:
if daysBack < 0 { daysBack += 7 }
// daysBack == 0 means target == today: 0 days back == today's date, which is correct.
```

---

## Warnings

### WR-01: `AdaptationService.persistAdaptedPlan` saves a freshly-generated `UUID()` as the Supabase plan ID, breaking cross-system linkage

**File:** `WorkoutApp/Features/Adaptation/AdaptationService.swift:258`

**Issue:** `repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)` generates a random UUID locally. The adapted plan is not inserted into Supabase `workout_plans` — the Edge Function handles server-side storage — so the client-side CoreData record ends up with a phantom ID that can never be resolved back to a real Supabase row. Any downstream operation that uses `supabaseId` (e.g., plan deletion, session sync by planId) will silently fail to match the server record. The existing comment in `PlanGenerationService` (CR-03 note) explicitly warns against this pattern.

**Fix:** The `AdaptedPlanResponse` should carry the Supabase plan ID created by the Edge Function. Add an `id` (or `planSupabaseId`) field to `AdaptedPlanResponse`, return it from the Edge Function, and pass it to `repo.save`. Until the Edge Function is updated, at minimum log a clear warning:

```swift
// Temporary: use existing active plan's supabaseId if available
let supabaseId = existingPlan?.supabaseId ?? ""
// assert(!supabaseId.isEmpty, "adapted plan has no Supabase ID — cross-system linkage broken")
try repo.save(plan: updatedPlan, supabaseId: supabaseId, userId: userId)
```

---

### WR-02: `requestWeeklyRegeneration` does not persist or save the regenerated plan to CoreData

**File:** `WorkoutApp/Features/Adaptation/AdaptationService.swift:104-120`

**Issue:** `requestWeeklyRegeneration` calls `callEdgeFunction` and sets `lastAdjustmentSummary`, but unlike `requestPostSessionAdaptation` and `requestMissedSessionAdaptation`, it does not call `persistAdaptedPlan`. If the Edge Function returns a regenerated plan, it is never written to CoreData. The user's local plan stays stale; the TrainView will show the old plan indefinitely until the user manually triggers an action that reloads from CoreData.

**Fix:**
```swift
func requestWeeklyRegeneration() async {
    do {
        let accessToken = try await fetchAccessToken()
        let response = try await callEdgeFunction(
            path: "regenerate-plan",
            body: AdaptPlanRequest(triggerType: "weekly", currentRating: nil, missedSessions: nil),
            accessToken: accessToken
        )
        lastAdjustmentSummary = response.adjustmentSummary
        let userId = try await supabase.auth.session.user.id.uuidString
        await persistAdaptedPlan(response, userId: userId)   // <-- add this
        await scheduleReminders(for: response)               // <-- add this
    } catch {
        print("AdaptationService: weekly regeneration failed: \(error)")
    }
}
```

---

### WR-03: `ProgressViewModel.detectPRs` issues a separate `fetchUserSessionIds` query per exercise in a loop, and the prior-set predicate is missing the userId constraint at the SQL level

**File:** `WorkoutApp/Features/Progress/ProgressViewModel.swift:271-300`

**Issue:** Inside the `for (exerciseName, currentMax) in currentMaxByExercise` loop, `fetchUserSessionIds` is called on every iteration. This executes a full CoreData fetch for every unique exercise in the current session (potentially 5–10 fetches for a typical workout). More importantly, the `priorRequest` predicate at line 275 does not scope to userId at the CoreData fetch level — it fetches all matching exercise rows across all users and then filters in memory at line 285. If the local store accumulates data from multiple accounts (e.g., shared device), the in-memory filter is the only barrier, making it load-then-discard rather than filter-at-fetch. This is the pattern the comment at T-06-02 claims to address but does not fully implement.

**Fix:** Cache the userId session IDs before the loop, and add userId scoping to the priorRequest predicate via a subquery or relationship predicate:

```swift
// Fetch user session IDs once, outside the loop
let userSessionIds = try fetchUserSessionIds(userId: effectiveUserId)

for (exerciseName, currentMax) in currentMaxByExercise {
    let priorRequest = CDSetLog.fetchRequest()
    priorRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: "exerciseName == %@", exerciseName),
        NSPredicate(format: "sessionId != %@", (sessionLog.id ?? UUID()) as CVarArg),
        NSPredicate(format: "sessionId IN %@", userSessionIds)  // push filter to CoreData
    ])
    let priorSetLogs = try viewContext.fetch(priorRequest)
    // No in-memory filter needed — predicate handles it
    let priorMax = priorSetLogs.map { Int($0.repsLogged) }.max() ?? 0
    // ...
}
```

---

### WR-04: `MissedSessionDetector.detectMissedSessions` uses `Calendar.current` weekday boundaries but `AdaptationService.checkOnForeground` uses `.gregorian` calendar implicitly — calendar mismatch possible in non-Gregorian locales

**File:** `WorkoutApp/Features/Adaptation/AdaptationService.swift:135-136`

**Issue:** `checkOnForeground` passes `calendar: Calendar.current` to `detectMissedSessions` (correct), but the `weekday == 2` check on line 141 uses `calendar.component(.weekday, from: today)` where `calendar` is `Calendar.current`. In non-Gregorian locales (e.g., Islamic, Hebrew), `Calendar.current` may have a different weekday numbering. The day-label map in both `MissedSessionDetector` and `AdaptationService.scheduleReminders` hard-codes Gregorian weekday integers (Sunday=1 … Saturday=7). If the device locale uses a different calendar, `weekday == 2` for Monday may never be true.

**Fix:** Use an explicit Gregorian calendar for weekday comparisons that depend on day-label maps:

```swift
// AdaptationService.checkOnForeground
let calendar = Calendar(identifier: .gregorian)
let today = Date()
let weekday = calendar.component(.weekday, from: today)
// pass this calendar to detectMissedSessions and isoDateString
```

---

### WR-05: `PlanGenerationService.generatePlan` increments `regenCountUsed` in `regeneratePlan` before the network call succeeds — counter is consumed even on failure

**File:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift:163-167`

**Issue:** `regeneratePlan` calls `regenCountUsed += 1` synchronously before `generatePlan` is invoked. Since `generatePlan` can silently fail and retry (D-16 auto-retry), a network outage causes the counter to be consumed without the user ever seeing a regenerated plan. After 3 failed attempts the user hits the regeneration cap with nothing to show for it. The counter decrement cannot be undone because `@AppStorage` persists across app restarts.

**Fix:** Increment the counter only after a successful completion event, or decrement on confirmed failure after both retry attempts:

```swift
func regeneratePlan(profile: UserProfile) {
    guard canRegenerate else { return }
    // Optimistic increment with rollback on terminal failure
    regenCountUsed += 1
    generatePlan(profile: profile, isRetry: false, onTerminalFailure: {
        self.regenCountUsed -= 1  // restore if both attempts fail
    })
}
```

This requires threading a `onTerminalFailure` callback through `generatePlan`, or using a pending-increment flag checked after both retries resolve.

---

## Info

### IN-01: Test 5 is a stub — body is empty, only a comment remains

**File:** `WorkoutAppTests/MissedSessionDetectorTests.swift:145-147`

**Issue:** `// MARK: - Test 5: Ignores sessions from previous weeks` has no test function. The actual test for this scenario (`testIgnoresPreviousWeekSessions`) appears later at line 213, but the MARK comment implies it was meant to be placed here and the body was never filled in or the MARK was left stranded. This is harmless but misleading during test suite navigation.

**Fix:** Remove the orphaned MARK comment at line 145-147 or move `testIgnoresPreviousWeekSessions` to follow it in order.

---

### IN-02: `dayOfWeekMap` is duplicated verbatim in three locations

**File:** `WorkoutApp/Features/Adaptation/MissedSessionDetector.swift:46-54`, `WorkoutApp/Features/Adaptation/AdaptationService.swift:271-274`, `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift:123-126`

**Issue:** The same `[String: Int]` day-label-to-weekday dictionary is copy-pasted in three separate files. Any future change (e.g., adding locale aliases) must be applied in all three places.

**Fix:** Promote to a shared constant in a common location, e.g., `WorkoutApp/Core/WeekdayMap.swift`:

```swift
enum WeekdayMap {
    static let dayLabelToWeekday: [String: Int] = [
        "Sunday": 1, "Monday": 2, "Tuesday": 3,
        "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7
    ]
}
```

---

### IN-03: `refreshEntitlements` in `AppState` does not set `isSubscribed = true` in DEBUG builds, inconsistent with `logIn` handler

**File:** `WorkoutApp/Core/AppState.swift:118-121`

**Issue:** `refreshEntitlements()` calls `revenueCatService.refreshEntitlements()` and assigns the result directly without a `#if DEBUG` branch. The `logIn` path at lines 54-60 sets `isSubscribed = true` unconditionally in DEBUG. If `refreshEntitlements` is called on foreground resume in a DEBUG build and the mock service returns `false`, the paywall gate reopens unexpectedly during development/testing.

**Fix:** Apply the same DEBUG guard in `refreshEntitlements`:

```swift
func refreshEntitlements() async {
    #if DEBUG
    self.isSubscribed = true
    #else
    let subscribed = await revenueCatService.refreshEntitlements()
    self.isSubscribed = subscribed
    #endif
}
```

---

_Reviewed: 2026-04-26T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
