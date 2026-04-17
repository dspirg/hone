import CoreData

// MARK: - PersistenceController
// Singleton CoreData stack for the WorkoutApp.
// Wraps NSPersistentContainer and provides an in-memory mode for unit tests.
// Uses the "WorkoutApp" model name matching WorkoutApp.xcdatamodeld.
//
// Usage:
//   Production: PersistenceController.shared
//   Tests:      PersistenceController(inMemory: true)
//
// Thread safety: viewContext is main-thread only; background saves use
// container.performBackgroundTask(_:) or a private queue context.

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WorkoutApp")
        if inMemory {
            // Point the store to /dev/null to prevent disk writes in tests
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                // fatalError is appropriate here: if CoreData cannot load, the app
                // cannot function. This surfaces immediately during development.
                fatalError("CoreData load error: \(error)")
            }
        }
        // Merge changes from background contexts into the view context automatically
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
