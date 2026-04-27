---
phase: 10-design-system-and-visual-identity
plan: "03"
subsystem: coach-identity
tags: [branding, hone, coach, chat-bubbles, notifications, theme-tokens]
dependency_graph:
  requires:
    - WorkoutApp/Features/Coach/Components/HoneAvatarView.swift
    - WorkoutApp/Core/Theme.swift
  provides:
    - WorkoutApp/Features/Coach/Components/ChatBubbleView.swift
    - WorkoutApp/Features/Coach/Components/CoachHeaderView.swift
    - WorkoutApp/Features/Coach/Components/ChatInputBar.swift
    - WorkoutApp/Features/Coach/Components/OfflineBannerView.swift
    - WorkoutApp/Features/Main/Tabs/CoachView.swift
    - WorkoutApp/Core/Notifications/NotificationScheduler.swift
    - WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift
    - WorkoutApp/Features/Main/Tabs/TrainView.swift
    - WorkoutApp/Features/Main/MainTabView.swift
  affects:
    - WorkoutApp/Features/Coach/Components/PlanModificationCard.swift
    - WorkoutApp.xcodeproj/project.pbxproj
tech_stack:
  added: []
  patterns:
    - "HoneAvatarView(diameter:) replaces figure.run in all coach contexts"
    - "Theme.* tokens replace all raw Color() calls in Coach feature files"
    - "Hone identity string used consistently across notifications, loading, tab bar"
decisions:
  - "PlanModificationCard.swift swept as part of Coach/ directory zero-raw-Color rule despite not being in the plan's file list"
  - "HoneAvatarView.swift, Theme.swift, VideoOverlayView.swift added to project.pbxproj (created in Plan 01 but never registered in Xcode project)"
key_files:
  created: []
  modified:
    - WorkoutApp/Features/Coach/Components/ChatBubbleView.swift
    - WorkoutApp/Features/Coach/Components/CoachHeaderView.swift
    - WorkoutApp/Features/Coach/Components/ChatInputBar.swift
    - WorkoutApp/Features/Coach/Components/OfflineBannerView.swift
    - WorkoutApp/Features/Main/Tabs/CoachView.swift
    - WorkoutApp/Core/Notifications/NotificationScheduler.swift
    - WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift
    - WorkoutApp/Features/Main/Tabs/TrainView.swift
    - WorkoutApp/Features/Main/MainTabView.swift
    - WorkoutApp/Features/Coach/Components/PlanModificationCard.swift
    - WorkoutApp.xcodeproj/project.pbxproj
metrics:
  duration: "~20 minutes"
  completed: "2026-04-27"
  tasks_completed: 2
  files_changed: 11
---

# Phase 10 Plan 03: Hone Coach Identity Summary

**One-liner:** Hone coach identity applied across chat bubbles, header, streaming bubble, notifications, plan loading phases, adaptation banner, and tab bar, with complete Theme.* token sweep of all Coach feature files and Xcode project registration fix for Plan 01 assets.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Restyle coach chat components with Hone identity and Theme tokens | 1704f9c | ChatBubbleView.swift, CoachHeaderView.swift, ChatInputBar.swift, OfflineBannerView.swift, CoachView.swift, PlanModificationCard.swift |
| 2 | Update Hone branding in notifications, plan loading, adaptation banner, and tab label | 489caca | NotificationScheduler.swift, PlanGenerationLoadingView.swift, TrainView.swift, MainTabView.swift |
| - | Fix: Add Plan 01 files to Xcode project | fb56e00 | WorkoutApp.xcodeproj/project.pbxproj |

## What Was Built

### Chat Component Rebrand (Task 1)

All five coach chat files updated:

- **ChatBubbleView.swift**: `HoneAvatarView(diameter: 20)` + `Text("Hone")` label replaces `Image(systemName: "figure.run")` + "Coach". User bubble uses `Theme.accent`, assistant bubble uses `Theme.surface`.
- **CoachHeaderView.swift**: `HoneAvatarView(diameter: 28)` + `Text("Hone")` headline replaces `figure.run` + "Coach".
- **ChatInputBar.swift**: `Theme.surface` replaces `Color(.systemGray6)` for text field background; `Theme.borderSubtle` replaces `Color(.systemGray4)` for inactive send button; `Theme.accent` replaces `Color("AccentColor")` for active send button.
- **OfflineBannerView.swift**: `Theme.surface` replaces `Color(.systemGray6)`.
- **CoachView.swift**: Streaming bubble uses `HoneAvatarView(diameter: 20)` + `Text("Hone")`; both streaming and error bubbles use `Theme.surface`.

