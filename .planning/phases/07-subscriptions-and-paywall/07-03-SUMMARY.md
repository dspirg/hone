---
phase: 07-subscriptions-and-paywall
plan: 03
subsystem: subscriptions
tags: [retention, cancellation, pause, discount, promotional-offer, profile]
dependency_graph:
  requires: [07-01]
  provides: [CancellationRetentionView, PauseOptionsView/ViewModel, DiscountOfferView/ViewModel, ProfileView, RetentionFlowTests]
  affects: [ProfileView, profiles table (subscription_pause_until), RevenueCat promotional offer]
tech_stack:
  added: [RevenueCatUI (CustomerCenterView for restore)]
  patterns: [pause-first retention flow, eligibility guard (monthly-only discount), Apple managementURL handoff, Supabase profiles UPDATE for pause date]
key_files:
  created:
    - WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift
    - WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift
    - WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift
    - WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift
    - WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift
    - WorkoutAppTests/RetentionFlowTests.swift
  modified:
    - WorkoutApp/Features/Main/Tabs/ProfileView.swift (placeholder replaced with functional profile)
    - WorkoutApp.xcodeproj/project.pbxproj (new files registered)
decisions:
  - "Pause is in-app UX only — Apple has NO native pause API (RESEARCH Pitfall 5); billing continues; mandatory transparency notice in UI"
  - "Discount screen only shown to active monthly subscribers (non-trial) — annual/trial skip to managementURL (RESEARCH Assumption A4)"
  - "Promo offer ID 'monthly_50pct_3months' verified against storeProduct.discounts before purchase attempt"
  - "'Cancel anyway' link uses Color.red (destructive) and opens Apple managementURL directly"
  - "ProfileView uses NavigationStack + NavigationLink (push) for retention flow — not sheet"
tests:
  - RetentionFlowTests: 7 tests — pause duration labels (D-11), CTA reactivity, selection state, promo ID, error handling, initial state
verification:
  build: SUCCEEDED
  grep_checks:
    - "Life gets busy — present (UI-SPEC heading)"
    - "Pausing hides your plan in the app — present (mandatory billing transparency)"
    - "subscription_pause_until — present (Supabase write)"
    - "monthly_50pct_3months — present (D-12)"
    - "isEligibleForDiscount — present (A4 eligibility guard)"
    - "isInTrial — present (trial users skip discount)"
    - "Manage Subscription in ProfileView — present (D-09)"
    - "CancellationRetentionView in ProfileView — present"
---

## What Was Built

Full cancellation retention flow accessible from Profile tab. `CancellationRetentionView` is the navigation coordinator: checks `activeSubscriptions` for monthly product and `periodType != .trial` to determine discount eligibility. For eligible users: pause chips screen → "I still want to cancel" → discount offer screen. For ineligible (annual/trial): pause chips → "I still want to cancel" → Apple managementURL directly.

`PauseOptionsView` shows 3 pause duration chips (1/2/3 months per D-11) with mandatory billing transparency notice ("Pausing hides your plan in the app. Your billing continues..."). On confirm, `PauseOptionsViewModel` writes `subscription_pause_until` to Supabase profiles then redirects to Apple managementURL.

`DiscountOfferView` presents 50% off for 3 months. `DiscountOfferViewModel` fetches the monthly package, verifies the `monthly_50pct_3months` promo exists on the product's `storeProduct.discounts`, then calls `purchaseWithPromo`. "Cancel anyway" is red/destructive and opens Apple managementURL. `ProfileView` replaced placeholder with List-based account, subscription ("Manage Subscription" → retention flow), and sign-out sections.
