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

    // MARK: - Preview (In-Memory Store for Tests and Previews)
    // Uses /dev/null to prevent disk writes; safe to use in unit tests and SwiftUI previews
    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WorkoutApp")
        if inMemory {
            // Point the store to /dev/null to prevent disk writes in tests
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        // Enable automatic lightweight migration (safe for new entities)
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
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
