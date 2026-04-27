---
phase: 10
slug: design-system-and-visual-identity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 16+) |
| **Config file** | WorkoutApp.xcodeproj (test target) |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -20` |
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
| 10-01-01 | 01 | 1 | UI-01 | — | N/A | visual | Simulator dark mode toggle — no white surfaces | n/a | ⬜ pending |
| 10-01-02 | 01 | 1 | UI-01 | — | N/A | unit | Theme.accent == #f59e0b | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | UI-02 | — | N/A | visual | Exercise rows show Mux thumbnail, not emoji | n/a | ⬜ pending |
| 10-02-02 | 02 | 1 | UI-03 | — | N/A | integration | Tap thumbnail → fullscreen AVPlayer presents | n/a | ⬜ pending |
| 10-03-01 | 03 | 2 | UI-06 | — | N/A | visual | Chat shows "Hone" name + gradient avatar | n/a | ⬜ pending |
| 10-03-02 | 03 | 2 | UI-06 | — | N/A | grep | NotificationScheduler contains "Hone" strings | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements. This phase is primarily visual — most verification is manual/visual with grep-based checks for string replacements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dark mode consistency across all 41 views | UI-01 | Visual inspection — no programmatic way to detect white surfaces | Run Simulator, navigate all screens, toggle Features → Light/Dark |
| Amber accent applied correctly (60/30/10 rule) | UI-01 | Color distribution is a design judgment | Review each screen against UI-SPEC color distribution table |
| Fullscreen video overlay dismiss gesture | UI-03 | Gesture interaction requires manual testing | Tap thumbnail → verify fullscreen → dismiss via X and swipe-down |
| Hone personality tone in copy | UI-06 | Subjective tone assessment | Read all Hone-attributed text for warm/direct/confident tone |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
