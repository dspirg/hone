---
phase: 07-subscriptions-and-paywall
plan: 01
subsystem: subscriptions
tags: [revenuecat, subscriptions, paywall, entitlements, webhook, supabase]
dependency_graph:
  requires: [01-01, 02-01, 03-01]
  provides: [RevenueCatService, AppState.isSubscribed, ContentView paywall gate, revenuecat-webhook Edge Function, subscription_pause_until migration]
  affects: [AppState, ContentView, WorkoutApp entry point, profiles table]
tech_stack:
  added: [RevenueCat SDK 5.x (purchases-ios SPM), RevenueCatUI 5.x]
  patterns: [dependency-injected service protocol, @MainActor mock for testing, Sendable protocol for Swift 6, fullScreenCover hard paywall gate]
key_files:
  created:
    - WorkoutApp/Core/RevenueCatService.swift
    - supabase/migrations/20260416000001_add_subscription_pause.sql
    - supabase/functions/revenuecat-webhook/index.ts
    - WorkoutAppTests/RevenueCatServiceTests.swift
    - WorkoutAppTests/EntitlementGateTests.swift
  modified:
    - WorkoutApp/Core/AppState.swift
    - WorkoutApp/WorkoutApp.swift
    - WorkoutApp/Info.plist
    - Config/Dev.xcconfig
    - Config/Prod.xcconfig
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - RevenueCat SDK 5.x (purchases-ios) added via SPM targeting upToNextMajorVersion from 5.0.0
  - Protocol-based RevenueCatServiceProtocol (Sendable) enables dependency injection without framework overhead
  - MockRevenueCatService is @MainActor final class to support XCTest async patterns safely
  - configure() called without appUserID at launch — logIn() called separately after Supabase auth resolves (Pitfall 1 guard)
  - cachedIsSubscribed() read synchronously at launch before auth listener starts (Pitfall 6 flash prevention)
  - ContentView paywall uses fullScreenCover with no-op setter — only dismissed when isSubscribed becomes true (D-13 hard paywall)
  - Webhook returns 200 on anonymous ID rejection to prevent RC retries on a permanently bad payload
  - Webhook returns 500 on DB update failure to trigger RC retry (up to 5x exponential backoff)
  - State-driven event mapping (not toggle logic) ensures idempotency (Pitfall 7)
metrics:
  duration: ~45 minutes
  completed: "2026-04-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 6
---

# Phase 07 Plan 01: RevenueCat SDK Integration and Subscription Infrastructure Summary

**One-liner:** RevenueCat SDK 5.x integrated with Sendable protocol wrapper, AppState entitlement gating via "pro" entitlement, hard paywall fullScreenCover, webhook Edge Function with RC_WEBHOOK_SECRET validation and anonymous ID rejection, and profiles migration for subscription_pause_until and grace_period status.

## What Was Built

### Task 1: RevenueCatService + AppState Integration + ContentView Gate + Test Scaffolds

**RevenueCatService.swift** (`WorkoutApp/Core/RevenueCatService.swift`)

Defines `RevenueCatServiceProtocol: Sendable` with all async methods needed by the subscription system:
- `configure()` — SDK init at launch (no appUserID — intentional per RESEARCH Pitfall 1)
- `logIn(userId:)` — called with Supabase UUID immediately after auth resolves; returns `entitlements["pro"]?.isActive`
- `logOut()` — clears RC identity on sign-out
- `refreshEntitlements()` — async re-check returning false on error (safe default)
- `fetchOfferings()`, `purchase(package:)`, `purchaseWithPromo(package:promoOfferID:)`, `getPromotionalOffer(offerID:product:)` — full purchase flow for Plan 02
- `cachedIsSubscribed()` — synchronous SDK cache read for launch flash prevention (Pitfall 6)

`MockRevenueCatService` is a `@MainActor final class` that tracks `logInCallCount`, `logInUserIdReceived`, `logOutCallCount`, `configureCallCount` for test assertions. `cachedIsSubscribed()` returns `mockIsSubscribed` directly.

