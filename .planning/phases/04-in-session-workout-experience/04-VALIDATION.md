---
phase: 4
slug: in-session-workout-experience
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing in `WorkoutAppTests/`) |
| **Config file** | Xcode scheme `WorkoutApp` — test action targets `WorkoutAppTests` |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests` |
| **Full suite command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 1 | SESS-01 | — | CDSetLog writes to CoreData on completeSet | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 1 | SESS-01 | — | CDSessionLog created on session start with userId + planId | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ W0 | ⬜ pending |
| 4-01-03 | 01 | 1 | SESS-02 | — | timerEndDate set correctly when set completed | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionViewModelTests` | ❌ W0 | ⬜ pending |
| 4-01-04 | 01 | 1 | SESS-03 | — | SessionSyncService marks syncedToSupabase=true after upsert | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionSyncServiceTests` | ❌ W0 | ⬜ pending |
| 4-01-05 | 01 | 1 | SESS-04 | — | Summary totals computed correctly from CDSessionLog + CDSetLog | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/SessionRepositoryTests.swift` — stubs for SESS-01, SESS-04
- [ ] `WorkoutAppTests/SessionViewModelTests.swift` — stubs for SESS-02
- [ ] `WorkoutAppTests/SessionSyncServiceTests.swift` — stubs for SESS-03

*All three test files require new source files to exist first — they are Wave 0 test scaffolds in Plan 04-01*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rest timer overlay does not interrupt AVPlayer video | SESS-01, SESS-02 | AVPlayer interruption requires Simulator observation | Start a session, play video, complete a set — verify video continues playing under overlay |
| Rest timer fires notification when app is backgrounded | SESS-02 | Push/local notification requires device/Simulator with background mode | Background app mid-timer — verify notification fires at countdown end |
| Session data survives app kill during offline session | SESS-03 | Requires Simulator force-quit while offline | Log 2 sets offline, force-quit app, relaunch — verify sets present in CoreData |
| Sync banner visible after 3 failed sync retries | SESS-03 | Requires network mock or airplane mode | Enable airplane mode, complete session — verify sync retries then shows banner |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
