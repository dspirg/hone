---
phase: 7
slug: subscriptions-and-paywall
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 7 — Validation Strategy

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
| 07-01-01 | 01 | 1 | SUBS-01 | T-07-01 | RevenueCat logIn called with Supabase UUID immediately after auth | unit | `xcodebuild test ... -only-testing WorkoutAppTests/RevenueCatServiceTests` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | SUBS-02 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/EntitlementGateTests` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 2 | SUBS-01, SUBS-03 | — | N/A | manual | See manual verifications | N/A | ⬜ pending |
| 07-03-01 | 03 | 3 | SUBS-04 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/RetentionFlowTests` | ❌ W0 | ⬜ pending |
| 07-03-02 | 03 | 3 | SUBS-04 | — | N/A | manual | See manual verifications | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/RevenueCatServiceTests.swift` — stubs for SUBS-01 (anonymous ID pitfall guard)
- [ ] `WorkoutAppTests/EntitlementGateTests.swift` — stubs for SUBS-02 (paywall gate logic)
- [ ] `WorkoutAppTests/RetentionFlowTests.swift` — stubs for SUBS-04 (pause/discount sequence)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Paywall renders with correct pricing from RevenueCat | SUBS-01 | Requires StoreKit sandbox environment | Run on simulator with StoreKit config, confirm monthly/annual prices and trial period display from SDK (not hardcoded) |
| Purchase flow completes and entitlement unlocks | SUBS-01 | StoreKit sandbox purchase required | Complete sandbox purchase, confirm `pro` entitlement active and content unlocked |
| Retention flow: pause → discount sequence | SUBS-04 | Multi-screen navigation flow | Trigger cancellation, confirm PauseOptionsView shown first, then DiscountOfferView on "Cancel anyway" |
| Billing transparency notice visible on paywall | SUBS-03 | Visual verification | Confirm notice text present below CTA before purchase |
| Promotional offer eligibility guard | SUBS-04 | Requires RevenueCat sandbox state | Confirm discount offer only shown to eligible subscribers (not new users) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
