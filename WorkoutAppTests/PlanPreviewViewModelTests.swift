import XCTest
@testable import WorkoutApp

// MARK: - PlanPreviewViewModelTests
// Unit tests for PlanPreviewViewModel computed properties.
// Tests verify that ViewModel correctly bridges PlanGenerationService state to UI-safe properties.
//
// Requirements: ONBD-03, AIPL-02, AIPL-03

@MainActor
final class PlanPreviewViewModelTests: XCTestCase {

    // MARK: - Test Data

    static let testPlan = WorkoutPlan(
        planName: "Test Plan",
        goalSummary: "Test summary",
        weeklyDays: [
            WorkoutDay(
                dayLabel: "Day 1",
                sessionName: "Upper Body",
                exercises: [
                    PlannedExercise(
                        exerciseName: "Bench Press",
                        sets: 4,
                        reps: "8-10",
                        restSeconds: 90,
                        rationale: "Primary chest compound"
                    )
                ]
            )
        ]
    )

    static let testProfile = UserProfile(
        goal: "Build Muscle",
        fitnessLevel: "Intermediate",
        daysPerWeek: 4,
        equipment: ["Barbell", "Dumbbells"],
        injuries: ""
    )

    // Helper: create a fresh service + viewModel pair for each test
    func makeViewModel() -> (PlanGenerationService, PlanPreviewViewModel) {
        let service = PlanGenerationService()
        let vm = PlanPreviewViewModel(service: service, profile: Self.testProfile)
        return (service, vm)
    }

    // MARK: - Tests

    /// Service starts in .idle — ViewModel should report isLoading = true.
    func testInitialStateIsLoading() {
        let (service, vm) = makeViewModel()
        XCTAssertEqual(service.state, .idle)
        XCTAssertTrue(vm.isLoading, "isLoading should be true when service is .idle")
    }

    /// No plan should be available before generation completes.
    func testPlanIsNilBeforeCompletion() {
        let (_, vm) = makeViewModel()
        XCTAssertNil(vm.plan, "plan should be nil when service is .idle")
    }

    /// When service transitions to .completed, ViewModel exposes the plan.
    func testPlanAvailableOnCompletion() {
        let (service, vm) = makeViewModel()
        service.state = .completed(Self.testPlan)
        XCTAssertNotNil(vm.plan, "plan should not be nil when service is .completed")
        XCTAssertEqual(vm.plan?.planName, Self.testPlan.planName)
    }

    /// isStreaming reflects .streaming state correctly.
    func testIsStreamingWhenStreaming() {
        let (service, vm) = makeViewModel()
        service.state = .streaming(partialText: "partial json...")
        XCTAssertTrue(vm.isStreaming, "isStreaming should be true when service is .streaming")
    }

    /// errorMessage is populated from .error state.
    func testErrorMessageOnError() {
        let (service, vm) = makeViewModel()
        service.state = .error("Something went wrong")
        XCTAssertEqual(vm.errorMessage, "Something went wrong")
    }

    /// canStartTraining is true only when a completed plan exists and not streaming.
    func testCanStartTrainingOnlyWhenCompleted() {
        let (service, vm) = makeViewModel()

        // idle → not ready
        service.state = .idle
        XCTAssertFalse(vm.canStartTraining, "canStartTraining should be false when idle")

        // completed → ready
        service.state = .completed(Self.testPlan)
        XCTAssertTrue(vm.canStartTraining, "canStartTraining should be true when completed")

        // streaming → not ready (even if previous plan shown)
        service.state = .streaming(partialText: "...")
        XCTAssertFalse(vm.canStartTraining, "canStartTraining should be false when streaming")
    }

    /// regenerationsRemaining delegates to service.regenerationsRemaining.
    /// With regenCountUsed at 0, remaining should equal max (3).
    func testRegenerationsRemainingDelegates() {
        // Clear the UserDefaults key to simulate fresh user
        UserDefaults.standard.removeObject(forKey: "regenCountUsed")

        let (_, vm) = makeViewModel()
        XCTAssertEqual(vm.regenerationsRemaining, 3,
            "New user should have 3 regenerations remaining")
    }

    /// canRegenerate returns false during streaming even when counter > 0 (T-03-13 mitigation).
    func testCanRegenerateFalseDuringStreaming() {
        // Ensure counter > 0
        UserDefaults.standard.removeObject(forKey: "regenCountUsed")

        let (service, vm) = makeViewModel()
        service.state = .streaming(partialText: "...")

        // Service itself says canRegenerate=true (counter > 0)
        XCTAssertTrue(service.canRegenerate, "Service canRegenerate should be true (counter > 0)")

        // ViewModel applies additional streaming guard
        XCTAssertFalse(vm.canRegenerate,
            "ViewModel canRegenerate should be false during streaming (prevents spam)")
    }
}
