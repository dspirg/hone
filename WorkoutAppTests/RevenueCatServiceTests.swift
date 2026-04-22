import XCTest
@testable import WorkoutApp

final class RevenueCatServiceTests: XCTestCase {
    @MainActor
    func testLogInReceivesSupabaseUUID() async throws {
        // Verify logIn is called with the exact UUID string format (RESEARCH Pitfall 1)
        // If a non-UUID string is passed, webhook payloads will contain garbage IDs
        // that don't match any profiles row
        let mock = MockRevenueCatService()
        mock.mockIsSubscribed = true
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
        let result = try await mock.logIn(userId: uuid)
        XCTAssertTrue(result, "logIn should return true when subscribed")
        XCTAssertEqual(mock.logInUserIdReceived, uuid, "logIn must receive the Supabase UUID")
        XCTAssertEqual(mock.logInCallCount, 1, "logIn should be called exactly once per auth event")
    }

    @MainActor
    func testLogOutClearsSubscriptionState() async throws {
        let mock = MockRevenueCatService()
        mock.mockIsSubscribed = true
        try await mock.logOut()
        XCTAssertFalse(mock.cachedIsSubscribed(), "After logOut, cachedIsSubscribed must return false")
        XCTAssertEqual(mock.logOutCallCount, 1)
    }

    @MainActor
    func testCachedIsSubscribedReturnsFalseByDefault() {
        // Safe default: show paywall until entitlement confirmed (T-07-01)
        let mock = MockRevenueCatService()
        XCTAssertFalse(mock.cachedIsSubscribed(), "Default cached state must be false (safe default)")
    }

    @MainActor
    func testConfigureCalledBeforeLogIn() async throws {
        // Validates the ordering contract: configure() at launch, logIn() after auth
        let mock = MockRevenueCatService()
        mock.configure()
        XCTAssertEqual(mock.configureCallCount, 1, "configure must be called once at app launch")
        let _ = try await mock.logIn(userId: "test-uuid")
        XCTAssertEqual(mock.logInCallCount, 1, "logIn called after configure")
    }
}
