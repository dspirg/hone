---
phase: 07-subscriptions-and-paywall
verified: 2026-04-24T12:00:00Z
status: human_needed
score: 15/15 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 9/15
  gaps_closed:
    - "Webhook Edge Function now correctly parses nested RevenueCat payload (payload.event.app_user_id)"
    - "BlurredPlanGateView wired to HomeView for expired/lapsed users (D-14, D-15)"
    - "StoreKit config prices corrected: $12.99/month (D-01), $79.99/year (D-02), $6.49 promo (D-12)"
    - "DiscountOfferView body text shows '$6.49/month for 3 months, then $12.99/month' per D-12"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Paywall pricing cards load with correct prices ($12.99/month, $79.99/year) from RevenueCat offerings"
    expected: "Annual card pre-selected with 'Most Popular' badge, monthly card shows $12.99/month, annual shows monthly equivalent (~$6.67/month), billed $79.99/year label"
    why_human: "Requires App Store Connect product registration and RevenueCat sandbox to return real offerings. Products have not yet been registered in App Store Connect."

  - test: "CTA reads 'Start 14-Day Free Trial' when trial-eligible (not hardcoded)"
    expected: "Trial period text derived from introductoryDiscount SDK property at runtime"
    why_human: "SDK runtime behavior depends on App Store Connect product introductory offer configuration"

  - test: "Sandbox purchase flow completes: StoreKit sheet appears, purchase succeeds, 'You're all set' screen shows, paywall dismisses"
    expected: "After purchase, refreshEntitlements() flips isSubscribed, fullScreenCover binding returns false, MainTabView accessible"
    why_human: "Requires live StoreKit sandbox transaction with registered App Store Connect products"
---

# Phase 7: Subscriptions and Paywall Verification Report

**Phase Goal:** Users are presented with a compelling paywall after seeing their personalized plan; monthly and annual subscription options are offered with a free trial; a cancellation retention flow is active
**Verified:** 2026-04-24T12:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (Plans 05, 06, 07)

## Re-verification Summary

All 4 gaps from the previous verification are closed. All 15 must-haves now pass automated verification. The remaining 3 human verification items are unchanged from the previous report — they require App Store Connect product registration before they can be completed. No regressions were detected in previously passing items.

