---
phase: 10-design-system-and-visual-identity
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 47
files_reviewed_list:
  - WorkoutApp/Core/Theme.swift
  - WorkoutApp/Core/Components/ChipView.swift
  - WorkoutApp/Core/Components/OnboardingProgressView.swift
  - WorkoutApp/Core/Notifications/NotificationScheduler.swift
  - WorkoutApp/Features/Auth/AuthView.swift
  - WorkoutApp/Features/Auth/PasswordResetView.swift
  - WorkoutApp/Features/Coach/Components/ChatBubbleView.swift
  - WorkoutApp/Features/Coach/Components/ChatInputBar.swift
  - WorkoutApp/Features/Coach/Components/CoachHeaderView.swift
  - WorkoutApp/Features/Coach/Components/HoneAvatarView.swift
  - WorkoutApp/Features/Coach/Components/OfflineBannerView.swift
  - WorkoutApp/Features/Coach/Components/PlanModificationCard.swift
  - WorkoutApp/Features/Disclaimer/DisclaimerView.swift
  - WorkoutApp/Features/Main/MainTabView.swift
  - WorkoutApp/Features/Main/Tabs/CoachView.swift
  - WorkoutApp/Features/Main/Tabs/HomeView.swift
  - WorkoutApp/Features/Main/Tabs/TrainView.swift
  - WorkoutApp/Features/Onboarding/Cards/EquipmentCardView.swift
  - WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift
  - WorkoutApp/Features/Onboarding/Components/ChipView.swift
  - WorkoutApp/Features/Onboarding/Components/OnboardingProgressView.swift
  - WorkoutApp/Features/Onboarding/OnboardingView.swift
  - WorkoutApp/Features/Paywall/Components/PricingCardView.swift
  - WorkoutApp/Features/Paywall/Components/ValuePropListView.swift
  - WorkoutApp/Features/Paywall/PaywallView.swift
  - WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift
  - WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift
  - WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift
  - WorkoutApp/Features/PlanPreview/Components/WorkoutDayCardView.swift
  - WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift
  - WorkoutApp/Features/PlanPreview/PlanPreviewView.swift
  - WorkoutApp/Features/Progress/Components/ChartSectionView.swift
  - WorkoutApp/Features/Progress/Components/PRBadgeView.swift
  - WorkoutApp/Features/Progress/Components/SessionDetailView.swift
  - WorkoutApp/Features/Progress/Components/StreakCard.swift
  - WorkoutApp/Features/Progress/Components/WeeklyRingView.swift
  - WorkoutApp/Features/Progress/ProgressView.swift
  - WorkoutApp/Features/Session/Components/RestTimerOverlay.swift
  - WorkoutApp/Features/Session/Components/SessionProgressBar.swift
  - WorkoutApp/Features/Session/Components/SessionSummaryView.swift
  - WorkoutApp/Features/Session/Components/SetLogRow.swift
  - WorkoutApp/Features/Session/SessionView.swift
  - WorkoutApp/Features/Train/ExerciseDetailView.swift
  - WorkoutApp/Features/Train/ExerciseLibraryRowView.swift
  - WorkoutApp/Features/Train/FilterChipRow.swift
  - WorkoutApp/Features/Train/VideoOverlayView.swift
  - WorkoutApp/WorkoutApp.swift
findings:
  critical: 1
  warning: 7
  info: 8
  total: 16
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 47
**Status:** issues_found

## Summary

Reviewed all UI source files in scope for the Design System and Visual Identity phase. The codebase has a solid foundation: `Theme.swift` provides a clean token layer, accessibility annotations are generally thorough, and the component hierarchy is well-structured. The design system is mostly consistent across the codebase — chip shapes, spacing scale, and typography follow the documented spec.

Key concerns found during review:

1. **Critical:** `DiscountOfferView` hardcodes subscription pricing strings (`$6.49/month`, `$12.99/month`) directly in the UI, violating the project's own established rule that all pricing must come from the RevenueCat SDK at runtime. This is a data correctness issue: if pricing changes in the App Store, the UI will show wrong prices.
2. **Warnings:** Duplicate component definitions exist for `ChipView` and `OnboardingProgressView` across `Core/Components/` and `Features/Onboarding/Components/` — these are byte-for-byte identical, creating a maintenance risk. Several views use deprecated `cornerRadius` modifier instead of `clipShape`. The `VideoOverlayView` silently accepts but ignores an empty `muxPlaybackId`. The error state comparison in `PaywallView` uses string literal equality against an error message, which is fragile. `NotificationScheduler.init` is not private despite having a singleton, allowing multiple instances to be created.
3. **Info:** Magic color values appear in `HoneAvatarView`. The `Go to Train` button in `ProgressView`'s empty state has no action wired up. Minor accessibility gaps, and some dead `@State` variables.

---

## Critical Issues

### CR-01: Hardcoded Pricing Strings in DiscountOfferView

**File:** `WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift:36-46`
**Issue:** Subscription prices `$6.49/month for 3 months, then $12.99/month` are hardcoded as string literals in two separate places in this file. The PaywallView comment (`RESEARCH anti-pattern`) and the `PricingCardView` docstring explicitly state: "All pricing strings read from SDK at runtime — never hardcoded." If App Store pricing changes, the discount offer screen will display incorrect prices while the actual charge is different. This can trigger App Store review rejection and user trust issues.

**Fix:** Pull the price strings from the `DiscountOfferViewModel` which already holds a reference to `RevenueCatService`. The view model should fetch the promotional offer price from the SDK and expose it as a computed property:
```swift
// In DiscountOfferViewModel:
var discountPriceLabel: String {
    // Fetch from promotional offer on the RevenueCat package
    return promotionalOffer?.storeProductDiscount.localizedPriceString ?? "—"
}

// In DiscountOfferView — replace hardcoded strings:
Text("Get 50% off for the next 3 months — \(vm.discountPriceLabel)/month for 3 months, then \(vm.regularPriceLabel)/month.")
```

---

## Warnings

### WR-01: Duplicate ChipView and OnboardingProgressView Definitions

**File:** `WorkoutApp/Core/Components/ChipView.swift` and `WorkoutApp/Features/Onboarding/Components/ChipView.swift` (lines 1–44 in both)
**File:** `WorkoutApp/Core/Components/OnboardingProgressView.swift` and `WorkoutApp/Features/Onboarding/Components/OnboardingProgressView.swift` (lines 1–48 in both)
**Issue:** Both `ChipView` and `OnboardingProgressView` are defined twice — once in `Core/Components/` and once in `Features/Onboarding/Components/`. The implementations are identical. Swift will produce a compiler error if both are compiled into the same module target. If they are currently in separate targets this will silently diverge — any fix applied to one copy will not apply to the other, causing future inconsistencies.

**Fix:** Delete the copies in `Features/Onboarding/Components/` and use the canonical definitions from `Core/Components/`. Verify both files are in the same app target in Xcode so the duplication is caught at build time immediately.

### WR-02: Deprecated `.cornerRadius()` Modifier Used Instead of `.clipShape()`

**Files:**
- `WorkoutApp/Features/Auth/AuthView.swift:57, 66, 75` (text fields and primary button)
- `WorkoutApp/Features/Auth/PasswordResetView.swift:51, 82` (email field and button)

**Issue:** These views use `.cornerRadius(12)` which was soft-deprecated in iOS 16 in favor of `.clipShape(RoundedRectangle(cornerRadius: 12))`. The rest of the codebase consistently uses `.clipShape(...)`. Using `.cornerRadius` on a `Button` with `.borderedProminent` style also does not clip the button's background — the system-rendered button background will still use its default shape, so the corner radius is applied to the wrong layer.