### Branding Updates (Task 2)

- **NotificationScheduler.swift**: Workout reminder title: `"Hone: your {type} session is ready"`; re-engagement title: `"Hone updated your plan"`.
- **PlanGenerationLoadingView.swift**: Phases array updated to `"Hone is analyzing your goals…"`, `"Hone is building your schedule…"`, `"Hone is selecting your exercises…"`.
- **TrainView.swift**: `AdaptationSummaryBanner` restructured with `HoneAvatarView(diameter: 20)` + `Text("Hone")` label + `Theme.accent` foreground; all `Color("CardBackground")` references replaced with `Theme.surface`.
- **MainTabView.swift**: Coach tab label changed to `Label("Hone", systemImage: "message")`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing sweep] PlanModificationCard.swift color token sweep**
- **Found during:** Task 1 verification (zero raw Color in Coach/ requirement)
- **Issue:** `Color("AccentColor")` on `.tint()` of Confirm button in PlanModificationCard.swift, not in the plan's file list but within the Coach/ directory that the acceptance criteria required to be zero-raw-Color
- **Fix:** Replaced `Color("AccentColor")` with `Theme.accent`
- **Files modified:** WorkoutApp/Features/Coach/Components/PlanModificationCard.swift
- **Commit:** 1704f9c

**2. [Rule 3 - Blocking build] Theme.swift, HoneAvatarView.swift, VideoOverlayView.swift not registered in Xcode project**
- **Found during:** Post-task build verification
- **Issue:** Plan 01 created these three files on disk but never added PBXBuildFile, PBXFileReference, group children, or Sources build phase entries in project.pbxproj. Build failed with "cannot find HoneAvatarView in scope" and "cannot find Theme in scope".
- **Fix:** Added all three files to project.pbxproj with correct IDs following existing naming pattern (B010xxx prefix). Theme.swift added to Core group; HoneAvatarView.swift added to Coach/Components group; VideoOverlayView.swift added to Train group.
- **Files modified:** WorkoutApp.xcodeproj/project.pbxproj
- **Commit:** fb56e00

## Known Stubs

None — all changes are string/styling replacements with no data rendering paths that could be stubbed.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All changes are UI copy and color token replacements. Aligns with plan threat model T-10-04: string literal and styling changes only.

## Self-Check

- [x] ChatBubbleView.swift contains `HoneAvatarView(diameter: 20)` and `Text("Hone")`
- [x] ChatBubbleView.swift contains `Theme.accent` and `Theme.surface`
- [x] ChatBubbleView.swift does NOT contain `figure.run` or `Color("AccentColor")`
- [x] CoachHeaderView.swift contains `HoneAvatarView(diameter: 28)` and `Text("Hone")`
- [x] ChatInputBar.swift contains `Theme.surface` and `Theme.borderSubtle`
- [x] OfflineBannerView.swift contains `Theme.surface`
- [x] CoachView.swift streaming bubble contains `HoneAvatarView(diameter: 20)` and `Text("Hone")`
- [x] NotificationScheduler.swift contains `"Hone: your"` and `"Hone updated your plan"`
- [x] PlanGenerationLoadingView.swift contains 3x `"Hone is..."` phases
- [x] TrainView.swift AdaptationSummaryBanner contains `HoneAvatarView(diameter: 20)` and `Text("Hone")`
- [x] MainTabView.swift contains `Label("Hone", systemImage: "message")`
- [x] Zero `systemGray` references in any Swift file
- [x] Zero `"Coach"` string literals in any Swift file
- [x] Zero `figure.run` in Coach feature files
- [x] Build succeeds: `** BUILD SUCCEEDED **`
- [x] Commits 1704f9c, 489caca, fb56e00 exist in git log

## Self-Check: PASSED
