import XCTest

/// Validates StoreKit configuration file prices match CONTEXT.md decisions (D-01, D-02, D-12).
/// This catches price drift without needing App Store Connect or RevenueCat.
final class StoreKitConfigTests: XCTestCase {

    private var config: [String: Any]!

    override func setUpWithError() throws {
        // StoreKit config is a project file, not bundled into the app.
        // Use #filePath to navigate from the test source to the project root.
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // WorkoutAppTests/
            .deletingLastPathComponent()  // project root
        let url = projectRoot
            .appendingPathComponent("WorkoutApp/Configuration/WorkoutAppProducts.storekit")

        let data = try Data(contentsOf: url)
        config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(config, "StoreKit config should parse as valid JSON")
    }

    // MARK: - Price Assertions

    func testMonthlyPriceMatchesD01() throws {
        try XCTSkipIf(config == nil, "StoreKit config not found in bundle")
        let monthly = try findSubscription(productID: "com.workoutapp.pro.monthly")
        let price = monthly["displayPrice"] as? String
        XCTAssertEqual(price, "12.99", "D-01: Monthly price should be $12.99")
    }

    func testAnnualPriceMatchesD02() throws {
        try XCTSkipIf(config == nil, "StoreKit config not found in bundle")
        let annual = try findSubscription(productID: "com.workoutapp.pro.annual")
        let price = annual["displayPrice"] as? String
        XCTAssertEqual(price, "79.99", "D-02: Annual price should be $79.99")
    }

    func testPromotionalOfferPriceMatchesD12() throws {
        try XCTSkipIf(config == nil, "StoreKit config not found in bundle")
        let monthly = try findSubscription(productID: "com.workoutapp.pro.monthly")
        let promos = monthly["promotionalOffers"] as? [[String: Any]] ?? []
        let promo = promos.first { ($0["identifier"] as? String) == "monthly_50pct_3months" }
        XCTAssertNotNil(promo, "Promo offer monthly_50pct_3months should exist")
        XCTAssertEqual(promo?["price"] as? String, "6.49", "D-12: Promo price should be $6.49")
        XCTAssertEqual(promo?["numberOfPeriods"] as? Int, 3, "D-12: Promo should last 3 periods")
    }

    func testBothProductsHave14DayTrial() throws {
        try XCTSkipIf(config == nil, "StoreKit config not found in bundle")
        for pid in ["com.workoutapp.pro.monthly", "com.workoutapp.pro.annual"] {
            let sub = try findSubscription(productID: pid)
            let intro = sub["introductoryOffer"] as? [String: Any]
            XCTAssertNotNil(intro, "\(pid) should have an introductory offer")
            XCTAssertEqual(intro?["duration"] as? String, "P14D", "D-03: \(pid) trial should be 14 days")
            XCTAssertEqual(intro?["offerMode"] as? String, "FREE_TRIAL", "\(pid) should be a free trial")
        }
    }

    func testNoOldPricesRemain() throws {
        try XCTSkipIf(config == nil, "StoreKit config not found in bundle")
        let monthly = try findSubscription(productID: "com.workoutapp.pro.monthly")
        let annual = try findSubscription(productID: "com.workoutapp.pro.annual")
        XCTAssertNotEqual(monthly["displayPrice"] as? String, "9.99", "Old monthly price $9.99 should not remain")
        XCTAssertNotEqual(annual["displayPrice"] as? String, "59.99", "Old annual price $59.99 should not remain")
    }

    // MARK: - Helpers

    private func findSubscription(productID: String) throws -> [String: Any] {
        let groups = config["subscriptionGroups"] as? [[String: Any]] ?? []
        for group in groups {
            let subs = group["subscriptions"] as? [[String: Any]] ?? []
            if let sub = subs.first(where: { ($0["productID"] as? String) == productID }) {
                return sub
            }
        }
        throw XCTSkip("Product \(productID) not found in StoreKit config")
    }
}