**Fix:**
```swift
// Replace this pattern:
.background(Theme.surface)
.cornerRadius(12)

// With:
.background(Theme.surface)
.clipShape(RoundedRectangle(cornerRadius: 12))

// For the primary CTA Button, add .clipShape after .tint:
.buttonStyle(.borderedProminent)
.tint(Theme.accent)
.clipShape(RoundedRectangle(cornerRadius: 12))
// Remove the separate .cornerRadius(12) line
```

### WR-03: VideoOverlayView Silently Accepts Empty muxPlaybackId

**File:** `WorkoutApp/Features/Train/VideoOverlayView.swift:12`
**Issue:** `VideoOverlayView` initializes `VideoPlayerView(muxPlaybackId: muxPlaybackId, localAssetURL: nil)` unconditionally. Both callers (`ExerciseRowView` line 52, `ExerciseLibraryRowView` line 55) guard `muxPlaybackId != nil` before showing the overlay, but they pass `muxPlaybackId ?? ""` — meaning an empty string reaches `VideoPlayerView` if the guard somehow fails. More importantly, `VideoOverlayView` itself has no guard, so it can be instantiated with an empty playback ID and will try to construct an invalid Mux HLS URL. `VideoOverlayView` also declares `@Environment(\.dismiss) private var dismiss` but never uses it — there is no way to close the overlay from within the view.

**Fix:**
```swift
struct VideoOverlayView: View {
    let muxPlaybackId: String
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if !muxPlaybackId.isEmpty {
                VideoPlayerView(muxPlaybackId: muxPlaybackId, localAssetURL: nil)
            }
            // Add dismiss button so user can close the overlay:
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .ignoresSafeArea()
    }
}
```

### WR-04: PaywallView Error State Comparison Uses String Literal Equality

**File:** `WorkoutApp/Features/Paywall/PaywallView.swift:69, 123`
**Issue:** Two separate locations compare `viewModel.errorMessage` to the string `"Couldn't load pricing"` using `==`. This is fragile: if the error message string changes in the view model (e.g. for localization or copy updates), one or both of these comparisons will silently break, causing the CTA button and fine print to show when they should be hidden (or the pricing error UI to not appear). The CTA guard on line 69 inverts the check with `!=`, meaning any non-matching error string will show the CTA incorrectly.

**Fix:** Expose a typed error state from `PaywallViewModel` instead of an `errorMessage: String?`:
```swift
// In PaywallViewModel:
enum LoadState { case idle, loading, loaded, pricingError }
var loadState: LoadState = .idle

// In PaywallView — replace string comparisons:
if viewModel.loadState != .pricingError {
    ctaButton
    // ...
}
// And:
} else if viewModel.loadState == .pricingError {
    // error card
}
```

### WR-05: NotificationScheduler Singleton init Is Public, Allowing Multiple Instances

**File:** `WorkoutApp/Core/Notifications/NotificationScheduler.swift:35-37`
**Issue:** `NotificationScheduler` declares a `static let shared` singleton (line 27) but its `init(context:)` is `internal` (no access modifier, defaults to `internal`). Any code in the module can call `NotificationScheduler()` and create an independent instance with its own `NSManagedObjectContext`. A second instance scheduling notifications will not be aware of what the first scheduled, potentially resulting in duplicate notifications or incorrect frequency-cap accounting (the `reengagementPending.count < 2` guard on line 178 queries `UNUserNotificationCenter` directly so it would still work, but `hasLoggedSessionToday` queries a potentially different `context`).

**Fix:**
```swift
// Make init private to enforce singleton use:
private init(context: NSManagedObjectContext? = nil) {
    self.context = context ?? PersistenceController.shared.container.viewContext
}
```

### WR-06: "Go to Train" Button in ProgressView Empty State Has No Action

