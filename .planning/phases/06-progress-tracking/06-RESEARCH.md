# Phase 6: Progress Tracking - Research

**Researched:** 2026-04-23
**Domain:** SwiftUI progress display, Apple Swift Charts, CoreData aggregation queries, UNUserNotificationCenter local scheduling
**Confidence:** HIGH

## Summary

Phase 6 adds a fifth tab (Progress) to the existing 4-tab MainTabView. All decisions are locked in CONTEXT.md — the implementation uses Apple Swift Charts (iOS 16+, no dependencies), CoreData queries against the existing CDSessionLog/CDSetLog schema, and UNUserNotificationCenter local notifications only. No new backend work, no new CoreData model migrations, no third-party libraries.

The primary data source is `CDSessionLog` (with its `setLogs` ordered relationship to `CDSetLog`), which already exists in `Core/Data/WorkoutApp.xcdatamodeld` and is being written by `SessionRepository` in Phase 4. The streak, weekly ring, PR detection, and chart data all derive from this single data store. The only new capability requiring careful handling is local notification scheduling — specifically rescheduling when the user's workout plan changes and the "no-op if already logged today" guard.

The CoreData model does NOT need a migration for Phase 6. The existing CDSessionLog schema provides all fields needed: `completedAt` (date), `workoutDayLabel` (for notifications), `totalExercises`, `totalSets`, `totalReps`. PR detection queries CDSetLog's `repsLogged` and `exerciseName` fields — both already present.

**Primary recommendation:** Implement ProgressViewModel as an `@Observable @MainActor` class that loads all CDSessionLog records on appear and derives streak, weekly ring, chart data, and PRs in pure Swift — no new CoreData entities, no model migration, no Supabase calls.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Tab Placement**
- D-01: New 5th tab added to MainTabView: Home — Train — Coach — Progress — Profile
- D-02: Progress tab uses `chart.bar.fill` SF Symbol
- D-03: ProgressView is the root view for the Progress tab; owns streak, history, charts, and PR display

**Primary Progress View**
- D-04: Top section: current streak (consecutive days with a logged session) + weekly completion ring ("3/4 done this week")
- D-05: Below streak: scrollable chronological session history list — date, workout name, exercise count, set count
- D-06: Tapping a session row expands or navigates to a session detail view (exercises, sets, reps logged)
- D-07: Streak number should be visually prominent — it's the primary motivational hook for consistency

**Charts (PROG-04)**
- D-08: Two charts included in Phase 6: sessions/week bar chart + total volume (sets x reps) over time line chart
- D-09: Implementation: Apple Swift Charts framework (iOS 16+, native, no dependencies)
- D-10: Charts appear below the session history section on the Progress tab
- D-11: Default time range for charts: last 8 weeks

**Personal Records**
- D-12: PR detection runs at session completion: compare each exercise's max reps logged in a single set against all prior sessions
- D-13: PR = most reps completed for an exercise in a single set (reps only, no weight tracking in v1)
- D-14: PRs displayed as inline badge on the session completion summary screen (Phase 4 SessionSummaryView, extended here)
- D-15: PR badge shows exercise name, new record, and previous best
- D-16: No animated overlay or in-session celebration — understated, matches non-gamified tone
- D-17: No dedicated PR history screen in v1 — PRs surface at the moment they happen
- D-18: PR data stored in CoreData as derived value (recalculate from session logs, or store max per exercise)

**Re-engagement Notifications**
- D-19: Local notifications only — no server push, no APNs certificates required
- D-20: Scheduled via `UNUserNotificationCenter` based on user's workout plan schedule (days of week)
- D-21: Fires at 7pm on each planned workout day if no session has been logged that day
- D-22: Copy is plan-aware + motivational: references the specific workout type ("Ready for your Push day? Your plan is waiting.")
- D-23: When streak >= 3 days, append streak info: "Push day is waiting — you're on a 5-day streak!"
- D-24: Notification permission requested once, after first session is completed (earned moment)
- D-25: No notification if session already logged that day (checked via CoreData query)

### Claude's Discretion
- Exact streak calculation logic (calendar day vs 24-hour window)
- Weekly ring implementation (SwiftUI shape or custom drawing)
- Session history row design details
- PR storage strategy (derived vs stored max in CoreData)
- Notification copy variants per workout type
- Chart styling, colors, and axis formatting
- Chart interaction (tap for detail vs static display)

