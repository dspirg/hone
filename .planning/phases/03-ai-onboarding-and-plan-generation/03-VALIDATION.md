---
phase: 3
slug: ai-onboarding-and-plan-generation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) — built into Xcode |
| **Config file** | WorkoutApp.xcodeproj |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing WorkoutAppTests 2>&1 | tail -20` |
| **Full suite command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command
- **After every plan wave:** Run full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | ONBD-01 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/OnboardingViewModelTests` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | ONBD-02 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/AppStateRoutingTests` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | AIPL-01, AIPL-02 | T-03-01 | Edge Function injects API key; no key in iOS binary | unit | `xcodebuild test ... -only-testing WorkoutAppTests/WorkoutPlanServiceTests` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | AIPL-03 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/WorkoutPlanParserTests` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 3 | ONBD-03, AIPL-04 | — | N/A | manual | See manual verifications | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/OnboardingViewModelTests.swift` — stubs for ONBD-01
- [ ] `WorkoutAppTests/AppStateRoutingTests.swift` — stubs for ONBD-02
- [ ] `WorkoutAppTests/WorkoutPlanServiceTests.swift` — stubs for AIPL-01, AIPL-02
- [ ] `WorkoutAppTests/WorkoutPlanParserTests.swift` — stubs for AIPL-03

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Streaming plan generation shows animated loading state | AIPL-03 | Simulator UI animation not reliably testable with XCTest | Run on simulator, complete onboarding, confirm pulsing ring animation appears and plan reveals on completion |
| Onboarding → paywall gate (plan visible but locked) | ONBD-03 | Navigation flow requires full app state | Run on simulator as new user, confirm plan preview shown before subscription paywall |
| Back navigation preserves chip selections | ONBD-01 | State preservation across card transitions | Tap through to card 3, go back twice, confirm chips still selected |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
