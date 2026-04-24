---
phase: 07-subscriptions-and-paywall
verified: 2026-04-24T00:00:00Z
status: gaps_found
score: 9/15 must-haves verified
overrides_applied: 0
re_verification: false
gaps:
  - truth: "Webhook Edge Function validates RC_WEBHOOK_SECRET, rejects $RCAnonymousID payloads, and updates profiles.subscription_status"
    status: failed
    reason: "CR-02 (from REVIEW.md): Webhook parses event payload as a flat object and reads event.app_user_id directly. RevenueCat sends a nested payload — { api_version, event: { type, app_user_id, id } }. Reading event.app_user_id on the outer object returns undefined at runtime. The anonymous-ID guard (!appUserId) fires on undefined (truthy for !), returning HTTP 200 with 'Anonymous ID rejected' for every real subscription event. profiles.subscription_status is NEVER updated by the webhook."
    artifacts:
      - path: "supabase/functions/revenuecat-webhook/index.ts"
        issue: "Lines 50-60: event = await req.json() then event.app_user_id — reads from flat outer object, not from the nested event.event object"
    missing:
      - "Parse the payload as { api_version: string, event: { type, app_user_id, id } } and read from payload.event.app_user_id, payload.event.type, payload.event.id"

  - truth: "Expired/lapsed users see blurred plan preview with 'Your plan is waiting' that triggers paywall on tap (D-14, D-15)"
    status: failed
    reason: "BlurredPlanGateView is defined in WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift but is only used in its own #Preview block. No production screen imports or uses this component. The 'expired user sees blurred plan' user journey does not exist in any navigable screen."
    artifacts:
      - path: "WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift"
        issue: "ORPHANED — only referenced in its own #Preview, not wired to any production view"
    missing:
      - "Wire BlurredPlanGateView to the appropriate screen (e.g., the plan preview tab visible from MainTabView when !isSubscribed) so expired/lapsed users see blurred plan content instead of empty state"

  - truth: "All prices read from package.storeProduct.localizedPriceString at runtime -- zero hardcoded price strings (RESEARCH anti-pattern)"
    status: failed
    reason: "The StoreKit configuration file (used for local sandbox testing and used as the RevenueCat product source during the 07-04 session) contains incorrect prices: $9.99 monthly (D-01 requires $12.99), $59.99 annual (D-02 requires $79.99), $4.99 promotional (D-12 requires $6.49). Additionally, DiscountOfferView.swift removed the required '$6.49/month for 3 months, then $12.99/month' body copy (plan acceptance criterion grep for '6.49' fails) and replaced it with generic copy 'then your regular price' — a regression from the plan spec."
    artifacts:
      - path: "WorkoutApp/Configuration/WorkoutAppProducts.storekit"
        issue: "Monthly displayPrice: 9.99 (should be 12.99 per D-01), Annual: 59.99 (should be 79.99 per D-02), Promo price: 4.99 (should be 6.49 per D-12)"
      - path: "WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift"
        issue: "Body text reads 'Get 50% off for the next 3 months — then your regular price.' Missing '$6.49/month for 3 months, then $12.99/month' per D-12 and plan acceptance criteria"
    missing:
      - "Update StoreKit configuration: monthly to $12.99, annual to $79.99, promo to $6.49 per D-01/D-02/D-12"
      - "Restore DiscountOfferView body text to explicitly show '$6.49/month for 3 months, then $12.99/month' per plan spec"

  - truth: "Purchase flow works in StoreKit sandbox; paywall renders with pricing cards loaded (Plan 04 human verification)"
    status: failed
    reason: "07-04-SUMMARY.md marks human verification as PARTIAL. The following items from the 32-step verification checklist remain unverified: pricing cards loading, annual pre-selection with Most Popular badge, dynamic CTA text, fine print, sandbox purchase flow, post-purchase success screen, paywall dismissal, retention flow navigation, PauseOptionsView and DiscountOfferView rendering, and accessibility checks. Root cause: RevenueCat SDK 5.x (StoreKit 2) requires App Store Connect product registration for purchase flow testing; local StoreKit config did not work on iOS 26 simulator."
    artifacts: []
    missing:
      - "Create app record in App Store Connect with bundle ID com.danspirgen.hone"
      - "Register subscription products com.workoutapp.pro.monthly and com.workoutapp.pro.annual in App Store Connect"
      - "Re-run Plan 04 verification steps 11-31 (pricing display, purchase flow, retention flow, accessibility)"

