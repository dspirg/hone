---
phase: 01-foundation
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - WorkoutApp.xcodeproj/project.pbxproj
  - WorkoutApp/WorkoutApp.swift
  - WorkoutApp/Core/AppState.swift
  - WorkoutApp/Core/SupabaseClient.swift
  - WorkoutApp/Assets.xcassets/AccentColor.colorset/Contents.json
  - WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json
  - WorkoutApp/Assets.xcassets/CardBackground.colorset/Contents.json
  - WorkoutApp/Info.plist
  - WorkoutApp/WorkoutApp.entitlements
  - Config/Dev.xcconfig
  - Config/Prod.xcconfig
  - supabase/config.toml
  - supabase/migrations/00000000000000_create_profiles.sql
  - WorkoutAppTests/WorkoutAppTests.swift
  - WorkoutAppUITests/WorkoutAppUITests.swift
  - WorkoutApp/AIPrompts/SafetySystemPrompt.md
  - WorkoutApp/Tests/RedTeamTests/SafetyGuardrailTests.md
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
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

This review covers the Phase 1 foundation scaffold: Xcode project configuration, the app entry point, core auth infrastructure (AppState, SupabaseClient, AuthViewModel, all auth views), the disclaimer gate, main tab shell, placeholder tab views, the Supabase migration, and the AI safety prompt documents.

The architecture is sound — PKCE flow, Keychain storage, cryptographic nonces, SECURITY DEFINER trigger with empty search_path, and the server-side AI proxy pattern are all correctly implemented. However, three critical issues were found that can cause runtime crashes or silent security failures in production.

The most urgent issue is a pair of force-unwraps in `SupabaseClient.swift` that will crash the app at launch in any build where xcconfig injection is misconfigured — a realistic scenario for a CI build, a new developer onboarding, or a production archive that was built before the Prod.xcconfig placeholders were filled in. The second critical issue is a silently-swallowed error in the deep-link URL handler in `WorkoutApp.swift`. The third is a URL scheme that is trivially interceptable by other apps on the device.

---

## Critical Issues

### CR-01: Force-unwrap crash at launch if xcconfig values are absent

**File:** `WorkoutApp/Core/SupabaseClient.swift:10-11`

**Issue:** Both `SUPABASE_URL` and `SUPABASE_ANON_KEY` are read from `Info.plist` with a force-cast (`as! String`) followed immediately by a force-unwrap (`!`) on the `URL(string:)` call. If either key is missing from `Info.plist` at runtime — which happens when `Dev.xcconfig` or `Prod.xcconfig` is not assigned to a build configuration, when a developer opens the project without the config files present, or when `Prod.xcconfig` still contains the literal placeholder strings `REPLACE_WITH_HOSTED_URL` / `REPLACE_WITH_HOSTED_ANON_KEY` — the app crashes at launch before any UI appears.

`URL(string: "REPLACE_WITH_HOSTED_URL")` returns `nil`, so the `!` on line 10 triggers a fatal crash. This is a production reliability issue, not just a developer inconvenience.

**Fix:**
```swift
// SupabaseClient.swift
private func loadRequiredConfig(_ key: String) -> String {
    guard let value = Bundle.main.infoDictionary?[key] as? String,
          !value.isEmpty,
          !value.hasPrefix("REPLACE_WITH") else {
        fatalError("Missing or unconfigured Info.plist key: \(key). Check xcconfig assignment.")
    }
    return value
}

private func loadRequiredURL(_ key: String) -> URL {
    let raw = loadRequiredConfig(key)
    guard let url = URL(string: raw) else {
        fatalError("Invalid URL for Info.plist key \(key): \(raw)")
    }
    return url
}

let supabase = SupabaseClient(
    supabaseURL: loadRequiredURL("SUPABASE_URL"),
    supabaseKey: loadRequiredConfig("SUPABASE_ANON_KEY"),
    options: SupabaseClientOptions(
        auth: .init(
            storage: KeychainLocalStorage(service: Bundle.main.bundleIdentifier!),
            redirectToURL: URL(string: "workout://auth-callback"),
            flowType: .pkce
        )
    )
)
```

Using `fatalError` with a descriptive message is strictly preferable to a silent force-unwrap crash: it surfaces the root cause immediately in Xcode and crash logs rather than a generic `EXC_BAD_INSTRUCTION` at an opaque address.

---

### CR-02: Deep-link auth error silently discarded — password reset may silently fail

**File:** `WorkoutApp/WorkoutApp.swift:31`

