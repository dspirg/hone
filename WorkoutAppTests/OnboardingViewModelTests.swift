import XCTest
@testable import WorkoutApp

// MARK: - OnboardingViewModelTests
// Unit tests covering ONBD-01 and ONBD-02 requirements.
// Tests step navigation, value setting, equipment exclusivity, and profile building.
@MainActor
final class OnboardingViewModelTests: XCTestCase {

    var viewModel: OnboardingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = OnboardingViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStepIsZero() {
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    func testTotalStepsIsFive() {
        // ONBD-02: 5 screens (4 required + 1 optional injuries)
        XCTAssertEqual(viewModel.totalSteps, 5)
    }

    // MARK: - Navigation Guards

    func testStepNeverExceedsFour() {
        // Advance 10 times — guard in advance() must clamp at 4
        for _ in 0..<10 {
            viewModel.advance()
        }
        XCTAssertLessThanOrEqual(viewModel.currentStep, 4)
    }

    func testGoBackDecrementsStep() {
        // Set step to 2 directly for testing, then go back
        viewModel.currentStep = 2
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, 1)
    }

    func testGoBackAtZeroDoesNothing() {
        // At step 0, goBack() guard must prevent decrement
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    // MARK: - Single-Select Value Setting (sync portion; async advance tested separately)

    func testSelectGoalSetsValue() {
        // Test the value-setting portion synchronously (advance() async delay tested independently)
        viewModel.selectedGoal = "Build Muscle"
        XCTAssertEqual(viewModel.selectedGoal, "Build Muscle")
    }

    func testSelectFitnessLevelSetsValue() {
        viewModel.selectedFitnessLevel = "Intermediate"
        XCTAssertEqual(viewModel.selectedFitnessLevel, "Intermediate")
    }

    func testSelectDaysPerWeekSetsValue() {
        viewModel.selectedDaysPerWeek = 4
        XCTAssertEqual(viewModel.selectedDaysPerWeek, 4)
    }

    // MARK: - selectGoal Sets Value (method-level test; advance is async)

    func testSelectGoalMethodSetsSelectedGoal() {
        viewModel.selectGoal("Lose Fat")
        // The selectGoal method sets selectedGoal synchronously before the async advance
        XCTAssertEqual(viewModel.selectedGoal, "Lose Fat")
    }

    // MARK: - Equipment Multi-Select and Mutual Exclusivity

    func testToggleEquipmentNoEquipmentExclusive() {
        // Select Dumbbells first, then No equipment — all others must be cleared
        viewModel.toggleEquipment("Dumbbells")
        viewModel.toggleEquipment("No equipment")
        XCTAssertEqual(viewModel.selectedEquipment, ["No equipment"])
    }

    func testToggleEquipmentDeselectsNoEquipment() {
        // Select No equipment first, then a gear chip — No equipment must be removed
        viewModel.toggleEquipment("No equipment")
        viewModel.toggleEquipment("Barbell")
        XCTAssertFalse(viewModel.selectedEquipment.contains("No equipment"))
        XCTAssertTrue(viewModel.selectedEquipment.contains("Barbell"))
    }

    func testCanAdvanceEquipmentFalseWhenEmpty() {
        XCTAssertFalse(viewModel.canAdvanceEquipment)
    }

    func testCanAdvanceEquipmentTrueWhenSelected() {
        viewModel.toggleEquipment("Dumbbells")
        XCTAssertTrue(viewModel.canAdvanceEquipment)
    }

    // MARK: - Profile Building

    func testCompleteOnboardingBuildsProfile() {
        var capturedProfile: UserProfile?
        viewModel.onComplete = { profile in
            capturedProfile = profile
        }

        viewModel.selectedGoal = "Build Muscle"
        viewModel.selectedFitnessLevel = "Intermediate"
        viewModel.selectedDaysPerWeek = 4
        viewModel.toggleEquipment("Dumbbells")
        viewModel.injuriesText = "lower back"

        viewModel.completeOnboarding()

        XCTAssertTrue(viewModel.isOnboardingComplete)
        XCTAssertNotNil(capturedProfile)
        XCTAssertEqual(capturedProfile?.goal, "Build Muscle")
        XCTAssertEqual(capturedProfile?.equipment, ["Dumbbells"])
        XCTAssertEqual(capturedProfile?.injuries, "lower back")
    }

    // MARK: - Progress Fraction

    func testProgressFraction() {
        // Step 0: 1/5 = 0.2
        viewModel.currentStep = 0
        XCTAssertEqual(viewModel.progressFraction, 0.2, accuracy: 0.001)

        // Step 2: 3/5 = 0.6
        viewModel.currentStep = 2
        XCTAssertEqual(viewModel.progressFraction, 0.6, accuracy: 0.001)
    }
}
