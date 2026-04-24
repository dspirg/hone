---
phase: 07-subscriptions-and-paywall
plan: 06
subsystem: ui
tags: [swiftui, paywall, subscription-gating, homeview]

requires:
  - phase: 07-02
    provides: BlurredPlanGateView component
provides:
  - BlurredPlanGateView wired into HomeView for expired/lapsed users
affects: [07-08]

tech-stack:
  added: []
  patterns:
    - "Subscription-gated content using BlurredPlanGateView wrapper"

key-files:
  created: []
  modified:
    - WorkoutApp/Features/Main/Tabs/HomeView.swift

key-decisions:
  - "Extracted plan card into reusable planCard(plan:) method to avoid duplication"
  - "Used fullScreenCover for PaywallView presentation (consistent with existing pattern)"

patterns-established:
  - "Subscription gating: wrap content in BlurredPlanGateView when !appState.isSubscribed"

requirements-completed: [SUBS-04]

duration: 2min
completed: 2026-04-24
---

# Plan 07-06: Wire BlurredPlanGateView to HomeView Summary

**Expired/lapsed users now see blurred plan preview with tap-to-subscribe on Home tab (D-14, D-15)**

## Performance

- **Duration:** 2 min
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- BlurredPlanGateView wraps plan content when `!appState.isSubscribed`
- Tapping blurred content triggers PaywallView via fullScreenCover
- Plan card extracted to reusable `planCard(plan:)` method

## Task Commits

1. **Task 1: Wire BlurredPlanGateView into HomeView** - `67ec976` (feat)

## Files Created/Modified
- `WorkoutApp/Features/Main/Tabs/HomeView.swift` - Added subscription check, BlurredPlanGateView wrapper, fullScreenCover for PaywallView

## Decisions Made
None - followed plan as specified

## Deviations from Plan
None - plan executed exactly as written

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- BlurredPlanGateView is no longer orphaned
- Plan 07-08 can verify the blurred plan gate on Home tab

---
*Phase: 07-subscriptions-and-paywall*
*Completed: 2026-04-24*