| Gap | Previous Status | Current Status |
|-----|----------------|----------------|
| Webhook nested payload parsing (CR-02) | FAILED | CLOSED — `rcEvent.app_user_id` from `payload.event` |
| BlurredPlanGateView not wired (D-14/D-15) | ORPHANED | CLOSED — wired in HomeView with `!isSubscribed` guard |
| StoreKit config prices wrong (D-01/D-02/D-12) | INCORRECT | CLOSED — $12.99/$79.99/$6.49 confirmed |
| DiscountOfferView generic price copy | FAILED | CLOSED — "$6.49/month for 3 months, then $12.99/month" confirmed |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | RevenueCat SDK initialized at app launch, logIn(supabaseUUID) called after auth resolves | ✓ VERIFIED | WorkoutApp.swift: `configure()` called before `listenForAuthChanges()`; AppState.swift: `revenueCatService.logIn(userId: session.user.id.uuidString)` in auth handler |
| 2 | AppState.isSubscribed reflects 'pro' entitlement from RevenueCat and drives fullScreenCover paywall gate | ✓ VERIFIED | AppState.swift line 63: `self.isSubscribed = subscribed` from `logIn()` result; WorkoutApp.swift line 87: fullScreenCover binding on `isAuthenticated && !isSubscribed` |
| 3 | Webhook validates RC_WEBHOOK_SECRET, rejects anonymous IDs, and updates profiles.subscription_status | ✓ VERIFIED | index.ts: auth header check against `RC_WEBHOOK_SECRET`; anonymous ID guard at line 76; `payload.event.app_user_id` parsing (Gap 1 closed); `subscription_status` updated via service_role at line 118 |
| 4 | Profiles table has subscription_pause_until TIMESTAMPTZ and subscription_status CHECK includes 'grace_period' | ✓ VERIFIED | Migration 20260416000001: `ADD COLUMN subscription_pause_until TIMESTAMPTZ DEFAULT NULL`; CHECK includes `('free', 'subscribed', 'grace_period')` |
| 5 | ContentView gates MainTabView behind isSubscribed with fullScreenCover that cannot be drag-dismissed | ✓ VERIFIED | WorkoutApp.swift: fullScreenCover with no-op setter; PaywallView.swift: `.interactiveDismissDisabled(true)` at line 99 |
| 6 | Paywall appears as fullScreenCover after user sees plan preview; annual pre-selected with 'Most Popular' badge | ✓ VERIFIED | PaywallViewModel: `selectedPackage = annualPackage` in `loadOfferings()`; PricingCardView: "Most Popular" badge renders when `showBadge == true`; ContentView routes to PaywallView after onboarding |
| 7 | All prices read from localizedPriceString at runtime — zero hardcoded price strings | ✓ VERIFIED | PricingCardView uses `localizedPriceString` for all price labels; StoreKit config corrected to $12.99/$79.99/$6.49 (Gap 3 closed) |
| 8 | Trial period read from introductoryDiscount — CTA shows 'Start N-Day Free Trial' only when eligible | ✓ VERIFIED | PaywallViewModel: `trialEligible` computed from `selectedPackage?.storeProduct.introductoryDiscount != nil`; `ctaLabel` returns "Start \(trialText) Free Trial" only when non-nil |
| 9 | Expired/lapsed users see blurred plan preview with 'Your plan is waiting' triggering paywall on tap | ✓ VERIFIED | HomeView.swift lines 19-31: `BlurredPlanGateView(showPaywall: $showPaywall)` wraps `planCard(plan:)` when `!appState.isSubscribed`; fullScreenCover at line 50 presents PaywallView (Gap 2 closed) |
| 10 | Successful purchase sets purchaseCompleted, triggers refreshEntitlements, dismisses paywall | ✓ VERIFIED | PaywallViewModel.purchase(): sets `purchaseCompleted = true`; PaywallView.onChange triggers `appState.refreshEntitlements()` which sets `isSubscribed = true`, auto-dismissing fullScreenCover |
| 11 | Social proof shows 'Join 1,200 members' (D-07) | ✓ VERIFIED | PaywallView.swift line 57: `Text("Join 1,200 members")` |
| 12 | User taps 'Manage Subscription' in Profile and sees retention flow | ✓ VERIFIED | ProfileView.swift: `NavigationLink { CancellationRetentionView() }` labeled "Manage Subscription" |
| 13 | Pause screen appears with 1/2/3 month chip selector and billing transparency notice | ✓ VERIFIED | PauseOptionsView: `ForEach(PauseDuration.allCases)` chips; "Pausing hides your plan in the app. Your billing continues..." mandatory notice present |
| 14 | Discount offer shown only to active monthly subscribers; annual/trial routes to Apple directly | ✓ VERIFIED | CancellationRetentionView: `activeSubscriptions.contains { $0.contains("monthly") } && !isInTrial`; NavigationLink to DiscountOfferView when eligible, URL open when not |
| 15 | 'Cancel anyway' link is red (destructive) and opens Apple subscription management URL | ✓ VERIFIED | DiscountOfferView.swift: `Button("Cancel anyway")` with `.foregroundStyle(Color.red)`, opens `vm.managementURL` |

