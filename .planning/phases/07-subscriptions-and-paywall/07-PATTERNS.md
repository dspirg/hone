# Phase 7: Subscriptions and Paywall — Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 14 (all existing — Phase 7 is fully implemented)
**Analogs found:** 14 / 14 (all files read from codebase directly; no pattern inference required)

> **Note:** All Phase 7 source files are already implemented in the codebase. This document
> captures the verified patterns for reference by future phases (08+) and for the deferred
> 07-04 App Store Connect verification work. The "analog" for every Phase 7 file IS that file
> itself — patterns are extracted directly from the implemented code.

---

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `WorkoutApp/Core/RevenueCatService.swift` | service | request-response | self (implemented) | exact |
| `WorkoutApp/Core/AppState.swift` | store | event-driven | self (implemented) | exact |
| `WorkoutApp/WorkoutApp.swift` (+ ContentView) | config / route | event-driven | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/PaywallViewModel.swift` | store (ViewModel) | request-response | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/PaywallView.swift` | component | request-response | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` | component | request-response | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Components/ValuePropListView.swift` | component | — | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift` | component | event-driven | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift` | component | request-response | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Retention/PauseOptionsView.swift` | component | CRUD | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift` | store (ViewModel) | CRUD | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Retention/DiscountOfferView.swift` | component | request-response | self (implemented) | exact |
| `WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift` | store (ViewModel) | request-response | self (implemented) | exact |
| `supabase/functions/revenuecat-webhook/index.ts` | service (Edge Function) | event-driven | self (implemented) | exact |
| `supabase/migrations/20260416000001_add_subscription_pause.sql` | migration | — | self (implemented) | exact |
| `WorkoutAppTests/RevenueCatServiceTests.swift` | test | — | self (implemented) | exact |
| `WorkoutAppTests/EntitlementGateTests.swift` | test | — | self (implemented) | exact |
| `WorkoutAppTests/PaywallViewModelTests.swift` | test | — | self (implemented) | exact |
| `WorkoutAppTests/RetentionFlowTests.swift` | test | — | self (implemented) | exact |

---

## Pattern Assignments

### `WorkoutApp/Core/RevenueCatService.swift` (service, request-response)

**Role:** Protocol + live implementation + mock for all RevenueCat SDK calls.

**Protocol pattern** (lines 7–17):
```swift
protocol RevenueCatServiceProtocol: Sendable {
    func configure()
    func logIn(userId: String) async throws -> Bool
    func logOut() async throws
    func refreshEntitlements() async -> Bool
    func fetchOfferings() async throws -> Offerings
    func purchase(package: Package) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool)
    func purchaseWithPromo(package: Package, promoOfferID: String) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool)
    func getPromotionalOffer(offerID: String, product: StoreProduct) async throws -> PromotionalOffer
    func cachedIsSubscribed() -> Bool
}
```

**SDK configure pattern — no appUserID at launch** (lines 32–34):
```swift
func configure() {
    Purchases.configure(withAPIKey: Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as! String)
}
```

**logIn pattern — UUID immediately after auth resolves** (lines 40–43):
```swift
func logIn(userId: String) async throws -> Bool {
    let (customerInfo, _) = try await Purchases.shared.logIn(userId)
    return customerInfo.entitlements["pro"]?.isActive == true
}
```

**Promotional offer purchase pattern** (lines 71–81):
```swift
func purchaseWithPromo(package: Package, promoOfferID: String) async throws -> ... {
    guard let discount = package.storeProduct.discounts.first(where: { $0.offerIdentifier == promoOfferID }) else {
        throw NSError(domain: "RevenueCatService", code: 404, ...)
    }
    let promoOffer = try await Purchases.shared.promotionalOffer(forProductDiscount: discount, product: package.storeProduct)
    return try await Purchases.shared.purchase(package: package, promotionalOffer: promoOffer)
}
```

**cachedIsSubscribed pattern — synchronous on-disk cache** (lines 100–102):
```swift
func cachedIsSubscribed() -> Bool {
    Purchases.shared.cachedCustomerInfo?.entitlements["pro"]?.isActive == true
}
```

**Mock pattern — @MainActor, call tracking** (lines 108–163):
```swift
@MainActor
final class MockRevenueCatService: @preconcurrency RevenueCatServiceProtocol {
    var mockIsSubscribed = false
    var shouldFailOfferings = false
    var logInCallCount = 0
    var logInUserIdReceived: String? = nil
    // ... protocol stubs that throw NSError for SDK types that can't be mocked
}
```

---

### `WorkoutApp/Core/AppState.swift` (store, event-driven)

**Role:** Observable root state. Auth routing + subscription state + RC service injection.

**Declaration pattern** (lines 8–10):
```swift
@Observable
@MainActor
final class AppState {
```

**Subscription state with DEBUG bypass** (lines 27–31):
```swift
#if DEBUG
var isSubscribed: Bool = true  // Bypass paywall in debug builds for testing
#else
var isSubscribed: Bool = false
#endif
```

**Dependency injection slot** (line 38):
```swift
var revenueCatService: RevenueCatServiceProtocol = RevenueCatService()
```

**logIn-after-auth pattern** (lines 57–65):
```swift
if let userId = session?.user.id.uuidString {
    #if DEBUG
    _ = try? await revenueCatService.logIn(userId: userId)
    self.isSubscribed = true
    #else
    let subscribed = (try? await revenueCatService.logIn(userId: userId)) ?? false
    self.isSubscribed = subscribed
    #endif
}
```

**Entitlement refresh method** (lines 123–126):
```swift
func refreshEntitlements() async {
    let subscribed = await revenueCatService.refreshEntitlements()
    self.isSubscribed = subscribed
}
```

---

### `WorkoutApp/WorkoutApp.swift` + `ContentView` (config, event-driven)

**Role:** App entry point — SDK init, cache read, auth listener. ContentView — paywall gate routing.

**Launch init sequence** (lines 40–47):
```swift
// 1. Configure SDK (no appUserID)
appState.revenueCatService.configure()
// 2. Synchronous cache read — prevents paywall flash (Pitfall 6)
#if DEBUG
appState.isSubscribed = true
#else
appState.isSubscribed = appState.revenueCatService.cachedIsSubscribed()
#endif
// 3. Auth listener (async — logIn called inside after session resolves)
await appState.listenForAuthChanges()
```

**Hard paywall fullScreenCover gate** (lines 79–87 in ContentView):
```swift
MainTabView()
    .fullScreenCover(isPresented: Binding(
        get: { appState.isAuthenticated && !appState.isSubscribed },
        set: { _ in } // no-op: only dismissed by isSubscribed becoming true
    )) {
        PaywallView()
    }
```

**Key constraint:** `.interactiveDismissDisabled(true)` is set inside `PaywallView` itself (line 99 of PaywallView.swift), not on the cover caller.

---

### `WorkoutApp/Features/Paywall/PaywallViewModel.swift` (ViewModel, request-response)

**Role:** Offerings fetch, package selection, purchase, restore, dynamic copy derivation.

**Observable ViewModel declaration** (lines 5–7):
```swift
@Observable
@MainActor
final class PaywallViewModel {
```

**Dependency injection via init** (lines 68–72):
```swift
private let revenueCatService: RevenueCatServiceProtocol

init(revenueCatService: RevenueCatServiceProtocol) {
    self.revenueCatService = revenueCatService
}
```

**Trial eligibility — runtime check, never hardcoded** (lines 21–23):
```swift
var trialEligible: Bool {
    selectedPackage?.storeProduct.introductoryDiscount != nil
}
```

**Dynamic CTA label** (lines 38–43):
```swift
var ctaLabel: String {
    if let trialText = trialPeriodText {
        return "Start \(trialText) Free Trial"
    }
    return "Subscribe Now"
}
```

**Annual monthly equivalent — locale-aware formatting** (lines 57–65):
```swift
var annualMonthlyEquivalent: String? {
    guard let annual = annualPackage else { return nil }
    let price = annual.storeProduct.price
    let monthly = price / 12
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = .current
    return formatter.string(from: monthly as NSDecimalNumber)
}
```

**loadOfferings with defer + annual pre-selection** (lines 75–87):
```swift
func loadOfferings() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
        let offerings = try await revenueCatService.fetchOfferings()
        annualPackage = offerings.current?.annual
        monthlyPackage = offerings.current?.monthly
        selectedPackage = annualPackage  // D-08: annual pre-selected
    } catch {
        errorMessage = "Couldn't load pricing"
    }
}
```

**Purchase pattern — check userCancelled + entitlement** (lines 95–109):
```swift
func purchase() async {
    guard let package = selectedPackage else { return }
    isPurchasing = true
    errorMessage = nil
    defer { isPurchasing = false }
    do {
        let (_, customerInfo, userCancelled) = try await revenueCatService.purchase(package: package)
        if userCancelled { return }
        if customerInfo.entitlements["pro"]?.isActive == true {
            purchaseCompleted = true
        }
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

---

### `WorkoutApp/Features/Paywall/PaywallView.swift` (component, request-response)

**Role:** Hard paywall UI — feature showcase, dynamic pricing cards, CTA, post-purchase success.

**Environment injection + lazy ViewModel init** (lines 12–16):
```swift
@Environment(AppState.self) var appState
@State private var viewModel = PaywallViewModel(revenueCatService: RevenueCatService())
```

**ViewModel reinit with AppState's service in .task** (lines 94–98):
```swift
.task {
    viewModel = PaywallViewModel(revenueCatService: appState.revenueCatService)
    await viewModel.loadOfferings()
}
```

**Post-purchase entitlement refresh via onChange** (lines 100–104):
```swift
.onChange(of: viewModel.purchaseCompleted) { _, newValue in
    if newValue {
        Task { await appState.refreshEntitlements() }
    }
}
```

**CTA button pattern — disabled state + ProgressView in-flight** (lines 167–196):
```swift
Button {
    Task { await viewModel.purchase() }
} label: {
    if viewModel.isPurchasing {
        ProgressView().progressViewStyle(.circular).tint(.white)
            .frame(maxWidth: .infinity).frame(height: 56)
    } else {
        Text(viewModel.ctaLabel)
            .font(.body).fontWeight(.semibold).foregroundStyle(Color.white)
            .frame(maxWidth: .infinity).frame(height: 56)
    }
}
.background(RoundedRectangle(cornerRadius: 14).fill(
    viewModel.isLoading || viewModel.isPurchasing || viewModel.selectedPackage == nil
    ? Color("AccentColor").opacity(0.5) : Color("AccentColor")
))
.disabled(viewModel.isLoading || viewModel.isPurchasing || viewModel.selectedPackage == nil)
```

**Loading skeleton pattern — redacted RoundedRectangle placeholders** (lines 113–121):
```swift
RoundedRectangle(cornerRadius: 16)
    .fill(Color("CardBackground"))
    .frame(height: 88)
    .redacted(reason: .placeholder)
```

---

### `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` (component, request-response)

**Role:** Single subscription option card with selection state + "Most Popular" badge.

**Dynamic price label — never hardcoded** (lines 26–31):
```swift
private var priceLabel: String {
    if package.packageType == .annual, let monthly = monthlyEquivalent {
        return "\(monthly)/month"
    }
    return "\(package.storeProduct.localizedPriceString)/month"
}
```

**Selected/unselected card styling** (lines 76–87):
```swift
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(isSelected ? Color("AccentColor").opacity(0.10) : Color("CardBackground"))
)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(
            isSelected ? Color("AccentColor") : Color(UIColor.tertiaryLabel),
            lineWidth: isSelected ? 2 : 1
        )
)
```

**"Most Popular" badge — Capsule, AccentColor, topTrailing offset** (lines 89–101):
```swift
Text("Most Popular")
    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.white)
    .padding(.horizontal, 8).frame(height: 24)
    .background(Capsule().fill(Color("AccentColor")))
// Applied via .overlay(alignment: .topTrailing) with .offset(x: 0, y: -12)
```

---

### `WorkoutApp/Features/Paywall/Components/BlurredPlanGateView.swift` (component, event-driven)

**Role:** Generic overlay for expired/lapsed state. Blurs underlying content, shows tap-to-subscribe CTA.

**Generic content wrapper pattern** (lines 8–35):
```swift
struct BlurredPlanGateView<Content: View>: View {
    @Binding var showPaywall: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            content().blur(radius: 8)
            Color.black.opacity(0.40)
            Text("Your plan is waiting")
                .font(.title2).fontWeight(.semibold).foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.6), radius: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { showPaywall = true }
        .accessibilityLabel("Your plan is waiting. Tap to subscribe.")
    }
}
```

---

### `WorkoutApp/Features/Paywall/Retention/CancellationRetentionView.swift` (component, request-response)

**Role:** Eligibility coordinator — checks discount eligibility before routing to PauseOptionsView.

**Eligibility check pattern — non-trial monthly guard** (lines 34–52):
```swift
private func checkDiscountEligibility() async {
    defer { isCheckingEligibility = false }
    do {
        let info = try await Purchases.shared.customerInfo()
        managementURL = info.managementURL
            ?? URL(string: "https://apps.apple.com/account/subscriptions")
        let activeSubscriptions = info.activeSubscriptions
        let hasMonthly = activeSubscriptions.contains { $0.contains("monthly") }
        let entitlement = info.entitlements["pro"]
        let isInTrial = entitlement?.periodType == .trial
        isEligibleForDiscount = hasMonthly && !isInTrial
    } catch {
        isEligibleForDiscount = false
        managementURL = URL(string: "https://apps.apple.com/account/subscriptions")
    }
}
```

---

### `WorkoutApp/Features/Paywall/Retention/PauseOptionsViewModel.swift` (ViewModel, CRUD)

**Role:** Pause duration selection, Supabase profile update, Apple managementURL fetch.

**PauseDuration enum — D-11** (lines 6–28):
```swift
enum PauseDuration: Int, CaseIterable, Identifiable {
    case oneMonth = 1
    case twoMonths = 2
    case threeMonths = 3

    var id: Int { rawValue }
    var label: String { ... }   // "1 month", "2 months", "3 months"
    var ctaLabel: String { ... } // "Pause for 1 month", etc.
}
```

**Supabase pause write — ISO8601 date, service bypasses RLS** (lines 65–72):
```swift
try await supabase
    .from("profiles")
    .update(["subscription_pause_until": pauseUntil.ISO8601Format()])
    .eq("id", value: userId)
    .execute()
```

---

### `WorkoutApp/Features/Paywall/Retention/DiscountOfferViewModel.swift` (ViewModel, request-response)

**Role:** Promotional offer redemption — fetch monthly package, verify promo exists, purchaseWithPromo.

**Promotional offer guard + purchase sequence** (lines 28–56):
```swift
let offerings = try await revenueCatService.fetchOfferings()
guard let monthlyPackage = offerings.current?.monthly else {
    offerUnavailable = true; return
}
let hasPromo = monthlyPackage.storeProduct.discounts.contains {
    $0.offerIdentifier == "monthly_50pct_3months"
}
guard hasPromo else { offerUnavailable = true; return }
let (_, customerInfo, _) = try await revenueCatService.purchaseWithPromo(
    package: monthlyPackage,
    promoOfferID: "monthly_50pct_3months"
)
if customerInfo.entitlements["pro"]?.isActive == true {
    offerAccepted = true
}
```

---

### `supabase/functions/revenuecat-webhook/index.ts` (Edge Function, event-driven)

**Role:** RevenueCat → Supabase subscription status sync. Stateless, idempotent.

**Authorization verification** (lines 43–47):
```typescript
const authHeader = req.headers.get("Authorization")
const secret = Deno.env.get("RC_WEBHOOK_SECRET")
if (!secret || authHeader !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 })
}
```

**Anonymous ID rejection — return 200 to stop RC retries** (lines 65–74):
```typescript
if (!appUserId || appUserId.startsWith("$RCAnonymousID")) {
    console.error(`[revenuecat-webhook] REJECTED: Anonymous ID...`)
    return new Response("Anonymous ID rejected -- logIn() not called", { status: 200 })
}
```

**State-driven idempotent event mapping** (lines 22–95):
```typescript
const ACTIVE_EVENTS = new Set(["INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", ...])
const GRACE_EVENTS = new Set(["BILLING_ISSUE"])
const INACTIVE_EVENTS = new Set(["CANCELLATION", "EXPIRATION", ...])

// Map to fixed status — same event always = same value (idempotent)
if (ACTIVE_EVENTS.has(eventType)) status = "subscribed"
else if (GRACE_EVENTS.has(eventType)) status = "grace_period"
else if (INACTIVE_EVENTS.has(eventType)) status = "free"
```

**Supabase service_role update** (lines 100–117):
```typescript
const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)
const { error } = await supabase
    .from("profiles")
    .update({ subscription_status: status })
    .eq("id", appUserId)
// Return 500 on error → RC retries. Return 200 on success.
```

---

### `supabase/migrations/20260416000001_add_subscription_pause.sql` (migration)

**Role:** Adds `subscription_pause_until TIMESTAMPTZ`, expands `subscription_status` CHECK, adds RLS policy.

**RLS anti-spoofing policy pattern** (lines 33–41):
```sql
CREATE POLICY "Users cannot update subscription_status directly"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (
        subscription_status = (
            SELECT p.subscription_status FROM public.profiles p WHERE p.id = auth.uid()
        )
    );
```

---

## Test Patterns

### `WorkoutAppTests/RevenueCatServiceTests.swift`

**Test declaration pattern** (lines 4–44):
```swift
final class RevenueCatServiceTests: XCTestCase {
    @MainActor
    func testLogInReceivesSupabaseUUID() async throws {
        let mock = MockRevenueCatService()
        mock.mockIsSubscribed = true
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
        let result = try await mock.logIn(userId: uuid)
        XCTAssertTrue(result)
        XCTAssertEqual(mock.logInUserIdReceived, uuid)
    }
}
```

**Pattern:** All async test methods are `@MainActor` + `async throws`. MockRevenueCatService is the injection point for all tests — never instantiate live `RevenueCatService` in tests.

### `WorkoutAppTests/EntitlementGateTests.swift`

**AppState injection pattern for tests** (lines 8–11):
```swift
let appState = AppState()
appState.revenueCatService = MockRevenueCatService()
appState.isAuthenticated = true
appState.isSubscribed = false
```

### `WorkoutAppTests/PaywallViewModelTests.swift`

**ViewModel test init pattern** (lines 8–10):
```swift
let mock = MockRevenueCatService()
let vm = PaywallViewModel(revenueCatService: mock)
await vm.loadOfferings()
```

### `WorkoutAppTests/RetentionFlowTests.swift`

**Enum/pure-logic test pattern** (lines 7–13):
```swift
func testPauseDurationLabelsMatchD11() {
    let durations = PauseDuration.allCases
    XCTAssertEqual(durations.count, 3)
    XCTAssertEqual(durations[0].label, "1 month")
}
```

---

## Shared Patterns

### Observable ViewModel Declaration
**Source:** `WorkoutApp/Features/Paywall/PaywallViewModel.swift` lines 5–7
**Apply to:** All new ViewModel files
```swift
@Observable
@MainActor
final class <Name>ViewModel {
```

### Protocol-Based Dependency Injection for Testability
**Source:** `WorkoutApp/Core/RevenueCatService.swift` lines 7–17
**Apply to:** Any new service that wraps an SDK that cannot be subclassed
Pattern: Define `<Name>Protocol: Sendable`, implement live class, implement `Mock<Name>` with call tracking for tests.

### Error Handling — defer + silent nil-fallback Pattern
**Source:** `WorkoutApp/Features/Paywall/PaywallViewModel.swift` lines 76–87
**Apply to:** All async ViewModel methods that mutate loading/error state
```swift
func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
        // ...
    } catch {
        errorMessage = "Human-readable message"
    }
}
```

### Entitlement Check — `entitlements["pro"]?.isActive`
**Source:** `WorkoutApp/Core/RevenueCatService.swift` line 42
**Apply to:** Every place subscription status is read from RevenueCat
```swift
customerInfo.entitlements["pro"]?.isActive == true
```

### AccentColor + CardBackground Design Tokens
**Source:** `WorkoutApp/Features/Paywall/Components/PricingCardView.swift` lines 76–87
**Apply to:** All new paywall-adjacent UI components
- Selected fill: `Color("AccentColor").opacity(0.10)`
- Unselected fill: `Color("CardBackground")`
- Selected border: `Color("AccentColor")`, lineWidth 2
- Unselected border: `Color(UIColor.tertiaryLabel)`, lineWidth 1
- CTA button corner radius: 14; card corner radius: 16

### fullScreenCover No-op Binding Pattern
**Source:** `WorkoutApp/WorkoutApp.swift` lines 79–87 (ContentView)
**Apply to:** Any hard gate that must only dismiss programmatically
```swift
.fullScreenCover(isPresented: Binding(
    get: { someCondition },
    set: { _ in }  // no-op — only dismissed by condition becoming false
)) {
    SomeView()
}
```

### @Environment(AppState.self) Injection in Views
**Source:** `WorkoutApp/Features/Paywall/PaywallView.swift` line 12
**Apply to:** Every feature view that needs subscription state or RC service
```swift
@Environment(AppState.self) var appState
```

### DEBUG Override for Paywall Bypass
**Source:** `WorkoutApp/Core/AppState.swift` lines 27–31
**Apply to:** Any boolean flag that would block UI during development
```swift
#if DEBUG
var isSubscribed: Bool = true
#else
var isSubscribed: Bool = false
#endif
```

### Supabase Edge Function Authorization Header Check
**Source:** `supabase/functions/revenuecat-webhook/index.ts` lines 43–47
**Apply to:** All new Supabase Edge Functions that receive third-party webhooks
```typescript
const authHeader = req.headers.get("Authorization")
const secret = Deno.env.get("RC_WEBHOOK_SECRET")
if (!secret || authHeader !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 })
}
```

### Supabase service_role Write (RLS-bypass)
**Source:** `supabase/functions/revenuecat-webhook/index.ts` lines 100–103
**Apply to:** Server-side writes that bypass Row Level Security intentionally
```typescript
const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)
```

---

## No Analog Found

None. All Phase 7 files are implemented in the codebase. No file requires pattern inference from RESEARCH.md.

---

## Critical Anti-Patterns to Enforce in Future Extensions

These are violations the existing code was designed to prevent. Any Phase 8+ code touching subscriptions must respect them:

| Anti-Pattern | Correct Pattern | Source |
|---|---|---|
| Hardcoding `"$12.99/month"` or `"14-day"` | Always read `package.storeProduct.localizedPriceString` and `introductoryDiscount` | `PaywallViewModel.swift` lines 21–54 |
| Calling `configure(withAPIKey:, appUserID:)` at launch | Configure without appUserID; call `logIn(userId:)` after auth resolves | `RevenueCatService.swift` lines 32–34; `AppState.swift` lines 57–65 |
| Using `AppState.isSubscribed` as backend gate | Backend reads `profiles.subscription_status`; `isSubscribed` is UX-only | `AppState.swift` comment on line 26; `revenuecat-webhook/index.ts` |
| Toggle logic in webhook (`status = !current`) | State-driven mapping: `INITIAL_PURCHASE` always → `"subscribed"` | `revenuecat-webhook/index.ts` lines 22–95 |
| Showing discount to trial or annual subscribers | Guard with `hasMonthly && !isInTrial` | `CancellationRetentionView.swift` lines 41–47 |
| Claiming "paused" means billing stops | Pause is UX-only; billing continues; mandatory transparency notice required | `PauseOptionsView.swift` line 67; `PauseOptionsViewModel.swift` comment |

---

## Metadata

**Analog search scope:** All Swift source files under `WorkoutApp/`, all TypeScript under `supabase/functions/`, all SQL under `supabase/migrations/`, all test files under `WorkoutAppTests/`
**Files scanned:** 19 source files read directly
**Pattern extraction date:** 2026-04-24
