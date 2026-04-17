---
phase: 03-ai-onboarding-and-plan-generation
plan: 05
subsystem: app-routing
tags: [routing, onboarding, app-state, integration, swift, swiftui]
dependency_graph:
  requires: [03-02, 03-03, 03-04]
  provides: [end-to-end-onboarding-flow, 3-branch-routing, home-plan-summary]
  affects: [WorkoutApp.swift, AppState.swift, HomeView.swift]
tech_stack:
  added: []
  patterns: [3-branch-routing, onboarding-flag-fetch, fullscreencover-coordinator]
key_files:
  created:
    - WorkoutAppTests/AppStateRoutingTests.swift
  modified:
    - WorkoutApp/Core/AppState.swift
    - WorkoutApp/WorkoutApp.swift
    - WorkoutApp/Features/Main/Tabs/HomeView.swift
decisions:
  - "OnboardingFlowView placed in WorkoutApp.swift as a separate struct below ContentView — keeps all root routing logic in one file without creating a new file for a small coordinator"
  - "fullScreenCover(.constant(true)) pattern used for Branch 2 — ensures the cover cannot be accidentally dismissed, which would strand an authenticated-but-not-onboarded user with no navigation path"
  - "fetchOnboardingStatus defaults to false on any error — safe fallback sends user through onboarding rather than skipping it (aligns with T-03-14 threat mitigation)"
metrics:
  duration: ~10 minutes
  completed_date: "2026-04-17"
  tasks_completed: 1
  tasks_total: 2
  files_changed: 4
---

# Phase 03 Plan 05: End-to-End Onboarding Integration Summary

**One-liner:** 3-branch ContentView routing with Supabase-backed onboarding flag, OnboardingFlowView coordinator wiring onboarding cards to plan generation and preview, and HomeView plan summary card from CoreData.

## What Was Built

### AppState.swift — Onboarding Flag

Added `onboardingCompleted: Bool = false` property to AppState. On every `.initialSession`, `.signedIn`, `.tokenRefreshed`, `.userUpdated` auth event, `fetchOnboardingStatus()` is called if the session is non-nil. This queries the `profiles.onboarding_completed` column from Supabase and sets the local flag. On `.signedOut`, the flag is reset to `false`. A public `markOnboardingComplete()` method updates the local flag after the user taps "Start Training" (Supabase has already been updated by `PlanGenerationService.setOnboardingCompleted()` per Pitfall 4 strict ordering from Plan 03).

### WorkoutApp.swift — ContentView 3-Branch Routing

Replaced the 2-branch ContentView with a 3-branch version:
- **Branch 1:** `isAuthenticated && onboardingCompleted` -> `MainTabView()`
- **Branch 2:** `isAuthenticated && !onboardingCompleted` -> `OnboardingFlowView()` via fullScreenCover
- **Branch 3:** `!isAuthenticated` -> `NavigationStack { AuthView() }`

### WorkoutApp.swift — OnboardingFlowView Coordinator

New `OnboardingFlowView` struct added to WorkoutApp.swift. Manages `@State private var planService`, `showPlanPreview`, and `userProfile`. When `OnboardingView.onComplete` fires, it sets `userProfile` and flips `showPlanPreview = true`, causing `PlanPreviewView` to appear. `PlanPreviewView.onAppear` calls `viewModel.startGeneration()` automatically. The `onStartTraining` closure calls `planService.resetRegenerationCounter()` then `appState.markOnboardingComplete()`, triggering ContentView re-evaluation which routes to `MainTabView`.

### HomeView.swift — Plan Summary Card

Replaced the empty state HomeView with a NavigationStack-wrapped ScrollView. On `.task`, calls `loadActivePlan()` which creates a `WorkoutPlanRepository` and calls `fetchActivePlan(userId:)`. If a plan is found, displays a summary card with:
- Plan name in `.title2.weight(.semibold)`
- Goal summary in `.body .secondary`
- Training day count in `.subheadline .secondary`
- `Color("CardBackground")` background with 16pt corner radius

