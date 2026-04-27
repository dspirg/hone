import Foundation
import CoreData
import Observation

// MARK: - ProgressViewModel
// Data layer for the Progress tab. Computes all metrics from CoreData:
//   - Streak (current and longest, calendar-day boundaries, deduplicated)
//   - Weekly ring (completed vs. planned sessions for the current week)
//   - Chart buckets (8-week history, grouped by ISO week)
//   - PR detection (max reps per exercise vs. all prior sessions)
//
// All NSFetchRequests include a userId predicate to prevent cross-user data leakage.
//
// Thread safety: All state mutations are on @MainActor (Swift 6 @Observable pattern).
//
// Requirements: PROG-01, PROG-02, PROG-03, PROG-04
// Threat mitigations:
//   T-06-01: fetchCompletedSessions predicate always includes userId == %@
//   T-06-02: detectPRs scopes prior CDSetLog queries via userId on parent sessions

@Observable
@MainActor
final class ProgressViewModel {

    // MARK: - Published State

    var sessions: [CDSessionLog] = []
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var weeklyCompleted: Int = 0
    var weeklyPlanned: Int = 0
    var weekBuckets: [WeekBucket] = []
    var isLoading: Bool = false
    var loadError: String? = nil

    // MARK: - Private State

    private var cachedUserId: String?
    private let viewContext: NSManagedObjectContext

    // MARK: - Init

    init(context: NSManagedObjectContext? = nil) {
        self.viewContext = context ?? PersistenceController.shared.container.viewContext
    }

    // MARK: - Lifecycle

    func onAppear(appState: AppState) {
        cachedUserId = appState.currentUser?.id.uuidString
        Task { await loadProgress() }
    }

    // MARK: - Load Progress

