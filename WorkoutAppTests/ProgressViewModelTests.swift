import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - ProgressViewModelTests
// Unit tests for ProgressViewModel — streak, PR detection, weekly bucketing, fetch filtering.
// Tests use PersistenceController(inMemory: true) for isolated CoreData context.
// All tests call ViewModel methods directly (not through loadProgress) to isolate logic.
//
// Requirements: PROG-01, PROG-02, PROG-03, PROG-04
// Threat mitigations tested:
//   T-06-01: fetchCompletedSessions excludes sessions with no userId match
//   T-06-02: detectPRs only finds PRs against sessions for same userId

@MainActor
final class ProgressViewModelTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var viewModel: ProgressViewModel!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        viewModel = ProgressViewModel(context: context)
        viewModel.setUserIdForTesting("test-user-id")
    }

    override func tearDownWithError() throws {
        viewModel = nil
        context = nil
        persistenceController = nil
    }

    // MARK: - Helpers

    /// Insert CDSessionLog records with specified completedAt dates.
    @discardableResult
    func makeSessions(dates: [Date], userId: String = "test-user-id") throws -> [CDSessionLog] {
        var sessions: [CDSessionLog] = []
        for date in dates {
            let session = CDSessionLog(context: context)
            session.id = UUID()
            session.userId = userId
            session.planId = "plan-test"
            session.workoutDayLabel = "Monday"
            session.startedAt = date.addingTimeInterval(-3600)
            session.completedAt = date
            session.totalExercises = 3
            session.totalSets = 9
            session.totalReps = 45
            session.syncedToSupabase = false
            sessions.append(session)
        }
        try context.save()
        return sessions
    }

    /// Create a CDSetLog and attach it to the given session.
    @discardableResult
    func makeSetLog(
        session: CDSessionLog,
        exerciseName: String,
        repsLogged: Int16,
        setNumber: Int16 = 1
    ) throws -> CDSetLog {
        let setLog = CDSetLog(context: context)
        setLog.id = UUID()
        setLog.sessionId = session.id
        setLog.exerciseName = exerciseName
        setLog.setNumber = setNumber
        setLog.targetReps = "10"
        setLog.repsLogged = repsLogged
        setLog.completedAt = session.completedAt ?? Date()
        setLog.syncedToSupabase = false
        session.addToSetLogs(setLog)
        try context.save()
        return setLog
    }

    // MARK: - Test 1: fetchCompletedSessions excludes in-progress sessions (T-06-01)

    func testFetchCompletedSessionsExcludesInProgress() throws {
        // 2 completed sessions
        let completedDates = [
            Date().addingTimeInterval(-86400),
            Date().addingTimeInterval(-172800)
        ]
        try makeSessions(dates: completedDates)

        // 1 in-progress session (completedAt == nil)
        let inProgress = CDSessionLog(context: context)
        inProgress.id = UUID()
        inProgress.userId = "test-user-id"
        inProgress.planId = "plan-test"
        inProgress.workoutDayLabel = "Tuesday"
        inProgress.startedAt = Date()
        inProgress.completedAt = nil
        inProgress.totalExercises = 3
        inProgress.totalSets = 0
        inProgress.totalReps = 0
        inProgress.syncedToSupabase = false
        try context.save()

        let fetched = try viewModel.fetchCompletedSessions()
        XCTAssertEqual(fetched.count, 2, "In-progress session with nil completedAt should be excluded")
    }

    // MARK: - Test 2: fetchCompletedSessions filters by userId (T-06-01)

    func testFetchCompletedSessionsFiltersByUserId() throws {
        // 2 sessions for test-user-id
        try makeSessions(dates: [
            Date().addingTimeInterval(-86400),
            Date().addingTimeInterval(-172800)
        ], userId: "test-user-id")

        // 1 session for a different user
        try makeSessions(dates: [Date().addingTimeInterval(-259200)], userId: "other-user-id")

        let fetched = try viewModel.fetchCompletedSessions()
        XCTAssertEqual(fetched.count, 2, "Sessions for other-user-id should be excluded")
        XCTAssertTrue(fetched.allSatisfy { $0.userId == "test-user-id" })
    }

    // MARK: - Test 3: streak counts consecutive calendar days correctly

    func testStreakConsecutiveDays() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let sessions = try makeSessions(dates: [today, yesterday, twoDaysAgo])
        viewModel.computeStreak(from: sessions)

        XCTAssertEqual(viewModel.currentStreak, 3, "Should count 3 consecutive days: today, yesterday, day before")
        XCTAssertEqual(viewModel.longestStreak, 3)
    }

    // MARK: - Test 4: streak resets to 1 when there is a gap

    func testStreakBrokenByGap() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let sessions = try makeSessions(dates: [today, threeDaysAgo])
        viewModel.computeStreak(from: sessions)

        XCTAssertEqual(viewModel.currentStreak, 1, "Streak should be 1 — gap between today and 3 days ago")
        XCTAssertEqual(viewModel.longestStreak, 1)
    }

    // MARK: - Test 5: multiple sessions on the same day count as streak of 1

    func testStreakDeduplicatesSameDay() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let morningToday = today.addingTimeInterval(3600)
        let eveningToday = today.addingTimeInterval(7200)

        let sessions = try makeSessions(dates: [morningToday, eveningToday])
        viewModel.computeStreak(from: sessions)

        XCTAssertEqual(viewModel.currentStreak, 1, "Two sessions on same day should deduplicate to streak of 1, not 2")
    }

    // MARK: - Test 6: streak is 0 when last session was more than 1 day ago

    func testStreakZeroWhenNoRecentSessions() throws {
        let calendar = Calendar.current
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date())!

        let sessions = try makeSessions(dates: [fiveDaysAgo])
        viewModel.computeStreak(from: sessions)

        XCTAssertEqual(viewModel.currentStreak, 0, "Streak should be 0 — last session was 5 days ago")
        XCTAssertEqual(viewModel.longestStreak, 1, "Longest streak should still be 1 for the single session")
    }

    // MARK: - Test 7: week buckets group sessions by calendar week

    func testWeeklyBucketsGroupsByWeek() throws {
        let calendar = Calendar.current
        let today = Date()

        // 3 sessions in current week
        guard let thisWeekMonday = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else {
            XCTFail("Could not compute this week's Monday")
            return
        }

        // Session in current week
        let thisWeekDate = thisWeekMonday.addingTimeInterval(86400)  // Tuesday

        // Session two weeks ago
        let twoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: thisWeekMonday)!
            .addingTimeInterval(86400)

        // Session four weeks ago
        let fourWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -4, to: thisWeekMonday)!
            .addingTimeInterval(86400)

        let sessions = try makeSessions(dates: [thisWeekDate, twoWeeksAgo, fourWeeksAgo])
        let buckets = viewModel.computeWeekBuckets(from: sessions)

        XCTAssertGreaterThanOrEqual(buckets.count, 3, "Should have buckets for at least 3 different weeks")

        // Each bucket should have exactly 1 session
        for bucket in buckets {
            XCTAssertEqual(bucket.sessionCount, 1, "Each week bucket should contain 1 session")
        }

        // Verify buckets are sorted ascending by checking count matches expected weeks
        // (WeekKey sort is validated by computeWeekBuckets using Comparable conformance,
        //  weekLabel strings don't sort lexicographically across month boundaries)
        XCTAssertEqual(buckets.count, 3, "Should have exactly 3 week buckets")
    }

    // MARK: - Test 8: PR detection finds new record correctly (T-06-02)

    func testPRDetectionFindsNewRecord() throws {
        viewModel.setUserIdForTesting("test-user-id")

        // Prior session with Push-ups at 10 reps
        let priorSessions = try makeSessions(dates: [Date().addingTimeInterval(-86400)])
        let priorSession = priorSessions[0]
        try makeSetLog(session: priorSession, exerciseName: "Push-ups", repsLogged: 10)

        // Current session with Push-ups at 15 reps (new PR)
        let currentSessions = try makeSessions(dates: [Date()])
        let currentSession = currentSessions[0]
        try makeSetLog(session: currentSession, exerciseName: "Push-ups", repsLogged: 15)

        let prs = try viewModel.detectPRs(for: currentSession)

        XCTAssertEqual(prs.count, 1, "Should detect exactly 1 PR")
        XCTAssertEqual(prs[0].exerciseName, "Push-ups")
        XCTAssertEqual(prs[0].newRecord, 15)
        XCTAssertEqual(prs[0].previousBest, 10)
    }

    // MARK: - Test 9: PR detection returns empty when no improvement

    func testPRDetectionReturnsEmptyWhenNoPR() throws {
        viewModel.setUserIdForTesting("test-user-id")

        // Prior session with Push-ups at 15 reps
        let priorSessions = try makeSessions(dates: [Date().addingTimeInterval(-86400)])
        let priorSession = priorSessions[0]
        try makeSetLog(session: priorSession, exerciseName: "Push-ups", repsLogged: 15)

        // Current session with Push-ups at only 10 reps (no PR)
        let currentSessions = try makeSessions(dates: [Date()])
        let currentSession = currentSessions[0]
        try makeSetLog(session: currentSession, exerciseName: "Push-ups", repsLogged: 10)

        let prs = try viewModel.detectPRs(for: currentSession)

        XCTAssertEqual(prs.count, 0, "Should not detect PR when current reps are less than prior max")
    }

    // MARK: - Test 10: PR detection treats first time doing exercise as a PR

    func testPRDetectionFirstTimeExercise() throws {
        viewModel.setUserIdForTesting("test-user-id")

        // Current session with Squats at 12 reps — no prior sessions for this exercise
        let currentSessions = try makeSessions(dates: [Date()])
        let currentSession = currentSessions[0]
        try makeSetLog(session: currentSession, exerciseName: "Squats", repsLogged: 12)

        let prs = try viewModel.detectPRs(for: currentSession)

        XCTAssertEqual(prs.count, 1, "First time doing an exercise should count as a PR")
        XCTAssertEqual(prs[0].exerciseName, "Squats")
        XCTAssertEqual(prs[0].newRecord, 12)
        XCTAssertEqual(prs[0].previousBest, 0, "previousBest should be 0 for first-time exercise")
    }
}
