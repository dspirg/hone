import Foundation
import Observation
import CoreData

// MARK: - HomeViewModel
// Observable ViewModel for the Home screen (Plan 02 full rebuild).
// Loads active plan + session stats in parallel on .task.
// Computes real PR count from CDSetLog history per D-05.
//
// Threat mitigations:
//   T-11-03: All CDSessionLog fetches include userId == %@ predicate — no cross-user data leakage.
//   T-11-04: Session launch reuses existing AppState auth guard — no new auth surface.
//
// Requirements: UI-04

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - State

    var activePlan: WorkoutPlan? = nil
    /// supabaseId of the active CDWorkoutPlan — used as planId when launching SessionView.
    var activePlanId: String = ""
    var todayWorkoutDay: WorkoutDay? = nil
    var completedDatesThisWeek: Set<Date> = []
    var currentStreak: Int = 0
    var totalSessions: Int = 0
    var totalSets: Int = 0
    var totalPRs: Int = 0
    var adaptationBanner: String? = nil
    var isLoading: Bool = true
    var loadError: String? = nil
    var showSession: Bool = false

    // MARK: - Load

    func load(appState: AppState, adaptationService: AdaptationService, context: NSManagedObjectContext) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        guard let userId = appState.currentUser?.id.uuidString else { return }

        do {
            // Parallel fetch: plan + stats
            async let planResult = loadPlan(userId: userId, context: context)
            async let statsResult = loadStats(userId: userId, context: context)
            let (planTuple, stats) = try await (planResult, statsResult)

            activePlan = planTuple.plan
            activePlanId = planTuple.supabaseId
            todayWorkoutDay = resolveTodayWorkoutDay(from: planTuple.plan)
            completedDatesThisWeek = stats.completedDates
            currentStreak = stats.streak
            totalSessions = stats.sessionCount
            totalSets = stats.totalSets
            totalPRs = stats.prCount

            // Adaptation banner — only show if within 24 hours (RESEARCH Pitfall 5, UI-SPEC line 286)
            if let date = adaptationService.lastAdjustmentDate,
               Date().timeIntervalSince(date) < 86400,
               let summary = adaptationService.lastAdjustmentSummary {
                adaptationBanner = summary
            } else {
                adaptationBanner = nil
            }
        } catch {
            loadError = "Couldn't load your workout"
        }
    }

    // MARK: - Time of Day Greeting

    var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"   // extend to 10 PM (22:00)
        default:      return "Good night"
        }
    }

    // MARK: - Private Helpers

    private func loadPlan(userId: String, context: NSManagedObjectContext) throws -> (plan: WorkoutPlan?, supabaseId: String) {
        let repo = WorkoutPlanRepository(context: context)
        let plan = try repo.fetchActivePlan(userId: userId)

        // Fetch supabaseId from CDWorkoutPlan — needed as planId when launching SessionView
        // (mirrors TrainView.loadActivePlan pattern)
        let cdReq = CDWorkoutPlan.fetchRequest()
        cdReq.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
        cdReq.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        cdReq.fetchLimit = 1
        let supabaseId = (try? context.fetch(cdReq).first?.supabaseId) ?? ""

        return (plan: plan, supabaseId: supabaseId)
    }

    private func loadStats(userId: String, context: NSManagedObjectContext) throws -> HomeStats {
        let calendar = Calendar.current

        // T-11-03: userId predicate prevents cross-user data leakage
        let request = CDSessionLog.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND completedAt != nil", userId)
        let sessions = try context.fetch(request)

        // Completed dates this week
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date())
        let thisWeekSessions = sessions.filter { s in
            guard let date = s.completedAt, let interval = weekInterval else { return false }
            return interval.contains(date)
        }
        let completedDates = Set(thisWeekSessions.compactMap { s in
            s.completedAt.map { calendar.startOfDay(for: $0) }
        })

        // Streak computation (mirrors ProgressViewModel.computeStreak)
        let uniqueDays = sessions
            .compactMap { $0.completedAt }
            .map { calendar.startOfDay(for: $0) }
        let sortedDays = Set(uniqueDays).sorted(by: >)
        var streak = 0
        if !sortedDays.isEmpty {
            let today = calendar.startOfDay(for: Date())
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            // Only count streak if most recent day is today or yesterday
            if sortedDays[0] == today || sortedDays[0] == yesterday {
                streak = 1
                for i in 1..<sortedDays.count {
                    let diff = calendar.dateComponents([.day], from: sortedDays[i], to: sortedDays[i - 1]).day ?? 0
                    if diff == 1 {
                        streak += 1
                    } else {
                        break
                    }
                }
            }
        }

        // Total sets from CDSessionLog.totalSets (denormalized aggregate, written by SessionRepository)
        let totalSets = sessions.reduce(0) { $0 + Int($1.totalSets) }

        // PR count per D-05 — count sessions where user achieved at least one personal record.
        // Uses same pattern as ProgressViewModel.detectPRs (PATTERNS.md):
        // Group CDSetLog by exerciseName, compare max reps per exercise across sessions chronologically.
        // T-11-03: filter to user's sessions via userId predicate on CDSessionLog first.
        let userSessionIds = Set(sessions.compactMap { $0.id })

        // T-11-03: scope CDSetLog fetch to user's session IDs at the CoreData layer —
        // avoids loading all users' set data into memory (mirrors SessionRepository.fetchBestReps).
        let setRequest = CDSetLog.fetchRequest()
        setRequest.predicate = NSPredicate(
            format: "sessionId IN %@", userSessionIds as CVarArg
        )
        let userSets = try context.fetch(setRequest)

        // Build per-session, per-exercise max reps
        var sessionExerciseMax: [UUID: [String: Int]] = [:]
        for setLog in userSets {
            guard let name = setLog.exerciseName, let sid = setLog.sessionId else { continue }
            let reps = Int(setLog.repsLogged)
            sessionExerciseMax[sid, default: [:]][name] = max(sessionExerciseMax[sid]?[name] ?? 0, reps)
        }

        // Process sessions chronologically to detect PRs
        let sortedSessionIds = sessions
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
            .compactMap { $0.id }

        var bestByExercise: [String: Int] = [:]
        var prSessionIds: Set<UUID> = []
        for sid in sortedSessionIds {
            guard let exerciseMaxes = sessionExerciseMax[sid] else { continue }
            for (name, maxReps) in exerciseMaxes {
                if let prior = bestByExercise[name], maxReps > prior {
                    prSessionIds.insert(sid)
                }
                bestByExercise[name] = max(bestByExercise[name] ?? 0, maxReps)
            }
        }
        let prCount = prSessionIds.count

        return HomeStats(
            completedDates: completedDates,
            streak: streak,
            sessionCount: sessions.count,
            totalSets: totalSets,
            prCount: prCount
        )
    }

    private func resolveTodayWorkoutDay(from plan: WorkoutPlan?) -> WorkoutDay? {
        guard let plan = plan else { return nil }
        let calendar = Calendar.current
        let todayIndex = calendar.component(.weekday, from: Date())
        // Map weekday index (1=Sunday) to day labels — find matching day
        let dayLabels = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayLabel = dayLabels[todayIndex - 1]
        return plan.weeklyDays.first { $0.dayLabel.lowercased() == todayLabel.lowercased() }
            ?? plan.weeklyDays.first  // Fallback to first day if no match for today
    }
}

// MARK: - HomeStats (private value type)

private struct HomeStats {
    let completedDates: Set<Date>
    let streak: Int
    let sessionCount: Int
    let totalSets: Int
    let prCount: Int
}
