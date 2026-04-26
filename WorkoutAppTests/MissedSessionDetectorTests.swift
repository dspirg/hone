import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - MissedSessionDetectorTests
// Unit tests for MissedSessionDetector.detectMissedSessions — pure logic, no UI/network.
// Uses injectable calendar and date for deterministic testing.
// Requirements: ADPT-03

@MainActor
final class MissedSessionDetectorTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
    }

    // MARK: - Helpers

    private func makeSession(completedAt: Date?, dayLabel: String) throws -> CDSessionLog {
        let session = CDSessionLog(context: context)
        session.id = UUID()
        session.userId = "test-user"
        session.planId = "plan-test"
        session.workoutDayLabel = dayLabel
        session.totalExercises = 3
        session.startedAt = Date()
        session.completedAt = completedAt
        session.syncedToSupabase = false
        try context.save()
        return session
    }

    private func makeDate(weekday: Int, hour: Int = 12) -> Date {
        // Create a date for a specific weekday in the current week
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)
        let diff = weekday - currentWeekday
        return calendar.date(byAdding: .day, value: diff, to: now)!
    }

    // MARK: - Test 1: No missed sessions when all completed

    func testNoMissedWhenAllCompleted() throws {
        // Plan: Mon, Wed, Fri. Today is Friday (weekday 6). Mon and Wed completed.
        let monday = makeDate(weekday: 2)
        let wednesday = makeDate(weekday: 4)
        let friday = makeDate(weekday: 6, hour: 10)

        try makeSession(completedAt: monday, dayLabel: "Monday")
        try makeSession(completedAt: wednesday, dayLabel: "Wednesday")

        let sessions = try context.fetch(CDSessionLog.fetchRequest())

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let missed = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: ["Monday", "Wednesday", "Friday"],
            completedSessions: sessions,
            today: friday,
            calendar: calendar
        )

        // Friday hasn't passed yet (today IS Friday), so only Mon/Wed could be missed — both completed
        XCTAssertEqual(missed, [], "Should have no missed sessions when all past days are completed")
    }

    // MARK: - Test 2: Detects missed session

    func testDetectsMissedMonday() throws {
        // Plan: Mon, Wed, Fri. Today is Wednesday. Monday not completed.
        let wednesday = makeDate(weekday: 4)

        let sessions: [CDSessionLog] = [] // No completed sessions

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let missed = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: ["Monday", "Wednesday", "Friday"],
            completedSessions: sessions,
            today: wednesday,
            calendar: calendar
        )

        XCTAssertEqual(missed, ["Monday"], "Should detect Monday as missed when today is Wednesday and no sessions completed")
    }

    // MARK: - Test 3: Does not flag future days

    func testDoesNotFlagFutureDays() throws {
        // Plan: Mon, Wed, Fri. Today is Tuesday. Only Mon has passed.
        let tuesday = makeDate(weekday: 3)

        let sessions: [CDSessionLog] = []

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let missed = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: ["Monday", "Wednesday", "Friday"],
            completedSessions: sessions,
            today: tuesday,
            calendar: calendar
        )

        XCTAssertEqual(missed, ["Monday"], "Should only flag Monday — Wed and Fri are future days")
    }

    // MARK: - Test 4: Does not flag rest days

    func testDoesNotFlagRestDays() throws {
        // Plan only has Mon/Wed/Fri. Today is Saturday.
        // Tuesday and Thursday are NOT rest days — they're just not in the plan.
        let saturday = makeDate(weekday: 7)

        let sessions: [CDSessionLog] = []

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let missed = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: ["Monday", "Wednesday", "Friday"],
            completedSessions: sessions,
            today: saturday,
            calendar: calendar
        )

        XCTAssertEqual(Set(missed), Set(["Monday", "Wednesday", "Friday"]),
                       "Should flag all 3 planned days but NOT Tue/Thu/Sat")
    }

    // MARK: - Test 5: Ignores sessions from previous weeks

    func testIgnoresPreviousWeekSessions() throws {
        // Session completed last Monday, but this Monday is also planned
        let lastMonday = Calendar.current.date(byAdding: .day, value: -7, to: makeDate(weekday: 2))!
        try makeSession(completedAt: lastMonday, dayLabel: "Monday")

        let wednesday = makeDate(weekday: 4)
        let sessions = try context.fetch(CDSessionLog.fetchRequest())

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let missed = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: ["Monday", "Wednesday"],
            completedSessions: sessions,
            today: wednesday,
            calendar: calendar
        )

        XCTAssertTrue(missed.contains("Monday"),
                      "Should flag Monday even though last week's Monday was completed")
    }
}
