---
phase: 01-foundation
plan: 03
subsystem: ui-auth
status: complete
tags: [swiftui, auth, supabase, apple-sign-in, disclaimer, tab-bar]
dependency_graph:
  requires: [01-01]
  provides: [disclaimer-ui, auth-ui, tab-shell]
  affects: []
tech_stack:
  added: []
  patterns:
    - "@Observable @MainActor ViewModel pattern (Swift 6 concurrency compliance)"
    - "UIViewRepresentable wrapper for ASAuthorizationAppleIDButton with SHA-256 nonce"
    - "AuthMode enum for login/signup toggle on single screen"
    - "ContentView routing: isAuthenticated ? MainTabView : NavigationStack { AuthView }"
key_files:
  created:
    - WorkoutApp/Features/Auth/AuthViewModel.swift
    - WorkoutApp/Features/Auth/SignInWithAppleButton.swift
    - WorkoutApp/Features/Auth/PasswordResetView.swift
    - WorkoutApp/Features/Auth/AuthView.swift
    - WorkoutApp/Features/Disclaimer/DisclaimerView.swift
    - WorkoutApp/Features/Main/MainTabView.swift
    - WorkoutApp/Features/Main/Tabs/HomeView.swift
    - WorkoutApp/Features/Main/Tabs/TrainView.swift
    - WorkoutApp/Features/Main/Tabs/CoachView.swift
    - WorkoutApp/Features/Main/Tabs/ProfileView.swift
  modified:
    - WorkoutApp/WorkoutApp.swift
    - WorkoutApp/Core/AppState.swift
    - WorkoutApp/Core/SupabaseClient.swift
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - "@MainActor applied to both AppState and AuthViewModel for Swift 6 strict concurrency compliance"
  - "SignInWithAppleButton uses @Binding var rawNonce: String to expose nonce to parent AuthView"
  - "All 10 feature Swift files registered in project.pbxproj with proper PBXGroup hierarchy"
metrics:
  duration_minutes: 8
  tasks_completed: 3
  tasks_total: 3
  files_created: 10
  files_modified: 4
  completed_date: "2026-04-16"
---

# Phase 01 Plan 03: Auth UI, Disclaimer Modal, and Tab Shell Summary

**One-liner:** Complete Phase 1 auth flow — disclaimer modal, login/signup screen with Apple Sign-In and SHA-256 nonce, password reset, and 4-tab empty-state shell wired into WorkoutApp.swift.

## Status

**Tasks 1, 2, and 3: COMPLETE** — All implementation files created, build succeeds, and UI visually verified in iOS Simulator.

## What Was Built

### Task 1: AuthViewModel, SignInWithAppleButton, DisclaimerView, PasswordResetView

- **AuthViewModel** (`@Observable @MainActor`): 4 auth methods — signUp, signIn, sendPasswordReset, signInWithApple. Error mapping to exact UI-SPEC Copywriting Contract strings. `defer { isLoading = false }` pattern on all async methods. T-03-06: Apple `fullName` captured immediately and written to profiles table (Pitfall 1 mitigated).
- **SignInWithAppleButton** (`UIViewRepresentable`): SHA-256 nonce via `SecRandomCopyBytes` (never arc4random). Raw nonce exposed via `@Binding var rawNonce` to parent. Hash sent to Apple; raw nonce sent to Supabase (T-03-01 mitigated).
- **DisclaimerView**: "Before You Train" heading, physician-consult body, "I Understand" CTA, `.interactiveDismissDisabled(true)` hard block (D-07, SAFE-01).
- **PasswordResetView**: Two states — form with "Send Reset Link" CTA, and success state "Check your email" with no CTA. User exits via system back button.

### Task 2: AuthView, MainTabView, Tab Empty States, WorkoutApp.swift wiring

- **AuthView**: `AuthMode` enum for login/signup toggle. Segmented `.pickerStyle`. Apple Sign-In as primary CTA above "or" divider (D-02). Display Name field shown in sign-up only. Email + SecureField. Inline error display. "Forgot password?" NavigationLink in login state only (D-03). Primary CTA shows ProgressView when loading (T-03-04).
- **MainTabView**: 4-tab TabView — Home (`house`), Train (`figure.strengthtraining.traditional`), Coach (`message`), Profile (`person`). `.tint(Color("AccentColor"))` for active tab.
- **HomeView**: `@Environment(AppState.self)` — "Welcome, [email]!" greeting (D-05). UI-SPEC empty state body copy.
- **TrainView, CoachView, ProfileView**: Empty states with SF Symbols, UI-SPEC headings and body copy.
- **WorkoutApp.swift**: All placeholder `Text()` views replaced — DisclaimerView, AuthView, MainTabView wired. Zero "placeholder" strings remain.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | `c0cc52d` | feat(01-03): AuthViewModel, SignInWithAppleButton, DisclaimerView, PasswordResetView |
| Task 2 | `8f6ed4a` | feat(01-03): AuthView, MainTabView, tab empty states, wire WorkoutApp.swift |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing `import Foundation` in SupabaseClient.swift**
- **Found during:** Task 1 verification (xcodebuild)
- **Issue:** `URL` and `Bundle` are Foundation types; without the import they were out of scope
- **Fix:** Added `import Foundation` to SupabaseClient.swift
- **Files modified:** `WorkoutApp/Core/SupabaseClient.swift`
- **Commit:** `c0cc52d`