### Deferred Ideas (OUT OF SCOPE)
- Per-exercise performance trend charts
- Muscle group heatmap (body diagram)
- Server-push notifications for lapsed users (Phase 8)
- Workout history export (CSV, Apple Health)
- Weight tracking per set + weight-based PRs
- Animated PR celebration overlay during session
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROG-01 | User can view a full history of all completed workout sessions | CDSessionLog fetch sorted by `completedAt DESC`, predicate `completedAt != nil`, SessionHistoryRow in ScrollView |
| PROG-02 | User can see current streak and longest streak, plus weekly consistency score | Calendar-day streak algorithm over sorted CDSessionLog dates; weekly ring = completedSessions / plannedDays this calendar week |
| PROG-03 | User is notified when they set a new personal record on an exercise | PR detection: compare max repsLogged per exercise in new session against all prior CDSetLog records for that exercise; inject PRBadgeView into SessionSummaryView |
| PROG-04 | User can view charts showing volume over time, workouts per week, and performance trends | Apple Swift Charts — BarMark for sessions/week, LineMark+AreaMark for volume over 8-week window |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Session history display | iOS Client (SwiftUI) | CoreData (local) | All data local; NSFetchRequest fetches CDSessionLog sorted by date |
| Streak calculation | iOS Client (ViewModel) | — | Pure Swift computation over fetched CDSessionLog array; no server needed |
| Weekly completion ring | iOS Client (SwiftUI) | — | Custom SwiftUI `Circle.trim` shape; data from ViewModel |
| PR detection | iOS Client (ViewModel) | CoreData (local) | Comparison at session-complete time; queries CDSetLog history for exercise name |
| Chart data aggregation | iOS Client (ViewModel) | — | Group CDSessionLog by calendar week; sum volume (totalSets × totalReps) |
| Local notification scheduling | iOS Client (NotificationScheduler) | — | UNUserNotificationCenter only; no APNs, no backend |
| Tab bar addition | iOS Client (SwiftUI) | — | Modify MainTabView.swift to add 5th TabItem |
| PR badge display | iOS Client (SwiftUI) | — | Inject PRBadgeView below existing stats in SessionSummaryView |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Apple Swift Charts | iOS 16+ (built-in) | BarMark sessions/week, LineMark+AreaMark volume trend | Native Apple framework, zero dependencies, locked decision D-09 |
| UserNotifications (UNUserNotificationCenter) | iOS 10+ (built-in) | Local notification scheduling for re-engagement | Native framework, locked decision D-19/D-20 |
| CoreData (NSFetchRequest) | iOS 14+ (built-in) | Query CDSessionLog and CDSetLog for all progress features | Already in use across Phases 2-5; existing PersistenceController |
| SwiftUI (@Observable, NavigationStack) | iOS 17+ | ProgressView, StreakCard, WeeklyRingView, ChartSectionView | Project standard from CLAUDE.md |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation (Calendar, DateComponents) | Built-in | Streak day boundary calculation, week bucketing for charts, notification DateComponents | Always — calendar arithmetic for streak and weekly ring |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Apple Swift Charts | Charts by Daniel Gindi | Third-party; more styling flexibility but adds dependency, conflicts with D-09 |
| UNCalendarNotificationTrigger repeating | Background App Refresh + check at launch | BGAppRefresh unreliable on iOS 16+ power management; local trigger is simpler and reliable for daily at-7pm |

**Installation:** No new packages. All required frameworks are Apple built-ins already linked.

**Version verification:** Swift Charts ships with Xcode and iOS SDK — no registry version to pin. [VERIFIED: Apple Developer Documentation, developer.apple.com/documentation/Charts]

---

## Architecture Patterns

### System Architecture Diagram

```
CDSessionLog / CDSetLog (CoreData local store)
           |
           v
    ProgressViewModel (@Observable @MainActor)
    ├── fetchAllSessions()           → [CDSessionLog]
    ├── computeStreak()              → Int (current), Int (longest)
    ├── computeWeeklyRing()          → (completed: Int, planned: Int)
    ├── computeChartData()           → [WeekBucket] (sessions + volume)
    └── detectPRs(for session)       → [PRResult]
           |
    ┌──────┴────────────────────────────────────┐
    |                                           |
    v                                           v
ProgressView (new tab)              SessionSummaryView (Phase 4, extended)
├── StreakCard                       └── PRBadgeView (injected if PRs detected)
├── WeeklyRingView
├── SessionHistoryList
│   └── SessionHistoryRow (tap → SessionDetailView)
└── ChartSectionView (x2)
    ├── BarChart (sessions/week)
    └── LineChart (volume trend)

NotificationScheduler (new service)
├── scheduleWorkoutReminders(plan:, currentStreak:)
├── cancelAllWorkoutReminders()
└── hasLoggedSessionToday() → Bool (CoreData check)

Trigger points for NotificationScheduler:
- After first session completes (permission request)
- When active plan changes (reschedule)
- On app foreground (re-evaluate if needed)
```

