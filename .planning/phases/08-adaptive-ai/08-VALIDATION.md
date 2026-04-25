---
phase: 8
slug: adaptive-ai
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode XCTest (iOS) + Deno test (Edge Functions) + Promptfoo (AI eval) |
| **Config file** | WorkoutApp.xcodeproj (XCTest), supabase/functions/adapt-plan/eval/promptfooconfig.yaml (Promptfoo) |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests/AdaptationTests 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -20` |
| **Estimated runtime** | ~45 seconds (iOS tests) + ~30 seconds (Edge Function + Promptfoo) |

---

## Sampling Rate

- **After every task commit:** Run quick XCTest suite for changed module
- **After every plan wave:** Run full XCTest suite + Deno Edge Function tests
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | ADPT-01 | T-08-01 | difficulty_rating validated server-side | unit | `xcodebuild test -only-testing:WorkoutAppTests/DifficultyRatingTests` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | ADPT-01 | — | CDSessionLog stores difficulty_rating | unit | `xcodebuild test -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ W0 | ⬜ pending |
| 08-02-01 | 02 | 1 | ADPT-01 | T-08-02 | adapt-plan validates Zod schema | integration | `cd supabase/functions/adapt-plan && deno test` | ❌ W0 | ⬜ pending |
| 08-02-02 | 02 | 1 | ADPT-01 | T-08-03 | clinical language blocked in rationale | unit | `cd supabase/functions/adapt-plan && deno test --filter guardrails` | ❌ W0 | ⬜ pending |
| 08-03-01 | 03 | 2 | ADPT-02 | — | weekly regeneration respects exercise continuity | eval | `promptfoo eval --config supabase/functions/adapt-plan/eval/promptfooconfig.yaml` | ❌ W0 | ⬜ pending |
| 08-04-01 | 04 | 2 | ADPT-03 | — | missed session redistribution logic | unit | `cd supabase/functions/adapt-plan && deno test --filter missed` | ❌ W0 | ⬜ pending |
| 08-05-01 | 05 | 3 | ADPT-01 | T-08-04 | notification guilt patterns blocked | unit | `xcodebuild test -only-testing:WorkoutAppTests/NotificationTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/AdaptationTests.swift` — stubs for ADPT-01 difficulty rating
- [ ] `WorkoutAppTests/NotificationTests/ReengagementTests.swift` — stubs for ADPT-03 notification guardrails
- [ ] `supabase/functions/adapt-plan/eval/` — Promptfoo config + fixture stubs
- [ ] `supabase/functions/_shared/adaptedPlanSchema.ts` — Zod schema for validation tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Emoji rating UX is intuitive and fast | ADPT-01 | Subjective UX evaluation | Open SessionSummaryView, complete a session, verify emoji scale appears, tap rating, verify Done enables |
| Adapted plan "feels" appropriate | ADPT-01, ADPT-02 | Qualitative fitness judgment | Complete 3+ sessions with "too hard" ratings, verify next workout is visibly easier |
| Re-engagement notification tone | ADPT-03 | Tone quality is subjective | Miss 2 planned sessions, verify notification received, verify supportive wording |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
