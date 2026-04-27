---
phase: 09
slug: bug-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 16+) |
| **Config file** | WorkoutApp.xcodeproj |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests` |
| **Full suite command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | FIX-01 | — | N/A | unit | `xcodebuild test -only-testing:WorkoutAppTests/AdaptationServiceTests` | ❌ W0 | ⬜ pending |
| 09-02-01 | 02 | 1 | FIX-02 | — | N/A | unit | `xcodebuild test -only-testing:WorkoutAppTests/MissedSessionDetectorTests` | ✅ | ⬜ pending |
| 09-03-01 | 03 | 1 | FIX-03 | — | N/A | unit | `xcodebuild test -only-testing:WorkoutAppTests/NotificationSchedulerTests` | ❌ W0 | ⬜ pending |
| 09-04-01 | 04 | 1 | FIX-04 | — | N/A | unit | `xcodebuild test -only-testing:WorkoutAppTests/ProgressViewModelTests` | ✅ | ⬜ pending |
| 09-05-01 | 05 | 1 | FIX-05 | — | N/A | grep | `grep -r isOnboarded WorkoutApp/` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/AdaptationServiceTests.swift` — stubs for FIX-01 adaptation persistence
- [ ] `WorkoutAppTests/NotificationSchedulerTests.swift` — stubs for FIX-03 notification wiring

*Existing infrastructure covers FIX-02, FIX-04, FIX-05.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| TrainView refreshes after adaptation | FIX-01 | UI observation requires simulator | Run adaptation flow, verify TrainView updates without relaunch |
| Notifications appear at correct times | FIX-03 | UNNotification requires device/simulator | Trigger plan generation, check pending notifications in Settings |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
