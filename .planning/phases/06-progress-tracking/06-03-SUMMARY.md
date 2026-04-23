---
phase: 06-progress-tracking
plan: 03
subsystem: notifications
tags: [notifications, local-push, CoreData, UNUserNotificationCenter, timezone, streak]
dependency_graph:
  requires:
    - WorkoutApp/Core/CoreData/PersistenceController.swift
    - WorkoutApp/Features/CoreData/SessionRepository.swift (CDSessionLog entity)
  provides:
    - WorkoutApp/Core/Notifications/NotificationScheduler.swift
  affects:
    - WorkoutApp/Info.plist (NSUserNotificationsUsageDescription added)
tech_stack:
  added:
    - UserNotifications framework (UNUserNotificationCenter, UNCalendarNotificationTrigger)
  patterns:
    - "@MainActor final class (no @Observable — no published UI state)"
    - "Earned-moment permission request pattern (called after first session completes)"
    - "Repeating UNCalendarNotificationTrigger with TimeZone.current in DateComponents"
    - "Identifier prefix 'workout-reminder-{weekday}' for targeted cancel/replace"
key_files:
  created:
    - WorkoutApp/Core/Notifications/NotificationScheduler.swift
    - WorkoutAppTests/NotificationSchedulerTests.swift
  modified:
    - WorkoutApp/Info.plist
    - WorkoutApp.xcodeproj/project.pbxproj
    - WorkoutAppTests/CoachViewModelTests.swift (Rule 3 fix)
decisions:
  - "NotificationScheduler is @MainActor final class (not @Observable) — no published UI state needed; scheduling is fire-and-forget"
  - "TimeZone.current set on DateComponents to prevent system defaulting to GMT (Pitfall 1 mitigation)"
  - "Identifier pattern 'workout-reminder-{weekday}' allows targeted cancel/replace per weekday without touching rest-timer notifications"
  - "hasLoggedSessionToday filters by userId predicate (T-06-05 mitigation — no cross-user data leakage)"
  - "UNUserNotificationCenter scheduling tests deferred to human verification (Plan 04) — requires running simulator"
metrics:
  duration: "~12 minutes"
  completed: "2026-04-23"
  tasks: 2
  files: 5
---

# Phase 06 Plan 03: NotificationScheduler Service Summary

**One-liner:** Local notification scheduling service with timezone-safe 7pm repeating triggers, streak-aware copy, and CoreData session-today guard filtering by userId.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create NotificationScheduler service and update Info.plist | a0ddb17 | NotificationScheduler.swift, Info.plist, project.pbxproj |
| 2 | Create NotificationSchedulerTests | 8ee892d | NotificationSchedulerTests.swift, CoachViewModelTests.swift |

## What Was Built

**NotificationScheduler.swift** — `@MainActor final class` at `WorkoutApp/Core/Notifications/NotificationScheduler.swift`:

- `requestPermissionIfNeeded()` — checks `.notDetermined` status before requesting; safe to call multiple times
- `scheduleWorkoutReminders(planDays:currentStreak:)` — cancels existing, creates repeating triggers at 7pm per weekday with `TimeZone.current` in DateComponents
- `cancelAllWorkoutReminders()` — filters by `"workout-reminder-"` prefix; preserves rest-timer notifications
- `hasLoggedSessionToday(userId:)` — CoreData NSFetchRequest with `completedAt >= today AND completedAt < tomorrow AND userId == %@`; fetchLimit 1
- `shouldScheduleNotifications()` — returns true only when `.authorized`; skips scheduling on `.denied`/`.notDetermined`

**Info.plist** — Added `NSUserNotificationsUsageDescription` with "We'll remind you when it's time for your next workout to help you stay on track."

**NotificationSchedulerTests.swift** — 5 unit tests for `hasLoggedSessionToday`:
1. Returns true when session exists today
2. Returns false when database empty
3. Returns false for yesterday's session (date boundary)
4. Returns false for different userId (T-06-05 cross-user isolation)
5. Returns false for in-progress sessions (nil completedAt)

All 5 tests pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing `import CoreData` to CoachViewModelTests.swift**
- **Found during:** Task 2 — first test run
- **Issue:** `CoachViewModelTests.swift` used `NSEntityDescription.insertNewObject` without `import CoreData`, causing a build failure that blocked running NotificationSchedulerTests
- **Fix:** Added `import CoreData` to the imports section of CoachViewModelTests.swift
- **Files modified:** WorkoutAppTests/CoachViewModelTests.swift
- **Commit:** 8ee892d (included in Task 2 commit)

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. NotificationScheduler operates entirely via local UNUserNotificationCenter and read-only CoreData queries.

## Known Stubs

None — NotificationScheduler is a complete service implementation. UNUserNotificationCenter integration tested via human verification (Plan 04); CoreData guard logic fully unit-tested here.

## Self-Check: PASSED

- WorkoutApp/Core/Notifications/NotificationScheduler.swift: EXISTS
- WorkoutAppTests/NotificationSchedulerTests.swift: EXISTS
- Info.plist contains NSUserNotificationsUsageDescription: VERIFIED
- Commit a0ddb17: EXISTS (Task 1)
- Commit 8ee892d: EXISTS (Task 2)
- All 5 NotificationSchedulerTests: PASSED