    func loadProgress() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let fetchedSessions = try fetchCompletedSessions()
            sessions = fetchedSessions
            computeStreak(from: fetchedSessions)
            // FIX-04: fetch planned days count from active plan (per D-09, D-10)
            if let userId = cachedUserId {
                let repo = WorkoutPlanRepository(context: viewContext)
                let plan = try? repo.fetchActivePlan(userId: userId)
                weeklyPlanned = plan?.weeklyDays.count ?? 3
            }
            computeWeeklyRing(from: fetchedSessions)
            weekBuckets = computeWeekBuckets(from: fetchedSessions)
        } catch {
            print("ProgressViewModel: loadProgress failed: \(error)")
            loadError = "Couldn't load your progress. Pull down to try again."
        }
    }

    // MARK: - Fetch Completed Sessions
    // T-06-01: predicate always includes userId == %@ to prevent cross-user data leakage

    func fetchCompletedSessions() throws -> [CDSessionLog] {
        let request = CDSessionLog.fetchRequest()
        request.predicate = NSPredicate(
            format: "completedAt != nil AND userId == %@",
            cachedUserId ?? ""
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "completedAt", ascending: false)
        ]
        return try viewContext.fetch(request)
    }

    // MARK: - Streak Computation
    // Uses calendar-day boundaries via Calendar.current.startOfDay(for:).
    // Deduplicates multiple sessions on the same day (Set<Date>).
    // Streak is 0 if most recent session was not today or yesterday.

    func computeStreak(from sessions: [CDSessionLog]) {
        let calendar = Calendar.current

        // Extract unique calendar days from completedAt dates
        let uniqueDays: [Date] = sessions
            .compactMap { $0.completedAt }
            .map { calendar.startOfDay(for: $0) }
            .reduce(into: Set<Date>()) { $0.insert($1) }
            .sorted(by: >)  // descending — most recent first

        guard !uniqueDays.isEmpty else {
            currentStreak = 0
            longestStreak = 0
            return
        }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // If the most recent session is not today or yesterday, current streak is 0
        let mostRecent = uniqueDays[0]
        guard mostRecent == today || mostRecent == yesterday else {
            currentStreak = 0
            // Still compute longest streak from the data
            longestStreak = computeLongestStreak(sortedDescendingDays: uniqueDays, calendar: calendar)
            return
        }

        // Walk from most recent day, counting consecutive calendar days
        var streak = 1
        for i in 1..<uniqueDays.count {
            let diff = calendar.dateComponents([.day], from: uniqueDays[i], to: uniqueDays[i - 1]).day ?? 0
            if diff == 1 {
                streak += 1
            } else {
                break
            }
        }
        currentStreak = streak
        longestStreak = max(streak, computeLongestStreak(sortedDescendingDays: uniqueDays, calendar: calendar))
    }

    private func computeLongestStreak(sortedDescendingDays: [Date], calendar: Calendar) -> Int {
        guard !sortedDescendingDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDescendingDays.count {
            let diff = calendar.dateComponents(
                [.day],
                from: sortedDescendingDays[i],
                to: sortedDescendingDays[i - 1]
            ).day ?? 0

            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    // MARK: - Weekly Ring Computation
    // Counts sessions completed in the current calendar week (weekOfYear).
    // weeklyPlanned is set from the active plan in loadProgress before this is called (FIX-04).

    func computeWeeklyRing(from sessions: [CDSessionLog]) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            weeklyCompleted = 0
            return
        }

        let completed = sessions.filter { session in
            guard let completedAt = session.completedAt else { return false }
            return weekInterval.contains(completedAt)
        }

        weeklyCompleted = completed.count
    }

    // MARK: - Week Buckets Computation
    // Groups sessions from the last 8 weeks into WeekBucket values for charting.
    // Each bucket contains session count and volume (totalSets * totalReps).

    @discardableResult
    func computeWeekBuckets(from sessions: [CDSessionLog]) -> [WeekBucket] {
        let calendar = Calendar.current
        guard let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: Date()) else {
            weekBuckets = []
            return []
        }

        // Filter to last 8 weeks
        let recentSessions = sessions.filter { session in
            guard let completedAt = session.completedAt else { return false }
            return completedAt >= eightWeeksAgo
        }

        // Group by WeekKey (yearForWeekOfYear, weekOfYear)
        var grouped: [WeekKey: [CDSessionLog]] = [:]
        for session in recentSessions {
            guard let completedAt = session.completedAt else { continue }
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: completedAt)
            guard let year = comps.yearForWeekOfYear, let week = comps.weekOfYear else { continue }
            let key = WeekKey(year: year, week: week)
            grouped[key, default: []].append(session)
        }

        // Build buckets, sorted ascending by week
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let buckets: [WeekBucket] = grouped
            .sorted { $0.key < $1.key }
            .map { (key, weekSessions) in
                // Get the Monday of this week for the label
                var comps = DateComponents()
                comps.yearForWeekOfYear = key.year
                comps.weekOfYear = key.week
                comps.weekday = 2  // Monday
                let monday = calendar.date(from: comps) ?? Date()
                let label = formatter.string(from: monday)

                let sessionCount = weekSessions.count
                let volume = weekSessions.reduce(0) { acc, session in
                    acc + Int(session.totalSets) * Int(session.totalReps)
                }

                return WeekBucket(
                    weekLabel: label,
                    sessionCount: sessionCount,
                    volume: volume
                )
            }

        weekBuckets = buckets
        return buckets
    }

    // MARK: - PR Detection
    // Detects exercises where the current session's max reps exceeds all prior sessions.
    // T-06-02: prior CDSetLog queries are scoped to userId via session relationship.
    //
    // Algorithm:
    //   1. Get current session's CDSetLog records
    //   2. Group by exerciseName, find max repsLogged per exercise
    //   3. For each exercise: fetch all prior CDSetLog records (sessionId != current, userId scoped)
    //   4. If current max > prior max → PRResult

    func detectPRs(for sessionLog: CDSessionLog, userId: String? = nil) throws -> [PRResult] {
        // T-06-07: prefer explicit userId parameter; fall back to cachedUserId
        let effectiveUserId = userId ?? cachedUserId ?? ""
        let currentSetLogs = (sessionLog.setLogs?.array as? [CDSetLog]) ?? []

        // Group current session sets by exercise name
        var currentMaxByExercise: [String: Int] = [:]
        for setLog in currentSetLogs {
            guard let exerciseName = setLog.exerciseName else { continue }
            let reps = Int(setLog.repsLogged)
            currentMaxByExercise[exerciseName] = max(
                currentMaxByExercise[exerciseName] ?? 0,
                reps
            )
        }

        var results: [PRResult] = []

        for (exerciseName, currentMax) in currentMaxByExercise {
            // Fetch prior set logs for this exercise, scoped to userId (T-06-02, T-06-07)
            // Exclude current session's sets by filtering sessionId != current session id
            let priorRequest = CDSetLog.fetchRequest()
            priorRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "exerciseName == %@", exerciseName),
                NSPredicate(format: "sessionId != %@", (sessionLog.id ?? UUID()) as CVarArg)
            ])

            let priorSetLogs = try viewContext.fetch(priorRequest)

            // Filter to userId-scoped sessions (T-06-02, T-06-07)
            // CDSetLog doesn't have direct userId; scope via fetching sessions for this user
            let userSessionIds = try fetchUserSessionIds(userId: effectiveUserId)
            let userScopedPriorLogs = priorSetLogs.filter { setLog in
                guard let setSessionId = setLog.sessionId else { return false }
                return userSessionIds.contains(setSessionId)
            }

            let priorMax = userScopedPriorLogs.map { Int($0.repsLogged) }.max() ?? 0

            if currentMax > priorMax {
                results.append(PRResult(
                    exerciseName: exerciseName,
                    newRecord: currentMax,
                    previousBest: priorMax
                ))
            }
        }

        return results
    }

    /// Fetch all session IDs for the given userId (used for userId scoping in detectPRs).
    private func fetchUserSessionIds(userId: String) throws -> Set<UUID> {
        let request = CDSessionLog.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.propertiesToFetch = ["id"]
        let sessions = try viewContext.fetch(request)
        return Set(sessions.compactMap { $0.id })
    }

    // MARK: - Testing Helpers

    /// For unit tests only — set cachedUserId directly without requiring AppState.
    func setUserIdForTesting(_ userId: String) {
        cachedUserId = userId
    }
}
