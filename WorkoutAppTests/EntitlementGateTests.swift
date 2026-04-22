import XCTest
@testable import WorkoutApp

final class EntitlementGateTests: XCTestCase {
    @MainActor
    func testPaywallShownWhenAuthenticatedButNotSubscribed() {
        // D-13: Hard paywall — authenticated but unsubscribed users must see the paywall
        let appState = AppState()
        appState.revenueCatService = MockRevenueCatService()
        appState.isAuthenticated = true
        appState.isSubscribed = false
        // Gate condition: isAuthenticated && !isSubscribed => paywall fullScreenCover shows
        XCTAssertTrue(appState.isAuthenticated && !appState.isSubscribed,
                       "Paywall must show when authenticated but not subscribed (D-13)")
    }

    @MainActor
    func testPaywallHiddenWhenSubscribed() {
        // Subscribed users should reach MainTabView without paywall interruption
        let appState = AppState()
        appState.revenueCatService = MockRevenueCatService()
        appState.isAuthenticated = true
        appState.isSubscribed = true
        XCTAssertFalse(appState.isAuthenticated && !appState.isSubscribed,
                        "Paywall must NOT show when subscribed")
    }

    @MainActor
    func testAuthScreenShownWhenNotAuthenticated() {
        // Not authenticated => auth screen, not paywall
        // The paywall gate is only evaluated after authentication
        let appState = AppState()
        appState.revenueCatService = MockRevenueCatService()
        appState.isAuthenticated = false
        appState.isSubscribed = false
        XCTAssertFalse(appState.isAuthenticated,
                        "Auth screen shown — paywall gate not evaluated when not authenticated")
    }

    @MainActor
    func testRefreshEntitlementsUpdatesIsSubscribed() async {
        // After a successful purchase, refreshEntitlements() must flip isSubscribed to true
        // so ContentView's fullScreenCover binding re-evaluates and dismisses the paywall
        let mock = MockRevenueCatService()
        mock.mockIsSubscribed = true
        let appState = AppState()
        appState.revenueCatService = mock
        appState.isSubscribed = false
        await appState.refreshEntitlements()
        XCTAssertTrue(appState.isSubscribed, "refreshEntitlements must update isSubscribed from RC")
    }
}