### Recommended Project Structure

```
WorkoutApp/Features/Progress/
├── ProgressView.swift              # Root tab view, NavigationStack
├── ProgressViewModel.swift         # @Observable; streak, history, chart, PR logic
├── Components/
│   ├── StreakCard.swift            # HStack of streak number + WeeklyRingView
│   ├── WeeklyRingView.swift        # Circle.trim custom ring, 120pt fixed
│   ├── SessionHistoryRow.swift     # NavigationLink row, 44pt min height
│   ├── SessionDetailView.swift     # Pushed from row; lists exercises/sets/reps
│   ├── ChartSectionView.swift      # Container card for each chart
│   └── PRBadgeView.swift           # Injected into SessionSummaryView
WorkoutApp/Core/Notifications/
└── NotificationScheduler.swift     # UNUserNotificationCenter wrapper
```

Changes to existing files:
- `MainTabView.swift` — add 5th TabItem for ProgressView between Coach and Profile
- `Session/Components/SessionSummaryView.swift` — inject PRBadgeView after stats block when PRs detected

### Pattern 1: Swift Charts — BarMark (Sessions/Week)

**What:** Native Apple Charts framework bar chart bucketed by calendar week.
**When to use:** Sessions/week chart per D-08.

```swift
// Source: mvolkmann.github.io/blog/swift/SwiftCharts + createwithswift.com
import Charts
import SwiftUI

struct SessionsBarChart: View {
    let weekBuckets: [WeekBucket]  // (weekLabel: String, sessionCount: Int)

    var body: some View {
        Chart(weekBuckets) { bucket in
            BarMark(
                x: .value("Week", bucket.weekLabel),
                y: .value("Sessions", bucket.sessionCount)
            )
            .foregroundStyle(.secondary)
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption)
            }
        }
    }
}
```

### Pattern 2: Swift Charts — LineMark + AreaMark (Volume Trend)

**What:** Line chart with filled area underneath for volume trend over 8 weeks.
**When to use:** Volume over time chart per D-08.

```swift
// Source: createwithswift.com/customizing-a-chart-in-swift-charts + mvolkmann.github.io
import Charts
import SwiftUI

struct VolumeTrendChart: View {
    let weekBuckets: [WeekBucket]  // (weekLabel: String, volume: Int)

    var body: some View {
        Chart(weekBuckets) { bucket in
            LineMark(
                x: .value("Week", bucket.weekLabel),
                y: .value("Volume", bucket.volume)
            )
            .foregroundStyle(Color("AccentColor").opacity(0.7))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Week", bucket.weekLabel),
                y: .value("Volume", bucket.volume)
            )
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color("AccentColor").opacity(0.2),
                        Color("AccentColor").opacity(0.02)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel().font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel().font(.caption)
            }
        }
    }
}
```

### Pattern 3: WeeklyRingView (Custom SwiftUI Shape)

**What:** Custom Circle.trim progress ring — 120pt diameter, 10pt stroke.
**When to use:** Weekly completion ring per D-04. No third-party library needed.

```swift
// Source: SwiftUI Circle.trim — established pattern, ASSUMED
struct WeeklyRingView: View {
    let completed: Int
    let planned: Int

    private var progress: CGFloat {
        guard planned > 0 else { return 0 }
        return min(CGFloat(completed) / CGFloat(planned), 1.0)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 10)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color("AccentColor"), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("\(completed)/\(planned)")
                    .font(.title2).fontWeight(.semibold)
                Text("this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityLabel("Weekly completion: \(completed) of \(planned) sessions done")
    }
}
```

### Pattern 4: Streak Calculation (Calendar Day Boundary)

**What:** Count consecutive calendar days (midnight boundary) where `completedAt != nil`.
**When to use:** Computing current streak and longest streak per D-04.
**Recommendation for Claude's Discretion:** Use calendar day (not 24-hour window). A user completing a workout at 11pm and then at 1am next day SHOULD count as consecutive — calendar date is the user-facing concept.

