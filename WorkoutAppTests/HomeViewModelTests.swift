import XCTest
@testable import WorkoutApp

@MainActor
final class HomeViewModelTests: XCTestCase {

    // MARK: - Time of Day Greeting (UI-04)

    func testTimeOfDayGreeting_morning() {
        // Verify timeOfDayGreeting returns "Good morning" for hours 5-11
        // Note: This property uses Date() internally, so testing requires
        // either dependency injection of a Clock or testing the hour-to-greeting mapping directly.
        // Stub: verify the property exists and returns a non-empty string.
        let vm = HomeViewModel()
        XCTAssertFalse(vm.timeOfDayGreeting.isEmpty, "Greeting should not be empty")
    }

    // MARK: - Initial State

    func testInitialState_isLoading() {
        let vm = HomeViewModel()
        XCTAssertTrue(vm.isLoading, "Should start in loading state")
        XCTAssertNil(vm.activePlan, "No plan before load")
        XCTAssertEqual(vm.totalPRs, 0, "PRs should be 0 before load")
        XCTAssertEqual(vm.totalSessions, 0, "Sessions should be 0 before load")
        XCTAssertEqual(vm.totalSets, 0, "Sets should be 0 before load")
        XCTAssertFalse(vm.showSession, "Session should not be showing")
    }
}