**Issue:** The URL handler calls `try? await supabase.auth.session(from: url)` with `try?`, which discards any error. If the session exchange fails — for example because the recovery token has expired, the URL is malformed, or there is a network error — the app silently does nothing. The user tapped a password-reset link from their email, the app opened, and nothing happened. There is no error state surfaced to the user and no signal to `AppState` or the UI.

```swift
// Current — error is swallowed
Task {
    try? await supabase.auth.session(from: url)
}
```

**Fix:**
```swift
.onOpenURL { url in
    Task {
        do {
            try await supabase.auth.session(from: url)
        } catch {
            // Surface the failure so the user knows the link didn't work.
            // AppState is @MainActor so this assignment is safe from a Task.
            appState.deepLinkError = "The reset link has expired or is invalid. Please request a new one."
        }
    }
}
```

`AppState` should add a `deepLinkError: String?` property and `AuthView` / `PasswordResetView` should observe and display it. At minimum, logging the error is required so the failure is diagnosable.

---

### CR-03: Custom URL scheme `workout://` is interceptable by any app on the device

**File:** `WorkoutApp/Info.plist:27-29` and `WorkoutApp/WorkoutApp.swift:31`

**Issue:** The auth callback uses a plain custom URL scheme (`workout://auth-callback`). On iOS, any app installed on the device can register the same URL scheme. If a malicious app registers `workout://`, it can intercept the password-reset deep link, receiving the recovery token before the legitimate app does. This is a known OAuth/PKCE callback interception attack vector for custom URL schemes.

Apple's recommended mitigation for this exact scenario is Universal Links (`https://` callbacks via Associated Domains), which the OS routes exclusively to the registered app and cannot be intercepted by a third party.

The PKCE flow in `SupabaseClient.swift` is correctly configured and significantly reduces the damage from token interception, but token interception still allows an attacker to initiate a password reset session for the victim's account.

**Fix:**

1. Register a domain (e.g., `workoutapp.example.com`) and add an Apple App Site Association (AASA) file at `https://workoutapp.example.com/.well-known/apple-app-site-association`.
2. Add the `com.apple.developer.associated-domains` entitlement to `WorkoutApp.entitlements`.
3. Change the `redirectToURL` in `SupabaseClient.swift` and the `resetPasswordForEmail` call in `AuthViewModel.swift` to use the Universal Link URL.
4. Update `supabase/config.toml`'s `additional_redirect_urls` to include the Universal Link URL.

Custom schemes are acceptable for development only. Before App Store submission, the auth callback should use Universal Links.

---

## Warnings

### WR-01: Missing input validation on email field before network call

**File:** `WorkoutApp/Features/Auth/AuthViewModel.swift:22-35` and `38-50`

**Issue:** `signUp()` and `signIn()` call the Supabase API even when the email or password fields are empty strings. An empty-string email produces a network round-trip and a server-side error, which is then mapped by `mapAuthError` to the generic "Something went wrong" message — giving the user no indication that they left a field blank. Password is never validated for minimum length client-side either, even though the server enforces 8 characters.

**Fix:**
```swift
func signUp() async {
    guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
        errorMessage = "Please enter your email address."
        return
    }
    guard password.count >= 8 else {
        errorMessage = "Password must be at least 8 characters."
        return
    }
    // ... rest of signUp
}
```

Apply the same guard pattern to `signIn()`. The minimum password length of 8 is already set in `supabase/config.toml:97` — client-side validation should match.

---

### WR-02: `mapAuthError` matches on `localizedDescription` — locale-sensitive and brittle

**File:** `WorkoutApp/Features/Auth/AuthViewModel.swift:103-116`

**Issue:** Error classification in `mapAuthError` depends on substring matching against `error.localizedDescription.lowercased()`. `localizedDescription` is locale-dependent — the string "invalid login credentials" is the English localization of the GoTrue error; on a device set to a non-English locale, the description may be translated by the OS or a localization layer, causing all auth errors to fall through to the generic "Something went wrong" message. Additionally, if Supabase/GoTrue ever changes its English error messages, all classification silently degrades.

**Fix:** Match against error codes or typed error cases rather than string content. The Supabase Swift SDK exposes typed `AuthError` cases. For example:

```swift
private func mapAuthError(_ error: Error) -> String {
    if let authError = error as? AuthError {
        switch authError {
        case .api(let apiError) where apiError.code == "invalid_credentials":
            return "Incorrect password. Try again or reset your password."
        // ... other typed cases
        default:
            return "Something went wrong. Please try again."
        }
    }
    if (error as NSError).domain == NSURLErrorDomain {
        return "Connection failed. Check your internet and try again."
    }
    return "Something went wrong. Please try again."
}
```

