---
phase: 10-design-system-and-visual-identity
fixed_at: 2026-04-27T00:00:00Z
review_path: .planning/phases/10-design-system-and-visual-identity/10-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 10: Code Review Fix Report

**Fixed at:** 2026-04-27
**Source review:** .planning/phases/10-design-system-and-visual-identity/10-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (1 Critical, 7 Warning)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: Hardcoded Pricing Strings in DiscountOfferView

**Files modified:** `WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift`, `WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift`
**Commit:** 68c82b5
**Applied fix:** Added `discountPriceLabel` and `regularPriceLabel` published properties to `DiscountOfferViewModel`. Added a `loadPricingLabels()` private method that fetches the monthly product's `localizedPriceString` and the `monthly_50pct_3months` discount's `localizedPriceString` from the RevenueCat SDK at runtime. `loadManagementURL()` now calls `loadPricingLabels()` so prices are populated when the view initializes. Both hardcoded string literals in `DiscountOfferView` are replaced with `\(vm.discountPriceLabel)` and `\(vm.regularPriceLabel)` interpolations. Placeholder values default to `"—"` until the SDK responds.

### WR-01: Duplicate ChipView and OnboardingProgressView Definitions

**Files modified:** `WorkoutApp/Features/Onboarding/Components/ChipView.swift` (deleted), `WorkoutApp/Features/Onboarding/Components/OnboardingProgressView.swift` (deleted)
**Commit:** 3c9430c
**Applied fix:** Deleted the byte-for-byte duplicate files from `Features/Onboarding/Components/`. The canonical definitions in `WorkoutApp/Core/Components/ChipView.swift` and `WorkoutApp/Core/Components/OnboardingProgressView.swift` remain as the single source of truth. Both are in the same app target, so the Swift compiler will catch any future re-introduction of duplicates at build time.

### WR-02: Deprecated `.cornerRadius()` Modifier Used Instead of `.clipShape()`

**Files modified:** `WorkoutApp/Features/Auth/AuthView.swift`, `WorkoutApp/Features/Auth/PasswordResetView.swift`
**Commit:** a169f47
**Applied fix:** Replaced all six occurrences of `.cornerRadius(12)` with `.clipShape(RoundedRectangle(cornerRadius: 12))`. This covers the Display Name field, Email field, and Password field in `AuthView`, the primary CTA button in `AuthView`, the Email field in `PasswordResetView`, and the primary CTA button in `PasswordResetView`. The `clipShape` modifier correctly clips both the view content and the `borderedProminent` button background.

### WR-03: VideoOverlayView Silently Accepts Empty muxPlaybackId

**Files modified:** `WorkoutApp/Features/Train/VideoOverlayView.swift`
**Commit:** 92cf026
**Applied fix:** Added `if !muxPlaybackId.isEmpty` guard before instantiating `VideoPlayerView`, preventing invalid Mux HLS URL construction on empty IDs. Added a dismiss button (`xmark.circle.fill`) anchored to the top-trailing corner that calls the existing `dismiss` environment action — `@Environment(\.dismiss)` was already declared but unused. The button includes an `accessibilityLabel("Close video")`.

### WR-04: PaywallView Error State Comparison Uses String Literal Equality

**Files modified:** `WorkoutApp/Features/Paywall/PaywallViewModel.swift`, `WorkoutApp/Features/Paywall/PaywallView.swift`
**Commit:** a47ef67
**Applied fix:** Added `PaywallLoadState` enum (`idle`, `loading`, `loaded`, `pricingError`) to `PaywallViewModel.swift`. Added `var loadState: PaywallLoadState = .idle` property. `loadOfferings()` now sets `loadState = .loading` at entry, `loadState = .loaded` on success, and `loadState = .pricingError` on error alongside the existing `errorMessage` assignment. Both string comparisons in `PaywallView` replaced: `viewModel.errorMessage != "Couldn't load pricing"` becomes `viewModel.loadState != .pricingError`, and the `else if viewModel.errorMessage == "Couldn't load pricing"` branch becomes `else if viewModel.loadState == .pricingError`.

### WR-05: NotificationScheduler Singleton init Is Public, Allowing Multiple Instances

**Files modified:** `WorkoutApp/Core/Notifications/NotificationScheduler.swift`
**Commit:** 3a45e6e
**Applied fix:** Added `private` access modifier to `init(context:)`. The singleton `static let shared` continues to work since it is inside the class body and can access `private` init. All external code now must use `NotificationScheduler.shared`.

### WR-06: "Go to Train" Button in ProgressView Empty State Has No Action

**Files modified:** `WorkoutApp/Features/Progress/ProgressView.swift`
**Commit:** 12c1ba9
**Applied fix:** Replaced the actionless `Button("Go to Train") {}` with a non-interactive `Text("Go to the Train tab to start a workout")` styled as `.subheadline` / `.secondary`. This removes the accessibility trap (a button that does nothing) while preserving the user-facing guidance. When tab-switching from this view is wired up in a future iteration, a proper `Button` with `@Binding var selectedTab` from `MainTabView` can be introduced.

### WR-07: restTimerOverlay ProgressView Uses Stale Start Time

**Files modified:** `WorkoutApp/Features/Session/Components/RestTimerOverlay.swift`
**Commit:** fae23e3
**Applied fix:** Added `@State private var timerStartDate: Date = Date()` which is captured once when the view is first rendered and does not change on subsequent re-renders. Replaced `Date()...endDate` in the `ProgressView(timerInterval:)` call with `timerStartDate...endDate`. The countdown text driven by `Text(endDate, style: .timer)` was already correctly anchored to `endDate` and was not changed.

---

_Fixed: 2026-04-27_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