**AppState.swift** additions:
- `var isSubscribed: Bool = false` — driven by RevenueCat "pro" entitlement (D-18)
- `var isOnboarded: Bool = false` — mirrors onboardingCompleted for SUBS-03
- `var revenueCatService: RevenueCatServiceProtocol = RevenueCatService()` — injectable
- In `listenForAuthChanges()` `.signedIn`/`.initialSession` branch: calls `revenueCatService.logIn(userId: session.user.id.uuidString)` immediately after auth resolves (RESEARCH Pitfall 1 critical guard)
- In `.signedOut` branch: calls `revenueCatService.logOut()` and sets `isSubscribed = false`
- New `refreshEntitlements()` method — called by PaywallView after purchase to dismiss the gate
- `markOnboardingComplete()` now also sets `isOnboarded = true`

**WorkoutApp.swift** changes:
- `.task` modifier now calls `appState.revenueCatService.configure()` and `appState.isSubscribed = appState.revenueCatService.cachedIsSubscribed()` BEFORE `listenForAuthChanges()` — ensures SDK is ready and flash prevention is in place
- `ContentView` updated: Branch 1 (authenticated + onboarded) now shows `MainTabView()` with `.fullScreenCover` that gates on `!appState.isSubscribed`. Binding setter is no-op — cover dismisses only when `isSubscribed` becomes true. Placeholder text "Subscription required" will be replaced by full `PaywallView` in Plan 02.

**xcconfig + Info.plist:**
- `Config/Dev.xcconfig`: added `REVENUECAT_API_KEY = appl_REPLACE_WITH_RC_KEY`
- `Config/Prod.xcconfig`: added `REVENUECAT_API_KEY = appl_REPLACE_WITH_PROD_RC_KEY`
- `WorkoutApp/Info.plist`: added `REVENUECAT_API_KEY` key with `$(REVENUECAT_API_KEY)` value

**project.pbxproj:**
- Added `XCRemoteSwiftPackageReference "purchases-ios"` pointing to `https://github.com/RevenueCat/purchases-ios`, `upToNextMajorVersion` from `5.0.0`
- Added `RevenueCat` and `RevenueCatUI` product dependencies on WorkoutApp target
- Added `RevenueCatService.swift` to Core group and Sources build phase
- Added `RevenueCatServiceTests.swift` and `EntitlementGateTests.swift` to WorkoutAppTests group and Sources build phase

### Task 2: Supabase Migration + Webhook Edge Function

**Migration** (`supabase/migrations/20260416000001_add_subscription_pause.sql`):
- `ADD COLUMN subscription_pause_until TIMESTAMPTZ DEFAULT NULL` — stores in-app pause end date (D-11; Apple has no native pause API per Pitfall 5)
- `DROP CONSTRAINT profiles_subscription_status_check` + `ADD CONSTRAINT` with `('free', 'subscribed', 'grace_period')` — adds grace_period for D-16
- RLS policy `"Users cannot update subscription_status directly"` — WITH CHECK ensures `subscription_status` cannot change via user JWT; only service_role (webhook) can modify it (T-07-06)

**Webhook Edge Function** (`supabase/functions/revenuecat-webhook/index.ts`):
- Step 1: Verifies `Authorization: Bearer {RC_WEBHOOK_SECRET}` header (T-07-02) — returns 401 if wrong/missing
- Step 2: Parses JSON payload
- Step 3: Rejects `$RCAnonymousID` payloads with detailed logging and 200 response (Pitfall 1 guard — permanent failure, no retry needed)
- Step 4: Validates UUID format with regex (T-07-03)
- Step 5: State-driven mapping: `ACTIVE_EVENTS` → `subscribed`, `GRACE_EVENTS` (BILLING_ISSUE) → `grace_period`, `INACTIVE_EVENTS` → `free` (Pitfall 7 idempotency)
- Step 6: Updates `profiles.subscription_status` via service_role key (bypasses RLS — T-07-06)
- Step 7: Returns 500 on DB error (triggers RC retry), 200 on success

## Threat Mitigations Applied

| Threat ID | Mitigation |
|-----------|-----------|
| T-07-01 | `isSubscribed` is UX gate only; documented that backend AI proxy must read `profiles.subscription_status` |
| T-07-02 | Webhook verifies `RC_WEBHOOK_SECRET` Authorization header before any processing |
| T-07-03 | Webhook rejects anonymous IDs and validates UUID format |
| T-07-04 | State-driven mapping (not toggle logic) — duplicate events produce identical SET operations |
| T-07-05 | Accepted — RevenueCat public API key (appl_*) is intentionally public |
| T-07-06 | RLS policy prevents user JWT from modifying subscription_status; webhook uses service_role key |

