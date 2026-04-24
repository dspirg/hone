---
phase: 07-subscriptions-and-paywall
reviewed: 2026-04-24T00:00:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - Config/Dev.xcconfig
  - Config/Prod.xcconfig
  - supabase/functions/revenuecat-webhook/index.ts
  - supabase/migrations/20260416000001_add_subscription_pause.sql
  - WorkoutApp/Core/AppState.swift
  - WorkoutApp/Core/RevenueCatService.swift
  - WorkoutApp/Features/Main/Tabs/ProfileView.swift
  - WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift
  - WorkoutApp/Features/Paywall/Components/PricingCardView.swift
  - WorkoutApp/Features/Paywall/Components/ValuePropListView.swift
  - WorkoutApp/Features/Paywall/PaywallView.swift
  - WorkoutApp/Features/Paywall/PaywallViewModel.swift
  - WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift
  - WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift
  - WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift
  - WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift
  - WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift
  - WorkoutApp/Info.plist
  - WorkoutApp/WorkoutApp.swift
  - WorkoutAppTests/EntitlementGateTests.swift
  - WorkoutAppTests/PaywallViewModelTests.swift
  - WorkoutAppTests/RetentionFlowTests.swift
  - WorkoutAppTests/RevenueCatServiceTests.swift
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-04-24
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

This phase implements the RevenueCat subscription paywall, billing lifecycle webhook, cancellation retention flow (pause + discount offer), and the in-app pause UX convention. The overall architecture is sound: the webhook correctly uses `service_role` to bypass RLS, the anonymous-ID guard prevents silent database misses, and the debug bypass pattern (`#if DEBUG`) is consistently applied. The RLS migration to block client-side `subscription_status` writes is well-constructed.

Two critical issues require attention before shipping. First, a real RevenueCat sandbox API key is committed in `Config/Dev.xcconfig`, which is a credential exposure risk even for sandbox keys. Second, the webhook payload is typed as `Record<string, string>` but RevenueCat sends a nested JSON object — accessing `event.app_user_id` and `event.type` when the actual payload structure is `event.event.app_user_id` means every webhook call silently reads `undefined`, bypasses all guards, and logs the anonymous-ID rejection message or falls through to an unhandled event — the database is never updated.

Four warnings cover: a silent crash path if the Force-unwrap in `configure()` fires in production (missing `REVENUECAT_API_KEY` in Info.plist build config for a target), a race condition in `DiscountOfferViewModel.loadManagementURL()` that calls `Purchases.shared` directly instead of going through the injected service, the purchase flow not surfacing user-facing error feedback to the paywall UI when a non-cancellation purchase error occurs, and the pause write using `.eq("id", value: userId)` with an unvalidated `userId` that could be an empty string.

---

## Critical Issues

### CR-01: RevenueCat Sandbox API Key Committed to Source Control

**File:** `Config/Dev.xcconfig:8`
**Issue:** The file comment says "Safe to commit — contains only local dev keys (standard Supabase local dev defaults)" but line 8 commits a real RevenueCat sandbox API key (`appl_efPqktxpbrfQbXOhuUnuoGopQYa`). RevenueCat sandbox keys are not throwaway values — they grant access to your RevenueCat project's sandbox environment, can be used to make purchases against your App Store Connect sandbox products, and are rotatable only by regenerating the key in the RevenueCat dashboard. If the repo is ever made public or accessed by an unintended party, the key can be used to probe your subscription configuration.

