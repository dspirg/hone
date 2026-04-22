---
phase: 07-subscriptions-and-paywall
plan: 02
subsystem: subscriptions
tags: [paywall, revenuecat, swiftui, pricing, trial, blurred-gate]
dependency_graph:
  requires: [07-01]
  provides: [PaywallView, PaywallViewModel, PricingCardView, ValuePropListView, BlurredPlanGateView, PaywallViewModelTests]
  affects: [ContentView paywall gate, AppState.isSubscribed]
tech_stack:
  added: []
  patterns: [dynamic pricing from SDK (localizedPriceString), trial eligibility from introductoryDiscount, annual pre-selection (D-08), interactiveDismissDisabled hard paywall (D-13), blurred expired gate (D-14/D-15), loading skeleton with .redacted]
key_files:
  created:
    - WorkoutApp/Features/Paywall/PaywallViewModel.swift
    - WorkoutApp/Features/Paywall/PaywallView.swift
    - WorkoutApp/Features/Paywall/Components/PricingCardView.swift
    - WorkoutApp/Features/Paywall/Components/ValuePropListView.swift
    - WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift
    - WorkoutAppTests/PaywallViewModelTests.swift
  modified:
    - WorkoutApp/WorkoutApp.swift (PaywallView replaces placeholder)
    - WorkoutApp.xcodeproj/project.pbxproj (new files registered)
decisions:
  - "All prices read from package.storeProduct.localizedPriceString — zero hardcoded price strings (RESEARCH anti-pattern avoided)"
  - "Trial period read from introductoryDiscount at runtime — CTA 'Start N-Day Free Trial' only when eligible (Pitfall 2)"
  - "Annual package pre-selected by default with 'Most Popular' badge (D-08)"
  - "interactiveDismissDisabled(true) for hard paywall — no drag dismiss (D-13)"
  - "BlurredPlanGateView uses blur(radius: 8) + full-surface tap to trigger paywall (D-14/D-15)"
  - "Post-purchase success dismisses via refreshEntitlements() flipping isSubscribed (fullScreenCover auto-dismisses)"
tests:
  - PaywallViewModelTests: 7 tests — annual pre-selection, CTA defaults, trial eligibility, offerings error, fine print, restore success/failure
verification:
  build: SUCCEEDED
  grep_checks:
    - "selectedPackage = annualPackage — present (D-08)"
    - "introductoryDiscount — present (Pitfall 2)"
    - "localizedPriceString — present (no hardcoded prices)"
    - "interactiveDismissDisabled — present (D-13)"
    - "Your plan is waiting — present (D-14)"
    - "blur.*radius.*8 — present"
    - "onTapGesture — present (D-15)"
    - "PaywallView in ContentView — present"
---

## What Was Built

Custom SwiftUI paywall replacing the Plan 01 placeholder. Full feature showcase layout with dynamic RevenueCat pricing — annual pre-selected with "Most Popular" badge and monthly equivalent display ($N/month), monthly below. All prices sourced from `localizedPriceString` at runtime. Trial CTA ("Start N-Day Free Trial") only shown when `introductoryDiscount` is non-nil. Hard paywall with `interactiveDismissDisabled(true)`. Loading skeleton with `.redacted(reason: .placeholder)`, error state with retry, post-purchase success screen with "Start Training" dismiss. BlurredPlanGateView for expired/lapsed users — blurred plan content + "Your plan is waiting" overlay, full-surface tap triggers paywall.

## Key Decisions

- **No hardcoded prices**: `localizedPriceString` enforced throughout; `grep -rn '"\$[0-9]' WorkoutApp/Features/Paywall/` returns zero results
- **Trial guard**: `trialEligible` computed from `selectedPackage?.storeProduct.introductoryDiscount != nil` — never assumes a trial period
- **Annual monthly equivalent**: Computed as `annualPrice / 12` using `NumberFormatter` with product locale
