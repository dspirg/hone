import CoreData
import Foundation

// MARK: - SessionRepository
// CRUD operations for CoreData session and set log persistence.
// Mirrors WorkoutPlanRepository structure: @MainActor, init with context parameter.
//
// Write-ahead pattern: all session data is written to CoreData immediately during the
// workout session. Supabase sync runs after session completion (Plan 04-05).
//
// Thread safety: startSession / finalizeSession / fetch / markSynced run on @MainActor
// with the view context. completeSet dispatches to a background context via
// container.performBackgroundTask to avoid blocking the main thread during a live session.
//
// Requirements: SESS-01, SESS-03, SESS-04
// Threat mitigations:
//   T-04-01: repsLogged clamped to 0–999 before CoreData write
//   T-04-02: syncedToSupabase flag enables filtered Supabase upsert

@MainActor
final class SessionRepository {
    private let context: NSManagedObjectContext
    private let container: NSPersistentContainer

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) {
        self.context = context
        self.container = container
    }

    // MARK: - Start Session

    /// Creates a CDSessionLog for the given workout day, saving immediately.
    /// - Parameters:
    ///   - day: The WorkoutDay being started (provides dayLabel and exercise count)
    ///   - planId: The active plan's supabaseId (or CoreData id string)
    ///   - userId: The authenticated user's UUID string
    /// - Returns: The newly created CDSessionLog
    func startSession(day: WorkoutDay, planId: String, userId: String) throws -> CDSessionLog {
        let session = CDSessionLog(context: context)
        session.id = UUID()
        session.userId = userId
        session.planId = planId
        session.workoutDayLabel = day.dayLabel
        session.totalExercises = Int16(min(day.exercises.count, Int(Int16.max)))
        session.startedAt = Date()
        session.syncedToSupabase = false
        try context.save()
        return session
    }

    // MARK: - Complete Set

    /// Records a completed set in a background context.
    /// T-04-01: repsLogged is clamped to 0–999 before write.
    /// - Parameters:
    ///   - session: The active CDSessionLog (id used for denormalized FK)
    ///   - exercise: The PlannedExercise being logged
    ///   - setNumber: 1-indexed set number within the exercise
    ///   - repsLogged: Raw rep count from UI (clamped to 0–999)
    func completeSet(
        session: CDSessionLog,
        exercise: PlannedExercise,
        setNumber: Int,
        repsLogged: Int
    ) {
        // T-04-01: clamp before write — invalid stepper input or programmatic call
        let clampedReps = min(max(repsLogged, 0), 999)
        let sessionId = session.id

        container.performBackgroundTask { bgCtx in
            let setLog = CDSetLog(context: bgCtx)
            setLog.id = UUID()
            setLog.sessionId = sessionId
            setLog.exerciseName = exercise.exerciseName
            setLog.setNumber = Int16(min(setNumber, Int(Int16.max)))
            setLog.targetReps = exercise.reps
            setLog.repsLogged = Int16(clampedReps)
            setLog.completedAt = Date()
            setLog.syncedToSupabase = false

            // Wire inverse relationship by fetching session in this background context
            let req = CDSessionLog.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", sessionId! as CVarArg)
            req.fetchLimit = 1
            if let bgSession = (try? bgCtx.fetch(req))?.first {
                bgSession.addToSetLogs(setLog)
            }
            try? bgCtx.save()
        }
    }

    /// Synchronous variant for tests — writes directly to the injected context.
    /// Not intended for production use; allows unit tests to avoid XCTestExpectation overhead.
    func completeSetSync(
        session: CDSessionLog,
        exercise: PlannedExercise,
        setNumber: Int,
        repsLogged: Int
    ) throws {
        let clampedReps = min(max(repsLogged, 0), 999)

        let setLog = CDSetLog(context: context)
        setLog.id = UUID()
        setLog.sessionId = session.id
        setLog.exerciseName = exercise.exerciseName
        setLog.setNumber = Int16(min(setNumber, Int(Int16.max)))
        setLog.targetReps = exercise.reps
        setLog.repsLogged = Int16(clampedReps)
        setLog.completedAt = Date()
        setLog.syncedToSupabase = false
        session.addToSetLogs(setLog)
        try context.save()
    }

    // MARK: - Finalize Session

    /// Marks a session complete: sets completedAt, aggregates totalSets and totalReps from
    /// CDSetLog records attached via the setLogs ordered relationship, saves context.
    func finalizeSession(_ session: CDSessionLog) throws {
        let setLogs = (session.setLogs?.array as? [CDSetLog]) ?? []
        session.totalSets = Int16(min(setLogs.count, Int(Int16.max)))
        session.totalReps = Int16(
            min(setLogs.reduce(0) { $0 + Int($1.repsLogged) }, Int(Int16.max))
        )
        session.completedAt = Date()
        try context.save()
    }

    // MARK: - Difficulty Rating

    /// Saves the difficulty rating to the session log (ADPT-01).
    /// Called after the user taps a rating emoji on the summary screen.
    func saveDifficultyRating(_ rating: DifficultyRating, for session: CDSessionLog) throws {
        session.difficultyRating = rating.rawValue
        try context.save()
    }

    // MARK: - Fetch Unsynced

    /// Returns completed sessions that have not yet been synced to Supabase.
    /// Only sessions with completedAt != nil are included (in-progress sessions excluded).
    func fetchUnsyncedSessions() throws -> [CDSessionLog] {
        let req = CDSessionLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "syncedToSupabase == NO AND completedAt != nil"
        )
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
        return try context.fetch(req)
    }

    /// Returns all CDSetLog records for a given session, ordered by completedAt.
    /// Uses the denormalized sessionId UUID for the fetch predicate.
    func fetchUnsyncedSetLogs(for session: CDSessionLog) throws -> [CDSetLog] {
        let req = CDSetLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "sessionId == %@ AND syncedToSupabase == NO",
            session.id! as CVarArg
        )
        req.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: true)]
        return try context.fetch(req)
    }

    // MARK: - Mark Synced

    /// Marks a session and its set logs as synced to Supabase.
    /// Called after a successful upsert to session_logs and set_logs tables.
    func markSynced(session: CDSessionLog, setLogs: [CDSetLog]) throws {
        session.syncedToSupabase = true
        setLogs.forEach { $0.syncedToSupabase = true }
        try context.save()
    }
}
