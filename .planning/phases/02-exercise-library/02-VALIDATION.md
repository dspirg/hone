---
phase: 2
slug: exercise-library
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in iOS) + Swift Testing (iOS 17+) |
| **Config file** | WorkoutApp.xcodeproj (scheme: WorkoutAppTests) |
| **Quick run command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing WorkoutAppTests/ExerciseLibraryTests 2>&1 | tail -20` |
| **Full suite command** | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40` |
| **Estimated runtime** | ~30 seconds (simulator boot + unit tests) |

---

## Sampling Rate

- **After every task commit:** Run quick command (ExerciseLibraryTests only)
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 02-01-01 | 01 | 0 | EXRC-01 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/CoreDataStackTests` | ⬜ pending |
| 02-01-02 | 01 | 0 | EXRC-02 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/ExerciseRepositoryTests` | ⬜ pending |
| 02-01-03 | 01 | 1 | EXRC-01 | — | RLS anon read only | unit | `xcodebuild test ... -only-testing WorkoutAppTests/SupabaseExerciseFetchTests` | ⬜ pending |
| 02-02-01 | 02 | 1 | EXRC-02 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/ExerciseSearchFilterTests` | ⬜ pending |
| 02-02-02 | 02 | 2 | EXRC-03 | — | N/A | manual | Simulator: open exercise detail, verify video plays inline | ⬜ pending |
| 02-02-03 | 02 | 2 | EXRC-03 | — | N/A | manual | Simulator: verify HLS loops without re-download (seek-to-zero pattern) | ⬜ pending |
| 02-03-01 | 03 | 2 | EXRC-04 | — | N/A | manual | Simulator: play video on Wi-Fi, toggle to airplane mode, verify offline playback | ⬜ pending |
| 02-03-02 | 03 | 2 | EXRC-04 | — | N/A | unit | `xcodebuild test ... -only-testing WorkoutAppTests/CacheEvictionTests` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `WorkoutAppTests/CoreDataStackTests.swift` — CoreData stack init, Exercise entity CRUD
- [ ] `WorkoutAppTests/ExerciseRepositoryTests.swift` — fetch, upsert, in-memory filter logic
- [ ] `WorkoutAppTests/ExerciseSearchFilterTests.swift` — search by name, filter by muscle group and equipment
- [ ] `WorkoutAppTests/CacheEvictionTests.swift` — 500MB limit logic, LRU eviction, cache size calculation
- [ ] `WorkoutAppTests/SupabaseExerciseFetchTests.swift` — mock Supabase client, verify fetch maps to Exercise entity

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HLS video plays inline with auto-loop | EXRC-03 | AVPlayer/AVKit requires physical simulator or device rendering | Open exercise detail in simulator, verify video plays in 40% player, loops without gap |
| Video plays offline after Wi-Fi cache | EXRC-04 | Network mode toggle requires simulator/device interaction | Play video on Wi-Fi, enable airplane mode in Control Center, navigate to same exercise, verify playback |
| Filter chips update exercise list | EXRC-02 | UI state interaction — chip tap → list filter | Tap "Chest" chip, verify list shows only chest exercises; tap again to deselect |
| Placeholder thumbnail for unlicensed video | EXRC-01 | Visual rendering check | Open exercise with null mux_playback_id, verify placeholder + "Video coming soon" label renders |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