```swift
// Source: [ASSUMED] — standard calendar-boundary streak pattern
func computeStreak(from sessions: [CDSessionLog]) -> (current: Int, longest: Int) {
    let calendar = Calendar.current
    // Extract unique calendar dates where a session completed
    let completedDates = sessions
        .compactMap { $0.completedAt }
        .map { calendar.startOfDay(for: $0) }
    let uniqueDates = Set(completedDates).sorted(by: >)  // descending

    var current = 0
    var longest = 0
    var streak = 0
    var previous: Date? = nil

    for date in uniqueDates {
        if let prev = previous {
            let diff = calendar.dateComponents([.day], from: date, to: prev).day ?? 0
            if diff == 1 {
                streak += 1
            } else {
                longest = max(longest, streak)
                streak = 1
            }
        } else {
            // Check if today or yesterday has a session (otherwise streak is 0)
            let today = calendar.startOfDay(for: Date())
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            streak = (date == today || date == yesterday) ? 1 : 0
        }
        previous = date
    }
    longest = max(longest, streak)
    current = streak  // streak was computed descending so it IS current
    return (current, longest)
}
```

### Pattern 5: UNCalendarNotificationTrigger — Workout Reminder

**What:** Schedule a repeating weekly notification per workout day at 7pm, cancelled if session already logged.
**When to use:** Re-engagement notifications per D-20/D-21.

```swift
// Source: donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/
import UserNotifications

func scheduleWorkoutReminder(
    weekday: Int,          // 1=Sunday, 2=Monday... (Calendar.Component.weekday)
    workoutType: String,   // e.g. "Push day"
    currentStreak: Int,
    identifier: String     // unique per weekday to allow cancel/replace
) async throws {
    var components = DateComponents()
    components.weekday = weekday
    components.hour = 19  // 7pm
    components.minute = 0
    components.timeZone = TimeZone.current  // CRITICAL: without this, defaults to GMT

    let content = UNMutableNotificationContent()
    content.sound = .default
    if currentStreak >= 3 {
        content.title = "\(workoutType) is waiting"
        content.body = "You're on a \(currentStreak)-day streak — keep it going!"
    } else {
        content.title = "Ready for your \(workoutType)?"
        content.body = "Your plan is waiting."
    }

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    try await UNUserNotificationCenter.current().add(request)
}
```

### Pattern 6: PR Detection at Session Completion

**What:** After `finalizeSession()`, query historical CDSetLog records to find max repsLogged per exercise. Compare against current session's set logs.
**When to use:** PR detection per D-12/D-13.

```swift
// Source: [ASSUMED] — standard CoreData NSFetchRequest pattern
func detectPRs(
    for sessionLog: CDSessionLog,
    context: NSManagedObjectContext
) throws -> [PRResult] {
    let currentSets = (sessionLog.setLogs?.array as? [CDSetLog]) ?? []

    // Group current session's max reps by exercise name
    var currentMaxByExercise: [String: Int] = [:]
    for set in currentSets {
        let name = set.exerciseName ?? ""
        let reps = Int(set.repsLogged)
        currentMaxByExercise[name] = max(currentMaxByExercise[name] ?? 0, reps)
    }

    var prs: [PRResult] = []
    for (exerciseName, currentMax) in currentMaxByExercise {
        // Fetch all PRIOR set logs for this exercise (exclude current session)
        let req = CDSetLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "exerciseName == %@ AND sessionId != %@",
            exerciseName,
            sessionLog.id! as CVarArg
        )
        let priorSets = try context.fetch(req)
        let previousMax = priorSets.map { Int($0.repsLogged) }.max() ?? 0

        if currentMax > previousMax {
            prs.append(PRResult(
                exerciseName: exerciseName,
                newRecord: currentMax,
                previousBest: previousMax
            ))
        }
    }
    return prs
}
```

### Anti-Patterns to Avoid

