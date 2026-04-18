import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - CoreDataStackTests
// Verifies the PersistenceController singleton and Exercise entity round-trips.
// All tests use PersistenceController.preview (in-memory store) — no disk writes.

final class CoreDataStackTests: XCTestCase {

    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        // Use in-memory store for isolation — no state bleeds between tests
        context = PersistenceController.preview.container.viewContext
    }

    override func tearDownWithError() throws {
        // Clean up any inserted entities after each test
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Exercise")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.execute(deleteRequest)
        try context.save()
    }

    // MARK: - Test 1: PersistenceController loads without crash

    func testPersistenceControllerLoads() throws {
        // The preview controller initializes in-memory — context must be non-nil and valid
        XCTAssertNotNil(context)
        XCTAssertEqual(context.concurrencyType, .mainQueueConcurrencyType)
    }

    // MARK: - Test 2: Exercise entity insert and fetch

    func testExerciseEntityInsertAndFetch() throws {
        // Insert an Exercise entity
        let entity = NSEntityDescription.insertNewObject(forEntityName: "Exercise", into: context)
        let exerciseId = UUID()
        entity.setValue(exerciseId, forKey: "id")
        entity.setValue("Push-Up", forKey: "name")
        entity.setValue("Chest", forKey: "primaryMuscle")
        entity.setValue("Bodyweight", forKey: "equipmentTag")
        entity.setValue("Beginner", forKey: "difficulty")
        entity.setValue(NSArray(array: ["Get into plank position", "Lower your chest to the floor", "Push back up"]), forKey: "howToSteps")
        entity.setValue(Date(), forKey: "syncedAt")

        try context.save()

        // Fetch by id
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Push-Up")
        XCTAssertEqual(results.first?.value(forKey: "primaryMuscle") as? String, "Chest")
    }

    // MARK: - Test 3: Exercise entity attributes round-trip (especially howToSteps Transformable)

    func testExerciseEntityAttributes() throws {
        let exerciseId = UUID()
        let steps = ["Plant feet shoulder-width apart", "Lower hips until thighs are parallel", "Drive through heels to stand"]
        let syncDate = Date()

        let entity = NSEntityDescription.insertNewObject(forEntityName: "Exercise", into: context)
        entity.setValue(exerciseId, forKey: "id")
        entity.setValue("Squat", forKey: "name")
        entity.setValue("Legs", forKey: "primaryMuscle")
        entity.setValue("Bodyweight", forKey: "equipmentTag")
        entity.setValue("Beginner", forKey: "difficulty")
        entity.setValue(NSArray(array: steps), forKey: "howToSteps")
        entity.setValue("Keep your back straight throughout the movement.", forKey: "formTips")
        entity.setValue(nil, forKey: "muxPlaybackId")        // unlicensed — nil is valid
        entity.setValue(nil, forKey: "thumbnailURL")
        entity.setValue(nil, forKey: "localAssetURL")
        entity.setValue(nil, forKey: "lastViewedAt")
        entity.setValue(syncDate, forKey: "syncedAt")

        try context.save()

        // Fetch and verify all attributes round-trip correctly
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
        let fetched = try context.fetch(request).first

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.value(forKey: "id") as? UUID, exerciseId)
        XCTAssertEqual(fetched?.value(forKey: "name") as? String, "Squat")
        XCTAssertEqual(fetched?.value(forKey: "primaryMuscle") as? String, "Legs")
        XCTAssertEqual(fetched?.value(forKey: "equipmentTag") as? String, "Bodyweight")
        XCTAssertEqual(fetched?.value(forKey: "difficulty") as? String, "Beginner")
        XCTAssertEqual(fetched?.value(forKey: "formTips") as? String, "Keep your back straight throughout the movement.")
        XCTAssertNil(fetched?.value(forKey: "muxPlaybackId"))
        XCTAssertNil(fetched?.value(forKey: "thumbnailURL"))
        XCTAssertNil(fetched?.value(forKey: "localAssetURL"))
        XCTAssertNil(fetched?.value(forKey: "lastViewedAt"))

        // Verify Transformable howToSteps round-trips as [String]
        let fetchedSteps = (fetched?.value(forKey: "howToSteps") as? NSArray)?.compactMap { $0 as? String }
        XCTAssertEqual(fetchedSteps, steps)

        // Verify syncedAt round-trips (within 1 second tolerance for Date precision)
        if let fetchedDate = fetched?.value(forKey: "syncedAt") as? Date {
            XCTAssertEqual(fetchedDate.timeIntervalSinceReferenceDate,
                           syncDate.timeIntervalSinceReferenceDate,
                           accuracy: 1.0)
        } else {
            XCTFail("syncedAt should not be nil")
        }
    }
}
