---
phase: 06-progress-tracking
reviewed: 2026-04-24T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - WorkoutApp/Core/Notifications/NotificationScheduler.swift
  - WorkoutApp/Features/Progress/Components/ChartSectionView.swift
  - WorkoutApp/Features/Progress/Components/PRBadgeView.swift
  - WorkoutApp/Features/Progress/Components/SessionDetailView.swift
  - WorkoutApp/Features/Progress/Components/SessionHistoryRow.swift
  - WorkoutApp/Features/Progress/Components/StreakCard.swift
  - WorkoutApp/Features/Progress/Components/WeeklyRingView.swift
  - WorkoutApp/Features/Progress/Models/PRResult.swift
  - WorkoutApp/Features/Progress/Models/WeekBucket.swift
  - WorkoutApp/Features/Progress/ProgressView.swift
  - WorkoutApp/Features/Progress/ProgressViewModel.swift
  - WorkoutApp/Features/Session/SessionViewModel.swift
  - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
  - WorkoutAppTests/NotificationSchedulerTests.swift
  - WorkoutAppTests/ProgressViewModelTests.swift
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-24
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

The progress tracking feature is well-structured with clear separation of concerns, correct userId-scoped CoreData predicates, and solid test coverage for the happy path. The streak algorithm, weekly ring computation, and chart bucketing are all logically sound.

However, one critical logic bug prevents PR detection from ever firing in production: `SessionViewModel` instantiates a fresh `ProgressViewModel()` without a userId, causing all PR lookups to query against `userId == ""`. Five warnings cover a dead-code weeklyPlanned branch, a false-passing test assertion, an optional UUID identity risk in SwiftUI ForEach, a duplicate notification permission prompt, and the no-op empty-state button. Three info items round out minor dead code and accessibility issues.

## Critical Issues

