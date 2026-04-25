import Foundation
import Network
import Observation

// MARK: - SessionSyncService
// Monitors network connectivity using NWPathMonitor and syncs unsynced CoreData session
// records to Supabase on reconnect.
//
// Thread safety:
//   - NWPathMonitor starts on a dedicated background DispatchQueue (never .main)
//   - All @Observable state mutations happen on @MainActor via Task { @MainActor in ... }
//   - isSyncing Bool guard prevents concurrent Supabase upserts from rapid reconnect events
//     (T-04-06: DoS mitigation for multiple NWPathMonitor reconnect events)
//
// Sync strategy:
//   - On reconnect: syncPendingLogs() reads all unsynced CDSessionLog + CDSetLog
//   - Upserts session_logs first (set_logs FK references session_logs)
//   - Upserts set_logs per session
//   - Marks CoreData records syncedToSupabase = true only after both upserts succeed
//   - Retries up to 3 times on failure; shows syncBannerVisible after 3 failures
//
// Requirements: SESS-03 (offline sync)

@Observable
@MainActor
final class SessionSyncService {

    // MARK: - State

    var syncBannerVisible: Bool = false
    private(set) var isSyncing: Bool = false

    // MARK: - Dependencies

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.workoutapp.network-monitor")
    private let repository: SessionRepository

    // MARK: - Init

    init(repository: SessionRepository = SessionRepository()) {
        self.repository = repository
    }

    // MARK: - Monitoring

    /// Starts NWPathMonitor on a background queue.
    /// NEVER start on .main — Swift 6 actor isolation warning and potential UI stutter.
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            // Bridge to MainActor for @Observable state access
            Task { @MainActor [weak self] in
                guard let self, !self.isSyncing else { return }
                await self.syncPendingLogs()
            }
        }
        monitor.start(queue: monitorQueue)
    }

    /// Stops network monitoring. Call from session cleanup.
    func stopMonitoring() {
        monitor.cancel()
    }

    // MARK: - Public Sync Entry Points

    /// Public entry point for manual sync trigger (called on app foreground).
    func syncNow() async {
        guard !isSyncing else { return }
        await syncPendingLogs()
    }

    // MARK: - Private Sync Logic

    private func syncPendingLogs() async {
        isSyncing = true
        defer { isSyncing = false }

        var retryCount = 0
        while retryCount < 3 {
            do {
                try await performBatchSync()
                syncBannerVisible = false
                return
            } catch {
                retryCount += 1
            }
        }
        // All 3 retries failed — show subtle sync failure banner
        syncBannerVisible = true
    }

    private func performBatchSync() async throws {
        let sessions = try repository.fetchUnsyncedSessions()
        guard !sessions.isEmpty else { return }

        // Upsert session_logs first (set_logs FK references session_logs)
        let sessionRows = sessions.compactMap { s -> SessionLogRow? in
            guard let id = s.id, let completedAt = s.completedAt else { return nil }
            return SessionLogRow(
                id: id.uuidString,
                userId: s.userId ?? "",
                planId: s.planId ?? "",
                workoutDayLabel: s.workoutDayLabel ?? "",
                startedAt: s.startedAt ?? Date(),
                completedAt: completedAt,
                totalExercises: Int(s.totalExercises),
                totalSets: Int(s.totalSets),
                totalReps: Int(s.totalReps),
                difficultyRating: s.difficultyRating
            )
        }

        if !sessionRows.isEmpty {
            try await supabase
                .from("session_logs")
                .upsert(sessionRows, onConflict: "id")
                .execute()
        }

        // Upsert set_logs per session (set_logs FK references session_logs.id)
        for session in sessions {
            let setLogs = try repository.fetchUnsyncedSetLogs(for: session)

            if !setLogs.isEmpty {
                let setRows = setLogs.compactMap { sl -> SetLogPayload? in
                    guard let id = sl.id, let completedAt = sl.completedAt else { return nil }
                    return SetLogPayload(
                        id: id.uuidString,
                        sessionId: sl.sessionId?.uuidString ?? "",
                        userId: session.userId ?? "",
                        exerciseName: sl.exerciseName ?? "",
                        setNumber: Int(sl.setNumber),
                        targetReps: sl.targetReps ?? "",
                        repsLogged: Int(sl.repsLogged),
                        completedAt: completedAt
                    )
                }

                if !setRows.isEmpty {
                    try await supabase
                        .from("set_logs")
                        .upsert(setRows, onConflict: "id")
                        .execute()
                }
            }

            // Mark synced only after both upserts succeed for this session
            let allSetLogs = (session.setLogs?.array as? [CDSetLog]) ?? []
            try repository.markSynced(session: session, setLogs: allSetLogs)
        }
    }

    // MARK: - Testing Hooks

    /// For unit tests only — bypasses Supabase calls and tests CoreData sync path.
    func syncNowSkippingSupabaseForTesting() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Perform only the repository fetch (no Supabase) to test the empty sync path
        let sessions = (try? repository.fetchUnsyncedSessions()) ?? []
        if sessions.isEmpty {
            syncBannerVisible = false
        }
    }

    /// For unit tests only — forces isSyncing state without starting a real sync.
    func setIsSyncingForTesting(_ value: Bool) {
        isSyncing = value
    }
}

// MARK: - Encodable Row Types

/// Encodable struct for Supabase session_logs upsert.
/// snake_case CodingKeys map to Supabase column names.
private struct SessionLogRow: Encodable {
    let id: String
    let userId: String
    let planId: String
    let workoutDayLabel: String
    let startedAt: Date
    let completedAt: Date
    let totalExercises: Int
    let totalSets: Int
    let totalReps: Int
    let difficultyRating: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planId = "plan_id"
        case workoutDayLabel = "workout_day_label"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case totalExercises = "total_exercises"
        case totalSets = "total_sets"
        case totalReps = "total_reps"
        case difficultyRating = "difficulty_rating"
    }
}

/// Encodable struct for Supabase set_logs upsert.
/// snake_case CodingKeys map to Supabase column names.
private struct SetLogPayload: Encodable {
    let id: String
    let sessionId: String
    let userId: String
    let exerciseName: String
    let setNumber: Int
    let targetReps: String
    let repsLogged: Int
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case exerciseName = "exercise_name"
        case setNumber = "set_number"
        case targetReps = "target_reps"
        case repsLogged = "reps_logged"
        case completedAt = "completed_at"
    }
}
