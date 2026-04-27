---
phase: 12
slug: app-store-submission
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) |
| **Config file** | Xcode scheme (shouldAutocreateTestPlan = "YES") |
| **Quick run command** | `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Full suite command** | `xcodebuild archive -scheme WorkoutApp -configuration Release` |
| **Estimated runtime** | ~60 seconds (build), ~120 seconds (archive) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "error:|warning:"`
- **After every plan wave:** Run `xcodebuild archive -scheme WorkoutApp -configuration Release`
- **Before `/gsd-verify-work`:** Full archive must succeed; App Store Connect validation passes
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | SHIP-02 | — | N/A | build | `xcodebuild build` (check PrivacyInfo bundled) | N/A | pending |
| 12-01-02 | 01 | 1 | SHIP-04 | T-12-01 | Prod keys not hardcoded | build | `xcodebuild build -configuration Release` | N/A | pending |
| 12-01-03 | 01 | 1 | SHIP-01 | — | N/A | build | `xcodebuild build` (no missing icon warning) | N/A | pending |
| 12-02-01 | 02 | 2 | SHIP-04 | — | N/A | archive | `xcodebuild archive -scheme WorkoutApp -configuration Release` | N/A | pending |
| 12-03-01 | 03 | 2 | SHIP-03 | — | N/A | manual | RevenueCat dashboard verification | Manual-only | pending |
| 12-04-01 | 04 | 2 | SHIP-05 | — | N/A | manual | Visual inspection of screenshot dimensions | Manual-only | pending |
| 12-04-02 | 04 | 2 | SHIP-06 | — | N/A | manual | App Store Connect listing review | Manual-only | pending |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. Most SHIP requirements are manual/external — automated tests are limited to build system verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| StoreKit product IDs match RevenueCat config | SHIP-03 | External service state (App Store Connect) | Compare product IDs in WorkoutAppProducts.storekit with App Store Connect subscription products |
| Screenshots at correct dimensions | SHIP-05 | Design artifact | Verify PNG files are exactly 1290x2796 (6.7") and 1179x2556 (6.1") using image properties |
| App Store listing completeness | SHIP-06 | External service (App Store Connect) | Verify all fields filled: title, subtitle, description, keywords, category, privacy policy URL |
| Privacy policy URL accessible | SHIP-06 | External hosted page | Open privacy policy URL in browser, verify HTTPS, content loads |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
