---
phase: 07-subscriptions-and-paywall
reviewed: 2026-04-24T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - supabase/functions/revenuecat-webhook/index.ts
  - WorkoutApp/Features/Main/Tabs/HomeView.swift
  - WorkoutApp/Configuration/WorkoutAppProducts.storekit
  - WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift
  - WorkoutApp/WorkoutApp.swift
  - WorkoutAppTests/StoreKitConfigTests.swift
  - WorkoutAppUITests/PaywallUITests.swift
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 7: Code Review Report (Gap Closure — Plans 07-05 through 07-08)

**Reviewed:** 2026-04-24
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Gap closure changes across webhook parsing, BlurredPlanGateView wiring, StoreKit pricing, DiscountOfferView copy, and the `--force-paywall` launch argument are largely correct. Prices in the StoreKit config file and DiscountOfferView copy are internally consistent. BlurredPlanGateView is wired correctly in HomeView. Three warnings and two info items were found; no critical security or data-loss issues are present.

---

## Warnings

### WR-01: `--force-paywall` skips `listenForAuthChanges` — UI tests cannot reach authenticated screens

**File:** `WorkoutApp/WorkoutApp.swift:55-57`

**Issue:** When `--force-paywall` is present, `listenForAuthChanges()` is never called. The flag sets `isAuthenticated = true` on line 46, but the auth listener that refreshes Supabase session, calls `Purchases.shared.logIn()`, and syncs `onboardingCompleted` never runs. Any UI test that needs to navigate past the hard paywall to verify a post-purchase screen will find `isSubscribed` stuck at `false` indefinitely — `refreshEntitlements()` is only called inside the listener. The current test suite works because it only asserts on the paywall itself (which is visible), but this wiring will silently break any future test that tries to simulate a successful purchase.

**Fix:** Introduce a second flag (e.g., `--force-subscribed`) that bypasses the `!isSubscribed` path rather than hacking both `isSubscribed` and `isAuthenticated` inside the existing flag. Alternatively, still call `listenForAuthChanges()` when `--force-paywall` is set but inject a mock `RevenueCatServiceProtocol` that returns `isSubscribed = false` so the paywall stays visible without suppressing the rest of the auth flow.

```swift
// Before (WorkoutApp.swift:55-57)
if !ProcessInfo.processInfo.arguments.contains("--force-paywall") {
    await appState.listenForAuthChanges()
}

// After: always start the listener; let the mock service control subscription state
await appState.listenForAuthChanges()
// isSubscribed is already set to false above by the --force-paywall branch,
// and cachedIsSubscribed() will not overwrite it inside listenForAuthChanges
// if the DEBUG guard is evaluated first.
```

---

### WR-02: Webhook type-field access is unchecked — missing `app_user_id`, `type`, or `id` fields produce runtime `""` not a 400

**File:** `supabase/functions/revenuecat-webhook/index.ts:64-66`

**Issue:** After `payload.event` is confirmed non-null on line 59, `appUserId`, `eventType`, and `eventId` are assigned directly from `rcEvent` fields with TypeScript's type assertion (`rcEvent.app_user_id: string`). If RevenueCat ever sends a payload where those fields are absent (malformed event, schema change, test ping), TypeScript's structural access returns `undefined`, which coerces to the string `"undefined"`. The anonymous-ID guard on line 71 will pass (`"undefined"` does not start with `$RCAnonymousID`), the UUID regex check on line 84 will reject it with a 200, and the event is silently dropped without a clear error log distinguishing it from an intentional anonymous-ID rejection.

**Fix:** Add explicit presence checks for `type` and `id` before use, and log them as 400-range errors so they are distinguishable from the intentional anonymous-ID 200 path.

```typescript
const appUserId: string | undefined = rcEvent.app_user_id
const eventType: string | undefined = rcEvent.type
const eventId: string | undefined = rcEvent.id

if (!eventType || !eventId) {
  console.error("[revenuecat-webhook] Missing required event fields", rcEvent)
  return new Response("Missing event fields", { status: 400 })
}
```

---

### WR-03: `DiscountOfferView` loads `DiscountOfferViewModel` inside `.task` on `ProgressView` — `viewModel` may never be set if the view is dismissed before the task completes

**File:** `WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift:14-19`

**Issue:** The `.task` modifier is attached to the inner `ProgressView`, not the outer `Group`. If the user dismisses the sheet before `vm.loadManagementURL()` returns, SwiftUI cancels the task on the `ProgressView` (which has been removed from the hierarchy), meaning `viewModel` is never assigned. On re-presentation the view starts over (which is fine), but if the sheet is presented modally with `interactiveDismissDisabled`, the dismiss path is the "Cancel anyway" button — which reads `vm.managementURL` directly. Since `viewModel` would be `nil` in the race, the `if let url = vm.managementURL` check is bypassed entirely (there is no `vm` to read). More concretely: `.task` on an inner view is cancelled when that inner view is removed; attaching it to the root container prevents the race.

**Fix:** Move the `.task` modifier to the outer `Group` so it is owned by the view's lifecycle, not the `ProgressView`'s:

```swift
var body: some View {
    Group {
        if let vm = viewModel {
            content(vm: vm)
        } else {
            ProgressView()
        }
    }
    .task {
        let vm = DiscountOfferViewModel(revenueCatService: appState.revenueCatService)
        await vm.loadManagementURL()
        viewModel = vm
    }
    .navigationTitle("Special Offer")
    .navigationBarTitleDisplayMode(.inline)
}
```

---

## Info

### IN-01: StoreKit config `groupNumber` values are inverted relative to expected purchase priority

**File:** `WorkoutApp/Configuration/WorkoutAppProducts.storekit:33` and `:73`

**Issue:** The monthly product has `"groupNumber": 2` and the annual product has `"groupNumber": 1`. In StoreKit sandbox testing, `groupNumber` controls display ordering within the group — lower numbers appear first. If the intended paywall layout shows annual first (the `PaywallView` likely places annual as the "Most Popular" top option), the config grouping is inverted. This does not affect production billing but means StoreKit sandbox test runs will render products in a different order than what App Store Connect will produce, which could make `StoreKitConfigTests` pass while visually testing the wrong ordering.

**Fix:** Set `"groupNumber": 1` on the annual product and `"groupNumber": 2` on the monthly product to match the intended display priority.

---

### IN-02: `PaywallUITests` uses soft-pass pattern throughout — test failures are silently swallowed

**File:** `WorkoutApp/WorkoutAppUITests/PaywallUITests.swift:19-29` and throughout

**Issue:** Every test gates assertions behind `if headline.waitForExistence(timeout: 10)` without an `else` branch or `XCTFail`. If the paywall never appears (auth screen blocks, app crashes, wrong launch args), all assertions are simply skipped and the test suite reports green. This makes the suite unreliable as a regression gate for the `--force-paywall` path — the tests were specifically written to exercise that path, yet they will pass even if the path is completely broken.

**Fix:** For tests that depend on `--force-paywall`, assert that the paywall headline exists unconditionally:

```swift
func testPaywallShowsTwoPricingCards() throws {
    app.launch()
    let headline = app.staticTexts["Your personalized plan is ready"]
    XCTAssertTrue(headline.waitForExistence(timeout: 10),
                  "--force-paywall should always show the paywall headline")
    // ... rest of assertions
}
```

The comment "If paywall doesn't show…test is inconclusive — not a failure" defeats the purpose of having an automated test for this specific launch argument path.

---

_Reviewed: 2026-04-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