Verify the exact `AuthError` cases against the Supabase Swift SDK 2.x API before implementing.

---

### WR-03: `showPasswordResetForm` state on `AppState` is never consumed

**File:** `WorkoutApp/Core/AppState.swift:12` and `27-28`

**Issue:** `AppState.showPasswordResetForm` is set to `true` when a `passwordRecovery` auth event fires, but no view in the reviewed codebase reads or reacts to this property. The intended behavior (showing the password reset form after a deep link callback) is therefore not implemented — a user who taps a password-reset email link will have the app open and the auth state listener will set this flag, but nothing in the UI will show the reset form.

This is a logic gap: the flag is set but the consumer is missing, making the feature partially wired. This needs to be connected before the auth flow can be considered complete.

**Fix:** `ContentView` or `AuthView` should observe `appState.showPasswordResetForm` and present `PasswordResetView` when it is `true`. For example, add a `.sheet(isPresented: Binding(...))` in `ContentView` that presents `PasswordResetView` when `showPasswordResetForm` is true, and resets the flag on dismiss.

---

### WR-04: `enable_confirmations = false` in Supabase auth config — users can sign up with unverified emails

**File:** `supabase/config.toml:110`

**Issue:** Email confirmation is disabled (`enable_confirmations = false`). This is noted in the config comment as intentional for development, but it has a meaningful security implication if this setting is carried to production: users can create accounts and sign in with any email address they do not own. This enables account squatting and subscription management issues (e.g., a user could sign up with another person's email address, and the real owner of that email would find they already have an account when they try to sign up).

**Fix:** This is acceptable for the local dev environment. Add a comment that explicitly flags this as a dev-only setting and add a checklist item (or a CI guard) to ensure `enable_confirmations = true` is set in the hosted Supabase project before any production traffic. Similarly, `secure_password_change = false` on line 113 should be enabled in production.

---

## Info

### IN-01: `AccentColor` has no dark-mode variant

**File:** `WorkoutApp/Assets.xcassets/AccentColor.colorset/Contents.json`

**Issue:** `AccentColor` defines only a single `"universal"` variant (RGB approximately `#FF6B35` — a strong orange-red). It has no `"dark"` appearance entry. `AppBackground` and `CardBackground` both correctly provide light and dark variants. The accent color at full sRGB saturation will render identically in both light and dark mode, which may not meet contrast requirements under WCAG AA on dark backgrounds. This should be reviewed with the design spec.

**Fix:** Add a dark-mode variant to `AccentColor/Contents.json` following the same structure as `AppBackground.colorset`, adjusting luminance as appropriate for dark backgrounds.

---

### IN-02: `PasswordResetView` creates a new `AuthViewModel` instance — email state is isolated from `AuthView`

**File:** `WorkoutApp/Features/Auth/PasswordResetView.swift:8`

**Issue:** `PasswordResetView` instantiates its own `@State private var viewModel = AuthViewModel()`. This means the email field in `PasswordResetView` always starts empty, even if the user had already typed their email in `AuthView` before tapping "Forgot password?". This is a minor UX friction point, not a bug, but it's worth noting. The view model is not shared with `AuthView`.

**Fix:** Consider passing the email string from `AuthView` to `PasswordResetView` as an initializer parameter: `PasswordResetView(initialEmail: viewModel.email)` and pre-populating the `viewModel.email` field.

---

### IN-03: Dev anon key is the public Supabase demo key — safe to commit, but should be documented

**File:** `Config/Dev.xcconfig:5`

**Issue:** The `SUPABASE_ANON_KEY` in `Dev.xcconfig` is the well-known public Supabase local-dev demo JWT (`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`). This is the default key Supabase CLI generates for local Docker environments and is safe to commit since it only works against `localhost:54321`. The comment on line 2 correctly states this.

However, there is no `.gitignore` entry or CI guard preventing a developer from accidentally populating `Prod.xcconfig` with real hosted keys and committing them. The `Prod.xcconfig` comment says "DO NOT COMMIT real values" but relies on human discipline rather than a technical control.

**Fix:** Add `Config/Prod.xcconfig` to `.gitignore` (while keeping `Config/Dev.xcconfig` tracked), or use environment variable substitution (`env(SUPABASE_URL)`) for the production config and populate via CI secrets rather than a committed file.

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