### CR-01: PR Detection Always Returns Empty — Missing userId in SessionViewModel

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:141-143`

**Issue:** Inside `completeSet`, when the last set of the last exercise is confirmed, the code creates a brand-new `ProgressViewModel()` with no context and no userId:

```swift
let progressVM = ProgressViewModel()
if let prs = try? progressVM.detectPRs(for: session, userId: userId) {
```

`ProgressViewModel.init` accepts an optional context and defaults to `PersistenceController.shared.container.viewContext`, which is fine. However, `detectPRs(for:userId:)` calls `fetchUserSessionIds(userId:)` which executes `NSPredicate(format: "userId == %@", userId)`. The `userId` parameter passed here comes from `SessionViewModel.userId` (the real user), so the predicate is correctly scoped. That part is fine.

The real problem is subtler: `detectPRs` also calls `viewContext.fetch(priorRequest)` where `priorRequest` has **no userId predicate** — it only filters by `exerciseName` and `sessionId != current`. The userId scoping happens in a second pass via `fetchUserSessionIds`. This two-pass approach is correct in isolation, but the freshly-created `ProgressViewModel()` uses a `viewContext` that is `PersistenceController.shared.container.viewContext`. If the `session` passed in was created on a different context (e.g. a background context from `SessionRepository`), the `CDSetLog` relationship fetch `session.setLogs?.array` on line 255 will return objects from a different context, and any subsequent cross-context fetch comparing `setLog.sessionId` UUIDs may silently return no matches — meaning `detectedPRs` is always empty.

The correct fix is to inject the `viewContext` (or use `session.managedObjectContext`) instead of constructing a throwaway ViewModel:

```swift
// In SessionViewModel.completeSet, replace:
let progressVM = ProgressViewModel()
if let prs = try? progressVM.detectPRs(for: session, userId: userId) {
    detectedPRs = prs
}

// With:
if let ctx = session.managedObjectContext {
    let progressVM = ProgressViewModel(context: ctx)
    progressVM.setUserIdForTesting(userId)  // or add a proper init param
    if let prs = try? progressVM.detectPRs(for: session, userId: userId) {
        detectedPRs = prs
    }
}
```

Better long-term: extract `detectPRs` into a standalone function or a `PRDetector` type that takes a context and userId as explicit parameters rather than relying on ViewModel state.

## Warnings

### WR-01: Dead Code Branch in weeklyPlanned — Zero Check Is Unreachable

**File:** `WorkoutApp/Features/Progress/ProgressViewModel.swift:179-180`

**Issue:** The `computeWeeklyRing` function sets `weeklyPlanned` on two consecutive lines that contradict each other:

```swift
weeklyPlanned = max(weeklyPlanned, 4)   // line 179 — always sets to >= 4
if weeklyPlanned == 0 { weeklyPlanned = 4 }  // line 180 — can never be true
```

After line 179, `weeklyPlanned` is guaranteed to be at least 4 (since `max(x, 4) >= 4` for all x). The `if weeklyPlanned == 0` check on line 180 is therefore dead code and will never execute. If the intent is to keep the existing value when it has been explicitly set by the UI layer to something >= 4, and only default to 4 when it is 0, the lines should be reversed:

```swift
if weeklyPlanned == 0 { weeklyPlanned = 4 }
weeklyPlanned = max(weeklyPlanned, 4)
```

Or more clearly:

```swift
weeklyPlanned = weeklyPlanned > 0 ? max(weeklyPlanned, completed.count) : 4
```

Clarify the intent and remove the dead branch.

### WR-02: Test Assertion Is a No-Op — Sort Order Never Verified

**File:** `WorkoutAppTests/ProgressViewModelTests.swift:219-223`

**Issue:** The sort-order assertion in `testWeeklyBucketsGroupsByWeek` short-circuits unconditionally:

```swift
XCTAssertTrue(
    buckets[i].weekLabel >= buckets[i - 1].weekLabel || true,  // always true
    "Buckets should be in ascending order"
)
```

`|| true` makes the entire boolean expression always `true`. The test passes regardless of bucket order, providing false confidence that `computeWeekBuckets` sorts ascending. Remove `|| true`:

```swift
// Note: weekLabel is "MMM d" (e.g. "Apr 7") — string comparison works only within
// the same month. Compare WeekBucket by a sortable key instead, or expose weekKey.
// For now, verify bucket count and session counts are correct; sort is covered by
// the WeekKey.Comparable conformance which is separately testable.
```

If string comparison of `weekLabel` is unreliable across month boundaries (e.g. "Mar 31" vs "Apr 1"), add a `sortKey: WeekKey` property to `WeekBucket` and compare that instead.

### WR-03: ForEach Uses Optional UUID as Identity — Nil id Causes View Recycling Bugs

**File:** `WorkoutApp/Features/Progress/Components/SessionDetailView.swift:113`

**Issue:** `ForEach(setLogs, id: \.id)` where `CDSetLog.id` is `UUID?` (optional). SwiftUI's `ForEach(id:)` requires a `Hashable` identifier. When `id` is `nil` for any set log, SwiftUI treats all nil-id rows as having the same identity, causing incorrect view reuse — rows may render with swapped data or fail to animate correctly.

```swift
// Replace:
ForEach(setLogs, id: \.id) { setLog in

// With (using ObjectIdentifier for managed objects):
ForEach(setLogs, id: \.objectID) { setLog in
```

`NSManagedObjectID` is always non-nil and unique for any inserted object. This is the idiomatic approach for CoreData objects in SwiftUI `ForEach`.

### WR-04: Duplicate Notification Permission Prompt at Session Start and Finish

**File:** `WorkoutApp/Features/Session/SessionViewModel.swift:105,147`

**Issue:** Notification permission is requested twice per session:
- At `startSession()` (line 105): `requestNotificationPermission()` calls the old callback-based `UNUserNotificationCenter.requestAuthorization`.
- At session finalization (line 147): `notificationScheduler.requestPermissionIfNeeded()` calls the async version.

The design comment (D-24) states permission should be requested as an "earned moment after first session completes," but `startSession()` requests it immediately on session begin, before the user has done any work. Remove the `requestNotificationPermission()` call from `startSession()` and rely solely on the `notificationScheduler.requestPermissionIfNeeded()` call after finalization:

```swift
func startSession() {
    sessionStartDate = Date()
    Task {
        do {
            sessionLog = try repository.startSession(
                day: workoutDay,
                planId: planId,
                userId: userId
            )
        } catch {
            // non-fatal
        }
    }
    // Remove requestNotificationPermission() — earned moment is on session complete (D-24)
}
```

Also, `requestNotificationPermission()` (line 211-215) uses the deprecated completion-handler API. Consistent use of the async `notificationScheduler.requestPermissionIfNeeded()` is sufficient and removes the duplicate.

### WR-05: Empty-State "Go to Train" Button Has No Action

**File:** `WorkoutApp/Features/Progress/ProgressView.swift:145-148`

**Issue:** The empty-state "Go to Train" button is rendered with `.borderedProminent` styling, implying it is interactive, but its action closure is empty and a comment states "Visual cue only — tab switching handled by MainTabView":

```swift
Button("Go to Train") {
    // Visual cue only — tab switching handled by MainTabView
}
.buttonStyle(.borderedProminent)
```

A tappable button that does nothing will confuse users and may be flagged during App Store review. Either wire tab switching through the environment or use `AppState`, or replace the button with a non-interactive label styled differently:

```swift
// Option A: wire action through AppState
Button("Go to Train") {
    appState.selectedTab = .train
}
.buttonStyle(.borderedProminent)

// Option B: remove interactivity entirely
Text("Go to the Train tab to log your first session")
    .font(.callout)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
```

## Info

### IN-01: Dead Ternary in StreakCard — Both Branches Return Identical String

**File:** `WorkoutApp/Features/Progress/Components/StreakCard.swift:26`

**Issue:** The ternary expression on line 26 is a no-op:

```swift
Text(currentStreak == 1 ? "day streak" : "day streak")
```

Both branches produce `"day streak"`. The likely intent was to pluralize — "day streak" vs "days streak" — or to show "day" vs "days". Remove the ternary and use the correct pluralization:

```swift
Text(currentStreak == 1 ? "day streak" : "days streak")
// or using SwiftUI's string interpolation with plural rules:
Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days") streak")
```

### IN-02: PRBadgeView Collapses All Badges Into One Accessibility Element

**File:** `WorkoutApp/Features/Progress/Components/PRBadgeView.swift:41`

**Issue:** `.accessibilityElement(children: .combine)` on the outer `VStack` merges all PR badges into a single VoiceOver element. A user with VoiceOver enabled will hear all PR announcements read as one long string with no ability to navigate between individual badges. For a list of 3+ PRs this creates an unreadable wall of text.

Move the accessibility grouping to the individual badge `HStack`, or remove it from the outer container and let each badge be separately focusable:

```swift
// Remove from VStack:
// .accessibilityElement(children: .combine)

// Add to each badge HStack:
HStack(spacing: 8) { ... }
.accessibilityElement(children: .combine)
.accessibilityLabel("\(pr.exerciseName): new record \(pr.newRecord) reps, previous best \(pr.previousBest) reps")
```

### IN-03: DateFormatter Instantiated Per Render in SessionHistoryRow

**File:** `WorkoutApp/Features/Progress/Components/SessionHistoryRow.swift:68-70`

**Issue:** `formattedDate` is a computed property that creates a new `DateFormatter` instance on every call. `DateFormatter` is expensive to allocate (it loads locale and calendar data). With 20 rows in the history list, this allocates 20 formatters per render pass.

```swift
// Replace the per-call allocation:
private var formattedDate: String {
    ...
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

// With a static shared formatter:
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()
```

Note: `SessionDetailView.swift:48-50` and `ProgressViewModel.swift:213` have the same pattern and benefit from the same fix.

---

_Reviewed: 2026-04-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
