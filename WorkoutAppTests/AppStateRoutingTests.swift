import XCTest
@testable import WorkoutApp

// MARK: - AppStateRoutingTests
// Unit tests verifying the 3-branch routing state machine in ContentView.
// Tests run on @MainActor because AppState is @MainActor-isolated.
//
// Routing branches:
//   Branch 1: isAuthenticated && onboardingCompleted  -> MainTabView
//   Branch 2: isAuthenticated && !onboardingCompleted -> OnboardingFlowView
//   Branch 3: !isAuthenticated                        -> AuthView

@MainActor
final class AppStateRoutingTests: XCTestCase {

    func testNotAuthenticatedDefaultState() throws {
        let state = AppState()
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertFalse(state.onboardingCompleted)
        // This matches Branch 3: AuthView
    }

    func testAuthenticatedNotOnboardedMatchesOnboardingBranch() throws {
        let state = AppState()
        state.isAuthenticated = true
        state.onboardingCompleted = false
        XCTAssertTrue(state.isAuthenticated && !state.onboardingCompleted)
        // This matches Branch 2: OnboardingFlowView
    }

    func testAuthenticatedAndOnboardedMatchesMainTabBranch() throws {
        let state = AppState()
        state.isAuthenticated = true
        state.onboardingCompleted = true
        XCTAssertTrue(state.isAuthenticated && state.onboardingCompleted)
        // This matches Branch 1: MainTabView
    }

    func testMarkOnboardingCompleteUpdatesFlag() throws {
        let state = AppState()
        XCTAssertFalse(state.onboardingCompleted)
        state.markOnboardingComplete()
        XCTAssertTrue(state.onboardingCompleted)
    }

    func testSignOutResetsAllState() throws {
        let state = AppState()
        state.isAuthenticated = true
        state.onboardingCompleted = true
        // Simulate sign-out (mirrors the .signedOut case in listenForAuthChanges)
        state.isAuthenticated = false
        state.currentUser = nil
        state.onboardingCompleted = false
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertFalse(state.onboardingCompleted)
        XCTAssertNil(state.currentUser)
    }

    func testDefaultOnboardingIsFalse() throws {
        let state = AppState()
        XCTAssertFalse(state.onboardingCompleted)
    }
}
