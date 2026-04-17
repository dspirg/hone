import XCTest
@testable import WorkoutApp

// MARK: - WorkoutPlanServiceTests
// Unit tests for PlanGenerationService state machine and regeneration counter logic.
//
// These tests verify the service's state machine and counter management WITHOUT
// making network calls. Full integration tests (actual SSE streaming) require a
// running Supabase Edge Function and valid OpenAI key.
//
// The regeneration counter uses @AppStorage("regenCountUsed") which reads from
// UserDefaults.standard. Tests reset this key before each test for isolation.

@MainActor
final class WorkoutPlanServiceTests: XCTestCase {

    // Shared test profile used across tests
    static let testProfile = UserProfile(
        goal: "Build Muscle",
        fitnessLevel: "Intermediate",
        daysPerWeek: 4,
        equipment: ["Dumbbells", "Barbell"],
        injuries: ""
    )

    override func setUp() {
        super.setUp()
        // Reset the @AppStorage key before each test to ensure isolation.
        // @AppStorage("regenCountUsed") reads from UserDefaults.standard.
        UserDefaults.standard.removeObject(forKey: "regenCountUsed")
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "regenCountUsed")
    }

    // MARK: - Test 1: Initial state is idle

    func testInitialStateIsIdle() {
        let service = PlanGenerationService()
        XCTAssertEqual(service.state, .idle, "Service must start in .idle state")
    }

    // MARK: - Test 2: Initial regeneration count is 3

    func testInitialRegenerationCountIsThree() {
        // UserDefaults key is cleared in setUp()
        let service = PlanGenerationService()
        XCTAssertEqual(service.regenerationsRemaining, 3,
            "Fresh service must show 3 regenerations remaining")
    }

    // MARK: - Test 3: canRegenerate is true initially

    func testCanRegenerateInitially() {
        let service = PlanGenerationService()
        XCTAssertTrue(service.canRegenerate,
            "canRegenerate must be true when counter is fresh (0 used of 3)")
    }

    // MARK: - Test 4: regeneratePlan decrements counter

    func testRegenerateDecrementsCounter() {
        // Start with 0 used (fresh counter)
        UserDefaults.standard.set(0, forKey: "regenCountUsed")
        let service = PlanGenerationService()

        // Verify starting state
        XCTAssertEqual(service.regenerationsRemaining, 3)

        // Call regeneratePlan — counter decrements immediately before async work begins.
        // The actual network call will fail (no real Edge Function in tests), but the
        // counter decrement is synchronous.
        service.regeneratePlan(profile: Self.testProfile)

        XCTAssertEqual(service.regenerationsRemaining, 2,
            "regenerationsRemaining must decrement from 3 to 2 after one regeneration")
    }

    // MARK: - Test 5: Cannot regenerate at zero — regeneration is blocked

    func testCannotRegenerateAtZero() {
        // Set counter to max used (3 of 3 used)
        UserDefaults.standard.set(3, forKey: "regenCountUsed")
        let service = PlanGenerationService()

        XCTAssertFalse(service.canRegenerate,
            "canRegenerate must be false when all 3 regenerations are used")
        XCTAssertEqual(service.regenerationsRemaining, 0)

        // Attempt regeneration — should be rejected (guard canRegenerate else return)
        service.regeneratePlan(profile: Self.testProfile)

        // State must remain .idle — regeneration was rejected before generatePlan was called
        XCTAssertEqual(service.state, .idle,
            "State must remain .idle when regeneration is blocked at 0 remaining")

        // Counter must not increase beyond 3 (guard prevents call)
        XCTAssertEqual(service.regenerationsRemaining, 0,
            "regenerationsRemaining must remain 0 when canRegenerate is false")
    }

    // MARK: - Test 6: resetRegenerationCounter resets to 3

    func testResetRegenerationCounter() {
        // Set counter to 2 used
        UserDefaults.standard.set(2, forKey: "regenCountUsed")
        let service = PlanGenerationService()

        XCTAssertEqual(service.regenerationsRemaining, 1,
            "Should have 1 remaining with 2 used")

        service.resetRegenerationCounter()

        XCTAssertEqual(service.regenerationsRemaining, 3,
            "resetRegenerationCounter must restore to 3 remaining")
    }
}