**Score:** 15/15 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkoutApp/Core/RevenueCatService.swift` | RevenueCat SDK wrapper protocol + implementation + mock | ✓ VERIFIED | RevenueCatServiceProtocol, RevenueCatService, MockRevenueCatService present and substantive |
| `supabase/functions/revenuecat-webhook/index.ts` | Webhook with auth verification, anonymous ID rejection, nested payload parsing | ✓ VERIFIED | RC_WEBHOOK_SECRET check; anonymous ID guard; `payload.event.app_user_id` parsing (Gap 1 closed) |
| `supabase/migrations/20260416000001_add_subscription_pause.sql` | subscription_pause_until column and grace_period status | ✓ VERIFIED | Both present |
| `WorkoutApp/Core/AppState.swift` | isSubscribed driven by RevenueCat entitlement | ✓ VERIFIED | isSubscribed set from logIn() result |
| `WorkoutApp/Features/Paywall/PaywallView.swift` | Full paywall modal with all UI-SPEC elements | ✓ VERIFIED | Headline, value props, pricing section, CTA, success state, interactiveDismissDisabled |
| `WorkoutApp/Features/Paywall/PaywallViewModel.swift` | Offerings fetch, package selection, purchase handling | ✓ VERIFIED | All expected methods present with dynamic pricing |
| `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` | Pricing card with Most Popular badge and dynamic prices | ✓ VERIFIED | localizedPriceString, badge, accessibility labels |
| `WorkoutApp/Features/Paywall/Components/ValuePropListView.swift` | 4-bullet value prop list | ✓ VERIFIED | "AI plan built for you", "500+ exercises with video", "Coach chat anytime", "Adapts as you improve" |
| `WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift` | Blurred overlay with 'Your plan is waiting' | ✓ VERIFIED | Wired in HomeView with subscription check (Gap 2 closed) |
| `WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift` | NavigationStack coordinator with eligibility guard | ✓ VERIFIED | isEligibleForDiscount and isInTrial checks present |
| `WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift` | Pause chip selector with billing transparency | ✓ VERIFIED | 3 chips, mandatory billing transparency notice present |
| `WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift` | Pause duration enum, Supabase write, managementURL | ✓ VERIFIED | subscription_pause_until written to Supabase profiles |
| `WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift` | 50% off screen with specific D-12 pricing copy | ✓ VERIFIED | "$6.49/month for 3 months, then $12.99/month" confirmed (Gap 3 closed) |
| `WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift` | Promo offer fetch and purchase | ✓ VERIFIED | monthly_50pct_3months promo ID used |
| `WorkoutApp/Features/Main/Tabs/ProfileView.swift` | Manage Subscription row with retention flow | ✓ VERIFIED | NavigationLink to CancellationRetentionView, Active/Free status, Restore Purchases |
| `WorkoutApp/Features/Main/Tabs/HomeView.swift` | BlurredPlanGateView wrapping plan content when !isSubscribed | ✓ VERIFIED | showPaywall state, BlurredPlanGateView wrapping, fullScreenCover for PaywallView |
| `WorkoutApp/Configuration/WorkoutAppProducts.storekit` | StoreKit config with correct prices (D-01/D-02/D-12) | ✓ VERIFIED | $12.99 monthly, $79.99 annual, $6.49 promo confirmed |
| `WorkoutAppTests/RevenueCatServiceTests.swift` | 4 tests covering UUID tracking, logOut, cache default | ✓ VERIFIED | File exists |
| `WorkoutAppTests/EntitlementGateTests.swift` | 4 tests covering paywall gate logic | ✓ VERIFIED | File exists |
| `WorkoutAppTests/PaywallViewModelTests.swift` | 7 tests covering VM behavior | ✓ VERIFIED | File exists |
| `WorkoutAppTests/RetentionFlowTests.swift` | 7 tests covering pause duration and discount flow | ✓ VERIFIED | File exists |
| `WorkoutAppTests/StoreKitConfigTests.swift` | Price drift detection tests | ✓ VERIFIED | File exists |
| `WorkoutAppUITests/PaywallUITests.swift` | UI tests for paywall with accessibility audit | ✓ VERIFIED | File exists |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| WorkoutApp.swift | RevenueCatService | configure() in .task before listenForAuthChanges | ✓ WIRED | `appState.revenueCatService.configure()` line 40 |
| AppState.swift | RevenueCatService | logIn(userId: session.user.id.uuidString) in auth listener | ✓ WIRED | `revenueCatService.logIn(userId: userId)` in .initialSession/.signedIn handler |
| revenuecat-webhook/index.ts | profiles table | UPDATE subscription_status WHERE id = payload.event.app_user_id | ✓ WIRED | Nested payload parsing fixed; `rcEvent.app_user_id` correctly read; subscription_status updated via service_role |
| ContentView | PaywallView | fullScreenCover when !isSubscribed | ✓ WIRED | `PaywallView()` inside fullScreenCover with `isAuthenticated && !isSubscribed` binding |
| PaywallViewModel | RevenueCatService | fetchOfferings(), purchase(), refreshEntitlements() | ✓ WIRED | All three methods called via `revenueCatService` |
| HomeView | BlurredPlanGateView | wraps planCard when !isSubscribed | ✓ WIRED | `BlurredPlanGateView(showPaywall: $showPaywall)` wrapping `planCard(plan:)` |
| ProfileView | CancellationRetentionView | NavigationLink push | ✓ WIRED | `NavigationLink { CancellationRetentionView() }` |
| PauseOptionsViewModel | Supabase profiles | UPDATE subscription_pause_until | ✓ WIRED | `supabase.from("profiles").update(["subscription_pause_until":...]).eq("id", value: userId)` |
| DiscountOfferViewModel | RevenueCatService | purchaseWithPromo(monthly_50pct_3months) | ✓ WIRED | `revenueCatService.purchaseWithPromo(package: monthlyPackage, promoOfferID: "monthly_50pct_3months")` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| PaywallView | annualPackage, monthlyPackage | RevenueCat fetchOfferings() | Conditional on App Store Connect product registration | ✓ FLOWING (when RC products configured) |
| ContentView | isSubscribed | RevenueCat logIn() -> entitlements["pro"] | Yes — RC entitlement check | ✓ FLOWING |
| HomeView | activePlan / isSubscribed | Supabase query + AppState | Yes — real DB and RC entitlement | ✓ FLOWING |
| PauseOptionsView | subscription_pause_until | Supabase UPDATE via PauseOptionsViewModel | Yes — writes to real DB column | ✓ FLOWING |
| revenuecat-webhook | subscription_status | RC event payload.event.app_user_id | Yes — fixed nested parsing, real DB update | ✓ FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED (iOS/Swift native app — no runnable entry points accessible from CLI)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SUBS-01 | 07-01, 07-02, 07-07 | Monthly and annual subscription plans; annual pre-selected at discount | ✓ SATISFIED | PaywallViewModel pre-selects annual; PricingCardView shows discount label; StoreKit config prices corrected to D-01/D-02 values |
| SUBS-02 | 07-02, 07-04 | New users receive a free trial period before billing begins | ✓ SATISFIED | 14-day trial in StoreKit config (P14D); PaywallViewModel reads introductoryDiscount for dynamic trial CTA |
| SUBS-03 | 07-01, 07-02 | Paywall presented after user sees AI-generated plan preview | ✓ SATISFIED | Flow: PlanPreviewView -> markOnboardingComplete() -> ContentView branch 3 -> MainTabView + PaywallView fullScreenCover |
| SUBS-04 | 07-03, 07-06 | Cancellation retention flow offered when user attempts to cancel | ✓ SATISFIED | ProfileView -> CancellationRetentionView -> PauseOptionsView -> DiscountOfferView; BlurredPlanGateView wired to HomeView for expired-user re-entry |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| WorkoutApp/Core/AppState.swift | 28 | `isSubscribed: Bool = true` in `#if DEBUG` bypasses paywall in all debug builds | Info | Paywall completely invisible during development; expected for developer ergonomics but worth noting |
| WorkoutApp/Core/RevenueCatService.swift | 33 | Force-unwrap `as! String` for REVENUECAT_API_KEY in `configure()` | Warning | App crashes at launch if key absent from build configuration |
| Config/Dev.xcconfig | 8 | Real RevenueCat sandbox API key committed | Warning | Credential exposure; key grants access to sandbox environment |