**File:** `WorkoutApp/Features/Progress/ProgressView.swift:144-148`
**Issue:** The `emptyState` view includes a `Button("Go to Train")` with a comment "Visual cue only — tab switching handled by MainTabView," but the button body is empty. A user tapping this button will see no response whatsoever — no tab change, no visual feedback, nothing. A button with no action creates a broken UX and fails accessibility expectations (screen reader users will encounter an interactive element that does nothing).

**Fix:** Either wire the button to a tab-switching mechanism (e.g., pass a binding or use a shared selection state from the parent), or replace it with a non-interactive label if tab switching truly cannot be triggered from here:
```swift
// Option A — make it non-interactive if tab switching is not yet wired:
Text("Go to the Train tab to start a workout")
    .font(.subheadline)
    .foregroundStyle(.secondary)

// Option B — wire tab selection via an @Binding passed from MainTabView:
Button("Go to Train") {
    selectedTab = 1  // Train tab index
}
.buttonStyle(.borderedProminent)
```

### WR-07: restTimerOverlay ProgressView Uses Stale Start Time

**File:** `WorkoutApp/Features/Session/Components/RestTimerOverlay.swift:41`
**Issue:** The `ProgressView(timerInterval: Date()...endDate, countsDown: true)` call captures `Date()` at the moment the view body is evaluated. If SwiftUI re-renders the view body (e.g., due to any state change in the parent), `Date()` will be re-evaluated to the current time, resetting the visible start of the progress ring even though `endDate` has not changed. The countdown text (`Text(endDate, style: .timer)`) is correctly anchored to `endDate` and will be unaffected, but the circular ring's fill fraction will jump because the interval start is re-read on each render.

**Fix:** Capture the timer start time once when the overlay appears:
```swift
@State private var timerStartDate: Date = Date()

// In .onAppear or init:
// timerStartDate is set once and never changes

ProgressView(timerInterval: timerStartDate...endDate, countsDown: true) { ... }
```

---

## Info

### IN-01: Magic Color Value in HoneAvatarView Gradient

**File:** `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift:8`
**Issue:** The gradient endpoint uses a hardcoded RGB value `Color(red: 0.976, green: 0.451, blue: 0.086)` rather than a named asset catalog color or Theme token. This orange value is not defined anywhere in `Theme.swift`, making it impossible to update consistently if the brand color changes.