human_verification:
  - test: "Paywall pricing cards load with correct prices ($12.99/month, $79.99/year) from RevenueCat offerings"
    expected: "Annual card pre-selected with 'Most Popular' badge, monthly card shows $12.99/month, annual shows monthly equivalent (~$6.67/month), billed $79.99/year label"
    why_human: "Requires App Store Connect product registration and RevenueCat sandbox to return real offerings"

  - test: "CTA reads 'Start 14-Day Free Trial' when trial-eligible (not hardcoded)"
    expected: "Trial period text derived from introductoryDiscount SDK property at runtime"
    why_human: "SDK runtime behavior depends on App Store Connect product introductory offer configuration"

  - test: "Sandbox purchase flow completes: StoreKit sheet appears, purchase succeeds, 'You're all set' screen shows, paywall dismisses"
    expected: "After purchase, refreshEntitlements() flips isSubscribed, fullScreenCover binding returns false, MainTabView accessible"
    why_human: "Requires live StoreKit sandbox transaction with configured products"

  - test: "Retention flow navigation: Profile -> Manage Subscription -> PauseOptionsView -> DiscountOfferView"
    expected: "Three screens navigate correctly with correct headings, billing transparency notice visible, 'Cancel anyway' in red"
    why_human: "Navigation flow requires live subscription state; visual correctness cannot be verified programmatically"

  - test: "Accessibility: pricing cards announce plan name, price, and selected state via VoiceOver"
    expected: "accessibilityLabel = '[Annual/Monthly] plan, [price]', accessibilityValue = 'selected'/'not selected'"
    why_human: "VoiceOver behavior requires Accessibility Inspector in simulator"
---

# Phase 7: Subscriptions and Paywall Verification Report

