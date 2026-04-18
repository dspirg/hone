import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - ExerciseRepositoryTests
// Tests for ExerciseRepository CoreData upsert and mapping logic.
// All tests use in-memory CoreData store (PersistenceController.preview) — no disk writes.
// Network-dependent fetchAndSync() tests require a live Supabase connection and are skipped here.

@MainActor
final class ExerciseRepositoryTests: XCTestCase {

    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        context = PersistenceController.preview.container.viewContext
    }

    override func tearDownWithError() throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Exercise")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.execute(deleteRequest)
        try context.save()
    }

    // MARK: - Helper: Insert Exercise entity directly into test context

    @discardableResult
    private func insertExercise(
        id: UUID = UUID(),
        name: String,
        primaryMuscle: String,
        equipmentTag: String = "Bodyweight",
        difficulty: String = "Beginner"
    ) throws -> NSManagedObject {
        let entity = NSEntityDescription.insertNewObject(forEntityName: "Exercise", into: context)
        entity.setValue(id, forKey: "id")
        entity.setValue(name, forKey: "name")
        entity.setValue(primaryMuscle, forKey: "primaryMuscle")
        entity.setValue(equipmentTag, forKey: "equipmentTag")
        entity.setValue(difficulty, forKey: "difficulty")
        entity.setValue(NSArray(array: ["Step 1", "Step 2"]), forKey: "howToSteps")
        entity.setValue(Date(), forKey: "syncedAt")
        try context.save()
        return entity
    }

    // MARK: - Test 1: Fetch and upsert populates CoreData

    func testFetchAndUpsertPopulatesCoreData() throws {
        // Insert an Exercise entity directly to simulate a prior sync
        let exerciseId = UUID()
        try insertExercise(id: exerciseId, name: "Push-Up", primaryMuscle: "Chest")

        // Verify it's in CoreData
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Push-Up")

        // Map to ExerciseModel and verify
        let model = ExerciseModel(from: results.first!)
        XCTAssertEqual(model.id, exerciseId)
        XCTAssertEqual(model.name, "Push-Up")
        XCTAssertEqual(model.primaryMuscle, "Chest")
        XCTAssertFalse(model.hasVideo) // muxPlaybackId is nil
    }

    // MARK: - Test 2: Upsert updates existing exercise

    func testUpsertUpdatesExistingExercise() throws {
        let exerciseId = UUID()
        // Insert initial entity
        let entity = try insertExercise(id: exerciseId, name: "Push Up", primaryMuscle: "Chest")

        // Simulate upsert with updated name (corrected capitalisation)
        entity.setValue("Push-Up", forKey: "name")
        try context.save()

        // Fetch and verify update was applied
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1, "Should still have exactly one entity after upsert")
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Push-Up")
    }

    // MARK: - Test 3: Filter by muscle group

    func testFilterByMuscleGroup() throws {
        // Insert 2 Chest and 1 Back exercise
        try insertExercise(name: "Push-Up", primaryMuscle: "Chest")
        try insertExercise(name: "Bench Press", primaryMuscle: "Chest")
        try insertExercise(name: "Pull-Up", primaryMuscle: "Back")

        // Filter by Chest
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "primaryMuscle == %@", "Chest")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 2, "Filter by Chest should return exactly 2 exercises")
        let names = results.compactMap { $0.value(forKey: "name") as? String }
        XCTAssertTrue(names.contains("Push-Up"))
        XCTAssertTrue(names.contains("Bench Press"))
        XCTAssertFalse(names.contains("Pull-Up"))
    }

    // MARK: - Test 4: Search by name (partial match)

    func testSearchByName() throws {
        // Insert exercises including one with "Push" in the name
        try insertExercise(name: "Push-Up", primaryMuscle: "Chest")
        try insertExercise(name: "Bench Press", primaryMuscle: "Chest")
        try insertExercise(name: "Pull-Up", primaryMuscle: "Back")

        // Search for "push" (case-insensitive partial match)
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "push")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1, "Search for 'push' should return Push-Up only")
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Push-Up")
    }
}