**Fix:** Remove the real key value and replace with a placeholder comment. Store the actual sandbox key out of version control (e.g., in a local `.xcconfig` file that is `.gitignore`'d, or in CI secrets).

```xcconfig
// Development environment configuration
// NEVER commit real keys. Set REVENUECAT_API_KEY locally or via CI secret.
REVENUECAT_API_KEY = appl_REPLACE_WITH_DEV_SANDBOX_KEY
```

Add `Config/Dev.local.xcconfig` to `.gitignore` and use that file for actual key values during local development.

---

### CR-02: Webhook Payload Typed as Flat Object — RevenueCat Sends Nested `event` Object

**File:** `supabase/functions/revenuecat-webhook/index.ts:50-59`
**Issue:** The code parses the request body into `event: Record<string, string>` and then reads `event.app_user_id` and `event.type` at the top level. However, RevenueCat webhook payloads are structured with a top-level `event` key containing the event data:

```json
{
  "api_version": "1.0",
  "event": {
    "type": "INITIAL_PURCHASE",
    "app_user_id": "550e8400-...",
    "id": "evt_..."
  }
}
```

Reading `event.app_user_id` on the outer object returns `undefined` (not a string). The anonymous-ID guard on line 65 checks `!appUserId || appUserId.startsWith("$RCAnonymousID")` — `undefined` is falsy, so `!appUserId` is `true`, the function returns HTTP 200 with "Anonymous ID rejected", and the database is **never updated for any subscription event**. This silently breaks the entire webhook pipeline.

The `Record<string, string>` type annotation also suppresses TypeScript's ability to catch this: `event.app_user_id` types as `string` when it is actually `undefined` at runtime.

**Fix:** Parse the full payload structure and extract from the nested `event` object:

```typescript
interface RCEventPayload {
  api_version: string
  event: {
    type: string
    app_user_id: string
    id: string
    [key: string]: unknown
  }
}

let payload: RCEventPayload
try {
  payload = await req.json()
} catch {
  console.error("[revenuecat-webhook] Failed to parse JSON payload")
  return new Response("Invalid JSON", { status: 400 })
}

const appUserId: string = payload.event?.app_user_id
const eventType: string = payload.event?.type
const eventId: string = payload.event?.id
```

Validate that `payload.event` exists before accessing its properties to handle malformed payloads gracefully.

---

## Warnings

### WR-01: Force-Unwrap of `REVENUECAT_API_KEY` in `configure()` Crashes on Missing Key

**File:** `WorkoutApp/Core/RevenueCatService.swift:33`
**Issue:** `configure()` uses `as! String` to cast the value from `Bundle.main.infoDictionary`. If `REVENUECAT_API_KEY` is absent from the build's Info.plist (e.g., a new build configuration not wired to the xcconfig, or a test host that does not include the full bundle), this force-unwrap crashes at app launch. Production apps fail closed — but a crash on launch is worse than showing the paywall.

```swift
Purchases.configure(withAPIKey: Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as! String)
```

**Fix:** Use a safe fallback with a logged assertion failure:

```swift
func configure() {
    guard let apiKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String,
          !apiKey.isEmpty,
          !apiKey.hasPrefix("appl_REPLACE") else {
        assertionFailure("REVENUECAT_API_KEY missing or placeholder — check xcconfig wiring")
        return
    }
    Purchases.configure(withAPIKey: apiKey)
}
```

---

### WR-02: `DiscountOfferViewModel.loadManagementURL()` Calls `Purchases.shared` Directly, Bypassing Injection

**File:** `WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift:60`
**Issue:** `loadManagementURL()` calls `Purchases.shared.customerInfo()` directly instead of going through the injected `revenueCatService`. This creates an inconsistency with the rest of the class, which correctly delegates to `revenueCatService`. More importantly, in tests, this direct SDK call will crash or return unexpected results because the SDK is not configured in unit test environments. `PauseOptionsViewModel.loadManagementURL()` (line 83) has the same issue.

```swift
func loadManagementURL() async {
    let info = try? await Purchases.shared.customerInfo()  // bypasses injection
    managementURL = info?.managementURL ...
}
```

**Fix:** Add `fetchManagementURL() async -> URL?` to `RevenueCatServiceProtocol`, implement it in `RevenueCatService` by calling `Purchases.shared.customerInfo()`, implement a stub in `MockRevenueCatService`, and update both ViewModels to call through the service. Alternatively, fetch `managementURL` alongside `customerInfo()` calls that are already made in `CancellationRetentionView.checkDiscountEligibility()` and pass it through as a constructor argument — this is simpler and avoids widening the protocol.

---

### WR-03: Purchase Error Not Shown to the User When `userCancelled == false`

**File:** `WorkoutApp/Features/Paywall/PaywallViewModel.swift:106-108`
**Issue:** When `purchase()` throws an error (e.g., network failure, payment declined), `errorMessage` is set but there is no UI in `PaywallView` that displays it during the purchasing flow. The `paywallContent` view checks `errorMessage == "Couldn't load pricing"` (line 69 in `PaywallView.swift`) to decide whether to hide the CTA, but a purchase-time error produces a different message (the localized SDK error string). The user sees the button re-enable (the `defer` clears `isPurchasing`) with no feedback about why the purchase failed.

```swift
} catch {
    errorMessage = error.localizedDescription  // set, but never displayed in paywallContent
}
```

**Fix:** Add an error display to `paywallContent` below the CTA button, conditioned on `errorMessage != nil && errorMessage != "Couldn't load pricing"`:

```swift
if let error = viewModel.errorMessage, error != "Couldn't load pricing" {
    Text(error)
        .font(.subheadline)
        .foregroundStyle(Color.red)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .padding(.top, 8)
}
```

---

### WR-04: Pause Write Uses Unvalidated `userId` That Can Be an Empty String

**File:** `WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift:67-70`
**Issue:** `PauseOptionsViewModel` is initialized with `userId: String` from `PauseOptionsView` line 17:

```swift
let userId = appState.currentUser?.id.uuidString ?? ""
```

If `appState.currentUser` is `nil` at the moment the view appears (an edge case during sign-out race or session expiry), `userId` is `""`. The `pause()` function does not validate `userId` before writing to Supabase:

```swift
try await supabase
    .from("profiles")
    .update(["subscription_pause_until": ...])
    .eq("id", value: userId)  // matches no rows if "", silently succeeds
```

The Supabase update with `.eq("id", value: "")` will match zero rows and return no error — `pauseCompleted` is set to `true`, and the user is redirected to the Apple management URL as if the pause succeeded, but no pause is actually recorded.

**Fix:** Guard on a non-empty `userId` before writing:

```swift
func pause() async {
    guard let duration = selectedDuration else { return }
    guard !userId.isEmpty else {
        errorMessage = "Session expired. Please sign in again."
        return
    }
    // ... rest of function
}
```

Also prefer passing `UUID` instead of `String` to make the type system enforce non-empty-ness, and initialize with `appState.currentUser?.id` (a `UUID` value) to avoid the `uuidString ?? ""` fallback entirely.

---

## Info

### IN-01: `annualSubLabel` Hardcodes "~50% off" Copy

**File:** `WorkoutApp/Features/Paywall/Components/PricingCardView.swift:35`
**Issue:** The sub-label for the annual card appends `"· ~50% off"` as a hardcoded string. If pricing changes such that the annual discount is no longer 50%, this copy becomes incorrect. The rest of the pricing strings correctly read from the SDK at runtime.

```swift
return "billed \(package.storeProduct.localizedPriceString)/year · ~50% off"
```

**Fix:** Either remove the discount claim and let the price differential speak for itself, or compute the discount dynamically from the annual and monthly prices when both packages are available. At minimum, add a comment flagging this string must be updated if pricing changes.

---

### IN-02: `isOnboarded` and `onboardingCompleted` Are Duplicate Fields Tracking the Same State

**File:** `WorkoutApp/Core/AppState.swift:20-35`
**Issue:** `AppState` has two boolean fields for onboarding status: `onboardingCompleted` (used in `ContentView` for routing) and `isOnboarded` (described as "mirrors onboardingCompleted for SUBS-03 compatibility"). Both are set together in `markOnboardingComplete()` and both default to `false`. Having two fields tracking the same logical state is a maintenance hazard — future code that only sets one will produce a subtle routing bug.

**Fix:** Remove `isOnboarded` and update any SUBS-03 consumer to use `onboardingCompleted` directly. If `isOnboarded` is truly needed as a distinct concept (e.g., a different semantic), document the distinction clearly in the property comment.

---

### IN-03: `CancellationRetentionView` Uses `Purchases.shared` Directly, Not the Injected Service

**File:** `WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift:37`
**Issue:** `checkDiscountEligibility()` calls `Purchases.shared.customerInfo()` directly without going through `appState.revenueCatService`. This is inconsistent with the project's dependency-injection pattern and means this code path cannot be exercised by the existing `MockRevenueCatService` in tests. This is why there is no test covering the eligibility check logic.

```swift
let info = try await Purchases.shared.customerInfo()
```

**Fix:** Use `appState.revenueCatService` via a protocol method (the same fix as WR-02 above). Add a `fetchCustomerInfo() async throws -> CustomerInfo` method to the protocol, or restructure to pass the eligibility result down from a parent that already has it.

---

_Reviewed: 2026-04-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
