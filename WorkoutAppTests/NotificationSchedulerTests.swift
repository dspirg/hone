import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - NotificationSchedulerTests
// Unit tests for NotificationScheduler's hasLoggedSessionToday guard logic.
//
// UNUserNotificationCenter scheduling requires a running simulator/device — those paths
// are covered by human verification in Plan 04. These tests focus on the CoreData
// hasLoggedSessionToday query which is the most bug-prone component (T-06-05).
//
// Each test uses PersistenceController(inMemory: true) for an isolated store.
//
// Requirements: PROG-03

@MainActor
final class NotificationSchedulerTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var scheduler: NotificationScheduler!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        scheduler = NotificationScheduler(context: context)
    }

    override func tearDownWithError() throws {
        scheduler = nil
        context = nil
        persistenceController = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func makeSession(completedAt: Date?, userId: String) throws -> CDSessionLog {
        let session = CDSessionLog(context: context)
        session.id = UUID()
        session.userId = userId
        session.planId = "plan-test"
        session.workoutDayLabel = "Push Day"
        session.totalExercises = 3
        session.startedAt = Date()
        session.completedAt = completedAt
        session.syncedToSupabase = false
        try context.save()
        return session
    }

    // MARK: - Test 1: Returns true when a completed session exists today

    func testHasLoggedSessionTodayReturnsTrueWhenSessionExists() throws {
        try makeSession(completedAt: Date(), userId: "test-user")

        XCTAssertTrue(
            scheduler.hasLoggedSessionToday(userId: "test-user"),
            "Should return true when a completed session exists for today"
        )
    }

    // MARK: - Test 2: Returns false when no session exists

    func testHasLoggedSessionTodayReturnsFalseWhenNoSession() throws {
        XCTAssertFalse(
            scheduler.hasLoggedSessionToday(userId: "test-user"),
            "Should return false when no sessions exist in the database"
        )
    }

    // MARK: - Test 3: Returns false for sessions completed yesterday

    func testHasLoggedSessionTodayReturnsFalseForYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        try makeSession(completedAt: yesterday, userId: "test-user")

        XCTAssertFalse(
            scheduler.hasLoggedSessionToday(userId: "test-user"),
            "Should return false when session was completed yesterday, not today"
        )
    }

    // MARK: - Test 4: Filters by userId (T-06-05 — no cross-user data leakage)

    func testHasLoggedSessionTodayFiltersByUserId() throws {
        try makeSession(completedAt: Date(), userId: "other-user")

        XCTAssertFalse(
            scheduler.hasLoggedSessionToday(userId: "test-user"),
            "Should return false when the logged session belongs to a different userId"
        )
    }

    // MARK: - Test 5: Returns false for in-progress sessions (completedAt == nil)

    func testHasLoggedSessionTodayExcludesInProgress() throws {
        try makeSession(completedAt: nil, userId: "test-user")

        XCTAssertFalse(
            scheduler.hasLoggedSessionToday(userId: "test-user"),
            "Should return false when session is in-progress (completedAt is nil)"
        )
    }
}
