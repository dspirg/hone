---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (bundled with Xcode 26.3) |
| **Config file** | Xcode test target — configured when Xcode project is created in Wave 0 |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Full suite command** | Same — test suite is small in Phase 1 |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run AUTH + SAFE unit/integration tests via the quick run command
- **After every plan wave:** Run full suite — must be green before advancing
- **Before `/gsd-verify-work`:** Full suite green + manual Apple Sign-In verification on device
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-AUTH-01 | TBD | 1 | AUTH-01 | JWT theft | Keychain storage via `KeychainLocalStorage` | Integration | `xcodebuild test -only-testing:WorkoutAppTests/AuthTests/testEmailSignUp` | ❌ W0 | ⬜ pending |
| 1-AUTH-02 | TBD | 1 | AUTH-02 | JWT theft | Session persists via Keychain across cold launch | Integration | `xcodebuild test -only-testing:WorkoutAppTests/AuthTests/testSessionPersistence` | ❌ W0 | ⬜ pending |
| 1-AUTH-03 | TBD | 1 | AUTH-03 | — | Password reset sends email without error | Integration (smoke) | `xcodebuild test -only-testing:WorkoutAppTests/AuthTests/testPasswordResetEmail` | ❌ W0 | ⬜ pending |
| 1-AUTH-04 | TBD | 1 | AUTH-04 | Replay attack | SHA-256 nonce via CryptoKit sent with Apple auth request | Manual only | Manual — simulator always throws on ASAuthorizationController | — | ⬜ pending |
| 1-SAFE-01 | TBD | 1 | SAFE-01 | — | Disclaimer modal on first launch only | UI test | `xcodebuild test -only-testing:WorkoutAppUITests/DisclaimerTests` | ❌ W0 | ⬜ pending |
| 1-SAFE-02 | TBD | 1 | SAFE-02 | Prompt injection | System prompt contains required safety rules (static check) | Unit | `xcodebuild test -only-testing:WorkoutAppTests/SafetyTests/testSystemPromptContainsGuardrails` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Xcode project with `WorkoutApp` scheme and two test targets (`WorkoutAppTests`, `WorkoutAppUITests`) — prerequisite for all test files
- [ ] Local Supabase environment (`supabase start`) — required for AUTH integration tests
- [ ] `WorkoutAppTests/AuthTests.swift` — stubs for AUTH-01, AUTH-02, AUTH-03
- [ ] `WorkoutAppUITests/DisclaimerTests.swift` — stub for SAFE-01
- [ ] `WorkoutAppTests/SafetyTests.swift` — stub for SAFE-02

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Apple Sign-In produces valid Supabase session | AUTH-04 | `ASAuthorizationController` always throws on iOS Simulator; requires physical device + Apple account | On a real device signed into an Apple ID: (1) Tap "Sign in with Apple" button, (2) Authenticate with Face ID / passcode, (3) Verify app reaches tab bar shell and `profiles` row exists in Supabase dashboard |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
