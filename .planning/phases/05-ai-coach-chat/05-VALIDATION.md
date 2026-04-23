---
phase: 5
slug: ai-coach-chat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 5 — Validation Strategy

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
| TBD | TBD | TBD | CHAT-01 | — | N/A | unit | TBD | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | CHAT-02 | — | N/A | unit | TBD | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | CHAT-03 | — | N/A | unit | TBD | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | CHAT-04 | — | N/A | unit | TBD | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test stubs for CHAT-01 through CHAT-04
- [ ] Shared test fixtures for mock AI responses and CoreData test context

*Existing XCTest infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSE streaming renders token-by-token in chat UI | CHAT-01 | Visual rendering timing cannot be automated | Send message in simulator, observe token-by-token appearance |
| Proactive check-in notification appears | CHAT-04 | Push notification UX requires device interaction | Wait for scheduled check-in trigger, verify notification and in-app display |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
