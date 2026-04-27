import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - SessionRepositoryTests
// Unit tests for SessionRepository using an in-memory CoreData store.
// Each test gets a fresh PersistenceController(inMemory: true) — avoids shared state.
//
// completeSetSync is used instead of completeSet (which uses performBackgroundTask)
// so tests can verify CoreData state synchronously without XCTestExpectation overhead.
//
// Requirements: SESS-01, SESS-03, SESS-04

@MainActor
final class SessionRepositoryTests: XCTestCase {

    var context: NSManagedObjectContext!
    private var persistenceController: PersistenceController!
    private var repository: SessionRepository!

    // Helper WorkoutDay for tests
    private var testDay: WorkoutDay {
        WorkoutDay(
            dayLabel: "Monday",
            sessionName: "Upper Body",
            exercises: [
                PlannedExercise(
                    exerciseName: "Push-Up",
                    sets: 3,
                    reps: "10-12",
                    restSeconds: 60,
                    rationale: "Compound push movement"
                ),
                PlannedExercise(
                    exerciseName: "Pull-Up",
                    sets: 3,
                    reps: "6-8",
                    restSeconds: 90,
                    rationale: "Compound pull movement"
                )
            ]
        )
    }

    private var testExercise: PlannedExercise {
        PlannedExercise(
            exerciseName: "Push-Up",
            sets: 3,
            reps: "10-12",
            restSeconds: 60,
            rationale: "Compound push movement"
        )
    }

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = SessionRepository(
            context: context,
            container: persistenceController.container
        )
    }

    override func tearDownWithError() throws {
        repository = nil
        context = nil
        persistenceController = nil
    }

    // MARK: - Test 1: startSession creates CDSessionLog with correct fields

    func testStartSessionCreatesLog() throws {
        let userId = "user-123"
        let planId = "plan-456"

        let session = try repository.startSession(day: testDay, planId: planId, userId: userId)

        XCTAssertNotNil(session.id, "Session id must not be nil")
        XCTAssertEqual(session.userId, userId, "userId must match")
        XCTAssertEqual(session.planId, planId, "planId must match")
        XCTAssertEqual(session.workoutDayLabel, "Monday", "dayLabel must match")
        XCTAssertEqual(session.totalExercises, 2, "totalExercises must match day.exercises.count")
        XCTAssertNotNil(session.startedAt, "startedAt must be set")
        XCTAssertFalse(session.syncedToSupabase, "New session must be unsynced")
        XCTAssertNil(session.completedAt, "completedAt must be nil until finalized")
    }

    // MARK: - Test 2: finalizeSession sets completedAt and correct totals

    func testFinalizeSessionSetsTotals() throws {
        let session = try repository.startSession(
            day: testDay, planId: "plan-1", userId: "user-1"
        )

        // Insert 5 CDSetLog records directly (repsLogged = 10 each)
        for i in 1...5 {
            try repository.completeSetSync(
                session: session,
                exercise: testExercise,
                setNumber: i,
                repsLogged: 10
            )
        }

        try repository.finalizeSession(session)

        XCTAssertNotNil(session.completedAt, "completedAt must be set after finalize")
        XCTAssertEqual(session.totalSets, 5, "totalSets must equal number of CDSetLog records")
        XCTAssertEqual(session.totalReps, 50, "totalReps must equal sum of repsLogged (5 * 10)")
    }

    // MARK: - Test 3: fetchUnsyncedSessions returns completed sessions only

    func testFetchUnsyncedReturnsCompletedOnly() throws {
        // Finalized session — should appear in unsynced fetch
        let completedSession = try repository.startSession(
            day: testDay, planId: "plan-1", userId: "user-1"
        )
        try repository.finalizeSession(completedSession)

        // Unfinished session (completedAt nil) — must NOT appear
        _ = try repository.startSession(
            day: testDay, planId: "plan-1", userId: "user-1"
        )

        let unsynced = try repository.fetchUnsyncedSessions()

        XCTAssertEqual(unsynced.count, 1, "Only completed sessions must be returned")
        XCTAssertEqual(unsynced.first?.id, completedSession.id, "The completed session must be in results")
    }

    // MARK: - Test 4: markSynced flips syncedToSupabase to true

    func testMarkSyncedFlipsFlag() throws {
        let session = try repository.startSession(
            day: testDay, planId: "plan-1", userId: "user-1"
        )
        try repository.completeSetSync(
            session: session,
            exercise: testExercise,
            setNumber: 1,
            repsLogged: 8
        )
        try repository.finalizeSession(session)

        let setLogs = try repository.fetchUnsyncedSetLogs(for: session)
        XCTAssertFalse(session.syncedToSupabase, "Session must start unsynced")

        try repository.markSynced(session: session, setLogs: setLogs)

        XCTAssertTrue(session.syncedToSupabase, "Session must be synced after markSynced")
        for log in setLogs {
            XCTAssertTrue(log.syncedToSupabase, "All set logs must be synced after markSynced")
        }

        // Unsynced fetch must now return empty (session is marked synced)
        let remaining = try repository.fetchUnsyncedSessions()
        XCTAssertTrue(remaining.isEmpty, "No unsynced sessions after markSynced")
    }

    // MARK: - Phase 11: Previous/Best Reps (UI-05)

    func testFetchPreviousReps_returnsNilWhenNoHistory() throws {
        // Given: no CDSetLog entries for "Bench Press"
        // When: fetchPreviousReps(exerciseName: "Bench Press", excludingSessionId: nil, userId: testUserId)
        // Then: returns nil
        let testUserId = "user-123"
        let result = try repository.fetchPreviousReps(
            exerciseName: "Bench Press",
            excludingSessionId: nil,
            userId: testUserId
        )
        XCTAssertNil(result, "Should return nil when no prior session data exists")
    }

    func testFetchBestReps_returnsNilWhenNoHistory() throws {
        // Given: no CDSetLog entries for "Bench Press"
        // When: fetchBestReps(exerciseName: "Bench Press", userId: testUserId)
        // Then: returns nil
        let testUserId = "user-123"
        let result = try repository.fetchBestReps(
            exerciseName: "Bench Press",
            userId: testUserId
        )
        XCTAssertNil(result, "Should return nil when no session data exists")
    }

    // MARK: - Test 5: repsLogged clamping (T-04-01)

    func testRepCountClamping() throws {
        let session = try repository.startSession(
            day: testDay, planId: "plan-1", userId: "user-1"
        )

        // Over-limit: 9999 should clamp to 999
        try repository.completeSetSync(
            session: session,
            exercise: testExercise,
            setNumber: 1,
            repsLogged: 9999
        )

        // Under-limit: -5 should clamp to 0
        try repository.completeSetSync(
            session: session,
            exercise: testExercise,
            setNumber: 2,
            repsLogged: -5
        )

        let setLogs = (session.setLogs?.array as? [CDSetLog]) ?? []
        XCTAssertEqual(setLogs.count, 2, "Must have 2 set log records")

        let sortedLogs = setLogs.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(sortedLogs[0].repsLogged, 999, "repsLogged=9999 must clamp to 999")
        XCTAssertEqual(sortedLogs[1].repsLogged, 0, "repsLogged=-5 must clamp to 0")
    }
}
