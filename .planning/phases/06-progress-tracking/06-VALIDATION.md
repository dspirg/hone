---
phase: 6
slug: progress-tracking
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
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
| 06-01-01 | 01 | 1 | PROG-01 | — | N/A | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 1 | PROG-02 | — | N/A | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 2 | PROG-03 | — | N/A | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 06-04-01 | 04 | 2 | PROG-04 | — | N/A | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/ProgressTests/` — test stubs for PROG-01 through PROG-04
- [ ] Streak calculation unit tests
- [ ] PR detection unit tests

*Existing XCTest infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chart rendering correctness | PROG-04 | Swift Charts visual output cannot be verified in unit tests | Run in Simulator, navigate to Progress tab, verify charts render with sample data |
| In-app notification display | PROG-03 | UNUserNotificationCenter requires device/simulator interaction | Complete a session with a new PR, verify notification appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
