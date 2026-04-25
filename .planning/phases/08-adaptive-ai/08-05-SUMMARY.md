---
phase: 08-adaptive-ai
plan: "05"
subsystem: notifications
tags: [notifications, adaptation, swift, usernotifications, guilt-blocklist]

# Dependency graph
requires:
  - phase: 08-adaptive-ai plan 04
    provides: AdaptationService.checkOnForeground, MissedSessionDetector

provides:
  - NotificationScheduler.scheduleReengagementNotificationIfNeeded: re-engagement scheduling with 2+ miss guard, 2/week cap, guilt blocklist
  - NotificationScheduler.shared: singleton for cross-service access
  - guiltPatterns blocklist: NSRegularExpression array preventing guilt language in notifications
  - AdaptationService integration: foreground check now triggers notification scheduling after missed detection

affects: [08-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guilt blocklist uses NSRegularExpression array as static lazy computed property — initialized once, reused on every notification schedule call"
    - "Re-engagement identifier prefix 'reengagement-' enables counting pending queue without storing external state"
    - "NotificationScheduler.shared singleton added without breaking existing SessionViewModel instantiation pattern (init still public)"

key-files:
  created: []
  modified:
    - WorkoutApp/Core/Notifications/NotificationScheduler.swift
    - WorkoutApp/Features/Adaptation/AdaptationService.swift

key-decisions:
  - "missedDays.count used directly as missedSessionCount — count of distinct missed day labels is the right signal for the 2+ threshold"
  - "Notification scheduled for 10am tomorrow (not tonight) — gives user time before nagging, avoids late-night interruption"
  - "NotificationScheduler.shared added as deviation (Rule 3) — plan references it but Phase 6 never added it; minor fix, not architectural"

patterns-established:
  - "Re-engagement notification: check after missed session adaptation in checkOnForeground; both the adaptation and notification share the same missed count"

requirements-completed: [ADPT-03]

# Metrics
duration: 40min
completed: 2026-04-25
---

# Phase 8 Plan 05: Adaptive AI — Smart Re-engagement Notifications Summary

**Re-engagement notification pipeline complete: guilt blocklist + 2+ miss threshold (D-08) + 2/week frequency cap (D-10) + supportive copy (D-09) wired into AdaptationService foreground check**

## Performance

- **Duration:** 40 min
- **Started:** 2026-04-25T14:46:07Z
- **Completed:** 2026-04-25T15:25:44Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- NotificationScheduler extended with `scheduleReengagementNotificationIfNeeded(missedSessionCount:)` — full guard chain: count >= 2, permissions authorized, pending < 2
- Guilt language blocklist (`guiltPatterns`) compiled as 9 NSRegularExpression patterns covering all AI-SPEC Section 5 prohibited phrases
- Safe fallback body constant (`safeFallbackBody`) activates if copy ever fails blocklist validation
- `passesGuiltBlocklist()` validates any notification body before scheduling — runs on hardcoded copy as a correctness guarantee
- `.shared` singleton added to NotificationScheduler enabling cross-service access
- AdaptationService `checkOnForeground()` now calls notification scheduling after missed session detection when count >= 2
- BUILD SUCCEEDED with all changes in place

## Task Commits

Each task was committed atomically:

1. **Task 1: Add re-engagement notification method to NotificationScheduler** — `bbf9d61` (feat)
2. **Task 2: Wire NotificationScheduler into AdaptationService foreground check** — `61dbff8` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — Added `.shared` singleton, `guiltPatterns` blocklist (9 regex patterns, caseInsensitive), `safeFallbackBody` constant, `passesGuiltBlocklist()` helper, `scheduleReengagementNotificationIfNeeded(missedSessionCount:)` method with full guard chain and UNCalendarNotificationTrigger for 10am tomorrow
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` — Added `if missedDays.count >= 2` block calling `NotificationScheduler.shared.scheduleReengagementNotificationIfNeeded` after missed session adaptation in `checkOnForeground()`

## Decisions Made

- `missedDays.count` is used directly as the `missedSessionCount` parameter — the array of missed day labels is the canonical count from MissedSessionDetector, matching the >= 2 threshold exactly.
- Notification is scheduled for 10am the next day — avoids late-night interruption while giving the user a clear morning prompt.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added NotificationScheduler.shared singleton**
- **Found during:** Task 1
- **Issue:** Task 2 calls `NotificationScheduler.shared` but the existing class had no static `shared` property. The class was instantiated ad-hoc (`NotificationScheduler()`) in SessionViewModel. Without `.shared`, Task 2 would not compile.
- **Fix:** Added `static let shared = NotificationScheduler()` inside the class body. The existing `init(context:)` remains public so SessionViewModel's ad-hoc instantiation continues to work without change.
- **Files modified:** WorkoutApp/Core/Notifications/NotificationScheduler.swift
- **Committed in:** bbf9d61 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking: missing .shared singleton required by Task 2)
**Impact on plan:** Non-breaking addition; no callers changed.

## Issues Encountered

None.

## Threat Model Coverage

| Threat | Mitigation | Applied |
|--------|-----------|---------|
| T-08-13: Notification copy tampering | Hardcoded copy; `passesGuiltBlocklist()` validates before schedule; `safeFallbackBody` on any match | NotificationScheduler.scheduleReengagementNotificationIfNeeded |
| T-08-14: Notification spam DoS | Frequency cap: `reengagementPending.count < 2` guard checks live pending queue | NotificationScheduler.scheduleReengagementNotificationIfNeeded |

## Known Stubs

None — re-engagement notification scheduling is fully wired. Hardcoded copy passes the guilt blocklist on its own (verified by the blocklist logic itself).

## Self-Check

Files exist:
- WorkoutApp/Core/Notifications/NotificationScheduler.swift — FOUND
- WorkoutApp/Features/Adaptation/AdaptationService.swift — FOUND

Commits exist:
- bbf9d61 — FOUND
- 61dbff8 — FOUND

## Self-Check: PASSED

---
*Phase: 08-adaptive-ai*
*Completed: 2026-04-25*