**Fix:** Add a named color token to `Theme.swift` and the asset catalog:
```swift
// In Theme.swift:
static let accentGradientEnd = Color("AccentGradientEnd")  // warm orange

// In HoneAvatarView:
LinearGradient(
    colors: [Theme.accent, Theme.accentGradientEnd],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### IN-02: Unused @State Variable in VideoOverlayView

**File:** `WorkoutApp/Features/Train/VideoOverlayView.swift:7`
**Issue:** `@Environment(\.dismiss) private var dismiss` is declared but never called anywhere in the view body. The overlay has no dismiss button and cannot be closed by the user from within the view itself (it relies entirely on the `fullScreenCover` being dismissed from the presenter). This is both dead code and a UX issue (see WR-03).

**Fix:** Either use `dismiss` to add a close button (recommended — see WR-03 fix), or remove the declaration until it is needed.

### IN-03: OnboardingView xmark Button Labelled "Sign Out" — Misleading Accessibility Label

**File:** `WorkoutApp/Features/Onboarding/OnboardingView.swift:46`
**Issue:** The close/quit button on the onboarding screen has `.accessibilityLabel("Sign out")`. The button actually opens a confirmation dialog asking to "Quit setup?" with options "Sign Out" and "Continue Setup." The accessibility label should describe the button's immediate action (opening a dialog to quit setup), not the destructive sub-action inside the dialog.

**Fix:**
```swift
.accessibilityLabel("Quit setup")
// Or more precisely:
.accessibilityLabel("Exit onboarding")
```

### IN-04: PlanModificationCard Uses Color.systemBackground Instead of Theme Token

**File:** `WorkoutApp/Features/Coach/Components/PlanModificationCard.swift:58`
**Issue:** The card background uses `Color(.systemBackground)` instead of `Theme.surface` or `Theme.background`. The rest of the codebase consistently uses `Theme.surface` for card backgrounds. Using `systemBackground` here means this card will not adapt to any future theming changes made to the asset catalog, and will appear visually distinct from other cards.

**Fix:**
```swift
.background(Color(.systemBackground))
// Change to:
.background(Theme.surface)
```

### IN-05: ChartSectionView "Last 8 weeks" Label Is Hardcoded

**File:** `WorkoutApp/Features/Progress/Components/ChartSectionView.swift:21`
**Issue:** The trailing label "Last 8 weeks" is hardcoded in the component rather than derived from the actual data window. If `ProgressViewModel` changes the bucket count (e.g., to 4 or 12 weeks), the label will be stale. This is a minor maintainability issue — there is no user-facing correctness bug yet, but it becomes one if the window changes.

**Fix:** Pass the time window as a parameter:
```swift
struct ChartSectionView<Content: View>: View {
    let title: String
    let timeWindowLabel: String  // e.g., "Last 8 weeks"
    @ViewBuilder let content: () -> Content
    // ...
    Text(timeWindowLabel)
```

### IN-06: Commented-Out `localAssetURL` Logic Pattern in ExerciseDetailView

**File:** `WorkoutApp/Features/Train/ExerciseDetailView.swift:42-48`
**Issue:** The second `else if` branch (lines 42–47) handles the case where `exercise.muxPlaybackId` is nil but `exercise.videoUrl` is non-nil, constructing a `VideoPlayerView` with an empty `muxPlaybackId: ""`. This is effectively dead code in production since `muxPlaybackId` being nil but `videoUrl` being non-nil is an unusual state, and passing `""` as a muxPlaybackId will result in an invalid HLS URL construction inside `VideoPlayerView`. The logic appears to be a transitional pattern left from before Mux integration was complete.

**Fix:** Consolidate the two video branches or add a guard:
```swift
if let playbackId = exercise.muxPlaybackId, !playbackId.isEmpty {
    VideoPlayerView(muxPlaybackId: playbackId, localAssetURL: exercise.localAssetURL.flatMap { URL(string: $0) })
        .aspectRatio(16 / 9, contentMode: .fit)
        // ...
} else {
    ExercisePlaceholderView(exerciseName: exercise.name)
}
```

### IN-07: PasswordResetView Has No Navigation Title

**File:** `WorkoutApp/Features/Auth/PasswordResetView.swift:1-91`
**Issue:** `PasswordResetView` is presented via `NavigationLink` from inside `AuthView`'s `ScrollView`, which is itself inside a `NavigationStack` (or should be, but `AuthView` has no `NavigationStack` of its own). The view sets no `.navigationTitle`, so the back button area will be bare and VoiceOver users will have no context about which screen they are on.

**Fix:**
```swift
// Add at the top level of the view:
.navigationTitle("Reset Password")
.navigationBarTitleDisplayMode(.inline)
```

### IN-08: PRBadgeView Uses `.accessibilityElement(children: .combine)` on a ForEach Container

**File:** `WorkoutApp/Features/Progress/Components/PRBadgeView.swift:41`
**Issue:** `.accessibilityElement(children: .combine)` is applied to the outer `VStack` wrapping a `ForEach`. When multiple PRs are present, VoiceOver will read all of them as a single combined element — one very long announcement with no way to navigate between individual records. Each PR badge should be individually focusable.

**Fix:**
```swift
// Remove .accessibilityElement(children: .combine) from the VStack
// Add it per-badge row instead, so each PR is a discrete VoiceOver stop:
HStack(spacing: 8) { ... }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(pr.exerciseName), new record: \(pr.newRecord) reps\(pr.previousBest > 0 ? ", previous best: \(pr.previousBest) reps" : "")")
```

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
