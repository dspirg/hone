---
phase: 07-subscriptions-and-paywall
plan: 04
type: summary
status: partial
completed: 2026-04-22
---

# Plan 07-04 Summary — Human Verification (Partial)

## What Was Done

**Task 1: StoreKit Configuration file** — COMPLETE
- Created `WorkoutApp/Configuration/WorkoutAppProducts.storekit` with monthly ($9.99) and annual ($59.99) products, both with 14-day free trial introductory offers, and monthly with `monthly_50pct_3months` promotional offer
- Added to Xcode project navigator and scheme (Run → Options → StoreKit Configuration)

**Task 2: Human verification** — PARTIAL (see deferred items below)

## RevenueCat Setup Completed During This Session

- Fixed API key in `Config/Dev.xcconfig` — was `test_lh...` (Test Store key), corrected to `appl_efPqktxpbrfQbXOhuUnuoGopQYa` (Hone App Store key)
- Added `com.workoutapp.pro.monthly` and `com.workoutapp.pro.annual` products to Hone (App Store) in RevenueCat dashboard
- Updated default offering packages to reference Hone (App Store) products
- RevenueCat auth now works (all 200s)

## Verification Results

### Passed (visual, iOS 26 simulator)
- [x] Paywall appears as fullScreenCover on sign-in
- [x] Hard paywall — cannot drag to dismiss
- [x] Headline: "Your personalized plan is ready"
- [x] 4 orange checkmark bullets: AI plan, 500+ exercises, Coach chat, Adapts
- [x] Social proof: "Join 1,200 members"
- [x] "Restore Purchases" visible top-right

### Deferred — requires App Store Connect product setup
- [ ] Pricing cards load (monthly/annual with correct prices)
- [ ] Annual pre-selected with "Most Popular" badge (D-08)
- [ ] CTA reads "Start [N]-Day Free Trial" (dynamic from StoreKit)
- [ ] Fine print updates per selected card
- [ ] Sandbox purchase flow completes
- [ ] "You're all set" success screen
- [ ] Paywall dismisses after purchase, MainTabView visible
- [ ] Retention flow (requires active subscription in Profile tab)
- [ ] PauseOptionsView, DiscountOfferView navigation
- [ ] Accessibility checks

## Root Cause of Deferred Items

RevenueCat SDK 5.x (StoreKit 2) requires product IDs to exist in App Store Connect sandbox for real device testing. Local StoreKit configuration file testing on iOS 26 simulator did not work (likely iOS 26 beta / RevenueCat SDK compatibility issue). Products `com.workoutapp.pro.monthly` and `com.workoutapp.pro.annual` need to be created in App Store Connect before purchase flow can be verified.

## Decisions Made

- RevenueCat Hone (App Store) public API key is now the canonical key in `Dev.xcconfig`
- Products must be registered in App Store Connect before Phase 7 purchase verification can complete

## What's Next

Before Phase 7 can be fully closed:
1. Create app record in App Store Connect with bundle ID `com.danspirgen.hone`
2. Add in-app purchase subscription products matching the product IDs
3. Re-run verification steps 11–31 on device with sandbox account