### AppStateRoutingTests.swift — 6 Unit Tests

New test file with `@MainActor` test class verifying:
1. `testNotAuthenticatedDefaultState` — both flags false by default (Branch 3)
2. `testAuthenticatedNotOnboardedMatchesOnboardingBranch` — Branch 2 condition
3. `testAuthenticatedAndOnboardedMatchesMainTabBranch` — Branch 1 condition
4. `testMarkOnboardingCompleteUpdatesFlag` — `markOnboardingComplete()` sets flag
5. `testSignOutResetsAllState` — all three properties reset correctly
6. `testDefaultOnboardingIsFalse` — confirms default value

## Acceptance Criteria Verification

- [x] AppState.swift has `var onboardingCompleted: Bool = false`
- [x] `listenForAuthChanges` calls `await fetchOnboardingStatus()` when session is not nil
- [x] `fetchOnboardingStatus()` queries `profiles` table for `onboarding_completed`
- [x] `fetchOnboardingStatus()` defaults to `onboardingCompleted = false` in catch block
- [x] AppState has `func markOnboardingComplete()` setting flag to true
- [x] Sign-out case sets `onboardingCompleted = false`
- [x] ContentView has exactly 3 if/else branches checking isAuthenticated and onboardingCompleted
- [x] Branch order: (1) authenticated+onboarded->MainTabView, (2) authenticated+!onboarded->OnboardingFlowView, (3) else->AuthView
- [x] ContentView passes `.environment(appState)` to OnboardingFlowView
- [x] OnboardingFlowView coordinates OnboardingView -> PlanPreviewView transition
- [x] OnboardingFlowView `onStartTraining` calls `planService.resetRegenerationCounter()` and `appState.markOnboardingComplete()`
- [x] HomeView creates WorkoutPlanRepository and calls `fetchActivePlan(userId:)`
- [x] HomeView displays plan name in `.title2.weight(.semibold)` and goal summary in `.body .secondary`
- [x] HomeView plan card uses `Color("CardBackground")` and 16pt corner radius
- [x] AppStateRoutingTests has 6 test methods

## Deviations from Plan

None — plan executed exactly as written.

## Task 2: Awaiting Human Verification

Task 2 is a `checkpoint:human-verify` gate. The following infrastructure prerequisites must be completed before end-to-end testing:

- Supabase migrations applied: `supabase db push` (profiles fitness columns + workout_plans table)
- Edge Function deployed: `supabase functions deploy generate-plan`
- OpenAI API key set: `supabase secrets set OPENAI_API_KEY=sk-...`

See the plan's Task 2 verification steps for the 7-scenario test checklist.

## Threat Surface Scan

No new security-relevant surfaces introduced beyond those in the plan's threat model:
- `fetchOnboardingStatus()` query is read-only and protected by Supabase RLS
- `markOnboardingComplete()` only updates local state — Supabase write is done by PlanGenerationService (T-03-14 satisfied)
- HomeView reads from local CoreData only — no new network surface

## Known Stubs

None — HomeView is wired to real CoreData via `WorkoutPlanRepository.fetchActivePlan`. The plan summary card will display real data after onboarding completes and the plan is persisted.

## Self-Check: PASSED

- FOUND: WorkoutApp/Core/AppState.swift (modified)
- FOUND: WorkoutApp/WorkoutApp.swift (modified)
- FOUND: WorkoutApp/Features/Main/Tabs/HomeView.swift (modified)
- FOUND: WorkoutAppTests/AppStateRoutingTests.swift (created)
- FOUND: .planning/phases/03-ai-onboarding-and-plan-generation/03-05-SUMMARY.md
- FOUND: commit 37e90fc (feat(03-05): AppState onboarding flag, 3-branch routing, OnboardingFlowView, HomeView plan summary, routing tests)