- **Fetching CDSetLog for chart data:** Volume chart data should aggregate from `CDSessionLog.totalSets * totalReps` (already computed at finalize), not re-scan all CDSetLog records. The repository already populates `totalSets` and `totalReps` in `finalizeSession()`.
- **Using @FetchRequest property wrapper in ProgressViewModel:** The ViewModel is `@Observable`, not a SwiftUI View. Use `NSFetchRequest` directly in the ViewModel's async methods and store results in `@Observable` properties.
- **Scheduling notifications without checking today's session:** Always guard with a CoreData check for today's date before scheduling, or build the check into the notification content extension. Per D-25, no notification if session already logged today.
- **Using a 24-hour rolling window for streaks:** Users expect calendar-day streaks, not rolling-24h. A workout at 11:50pm and one at 12:10am the next day should count as consecutive.
- **Re-requesting notification permission every session:** Permission is requested once after first session completes (D-24). The SessionViewModel already calls `requestNotificationPermission()` in `startSession()` — this is the wrong moment (before session completes). Phase 6 moves the earned-moment permission request to after `finalizeSession()`.
- **Two xcdatamodel files — wrong model used:** The project has two `WorkoutApp.xcdatamodeld` directories (`Core/CoreData/` and `Core/Data/`). Only `Core/Data/WorkoutApp.xcdatamodeld` has `CDSessionLog` and `CDSetLog`. The PersistenceController in `Core/Data/` loads from the correct model. Do not add entities to the stale `Core/CoreData/` copy.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bar/line charts | Custom Canvas drawing with CGPath | Apple Swift Charts | Chart handles axis scaling, label placement, dark mode, accessibility, Dynamic Type automatically |
| Weekly progress ring | Third-party ring component | SwiftUI `Circle().trim()` | Native SwiftUI shape; 8 lines of code; no dependency |
| Notification permission UI | Custom permission flow | `UNUserNotificationCenter.requestAuthorization()` | System alert is mandatory; custom pre-prompt can appear before it |
| Calendar week bucketing | Custom date arithmetic | `Calendar.current.component(.weekOfYear, from:)` | Foundation Calendar handles DST, locale, leap years correctly |
| Volume calculation | Store separate volume entity | `CDSessionLog.totalSets * CDSessionLog.totalReps` | Already computed and persisted by `SessionRepository.finalizeSession()` |

**Key insight:** All chart data is derivable from existing CoreData entities in < 50 lines of Swift. The most dangerous temptation is to introduce a new CoreData entity for aggregated stats — this adds migration complexity with zero benefit.

---

## Common Pitfalls

### Pitfall 1: DateComponents Timezone Omission in UNCalendarNotificationTrigger

**What goes wrong:** Notification fires at wrong local time — e.g., fires at 7am instead of 7pm, or on the wrong day.
**Why it happens:** `DateComponents` defaults to GMT when `timeZone` is not set. On a device in UTC-7, a 7pm local notification scheduled without explicit timezone fires at midnight GMT.
**How to avoid:** Always set `components.timeZone = TimeZone.current` before creating `UNCalendarNotificationTrigger(dateMatching:repeats:)`.
**Warning signs:** Notification fires at unexpected hour in simulator; works correctly in GMT timezone but not in others.

[CITED: donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/]

### Pitfall 2: Stale CoreData Model File

**What goes wrong:** Build fails with "The model used to open the store is incompatible with the one used to create the store."
**Why it happens:** The project has two `WorkoutApp.xcdatamodeld` directories. If Xcode includes `Core/CoreData/WorkoutApp.xcdatamodeld` (the stale one without CDSessionLog) in the build target instead of `Core/Data/WorkoutApp.xcdatamodeld`, the model won't match the live store.
**How to avoid:** Before implementing, verify in Xcode Build Phases → Compile Sources that only one `.xcdatamodeld` is compiled. The correct file is `Core/Data/WorkoutApp.xcdatamodeld` (contains CDSessionLog, CDSetLog, CDChatMessage).
**Warning signs:** CoreData fatalError on launch ("WorkoutApp load error").

[VERIFIED: codebase inspection — two xcdatamodeld files found at different paths]

### Pitfall 3: Notification Permission Re-Request Timing

**What goes wrong:** Permission prompt appears at app launch or before the user has any context for why notifications are useful.
**Why it happens:** D-24 specifies permission after first session completes, but `SessionViewModel.startSession()` already calls `requestNotificationPermission()` at session start, not finish.
**How to avoid:** The notification scheduler for workout reminders (distinct from rest-timer notifications) must request permission in the post-`finalizeSession()` flow in `SessionViewModel`, not at session start. Consider adding a `requestWorkoutReminderPermission()` call inside the `isSessionComplete = true` block, or triggering it from the `SessionSummaryView.onAppear`.
**Warning signs:** Permission alert appears on first app launch before any workout is done.

### Pitfall 4: Chart Data Including In-Progress Sessions

**What goes wrong:** Charts show partial sessions or sessions without a `completedAt` date.
**Why it happens:** `CDSessionLog` records are created at session start (not completion). An in-progress session (completedAt = nil) would show up in chart data.
**How to avoid:** All NSFetchRequest predicates for progress features must include `completedAt != nil`.

[VERIFIED: SessionRepository.swift — `fetchUnsyncedSessions()` already uses `completedAt != nil` as precedent]

### Pitfall 5: Streak Broken by Grace Period Edge Case

