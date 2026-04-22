import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - SessionSyncServiceTests
// Unit tests for SessionSyncService — state management and CoreData interaction.
// Actual Supabase upsert calls are NOT tested here (integration tests).
// Tests verify: initial state, isSyncing guard, empty sync path, markSynced clears fetch.
// Covers SESS-03: session tracking works offline; data syncs when internet is restored.

@MainActor
final class SessionSyncServiceTests: XCTestCase {

    var persistenceController: PersistenceController!
    var repository: SessionRepository!

    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        repository = SessionRepository(
            context: persistenceController.container.viewContext,
            container: persistenceController.container
        )
    }

    override func tearDown() async throws {
        repository = nil
        persistenceController = nil
    }

    // MARK: - Test 1: syncBannerVisible starts false

    func testSyncBannerInitiallyFalse() {
        let service = SessionSyncService(repository: repository)
        XCTAssertFalse(service.syncBannerVisible, "syncBannerVisible should be false on init")
    }

    // MARK: - Test 2: isSyncing guard prevents double execution

    func testIsSyncingPreventsDoubleExecution() async {
        let service = SessionSyncService(repository: repository)

        // Manually set isSyncing to simulate an in-progress sync
        service.setIsSyncingForTesting(true)
        XCTAssertTrue(service.isSyncing)

        // syncNow should return immediately without executing a second sync
        // This is verified by the method returning immediately (no state change)
        let bannerBefore = service.syncBannerVisible
        await service.syncNow()

        // syncBannerVisible should not have been set to true since sync was skipped
        // (an empty repository would set it to false, not true — but it should stay unchanged
        //  since the guard triggers)
        XCTAssertEqual(service.syncBannerVisible, bannerBefore,
                       "syncBannerVisible should not change when isSyncing guard triggers")

        // Reset
        service.setIsSyncingForTesting(false)
    }

    // MARK: - Test 3: empty sync succeeds without error and banner stays false

    func testEmptySyncSucceedsWithoutError() async {
        let service = SessionSyncService(repository: repository)

        // No unsynced sessions in the repository — sync should complete cleanly
        // We override performBatchSync behavior by using the testable sync path
        await service.syncNowSkippingSupabaseForTesting()

        XCTAssertFalse(service.syncBannerVisible,
                       "syncBannerVisible should be false after a successful empty sync")
        XCTAssertFalse(service.isSyncing,
                       "isSyncing should be false after sync completes")
    }

    // MARK: - Test 4: markSynced clears unsynced fetch results

    func testMarkSyncedClearsUnsyncedFetch() throws {
        let context = persistenceController.container.viewContext

        // Create a finalized CDSessionLog that is NOT yet synced
        let sessionLog = CDSessionLog(context: context)
        sessionLog.id = UUID()
        sessionLog.userId = "user-test"
        sessionLog.planId = "plan-test"
        sessionLog.workoutDayLabel = "Monday"
        sessionLog.startedAt = Date()
        sessionLog.completedAt = Date()
        sessionLog.totalExercises = 1
        sessionLog.totalSets = 1
        sessionLog.totalReps = 10
        sessionLog.syncedToSupabase = false
        try context.save()

        // Verify it appears in unsynced fetch
        let unsyncedBefore = try repository.fetchUnsyncedSessions()
        XCTAssertEqual(unsyncedBefore.count, 1, "Should have one unsynced session")

        // Mark synced
        try repository.markSynced(session: sessionLog, setLogs: [])

        // Verify it no longer appears in unsynced fetch
        let unsyncedAfter = try repository.fetchUnsyncedSessions()
        XCTAssertEqual(unsyncedAfter.count, 0, "Unsynced sessions should be empty after markSynced")
    }
}