**Phase Goal:** Users are presented with a compelling paywall after seeing their personalized plan; monthly and annual subscription options are offered with a free trial; a cancellation retention flow is active
**Verified:** 2026-04-24T00:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | RevenueCat SDK initialized at app launch, logIn(supabaseUUID) called after auth resolves | ✓ VERIFIED | WorkoutApp.swift calls configure() before listenForAuthChanges(); AppState.listenForAuthChanges() calls revenueCatService.logIn(userId: session.user.id.uuidString) in the auth event handler |
| 2 | AppState.isSubscribed reflects 'pro' entitlement from RevenueCat and drives fullScreenCover paywall gate | ✓ VERIFIED | AppState.swift: isSubscribed set from entitlements["pro"]?.isActive; ContentView.swift: fullScreenCover binding reads appState.isAuthenticated && !appState.isSubscribed |
| 3 | Webhook validates RC_WEBHOOK_SECRET, rejects anonymous IDs, and updates profiles.subscription_status | ✗ FAILED | CR-02: webhook reads event.app_user_id from the flat outer JSON object; RevenueCat sends { api_version, event: { app_user_id, type } }; event.app_user_id is undefined at runtime; anonymous-ID guard fires for every real event; database is never updated |
| 4 | Profiles table has subscription_pause_until TIMESTAMPTZ and subscription_status CHECK includes 'grace_period' | ✓ VERIFIED | supabase/migrations/20260416000001_add_subscription_pause.sql: ADD COLUMN subscription_pause_until TIMESTAMPTZ DEFAULT NULL; CHECK (subscription_status IN ('free', 'subscribed', 'grace_period')) |
| 5 | ContentView gates MainTabView behind isSubscribed with fullScreenCover that cannot be drag-dismissed | ✓ VERIFIED | WorkoutApp.swift ContentView: fullScreenCover with no-op setter + PaywallView; PaywallView.swift: .interactiveDismissDisabled(true) |
| 6 | Paywall appears as fullScreenCover after user sees plan preview; annual pre-selected with 'Most Popular' badge | ✓ VERIFIED (partial) | Architecture verified: markOnboardingComplete() -> ContentView branch 3 -> MainTabView + PaywallView fullScreenCover. Annual pre-selection code: selectedPackage = annualPackage in loadOfferings(). PricingCardView shows "Most Popular" badge. Human verification of rendered pricing cards outstanding (StoreKit products not yet in App Store Connect) |
| 7 | All prices read from localizedPriceString at runtime — zero hardcoded price strings | ✗ FAILED | PaywallView.swift and PricingCardView.swift correctly use localizedPriceString. However, StoreKit config has wrong prices ($9.99/$59.99 instead of D-01 $12.99/D-02 $79.99). DiscountOfferView removed the required '$6.49/month for 3 months, then $12.99/month' price copy and replaced with generic text — a regression from plan spec |
| 8 | Trial period read from introductoryDiscount — CTA shows 'Start N-Day Free Trial' only when eligible | ✓ VERIFIED | PaywallViewModel.trialEligible computed from selectedPackage?.storeProduct.introductoryDiscount != nil; ctaLabel dynamically returns "Start \(trialText) Free Trial" only when introductoryDiscount present |
| 9 | Expired/lapsed users see blurred plan preview with 'Your plan is waiting' triggering paywall on tap | ✗ FAILED | BlurredPlanGateView.swift is ORPHANED — only referenced in its own #Preview. No production screen uses this component. The expired-user blurred-plan journey is not implemented in any navigable screen |
| 10 | Successful purchase sets purchaseCompleted, triggers refreshEntitlements, dismisses paywall | ✓ VERIFIED | PaywallViewModel.purchase(): sets purchaseCompleted = true when pro entitlement active; PaywallView.onChange(of: viewModel.purchaseCompleted) calls appState.refreshEntitlements(); "Start Training" button also calls refreshEntitlements() which sets isSubscribed = true, auto-dismissing the fullScreenCover |
| 11 | Social proof shows 'Join 1,200 members' (D-07) | ✓ VERIFIED | PaywallView.swift line 57: Text("Join 1,200 members") |
| 12 | User taps 'Manage Subscription' in Profile and sees retention flow | ✓ VERIFIED | ProfileView.swift: NavigationLink -> CancellationRetentionView(); CancellationRetentionView.swift: NavigationStack wrapping PauseOptionsView |
| 13 | Pause screen appears with 1/2/3 month chip selector and billing transparency notice | ✓ VERIFIED | PauseOptionsView.swift: ForEach(PauseDuration.allCases) chips; "Pausing hides your plan in the app. Your billing continues..." notice present |
| 14 | Discount offer ($6.49/3 months) shown only to active monthly subscribers; annual/trial routes to Apple directly | ✓ VERIFIED (structural) | CancellationRetentionView.checkDiscountEligibility(): checks activeSubscriptions for "monthly" + !isInTrial; PauseOptionsView: NavigationLink to DiscountOfferView when eligible, Button opening managementURL when not. Structural routing verified; DiscountOfferView body text omits the $6.49 price per D-12 |
| 15 | 'Cancel anyway' link is red (destructive) and opens Apple subscription management URL | ✓ VERIFIED | DiscountOfferView.swift: Button("Cancel anyway") with .foregroundStyle(Color.red), opens vm.managementURL |

**Score:** 9/15 truths verified (3 failed, 3 need human verification to fully close)

### Deferred Items