## Deviations from Plan

None — plan executed exactly as written with one clarification:

**ContentView routing preserved:** The existing 3-branch routing (authenticated+onboarded, authenticated+not-onboarded, not-authenticated) was preserved. The paywall fullScreenCover was added to Branch 1 (MainTabView) rather than replacing the routing structure, which matches the plan's intent while preserving the existing onboarding gate from Phase 3.

## Known Stubs

**PaywallView placeholder in ContentView:** The `fullScreenCover` body currently shows `Text("Subscription required")`. This is an intentional stub — Plan 02 replaces it with the full custom `PaywallView`. The gate logic (`isAuthenticated && !isSubscribed`) is fully functional; only the UI inside the cover is a placeholder.

## User Setup Required Before Testing

RevenueCat and App Store Connect setup is required before end-to-end testing:
1. Create RevenueCat account and project at `app.revenuecat.com`
2. Add iOS app with bundle ID `com.danspirgen.hone`
3. Create entitlement named `pro`
4. Create Offering named `default` with monthly and annual packages
5. Replace `REVENUECAT_API_KEY` placeholder in `Config/Dev.xcconfig` with real sandbox key
6. Configure webhook URL: `https://{supabase-project}.supabase.co/functions/v1/revenuecat-webhook`
7. Set `RC_WEBHOOK_SECRET` in Supabase Vault
8. Create subscription products in App Store Connect (see plan `user_setup` section)

## Self-Check

### Files Created/Modified

- [x] `WorkoutApp/Core/RevenueCatService.swift` — FOUND
- [x] `WorkoutApp/Core/AppState.swift` — FOUND (modified)
- [x] `WorkoutApp/WorkoutApp.swift` — FOUND (modified)
- [x] `Config/Dev.xcconfig` — FOUND (modified)
- [x] `Config/Prod.xcconfig` — FOUND (modified)
- [x] `WorkoutApp/Info.plist` — FOUND (modified)
- [x] `WorkoutApp.xcodeproj/project.pbxproj` — FOUND (modified)
- [x] `WorkoutAppTests/RevenueCatServiceTests.swift` — FOUND
- [x] `WorkoutAppTests/EntitlementGateTests.swift` — FOUND
- [x] `supabase/migrations/20260416000001_add_subscription_pause.sql` — FOUND
- [x] `supabase/functions/revenuecat-webhook/index.ts` — FOUND

### Acceptance Criteria

- [x] `RevenueCatServiceProtocol` in RevenueCatService.swift
- [x] `MockRevenueCatService` in RevenueCatService.swift
- [x] `entitlements["pro"]` in RevenueCatService.swift (D-18)
- [x] `logIn.*uuidString` in AppState.swift (Pitfall 1 guard)
- [x] `isSubscribed` in AppState.swift
- [x] `refreshEntitlements` in AppState.swift
- [x] `cachedIsSubscribed` in WorkoutApp.swift (Pitfall 6 flash prevention)
- [x] `configure` in WorkoutApp.swift (SDK init before auth listener)
- [x] `purchases-ios` in project.pbxproj (SPM dependency)
- [x] `REVENUECAT_API_KEY` in Dev.xcconfig
- [x] `REVENUECAT_API_KEY` in Prod.xcconfig
- [x] `fullScreenCover` in WorkoutApp.swift (paywall gate)
- [x] `logInUserIdReceived` in RevenueCatService.swift (mock tracks UUID for test)
- [x] `RevenueCatServiceTests.swift` exists
- [x] `EntitlementGateTests.swift` exists
- [x] `subscription_pause_until` in migration
- [x] `grace_period` in migration (D-16)
- [x] `RC_WEBHOOK_SECRET` in webhook Edge Function (T-07-02)
- [x] `RCAnonymousID` rejection in webhook (Pitfall 1)
- [x] `INITIAL_PURCHASE` in webhook
- [x] `BILLING_ISSUE` in webhook (grace period)
- [x] `CANCELLATION` in webhook
- [x] `subscription_status` in webhook
- [x] `service_role` in webhook (T-07-06 RLS bypass)

## Self-Check: PASSED

All files created and verified via Glob tool. All acceptance criteria satisfied by file content inspection.
