import CoreData
import Foundation

// MARK: - SessionRepository
// CRUD operations for CDSessionLog and CDSetLog CoreData entities.
// Provides write-ahead logging for in-session workout data.
// Provides sync query methods for SessionSyncService to upload to Supabase.
//
// Thread safety: all methods run on @MainActor with the view context.
// Background saves (completeSet) use container.performBackgroundTask for non-blocking writes.
//
// Requirements: SESS-01 (CDSetLog writes on completeSet), SESS-03 (offline-first sync)

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

    // MARK: - Session Lifecycle

    /// Creates and persists a CDSessionLog at the start of a session.
    /// Called once when the session begins; sessionLog.completedAt is nil until finalized.
    func startSession(day: WorkoutDay, planId: String, userId: String) throws -> CDSessionLog {
        let sessionLog = CDSessionLog(context: context)
        sessionLog.id = UUID()
        sessionLog.userId = userId
        sessionLog.planId = planId
        sessionLog.workoutDayLabel = day.dayLabel
        sessionLog.startedAt = Date()
        sessionLog.completedAt = nil
        sessionLog.totalExercises = Int16(min(day.exercises.count, Int(Int16.max)))
        sessionLog.totalSets = 0
        sessionLog.totalReps = 0
        sessionLog.syncedToSupabase = false
        try context.save()
        return sessionLog
    }

    /// Records a completed set as a CDSetLog in a background context.
    /// Non-throwing — CoreData write failure is non-fatal; session continues in memory.
    /// T-04-05: repsLogged clamped to 0–999 before Int16 cast.
    func completeSet(
        session: CDSessionLog,
        exercise: PlannedExercise,
        setNumber: Int,
        repsLogged: Int
    ) {
        // Capture values for background context
        let sessionId = session.id
        let exerciseName = exercise.exerciseName
        let targetReps = exercise.reps
        let clampedReps = min(max(repsLogged, 0), 999)
        let clampedSetNumber = min(setNumber, Int(Int16.max))

        container.performBackgroundTask { backgroundContext in
            let setLog = CDSetLog(context: backgroundContext)
            setLog.id = UUID()
            setLog.sessionId = sessionId
            setLog.exerciseName = exerciseName
            setLog.setNumber = Int16(clampedSetNumber)
            setLog.targetReps = targetReps
            setLog.repsLogged = Int16(clampedReps)
            setLog.completedAt = Date()
            setLog.syncedToSupabase = false

            // Link to parent session via relationship (fetch in this background context)
            if let sessionId = sessionId {
                let request = CDSessionLog.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
                request.fetchLimit = 1
                if let parentSession = try? backgroundContext.fetch(request).first {
                    setLog.session = parentSession
                }
            }

            try? backgroundContext.save()
        }
    }

    /// Finalizes the session by setting completedAt and computing aggregate totals.
    /// Called when the last set of the last exercise is logged.
    func finalizeSession(_ session: CDSessionLog) throws {
        session.completedAt = Date()

        // Aggregate totals from set logs
        let setLogs = (session.setLogs?.array as? [CDSetLog]) ?? []
        session.totalSets = Int16(min(setLogs.count, Int(Int16.max)))
        let totalReps = setLogs.reduce(0) { $0 + Int($1.repsLogged) }
        session.totalReps = Int16(min(totalReps, Int(Int16.max)))

        try context.save()
    }

    // MARK: - Sync Queries

    /// Returns all CDSessionLog records where syncedToSupabase == false AND completedAt != nil.
    /// Only completed sessions are synced — abandoned sessions are excluded.
    func fetchUnsyncedSessions() throws -> [CDSessionLog] {
        let request = CDSessionLog.fetchRequest()
        request.predicate = NSPredicate(format: "syncedToSupabase == NO AND completedAt != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: true)]
        return try context.fetch(request)
    }

    /// Returns all CDSetLog records for the given session where syncedToSupabase == false.
    func fetchUnsyncedSetLogs(for session: CDSessionLog) throws -> [CDSetLog] {
        let request = CDSetLog.fetchRequest()
        guard let sessionId = session.id else { return [] }
        request.predicate = NSPredicate(format: "sessionId == %@ AND syncedToSupabase == NO", sessionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: true)]
        return try context.fetch(request)
    }

    /// Marks a session and its set logs as synced in CoreData.
    /// Called by SessionSyncService after successful Supabase upsert.
    func markSynced(session: CDSessionLog, setLogs: [CDSetLog]) throws {
        session.syncedToSupabase = true
        for setLog in setLogs {
            setLog.syncedToSupabase = true
        }
        try context.save()
    }
}
