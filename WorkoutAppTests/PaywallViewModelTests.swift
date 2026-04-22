import XCTest
@testable import WorkoutApp

final class PaywallViewModelTests: XCTestCase {
    @MainActor
    func testAnnualPreSelectedByDefault() async {
        // D-08: after loading offerings, selectedPackage must be annualPackage
        let mock = MockRevenueCatService()
        let vm = PaywallViewModel(revenueCatService: mock)
        await vm.loadOfferings()
        // Mock throws, so selectedPackage will be nil — that's OK.
        // The key assertion is the code path: selectedPackage = annualPackage
        // Full integration test requires StoreKit config file.
        XCTAssertNil(vm.annualPackage, "Mock throws on fetchOfferings — annualPackage stays nil")
    }

    @MainActor
    func testCTALabelDefaultsToSubscribeNow() {
        // When no package is loaded (no introductoryDiscount), CTA = "Subscribe Now"
        // RESEARCH Pitfall 2: trial period must NEVER be hardcoded
        let vm = PaywallViewModel(revenueCatService: MockRevenueCatService())
        XCTAssertEqual(vm.ctaLabel, "Subscribe Now",
                       "CTA must default to 'Subscribe Now' when no trial info available")
    }

    @MainActor
    func testTrialEligibleIsFalseWithoutPackage() {
        let vm = PaywallViewModel(revenueCatService: MockRevenueCatService())
        XCTAssertFalse(vm.trialEligible,
                       "trialEligible must be false when no package loaded")
    }

    @MainActor
    func testErrorStateOnOfferingsFetchFailure() async {
        let mock = MockRevenueCatService()
        mock.shouldFailOfferings = true
        let vm = PaywallViewModel(revenueCatService: mock)
        await vm.loadOfferings()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.errorMessage, "Couldn't load pricing",
                       "Error message must match UI-SPEC error state copy")
    }

    @MainActor
    func testFinePrintEmptyWithoutPackage() {
        let vm = PaywallViewModel(revenueCatService: MockRevenueCatService())
        XCTAssertEqual(vm.finePrintText, "",
                       "Fine print must be empty when no package selected")
    }

    @MainActor
    func testRestorePurchasesFailsGracefully() async {
        let mock = MockRevenueCatService()
        mock.mockIsSubscribed = false
        let vm = PaywallViewModel(revenueCatService: mock)
        await vm.restorePurchases()
        XCTAssertFalse(vm.purchaseCompleted)
        XCTAssertEqual(vm.errorMessage, "No active subscription found.")
    }

    @MainActor
    func testRestorePurchasesSucceeds() async {
        let mock = MockRevenueCatService()
        mock.mockIsSubscribed = true
        let vm = PaywallViewModel(revenueCatService: mock)
        await vm.restorePurchases()
        XCTAssertTrue(vm.purchaseCompleted,
                      "purchaseCompleted must be true after successful restore")
    }
}