**What goes wrong:** User completes workout at 11:58pm, then completes another at 12:02am the next night. Streak correctly increments to 2. But if the user skips a calendar day and completes two workouts on one day, the streak should NOT double-count the day.
**Why it happens:** Naive counting of `[CDSessionLog]` without deduplicating by calendar day inflates the streak.
**How to avoid:** Always deduplicate `completedAt` dates to unique calendar days using `Set(dates.map { calendar.startOfDay(for: $0) })` before streak calculation.

### Pitfall 6: Info.plist Missing Notification String

**What goes wrong:** Notification permission system alert is missing app-provided reason string; App Store review may flag it.
**Why it happens:** `NSUserNotificationsUsageDescription` is required in Info.plist to explain why the app requests notification permission (per Apple guidelines).
**How to avoid:** Add `NSUserNotificationsUsageDescription` to `WorkoutApp/Info.plist` before shipping. Example value: "We'll remind you when it's time for your next workout to help you stay on track."
**Warning signs:** No crash but App Store review rejection under guideline 2.5.13.

[ASSUMED] — Apple requires privacy strings for notification permission; exact key name verified in Apple docs patterns.

---

## Code Examples

### Fetching All Completed Sessions Sorted by Date

```swift
// Source: [VERIFIED: codebase — SessionRepository pattern; NSFetchRequest standard CoreData]
func fetchCompletedSessions(context: NSManagedObjectContext) throws -> [CDSessionLog] {
    let req = CDSessionLog.fetchRequest()
    req.predicate = NSPredicate(format: "completedAt != nil")
    req.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
    return try context.fetch(req)
}
```

### Weekly Bucketing for Chart Data (Last 8 Weeks)

```swift
// Source: [ASSUMED] — Foundation Calendar.current weekOfYear standard pattern
func weeklyBuckets(from sessions: [CDSessionLog]) -> [WeekBucket] {
    let calendar = Calendar.current
    let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: Date())!

    let recentSessions = sessions.filter {
        guard let date = $0.completedAt else { return false }
        return date >= eightWeeksAgo
    }

    // Group by (year, weekOfYear)
    var buckets: [WeekKey: (count: Int, volume: Int)] = [:]
    for session in recentSessions {
        guard let date = session.completedAt else { continue }
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let key = WeekKey(year: year, week: week)
        let volume = Int(session.totalSets) * Int(session.totalReps)
        buckets[key, default: (0, 0)].count += 1
        buckets[key, default: (0, 0)].volume += volume
    }
    // Sort and format for display
    return buckets.sorted { $0.key < $1.key }
        .map { WeekBucket(weekLabel: formatWeekLabel($0.key), sessionCount: $0.value.count, volume: $0.value.volume) }
}
```

### Notification Permission Request (Earned Moment)

```swift
// Source: donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/
func requestWorkoutReminderPermission() async {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .notDetermined else { return }
    _ = try? await center.requestAuthorization(options: [.alert, .sound])
}
```

### Cancelling and Rescheduling All Workout Reminders