None — all gaps are actionable in this phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkoutApp/Core/RevenueCatService.swift` | RevenueCat SDK wrapper protocol + implementation + mock | ✓ VERIFIED | RevenueCatServiceProtocol, RevenueCatService, MockRevenueCatService all present and substantive |
| `supabase/functions/revenuecat-webhook/index.ts` | Webhook with RC_WEBHOOK_SECRET validation and anonymous ID rejection | ✗ STUB (broken) | File exists and has correct structure but CR-02 means it never processes real payloads correctly |
| `supabase/migrations/20260416000001_add_subscription_pause.sql` | subscription_pause_until column and grace_period status | ✓ VERIFIED | Both present |
| `WorkoutApp/Core/AppState.swift` | isSubscribed property driven by RevenueCat entitlement check | ✓ VERIFIED | isSubscribed set from revenueCatService.logIn() result |
| `WorkoutApp/Features/Paywall/PaywallView.swift` | Full paywall modal | ✓ VERIFIED | Headline, value props, pricing section, CTA, success state, interactiveDismissDisabled |
| `WorkoutApp/Features/Paywall/PaywallViewModel.swift` | Offerings fetch, package selection, purchase handling | ✓ VERIFIED | All expected methods present |
| `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` | Pricing card with Most Popular badge | ✓ VERIFIED | localizedPriceString, badge, accessibility labels |
| `WorkoutApp/Features/Paywall/Components/ValuePropListView.swift` | 4-bullet value prop list | ✓ VERIFIED | "AI plan built for you", "500+ exercises with video", "Coach chat anytime", "Adapts as you improve" |
| `WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift` | Blurred overlay with 'Your plan is waiting' | ✗ ORPHANED | File exists and is correct implementation; not wired to any production screen |
| `WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift` | NavigationStack coordinator with eligibility guard | ✓ VERIFIED | isEligibleForDiscount check, isInTrial check |
| `WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift` | Pause chip selector with billing transparency | ✓ VERIFIED | 3 chips, transparency notice present |
| `WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift` | Pause duration enum, Supabase write, managementURL fetch | ✓ VERIFIED | subscription_pause_until write to Supabase profiles |
| `WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift` | 50% off screen with accept/cancel | ✓ VERIFIED (partial) | Structure and Cancel anyway button correct; body text omits D-12 specific prices |
| `WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift` | Promo offer fetch and purchase | ✓ VERIFIED | monthly_50pct_3months promo ID used |
| `WorkoutApp/Features/Main/Tabs/ProfileView.swift` | Manage Subscription row with retention flow | ✓ VERIFIED | NavigationLink to CancellationRetentionView, status display, Restore Purchases |
| `WorkoutApp/Configuration/WorkoutAppProducts.storekit` | StoreKit config with correct prices | ✗ INCORRECT | Prices: $9.99/$59.99/$4.99 — should be $12.99/$79.99/$6.49 per D-01/D-02/D-12 |
| `WorkoutAppTests/RevenueCatServiceTests.swift` | 4 tests covering UUID tracking, logOut, cache default | ✓ VERIFIED | File exists |
| `WorkoutAppTests/EntitlementGateTests.swift` | 4 tests covering paywall gate logic | ✓ VERIFIED | File exists |
| `WorkoutAppTests/PaywallViewModelTests.swift` | 7 tests covering VM behavior | ✓ VERIFIED | File exists |
| `WorkoutAppTests/RetentionFlowTests.swift` | 7 tests covering pause duration and discount flow | ✓ VERIFIED | File exists |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| WorkoutApp.swift | RevenueCatService | configure() in .task before listenForAuthChanges | ✓ WIRED | appState.revenueCatService.configure() on line 40 |
| AppState.swift | RevenueCatService | logIn(userId: session.user.id.uuidString) in auth listener | ✓ WIRED | revenueCatService.logIn(userId: userId) in .initialSession/.signedIn handler |
| revenuecat-webhook/index.ts | profiles table | UPDATE subscription_status | ✗ NOT_WIRED | Payload parsing bug (CR-02): event.app_user_id is always undefined; database update never executes for real RC events |
| ContentView | PaywallView | fullScreenCover when !isSubscribed | ✓ WIRED | PaywallView() inside fullScreenCover with isAuthenticated && !isSubscribed binding |
| PaywallViewModel | RevenueCatService | fetchOfferings(), purchase(), refreshEntitlements() | ✓ WIRED | revenueCatService.fetchOfferings(), .purchase(), .refreshEntitlements() |
| ProfileView | CancellationRetentionView | NavigationLink push | ✓ WIRED | NavigationLink { CancellationRetentionView() } |
| PauseOptionsViewModel | Supabase profiles | UPDATE subscription_pause_until | ✓ WIRED | supabase.from("profiles").update(["subscription_pause_until":...]).eq("id", value: userId) |
| DiscountOfferViewModel | RevenueCatService | purchaseWithPromo(monthly_50pct_3months) | ✓ WIRED | revenueCatService.purchaseWithPromo(package: monthlyPackage, promoOfferID: "monthly_50pct_3months") |
| BlurredPlanGateView | any production screen | Usage in production | ✗ NOT_WIRED | BlurredPlanGateView only referenced in own #Preview — no production view uses it |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| PaywallView | annualPackage, monthlyPackage | RevenueCat fetchOfferings() | Conditional — requires App Store Connect products to be configured | ✓ FLOWING (when RC products exist) |
| ContentView | isSubscribed | RevenueCat logIn() -> entitlements["pro"] | Yes — RC entitlement check | ✓ FLOWING |
| PauseOptionsView | subscription_pause_until | Supabase UPDATE | Yes — writes to real DB column | ✓ FLOWING |
| revenuecat-webhook | subscription_status | RC event payload | NO — payload parsing bug means status update never runs | ✗ DISCONNECTED |

### Behavioral Spot-Checks

Step 7b: SKIPPED (iOS/Swift native app — no runnable entry points accessible from CLI)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SUBS-01 | 07-01, 07-02 | Monthly and annual subscription plans; annual pre-selected at discount | ✓ SATISFIED (with gap) | PaywallViewModel pre-selects annual; PricingCardView shows discount label. StoreKit prices incorrect but plan logic is correct |
| SUBS-02 | 07-02 | New users receive a free trial period before billing begins | ✓ SATISFIED | 14-day trial in StoreKit config (P14D); PaywallViewModel reads introductoryDiscount for trial CTA |
| SUBS-03 | 07-01, 07-02 | Paywall presented after user sees AI-generated plan preview | ✓ SATISFIED | Flow: PlanPreviewView -> "Start Training" -> markOnboardingComplete() -> ContentView branch 3 -> MainTabView + PaywallView fullScreenCover |
| SUBS-04 | 07-03 | Cancellation retention flow offered when user attempts to cancel | ✓ SATISFIED (with gap) | ProfileView -> CancellationRetentionView -> PauseOptionsView -> DiscountOfferView. Structural flow verified. BlurredPlanGateView for expired-user re-entry not wired |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| supabase/functions/revenuecat-webhook/index.ts | 50-60 | Flat JSON parse of nested RC payload — event.app_user_id always undefined | Blocker | webhook NEVER updates subscription_status; server-side subscription sync broken entirely |
| WorkoutApp/Configuration/WorkoutAppProducts.storekit | multiple | Prices $9.99/$59.99/$4.99 instead of D-01 $12.99/D-02 $79.99/D-12 $6.49 | Blocker | When App Store Connect products are created, their prices must match; StoreKit config used for local testing shows wrong prices, misleading sandbox testing |
| WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift | 36 | Body text "then your regular price" instead of "$6.49/month for 3 months, then $12.99/month" per D-12 | Warning | Users do not see the specific promotional price before accepting the offer; plan acceptance criterion fails |
| Config/Dev.xcconfig | 8 | Real RevenueCat sandbox API key committed (appl_efPqktxpbrfQbXOhuUnuoGopQYa) | Warning | Credential exposure risk; key grants access to sandbox environment and RevenueCat project configuration |
| WorkoutApp/Core/RevenueCatService.swift | 33 | Force-unwrap as! String for REVENUECAT_API_KEY in configure() | Warning | App crashes at launch if key absent from build configuration |
| WorkoutApp/Core/AppState.swift | 27-31 | isSubscribed = true in #if DEBUG always bypasses paywall in debug builds | Info | Paywall gate completely invisible during development; all debug test scenarios skip subscription |

### Human Verification Required

#### 1. Pricing Cards Render With Correct Prices

**Test:** Build and run on iOS simulator with App Store Connect products registered. Verify paywall renders annual card showing ~$6.67/month equivalent (billed $79.99/year) and monthly card showing $12.99/month.
**Expected:** Annual card pre-selected with orange border and "Most Popular" badge. Monthly card with gray border below. Prices match App Store Connect pricing.
**Why human:** Requires live RevenueCat offering fetch with registered products.

#### 2. CTA Shows Dynamic Trial Period

**Test:** As a new user (trial-eligible), verify the CTA button reads "Start 14-Day Free Trial" (not hardcoded "Start [N]-Day Free Trial").
**Expected:** N is dynamically resolved from introductoryDiscount.subscriptionPeriod.value at runtime.
**Why human:** Requires live StoreKit trial eligibility state.

#### 3. Sandbox Purchase Completes

**Test:** Tap the CTA button with a sandbox Apple ID. Complete the StoreKit purchase sheet. Verify "You're all set" success screen appears, then paywall dismisses and MainTabView is accessible.
**Expected:** Full purchase flow, success screen with dynamic trial copy, paywall auto-dismiss.
**Why human:** Requires live StoreKit sandbox transaction.

#### 4. Retention Flow Navigation

**Test:** With an active subscription (sandbox), go to Profile tab. Tap "Manage Subscription". Verify PauseOptionsView appears with heading "Life gets busy — take a break", three pause chips (1 month, 2 months, 3 months), and billing transparency notice. Tap "I still want to cancel" (for monthly subscriber). Verify DiscountOfferView pushes with heading "Stay for half price".
**Expected:** Three-screen flow navigates correctly. Billing transparency notice visible. "Cancel anyway" link appears in red.
**Why human:** Navigation flow and visual correctness require live subscription state.

#### 5. VoiceOver Accessibility on Pricing Cards

**Test:** Enable Accessibility Inspector in simulator. Navigate to paywall pricing cards. Verify VoiceOver announces plan name, price, and selected state.
**Expected:** Annual card: "Annual plan, $6.67/month, selected". Monthly card: "Monthly plan, $12.99/month, not selected".
**Why human:** VoiceOver behavior requires Accessibility Inspector.

---

## Gaps Summary

Four gaps block full phase goal achievement:

**Gap 1 — Webhook payload parsing broken (CR-02):** The RevenueCat webhook Edge Function has a critical payload structure mismatch. RevenueCat sends `{ api_version, event: { type, app_user_id, id } }` but the function reads `event.app_user_id` from the outer object (always `undefined`). Every real subscription event is rejected as an anonymous ID (HTTP 200) and `profiles.subscription_status` is never updated. This breaks the server-side subscription authority (D-19) — without it, the AI proxy Edge Functions cannot reliably gate content by server-side subscription status. Fix requires parsing `payload.event.app_user_id` from the nested structure.

**Gap 2 — BlurredPlanGateView not wired to production (D-14, D-15 unmet):** The component is correctly implemented but orphaned — no production screen uses it. Expired/lapsed users encounter the standard paywall (which blocks access correctly via D-13) but do not see the specific "blurred plan preview" experience that ROADMAP SC-1 calls for and that D-14/D-15 decisions describe. The component needs to be wired to the plan preview screen or equivalent content area visible from MainTabView.

**Gap 3 — Pricing configuration errors (D-01, D-02, D-12):** The StoreKit configuration file contains pre-decision prices ($9.99 monthly, $59.99 annual, $4.99 promotional) that contradict the settled decisions in CONTEXT.md (D-01: $12.99, D-02: $79.99, D-12: $6.49). Additionally, DiscountOfferView's body text omits the specific promotional prices required by D-12 and the plan's acceptance criteria. Both the StoreKit config prices and the DiscountOfferView body text need updating before App Store Connect products are registered.

**Gap 4 — Human verification incomplete (Plan 04 partial):** The 07-04 session completed only the first 10 of 32 verification steps. Purchase flow, pricing display, retention navigation, and accessibility checks remain unverified. These require App Store Connect product registration first.

---

_Verified: 2026-04-24T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