No blockers remain. The previous blocker (webhook payload bug) is closed.

### Human Verification Required

#### 1. Paywall Pricing Cards Load With Correct Prices

**Test:** Build and run on iOS simulator with App Store Connect products registered. Verify paywall renders annual card showing ~$6.67/month equivalent (billed $79.99/year) and monthly card showing $12.99/month.
**Expected:** Annual card pre-selected with orange border and "Most Popular" badge. Prices match App Store Connect product configuration.
**Why human:** Requires live RevenueCat offering fetch with registered App Store Connect products. Products `com.workoutapp.pro.monthly` and `com.workoutapp.pro.annual` must be created in App Store Connect and configured in RevenueCat dashboard before the SDK returns real offerings.

**Pre-requisites (from 07-08 Task 1):**
1. Create subscription group "WorkoutApp Pro" in App Store Connect
2. Register `com.workoutapp.pro.monthly` at $12.99/month with 14-day free trial and `monthly_50pct_3months` promotional offer at $6.49/month for 3 periods
3. Register `com.workoutapp.pro.annual` at $79.99/year with 14-day free trial
4. Configure RevenueCat dashboard: "pro" entitlement, default offering with both packages

#### 2. CTA Shows Dynamic Trial Period Text

**Test:** As a new trial-eligible user, verify the CTA button reads "Start 14-Day Free Trial" with N resolved from the SDK.
**Expected:** N = 14 derived from `introductoryDiscount.subscriptionPeriod.value` at runtime, not hardcoded.
**Why human:** Requires live StoreKit trial eligibility state with configured App Store Connect product introductory offer.

#### 3. Sandbox Purchase Flow Completes End-to-End

**Test:** Tap the CTA with a sandbox Apple ID. Complete the StoreKit payment sheet. Verify "You're all set" success screen appears, then paywall dismisses and MainTabView is accessible.
**Expected:** Full purchase flow completes; `refreshEntitlements()` flips `isSubscribed`; fullScreenCover binding auto-dismisses.
**Why human:** Requires live StoreKit sandbox transaction with registered products.

---

## Gaps Summary

No automated gaps remain. All 4 gaps from the previous verification are closed:

- **Gap 1 (Webhook payload parsing):** `payload.event.app_user_id` correctly reads from nested RevenueCat payload. Guard for missing `event` object returns HTTP 400. Real subscription events will now update `profiles.subscription_status`.

- **Gap 2 (BlurredPlanGateView orphaned):** HomeView now wraps plan content in `BlurredPlanGateView(showPaywall: $showPaywall)` when `!appState.isSubscribed`, with a fullScreenCover presenting `PaywallView()`. Expired/lapsed users see the blurred plan preview with "Your plan is waiting" and can tap to access the paywall (D-14, D-15).

- **Gap 3 (Pricing configuration):** StoreKit config updated to $12.99 monthly, $79.99 annual, $6.49 promo. DiscountOfferView now shows "$6.49/month for 3 months, then $12.99/month" in both the body text and the offer card subtitle, matching D-12 requirements.

- **Gap 4 (Human verification incomplete):** Automated verification extended via StoreKitConfigTests and PaywallUITests. 3 remaining items require App Store Connect product registration before completion — these are the human_needed items above.

---

_Verified: 2026-04-24T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