```swift
// Source: [VERIFIED: UNUserNotificationCenter Apple docs pattern]
func rescheduleWorkoutReminders(
    planDays: [CDWorkoutDay],  // days with scheduled workouts
    currentStreak: Int
) async {
    let center = UNUserNotificationCenter.current()
    // Cancel existing workout reminders (not rest-timer notifications)
    let pending = await center.pendingNotificationRequests()
    let workoutIds = pending
        .map(\.identifier)
        .filter { $0.hasPrefix("workout-reminder-") }
    center.removePendingNotificationRequests(withIdentifiers: workoutIds)

    // Reschedule for each plan day
    for day in planDays {
        let weekday = weekdayIndex(for: day.dayLabel ?? "")
        try? await scheduleWorkoutReminder(
            weekday: weekday,
            workoutType: day.sessionName ?? "Workout",
            currentStreak: currentStreak,
            identifier: "workout-reminder-\(weekday)"
        )
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom third-party charting (Charts by Daniel Gindi) | Apple Swift Charts native | iOS 16 (2022) | No dependency; automatic dark mode, accessibility, Dynamic Type support |
| UILocalNotification | UNUserNotificationCenter | iOS 10 (2016) | Async/await support in modern Swift; `UNCalendarNotificationTrigger` for calendar-based repeating |
| `@FetchRequest` property wrapper in views | NSFetchRequest in `@Observable` ViewModel | Swift 5.9+ (@Observable) | Cleaner separation; ViewModel owns data fetching; View binds to published state |

**Deprecated/outdated:**
- `UILocalNotification`: Removed in iOS 10. Use `UNUserNotificationCenter` throughout. [VERIFIED: Apple docs — UNUserNotificationCenter available iOS 10+]
- `ObservableObject` / `@Published` for ViewModels: Project uses `@Observable` macro (iOS 17+) as established in all prior phases. Continue this pattern.

---

## Runtime State Inventory

This is a greenfield feature phase (new tab, new view, new ViewModel, new service). No rename/refactor. This section is not applicable.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Streak uses calendar-day boundary (midnight), not 24-hour rolling window | Pattern 4 / Common Pitfalls | Low — either approach is defensible; calendar day is more user-intuitive and the safer choice |
| A2 | `NSUserNotificationsUsageDescription` key is required in Info.plist for notification permission | Pitfall 6 | Medium — App Store review may reject without it; should be verified against current App Review Guidelines |
| A3 | `CDSessionLog.totalSets * totalReps` is a valid proxy for training volume | Don't Hand-Roll / Chart data | Low — volume = sets × reps is standard; the alternative (sum of repsLogged per set) gives identical result for uniform set sizes |
| A4 | Streak should NOT increment if user logs multiple sessions in one calendar day | Pattern 4 | Low — deduplicating by calendar day is the only sensible interpretation; double-counting same-day sessions would be confusing |
| A5 | Notification scheduler should use `identifier: "workout-reminder-\(weekday)"` pattern to allow cancel/replace on plan change | Pattern 5 | Low — consistent identifier pattern is the standard UNUserNotificationCenter approach for mutable recurring notifications |

---

## Open Questions

1. **Notification scheduling trigger when plan changes**
   - What we know: Plan can be regenerated via AI Coach (Phase 5). The active plan's workout days determine which weekdays get notifications.
   - What's unclear: Is there a published event/notification when a new plan becomes active? The planner will need to hook `rescheduleWorkoutReminders` to plan change.
   - Recommendation: Check if `TrainView` or the plan-loading flow already emits any observable state change that `NotificationScheduler` can observe. If not, add a call in the plan-accept flow.

2. **PR detection source-of-truth: CoreData derived vs stored max**
   - What we know: D-18 leaves this to Claude's Discretion. SessionRepository writes complete CDSetLog records with `repsLogged`.
   - What's unclear: Whether to query all CDSetLog records at detection time (cheap with small dataset) or maintain a separate `CDExerciseRecord` entity (adds migration).
   - Recommendation: Derive at detection time by querying CDSetLog. At ~5 exercises × 3 sets × 100 sessions = 1,500 records max for active users — this is trivially fast and avoids a CoreData migration. If the dataset ever grows to tens of thousands, add an index.

3. **SessionViewModel notification permission timing**
   - What we know: `SessionViewModel.startSession()` currently calls `requestNotificationPermission()` for rest-timer notifications (alerts + sound). Phase 6 needs permission for workout reminders (also alerts + sound). The options are identical.
   - What's unclear: Whether calling `requestAuthorization` a second time after the first session completes is a no-op (it is — system won't show the prompt twice) or whether a pre-prompt custom UI is desired.
   - Recommendation: The Phase 6 NotificationScheduler should call `requestAuthorization` after session completion. Since `requestAuthorization` is a no-op if already granted/denied, this is safe even if the rest-timer already requested it.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Apple Swift Charts | PROG-04 charts | ✓ | iOS 16+ (built-in SDK) | — |
| UserNotifications framework | PROG-03, D-19 | ✓ | iOS 10+ (built-in) | — |
| CoreData / NSPersistentContainer | PROG-01, PROG-02, PROG-03 | ✓ | Already configured in PersistenceController | — |
| Xcode 16+ | Build | ✓ (assumed — Swift 6 project) | 16+ | — |

[VERIFIED: codebase — PersistenceController.swift already imports CoreData and is functional; SessionRepository.swift writes CDSessionLog records successfully in Phase 4]

No missing dependencies. All required frameworks are bundled with iOS 16+ SDK.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) |
| Config file | WorkoutAppTests/ target in Xcode project |
| Quick run command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests` |
| Full suite command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROG-01 | fetchCompletedSessions returns only sessions with completedAt != nil, sorted descending | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests` | ❌ Wave 0 |
| PROG-02 | computeStreak returns correct current and longest streak for sequence of dates including gaps | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests/testStreakCalculation` | ❌ Wave 0 |
| PROG-02 | computeWeeklyRing returns correct completed/planned counts for current calendar week | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests/testWeeklyRing` | ❌ Wave 0 |
| PROG-03 | detectPRs returns PRResult for exercise where current session max > prior session max | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests/testPRDetection` | ❌ Wave 0 |
| PROG-03 | detectPRs returns empty when no PR set | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests/testNoPRWhenNotExceeded` | ❌ Wave 0 |
| PROG-04 | weeklyBuckets groups sessions correctly by calendar week over 8-week window | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests/testWeeklyBuckets` | ❌ Wave 0 |
| D-25 | NotificationScheduler does not schedule if session already logged today | unit | `xcodebuild test -only-testing:WorkoutAppTests/NotificationSchedulerTests` | ❌ Wave 0 |
| D-19 | NotificationScheduler uses UNCalendarNotificationTrigger with TimeZone.current | unit | `xcodebuild test -only-testing:WorkoutAppTests/NotificationSchedulerTests/testTimezoneSet` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run `ProgressViewModelTests` and `NotificationSchedulerTests` only
- **Per wave merge:** Full suite `xcodebuild test -scheme WorkoutApp`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `WorkoutAppTests/ProgressViewModelTests.swift` — covers PROG-01, PROG-02, PROG-03, PROG-04; needs in-memory CoreData setup (reuse PersistenceController(inMemory: true) pattern from SessionRepositoryTests)
- [ ] `WorkoutAppTests/NotificationSchedulerTests.swift` — covers D-25, D-19 timezone; mock UNUserNotificationCenter or inject center dependency

