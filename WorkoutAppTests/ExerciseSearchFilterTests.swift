import XCTest
@testable import WorkoutApp

// MARK: - ExerciseSearchFilterTests
// Tests for ExerciseLibraryViewModel filter and search logic (EXRC-02).
// All tests operate purely in-memory — no CoreData or Supabase dependency.
// ViewModel is populated directly via allExercises setter (no async fetch needed).

@MainActor
final class ExerciseSearchFilterTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an ExerciseModel from an ExerciseDTO for test convenience.
    private func makeExercise(
        name: String,
        primaryMuscle: String,
        equipmentTag: String = "Bodyweight",
        difficulty: String = "Beginner"
    ) -> ExerciseModel {
        let dto = ExerciseDTO(
            id: UUID(),
            name: name,
            primaryMuscle: primaryMuscle,
            equipmentTag: equipmentTag,
            difficulty: difficulty,
            howToSteps: ["Step 1"],
            formTips: nil,
            muxPlaybackId: nil,
            thumbnailUrl: nil,
            updatedAt: Date()
        )
        return ExerciseModel(from: dto)
    }

    // Seed ViewModel with a mix of exercises across muscle groups and equipment
    private func makeViewModel() -> ExerciseLibraryViewModel {
        let vm = ExerciseLibraryViewModel()
        vm.allExercises = [
            makeExercise(name: "Push-Up",          primaryMuscle: "Chest",     equipmentTag: "Bodyweight"),
            makeExercise(name: "Bench Press",       primaryMuscle: "Chest",     equipmentTag: "Barbell"),
            makeExercise(name: "Pull-Up",           primaryMuscle: "Back",      equipmentTag: "Bodyweight"),
            makeExercise(name: "Deadlift",          primaryMuscle: "Back",      equipmentTag: "Barbell"),
            makeExercise(name: "Overhead Press",    primaryMuscle: "Shoulders", equipmentTag: "Barbell"),
            makeExercise(name: "Dumbbell Curl",     primaryMuscle: "Arms",      equipmentTag: "Dumbbells"),
            makeExercise(name: "Squat",             primaryMuscle: "Legs",      equipmentTag: "Barbell"),
        ]
        return vm
    }

    // MARK: - Test 1: Muscle group filter reduces sections

    func testMuscleGroupFilterReducesSections() {
        let vm = makeViewModel()
        vm.activeMuscleGroup = "Chest"

        // Only Chest section should appear
        XCTAssertEqual(vm.exerciseSections.count, 1, "Only Chest section expected")
        XCTAssertEqual(vm.exerciseSections.first?.0, "Chest")

        let chestExercises = vm.exerciseSections.first?.1 ?? []
        XCTAssertEqual(chestExercises.count, 2, "Chest has 2 exercises in test data")
        let names = chestExercises.map(\.name)
        XCTAssertTrue(names.contains("Push-Up"))
        XCTAssertTrue(names.contains("Bench Press"))
        XCTAssertFalse(names.contains("Pull-Up"), "Back exercise must not appear in Chest section")
    }

    // MARK: - Test 2: Search returns partial name match

    func testSearchReturnsPartialNameMatch() {
        let vm = makeViewModel()
        vm.searchText = "push"

        let results = vm.filteredExercises
        XCTAssertEqual(results.count, 1, "Search for 'push' should return exactly 1 result")
        XCTAssertEqual(results.first?.name, "Push-Up")
    }

    // MARK: - Test 3: All chip clears filters (setting both to nil)

    func testAllChipClearsFilters() {
        let vm = makeViewModel()
        // Activate both filters
        vm.activeMuscleGroup = "Chest"
        vm.activeEquipment = "Bodyweight"

        // Verify filters are active
        XCTAssertLessThan(vm.filteredExercises.count, vm.allExercises.count, "Filters should reduce results")

        // Clear both filters (simulates tapping "All" chip)
        vm.activeMuscleGroup = nil
        vm.activeEquipment = nil

        // All exercises should be returned
        XCTAssertEqual(vm.filteredExercises.count, vm.allExercises.count, "All chip should return all exercises")
        XCTAssertEqual(vm.exerciseSections.flatMap(\.1).count, vm.allExercises.count)
    }

    // MARK: - Test 4: Equipment filter works

    func testEquipmentFilterWorks() {
        let vm = makeViewModel()
        vm.activeEquipment = "Bodyweight"

        let results = vm.filteredExercises
        XCTAssertEqual(results.count, 2, "Only bodyweight exercises expected (Push-Up, Pull-Up)")
        XCTAssertTrue(results.allSatisfy { $0.equipmentTag == "Bodyweight" })
    }

    // MARK: - Test 5: Combined filter applies AND logic

    func testCombinedFilterANDLogic() {
        let vm = makeViewModel()
        vm.activeMuscleGroup = "Chest"
        vm.activeEquipment = "Bodyweight"

        // Only Push-Up is Chest + Bodyweight (Bench Press is Chest + Barbell)
        let results = vm.filteredExercises
        XCTAssertEqual(results.count, 1, "AND logic: only Chest + Bodyweight exercises expected")
        XCTAssertEqual(results.first?.name, "Push-Up")
        XCTAssertEqual(results.first?.primaryMuscle, "Chest")
        XCTAssertEqual(results.first?.equipmentTag, "Bodyweight")
    }
}