**2. [Rule 1 - Bug] Wrong argument order in SupabaseClientOptions auth init**
- **Found during:** Task 1 verification (xcodebuild)
- **Issue:** `redirectToURL` must precede `flowType` per Supabase Swift SDK signature
- **Fix:** Reordered to `redirectToURL:` before `flowType:`
- **Files modified:** `WorkoutApp/Core/SupabaseClient.swift`
- **Commit:** `c0cc52d`

**3. [Rule 1 - Bug] AppState missing @MainActor — Swift 6 data race**
- **Found during:** Task 1 verification (xcodebuild)
- **Issue:** `.task { await appState.listenForAuthChanges() }` in WorkoutApp.swift (main actor) sending AppState to nonisolated context causes data race under Swift 6 strict concurrency
- **Fix:** Added `@MainActor` annotation to `AppState` class
- **Files modified:** `WorkoutApp/Core/AppState.swift`
- **Commit:** `c0cc52d`

**4. [Rule 1 - Bug] AuthViewModel missing @MainActor — Swift 6 data race**
- **Found during:** Task 2 verification (xcodebuild)
- **Issue:** `Task { await viewModel.sendPasswordReset() }` in PasswordResetView sending `@Observable` ViewModel across actor boundaries
- **Fix:** Added `@MainActor` annotation to `AuthViewModel` class
- **Files modified:** `WorkoutApp/Features/Auth/AuthViewModel.swift`
- **Commit:** `8f6ed4a`

**5. [Rule 3 - Blocking] New Swift files not registered in project.pbxproj**
- **Found during:** Task 2 verification (xcodebuild)
- **Issue:** DisclaimerView, AuthView, MainTabView, tab views all "cannot find type in scope" because files existed on disk but were not added to Xcode project
- **Fix:** Added PBXBuildFile, PBXFileReference, PBXGroup (Features/Auth/Disclaimer/Main/Tabs), and Sources build phase entries for all 10 new files
- **Files modified:** `WorkoutApp.xcodeproj/project.pbxproj`
- **Commit:** `8f6ed4a`

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `appState.currentUser?.email ?? ""` | `HomeView.swift:18` | Display name not yet loaded from profiles table — email used as fallback per plan spec (D-05); display_name wired in Phase 2 onboarding |

## Threat Surface Scan

No new threat surface introduced beyond what the plan's threat model covers. All T-03-xx mitigations implemented as specified.

## Task 3: Human Verification — APPROVED

User visually verified all screens in iOS Simulator:
1. ✓ Disclaimer modal "Before You Train" — hard blocks swipe-to-dismiss, dismisses on "I Understand"
2. ✓ Auth screen — "Welcome back." heading, login/signup toggle, Apple Sign-In above divider
3. ✓ Sign Up toggle — "Let's get started." heading, Display Name field appears
4. ✓ "Forgot password?" — navigates to password reset screen
5. ✓ Styling — orange accent, correct layout

## Self-Check

- [x] `WorkoutApp/Features/Auth/AuthViewModel.swift` — exists, contains `@Observable`, all 4 methods, error mapping
- [x] `WorkoutApp/Features/Auth/SignInWithAppleButton.swift` — exists, contains `SecRandomCopyBytes`, `SHA256`, `UIViewRepresentable`
- [x] `WorkoutApp/Features/Disclaimer/DisclaimerView.swift` — exists, contains "I Understand", `interactiveDismissDisabled`, "Before You Train"
- [x] `WorkoutApp/Features/Auth/PasswordResetView.swift` — exists, contains "Send Reset Link", "Check your email", `emailSent`
- [x] `WorkoutApp/Features/Auth/AuthView.swift` — exists, contains `enum AuthMode`, "Welcome back.", "Let's get started.", "Forgot password?", "Sign In", "Create Account", `.segmented`
- [x] `WorkoutApp/Features/Main/MainTabView.swift` — exists, contains `TabView`, `figure.strengthtraining.traditional`, `Color("AccentColor")`
- [x] `WorkoutApp/Features/Main/Tabs/HomeView.swift` — exists, contains "Welcome"
- [x] `WorkoutApp/Features/Main/Tabs/TrainView.swift` — exists, contains "Your workouts live here"
- [x] `WorkoutApp/Features/Main/Tabs/CoachView.swift` — exists, contains "Meet your AI coach"
- [x] `WorkoutApp/Features/Main/Tabs/ProfileView.swift` — exists, contains "Your profile"
- [x] `WorkoutApp/WorkoutApp.swift` — contains "DisclaimerView", "MainTabView", "AuthView", 0 "placeholder" matches
- [x] Build: `xcodebuild BUILD SUCCEEDED`
- [x] Commits `c0cc52d` and `8f6ed4a` exist in git log

## Self-Check: PASSED
