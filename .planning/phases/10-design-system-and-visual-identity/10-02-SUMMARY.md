---
phase: 10-design-system-and-visual-identity
plan: "02"
subsystem: ui-theme
tags: [color-tokens, theme, refactor, dark-mode]
dependency_graph:
  requires: [10-01]
  provides: [unified-color-tokens-all-screens]
  affects: [all-view-files]
tech_stack:
  added: []
  patterns: [Theme.accent, Theme.background, Theme.surface]
key_files:
  modified:
    - WorkoutApp/Core/Components/ChipView.swift
    - WorkoutApp/Core/Components/OnboardingProgressView.swift
    - WorkoutApp/Features/Disclaimer/DisclaimerView.swift
    - WorkoutApp/Features/Progress/Components/PRBadgeView.swift
    - WorkoutApp/Features/Progress/Components/StreakCard.swift
    - WorkoutApp/Features/Progress/Components/WeeklyRingView.swift
    - WorkoutApp/Features/Progress/Components/ChartSectionView.swift
    - WorkoutApp/Features/Progress/Components/SessionDetailView.swift
    - WorkoutApp/Features/Progress/ProgressView.swift
    - WorkoutApp/Features/Auth/AuthView.swift
    - WorkoutApp/Features/Auth/PasswordResetView.swift
    - WorkoutApp/Features/Train/ExerciseDetailView.swift
    - WorkoutApp/Features/Train/FilterChipRow.swift
    - WorkoutApp/Features/Train/ExerciseLibraryRowView.swift
    - WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift
    - WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift
    - WorkoutApp/Features/Paywall/PaywallView.swift
    - WorkoutApp/Features/Paywall/Components/PricingCardView.swift
    - WorkoutApp/Features/Paywall/Components/ValuePropListView.swift
    - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
    - WorkoutApp/Features/Session/SessionView.swift
    - WorkoutApp/Features/Session/Components/SessionProgressBar.swift
    - WorkoutApp/Features/Session/Components/RestTimerOverlay.swift
    - WorkoutApp/Features/Session/Components/SetLogRow.swift
    - WorkoutApp/Features/Main/Tabs/HomeView.swift
    - WorkoutApp/Features/Main/MainTabView.swift
    - WorkoutApp/Features/Onboarding/OnboardingView.swift
    - WorkoutApp/Features/Onboarding/Components/OnboardingProgressView.swift
    - WorkoutApp/Features/Onboarding/Components/ChipView.swift
    - WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift
    - WorkoutApp/Features/Onboarding/Cards/EquipmentCardView.swift
    - WorkoutApp/Features/PlanPreview/PlanPreviewView.swift
    - WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift
    - WorkoutApp/Features/PlanPreview/Components/WorkoutDayCardView.swift
    - WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift
decisions:
  - "Replaced Color(\"AccentColor\") with Theme.accent, Color(\"AppBackground\") with Theme.background, Color(\"CardBackground\") with Theme.surface across all 35 view files in a single atomic sweep"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-27"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 35
---

# Phase 10 Plan 02: Color Sweep (Non-Coach View Files) Summary

**One-liner:** Full color token sweep replacing all 87 raw Color("AccentColor"), Color("AppBackground"), and Color("CardBackground") references with Theme.accent, Theme.background, and Theme.surface across 35 view files.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Color sweep — non-Coach view files | a67904e | 35 files modified |

## What Was Built

Systematic color token migration across every non-Coach view file in the app. After this plan, the design token layer established in Plan 01 (Theme.swift) is fully adopted by auth, onboarding, paywall, session, progress, train, plan preview, home, disclaimer, and main tab screens.

**Replacements applied:**
- `Color("AccentColor")` -> `Theme.accent` (50 occurrences across 35 files)
- `Color("AppBackground")` -> `Theme.background` (10 files)
- `Color("CardBackground")` -> `Theme.surface` (25+ files)

**Files covered by feature area:**
- Core components (2): ChipView, OnboardingProgressView
- Auth (2): AuthView, PasswordResetView
- Disclaimer (1): DisclaimerView
- Progress (5): PRBadgeView, StreakCard, WeeklyRingView, ChartSectionView, SessionDetailView, ProgressView
- Train (3): ExerciseDetailView, FilterChipRow, ExerciseLibraryRowView
- Paywall (5): PauseOptionsView, DiscountOfferView, PaywallView, PricingCardView, ValuePropListView
- Session (5): SessionSummaryView, SessionView, SessionProgressBar, RestTimerOverlay, SetLogRow
- Main (2): HomeView, MainTabView
- Onboarding (5): OnboardingView, OnboardingProgressView, ChipView, InjuriesCardView, EquipmentCardView
- PlanPreview (4): PlanPreviewView, PlanGenerationLoadingView, WorkoutDayCardView, ExerciseRowView

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

```
=== Remaining raw Color references (should be 0 in non-Coach files) ===
0
=== Theme.accent usage count ===
50
```

All acceptance criteria confirmed:
- Zero occurrences of Color("AccentColor") in all 35 files
- Zero occurrences of Color("AppBackground") in all 35 files
- Zero occurrences of Color("CardBackground") in all 35 files
- MainTabView.swift contains .tint(Theme.accent)
- AuthView.swift contains Theme.accent (2 occurrences)
- PaywallView.swift contains Theme.background
- ExerciseLibraryRowView.swift contains Theme.surface
- PlanGenerationLoadingView.swift contains Theme.accent (5 occurrences)
- ChartSectionView.swift contains Theme.accent (3 occurrences)
- ExerciseRowView preview contains Theme.surface
- No hardcoded hex color strings introduced

## Known Stubs

None — this is a pure refactor. No data flows or UI stubs introduced.

## Threat Flags

None — this is a purely cosmetic token replacement with no data flow, auth, network, or schema changes.

## Self-Check: PASSED

- All 35 files modified and committed in a67904e
- Zero raw Color references remain in swept files (verified via grep)
- 50 Theme.accent usages confirmed across the codebase