*(No framework install needed — XCTest already configured for this project.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Progress data reads are user-scoped by `userId` predicate in CoreData |
| V3 Session Management | no | No new session tokens |
| V4 Access Control | yes | CoreData queries must filter by `userId` — never fetch another user's sessions |
| V5 Input Validation | no | Read-only display; no user input fields in this phase |
| V6 Cryptography | no | No encryption needed for progress metrics |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Fetching all CDSessionLog without userId predicate | Info Disclosure | Add `userId == %@` predicate to all NSFetchRequests in ProgressViewModel; `currentUser.id.uuidString` from AppState |
| Notification content leaking workout schedule to lock screen | Info Disclosure (low severity) | Acceptable per product decision (D-22); notification copy is motivational not sensitive |
| Storing PRs globally without user scoping if CDExerciseRecord entity added | Info Disclosure | Scope any new CoreData entities by userId; or derive from scoped CDSetLog queries (recommended — avoids new entity) |

---

## Sources

### Primary (HIGH confidence)
- Apple Swift Charts framework — [developer.apple.com/documentation/Charts](https://developer.apple.com/documentation/Charts) — Chart, BarMark, LineMark, AreaMark, chartXAxis, chartYAxis patterns
- UNUserNotificationCenter official docs — [developer.apple.com/documentation/usernotifications/unusernotificationcenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- CoreData schema — verified by direct inspection of `Core/Data/WorkoutApp.xcdatamodeld/WorkoutApp.xcdatamodel/contents`
- SessionRepository.swift, SessionSummaryView.swift, MainTabView.swift, AppState.swift — verified by direct codebase read

### Secondary (MEDIUM confidence)
- Swift Charts code examples — [mvolkmann.github.io/blog/swift/SwiftCharts/](https://mvolkmann.github.io/blog/swift/SwiftCharts/) — AxisMarks, BarMark, LineMark, AreaMark, chartPlotStyle patterns
- Swift Charts area fill + gradient — [createwithswift.com/customizing-a-chart-in-swift-charts/](https://www.createwithswift.com/customizing-a-chart-in-swift-charts/) — LinearGradient AreaMark
- UNCalendarNotificationTrigger + timezone pitfall — [donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/](https://www.donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/) — DateComponents.timeZone requirement

### Tertiary (LOW confidence)
- `NSUserNotificationsUsageDescription` Info.plist key requirement — [ASSUMED from general Apple privacy string conventions; verify against current App Review Guidelines]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Apple native frameworks, verified against codebase and docs
- Architecture: HIGH — All patterns derived from existing codebase conventions and official documentation
- CoreData schema: HIGH — Verified by direct inspection of xcdatamodel contents file
- Pitfalls: MEDIUM-HIGH — Timezone and stale model pitfalls verified; streak edge cases ASSUMED from common patterns
- Chart code: MEDIUM — Verified against multiple secondary sources; Apple developer docs returned JS-only page

**Research date:** 2026-04-23
**Valid until:** 2026-10-23 (stable Apple frameworks; Swift Charts API is stable since iOS 16)
