import RevenueCat

// MARK: - RevenueCatServiceProtocol
// All methods async, protocol is Sendable for Swift 6 concurrency (D-17, D-18)
// Protocol enables dependency injection and mocking for tests (EntitlementGateTests, RevenueCatServiceTests)
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

// MARK: - RevenueCatService (Live Implementation)
// Wraps RevenueCat SDK 5.x calls with async/await (D-17)
// CRITICAL ORDERING:
//   1. configure() at app launch (no appUserID) — intentional: anonymous ID is okay until auth resolves
//   2. logIn(userId:) immediately after Supabase auth resolves — MUST use Supabase UUID (Pitfall 1)
//      Without this, webhook payloads contain $RCAnonymousID instead of UUID, breaking
//      the revenuecat-webhook -> profiles.subscription_status pipeline
//   3. cachedIsSubscribed() synchronously at launch — prevents paywall flash (Pitfall 6)
final class RevenueCatService: RevenueCatServiceProtocol {
    // MARK: configure
    // Called once at app launch. Does NOT pass appUserID — the user identity is set later
    // via logIn() after Supabase auth resolves. This is the correct pattern per RC docs:
    // configure without ID -> then logIn() with Supabase UUID (RESEARCH Pattern 1)
    func configure() {
        Purchases.configure(withAPIKey: Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as! String)
    }

    // MARK: logIn
    // MUST be called with the Supabase user UUID string (e.g., "550e8400-e29b-41d4-a716-446655440000")
    // Calling with any other ID breaks the webhook -> database pipeline (RESEARCH Pitfall 1)
    // Returns true when the "pro" entitlement (D-18) is active
    func logIn(userId: String) async throws -> Bool {
        let (customerInfo, _) = try await Purchases.shared.logIn(userId)
        return customerInfo.entitlements["pro"]?.isActive == true
    }

    // MARK: logOut
    func logOut() async throws {
        try await Purchases.shared.logOut()
    }

    // MARK: refreshEntitlements
    // Async read of entitlement state. Returning false on error is safe — the paywall
    // will show, which is the correct default (T-07-01)
    func refreshEntitlements() async -> Bool {
        let info = try? await Purchases.shared.customerInfo()
        return info?.entitlements["pro"]?.isActive == true
    }

    // MARK: fetchOfferings
    func fetchOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    // MARK: purchase
    func purchase(package: Package) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool) {
        try await Purchases.shared.purchase(package: package)
    }

    // MARK: purchaseWithPromo
    // Requires In-App Purchase Key (.p8) uploaded to RevenueCat dashboard (RESEARCH Pitfall 4)
    // promoOfferID must match an offer created in App Store Connect (e.g., "monthly_50pct_3months")
    func purchaseWithPromo(package: Package, promoOfferID: String) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool) {
        guard let discount = package.storeProduct.discounts.first(where: { $0.offerIdentifier == promoOfferID }) else {
            throw NSError(
                domain: "RevenueCatService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Promotional offer '\(promoOfferID)' not found on product '\(package.storeProduct.productIdentifier)'"]
            )
        }
        let promoOffer = try await Purchases.shared.promotionalOffer(forProductDiscount: discount, product: package.storeProduct)
        return try await Purchases.shared.purchase(package: package, promotionalOffer: promoOffer)
    }

    // MARK: getPromotionalOffer
    // Used by DiscountOfferView to pre-fetch the signed offer token before presenting the CTA
    func getPromotionalOffer(offerID: String, product: StoreProduct) async throws -> PromotionalOffer {
        guard let discount = product.discounts.first(where: { $0.offerIdentifier == offerID }) else {
            throw NSError(
                domain: "RevenueCatService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Promotional offer '\(offerID)' not found on product '\(product.productIdentifier)'"]
            )
        }
        return try await Purchases.shared.promotionalOffer(forProductDiscount: discount, product: product)
    }

    // MARK: cachedIsSubscribed
    // Synchronous read from SDK's on-disk cache. Used at app launch BEFORE the async auth listener
    // starts, to prevent a brief paywall flash for already-subscribed users (RESEARCH Pitfall 6).
    // Returns false if cachedCustomerInfo is nil or SDK not yet initialized — safe default.
    func cachedIsSubscribed() -> Bool {
        Purchases.shared.cachedCustomerInfo?.entitlements["pro"]?.isActive == true
    }
}

// MARK: - MockRevenueCatService
// Test double for unit tests. Tracks call counts and arguments for assertion.
// Uses actor isolation via @MainActor for safe mutation in XCTest async contexts.
@MainActor
final class MockRevenueCatService: RevenueCatServiceProtocol {
    // MARK: Configurable State
    var mockIsSubscribed = false
    var shouldFailOfferings = false
    var shouldFailPurchase = false

    // MARK: Call Tracking (for test assertions)
    var logInCallCount = 0
    var logInUserIdReceived: String? = nil
    var logOutCallCount = 0
    var configureCallCount = 0

    // MARK: Protocol Implementation

    func configure() {
        configureCallCount += 1
    }

    func logIn(userId: String) async throws -> Bool {
        logInUserIdReceived = userId
        logInCallCount += 1
        return mockIsSubscribed
    }

    func logOut() async throws {
        mockIsSubscribed = false
        logOutCallCount += 1
    }

    func refreshEntitlements() async -> Bool {
        mockIsSubscribed
    }

    func fetchOfferings() async throws -> Offerings {
        // Mock cannot create real Offerings objects (SDK type requires internal initializer)
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "MockRevenueCatService cannot produce real Offerings"])
    }

    func purchase(package: Package) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool) {
        // Mock cannot create real StoreTransaction or CustomerInfo (SDK internal types)
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "MockRevenueCatService cannot produce real purchase results"])
    }

    func purchaseWithPromo(package: Package, promoOfferID: String) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool) {
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "MockRevenueCatService cannot produce real purchase results"])
    }

    func getPromotionalOffer(offerID: String, product: StoreProduct) async throws -> PromotionalOffer {
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "MockRevenueCatService cannot produce real PromotionalOffer"])
    }

    func cachedIsSubscribed() -> Bool {
        mockIsSubscribed
    }
}
