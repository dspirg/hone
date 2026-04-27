import Foundation
import Observation
import Supabase
import CoreData

// MARK: - AdaptationService
// iOS client for adapt-plan and regenerate-plan Supabase Edge Functions.
// Injected via @Environment at MainTabView level (same pattern as SessionSyncService).
//
// Auth: Uses supabase.auth.session to get Bearer token — same pattern as PlanSSEClient
// and CoachSSEClient (Supabase Swift SDK issue #634 requires manual auth headers).
//
// Threat mitigations:
//   T-08-11: Bearer token fetched from supabase.auth.session (not from binary) on every call.
//   T-08-12: Weekly regen gated by ISO week key; missed session detection is pure local compute.
//
// Requirements: ADPT-01 (post-session), ADPT-02 (weekly regen), ADPT-03 (missed sessions)

@Observable
@MainActor
final class AdaptationService {

    // MARK: - State

    /// The most recent adjustment summary text — shown in TrainView (D-05).
    var lastAdjustmentSummary: String? = nil

    /// The date of the most recent adaptation — used by HomeView to check if adaptation
    /// occurred within the last 24 hours (UI-SPEC line 286, RESEARCH Pitfall 5).
    /// Set alongside lastAdjustmentSummary in all three adaptation paths.
    var lastAdjustmentDate: Date? = nil

    // MARK: - Private

    private let supabaseURL: String
    private let supabaseAnonKey: String

    // ISO week key to prevent duplicate Monday regeneration calls (T-08-12).
    // Format: "YYYY-Www" e.g. "2026-W17" — unique per user session since service is @MainActor.
    private var lastWeeklyCheckKey: String = ""
    // In-progress guard — prevents a second Task created from rapid scenePhase .active transitions
    // from issuing a second weekly regen call even if lastWeeklyCheckKey is set before the first await.
    private var isWeeklyCheckInProgress: Bool = false

    // MARK: - Init

    init() {
        // SUPABASE_URL and SUPABASE_ANON_KEY read from Info.plist (set via xcconfig in Phase 1).
        // Never hard-coded — same constraint as PlanSSEClient.
        self.supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        self.supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    // MARK: - Post-Session Adaptation (ADPT-01)

    /// Called after session completion + rating capture.
    /// Sends the difficulty rating to adapt-plan for immediate next-session adjustment (D-03).
    func requestPostSessionAdaptation(rating: DifficultyRating) async {
        do {
            let accessToken = try await fetchAccessToken()
            let body = AdaptPlanRequest(
                triggerType: "post_session",
                currentRating: rating.rawValue,
                missedSessions: nil
            )
            let response = try await callEdgeFunction(
                path: "adapt-plan",
                body: body,
                accessToken: accessToken
            )
            lastAdjustmentSummary = response.adjustmentSummary
            lastAdjustmentDate = Date()
            let userId = try await supabase.auth.session.user.id.uuidString
            await persistAdaptedPlan(response, userId: userId)
            await scheduleReminders(for: response)
        } catch {
            // Non-fatal: adaptation is best-effort. Log for diagnostics.
            print("AdaptationService: post-session adaptation failed: \(error)")
        }
    }

    // MARK: - Missed Session Adaptation (ADPT-03)

    /// Called when missed sessions are detected on app foreground (D-07).
    /// Redistributes missed day's exercises across remaining days.
    func requestMissedSessionAdaptation(missedDays: [String]) async {
        guard !missedDays.isEmpty else { return }
        do {
            let accessToken = try await fetchAccessToken()
            let body = AdaptPlanRequest(
                triggerType: "missed_session",
                currentRating: nil,
                missedSessions: missedDays
            )
            let response = try await callEdgeFunction(
                path: "adapt-plan",
                body: body,
                accessToken: accessToken
            )
            lastAdjustmentSummary = response.adjustmentSummary
            lastAdjustmentDate = Date()
            let userId = try await supabase.auth.session.user.id.uuidString
            await persistAdaptedPlan(response, userId: userId)
            await scheduleReminders(for: response)
        } catch {
            print("AdaptationService: missed session adaptation failed: \(error)")
        }
    }

    // MARK: - Weekly Regeneration (ADPT-02)

    /// Called on Monday morning app foreground (D-04).
    /// AI reviews last 2–4 weeks and regenerates the full plan.
    func requestWeeklyRegeneration() async {
        do {
            let accessToken = try await fetchAccessToken()
            let response = try await callEdgeFunction(
                path: "regenerate-plan",
                body: AdaptPlanRequest(
                    triggerType: "weekly",
                    currentRating: nil,
                    missedSessions: nil
                ),
                accessToken: accessToken
            )
            lastAdjustmentSummary = response.adjustmentSummary
            lastAdjustmentDate = Date()
        } catch {
            print("AdaptationService: weekly regeneration failed: \(error)")
        }
    }

    // MARK: - Foreground Check (D-04, D-07)

    /// Run on every app foreground (scenePhase == .active).
    /// - Triggers weekly regen on Monday, once per ISO week (T-08-12 dedup).
    /// - Detects missed sessions and triggers adaptation if any found.
    ///
    /// - Parameters:
    ///   - activePlanDayLabels: Day labels from the user's active plan (e.g. ["Monday", "Wednesday"])
    ///   - completedSessions: All CDSessionLog records for missed-session computation
    func checkOnForeground(
        activePlanDayLabels: [String],
        completedSessions: [CDSessionLog]
    ) async {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let isoWeekKey = isoWeekString(for: today)

        // Weekly regeneration — Monday (weekday 2) only, once per ISO week.
        // isWeeklyCheckInProgress provides an extra guard against reentrant calls from rapid
        // scenePhase .active transitions (two Tasks on @MainActor can interleave across await).
        if weekday == 2 && isoWeekKey != lastWeeklyCheckKey && !isWeeklyCheckInProgress {
            isWeeklyCheckInProgress = true
            lastWeeklyCheckKey = isoWeekKey
            await requestWeeklyRegeneration()
            isWeeklyCheckInProgress = false
        }

        // Missed session detection — pure local compute, then network call only if needed
        let missedDays = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: activePlanDayLabels,
            completedSessions: completedSessions,
            today: today,
            calendar: calendar
        )
        // FIX-02: Convert day-label strings to ISO dates before sending to Edge Function (per D-03, D-04, D-05)
        let missedIsoDates = missedDays.compactMap {
            MissedSessionDetector.isoDateString(for: $0, relativeTo: today, calendar: calendar)
        }
        if !missedIsoDates.isEmpty {
            await requestMissedSessionAdaptation(missedDays: missedIsoDates)
        }

        // Re-engagement notification: schedule if 2+ consecutive missed sessions (D-08, ADPT-03)
        if missedDays.count >= 2 {
            await NotificationScheduler.shared.scheduleReengagementNotificationIfNeeded(
                missedSessionCount: missedDays.count
            )
        }
    }

    // MARK: - Private Helpers

    /// Fetches the current session access token from Supabase auth.
    /// Throws if no valid session exists.
    /// Pattern: same as PlanSSEClient and CoachSSEClient (SDK issue #634 workaround).
    private func fetchAccessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }

    /// POSTs to a Supabase Edge Function with Bearer auth and returns the decoded response.
    private func callEdgeFunction<T: Encodable>(
        path: String,
        body: T,
        accessToken: String
    ) async throws -> AdaptedPlanResponse {
        guard let url = URL(string: "\(supabaseURL)/functions/v1/\(path)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // CRITICAL: Manual auth headers — SDK streaming path drops JWT (issue #634).
        // Same pattern as PlanSSEClient and CoachSSEClient.
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("AdaptationService: \(path) returned HTTP \(statusCode)")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AdaptedPlanResponse.self, from: data)
    }

    /// Computes an ISO week string (e.g. "2026-W17") for deduplication of weekly checks.
    private func isoWeekString(for date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    // MARK: - FIX-01: Persist Adapted Plan to CoreData

    /// Persists an adapted plan response to CoreData, replacing the current active plan.
    /// Maps AdaptedPlanResponse -> WorkoutPlan using 1:1 field mapping (per D-01, D-02).
    /// Uses the existing active plan's name/goalSummary for continuity; falls back to defaults.
    /// Non-fatal: errors are logged but do not interrupt the adaptation flow (best-effort).
    /// Threat: T-09-01 — uses WorkoutPlanRepository.save() which enforces Int16 clamping.
    private func persistAdaptedPlan(_ response: AdaptedPlanResponse, userId: String) async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let repo = WorkoutPlanRepository(context: context)

            // Preserve name/goalSummary from current active plan for continuity
            let existingPlan = try repo.fetchActivePlan(userId: userId)
            let planName = existingPlan?.planName ?? "Adapted Plan"
            let goalSummary = existingPlan?.goalSummary ?? ""

            // Map AdaptedDay -> WorkoutDay and AdaptedExercise -> PlannedExercise (1:1 field mapping)
            let weeklyDays: [WorkoutDay] = response.weeklyDays.map { adaptedDay in
                let exercises: [PlannedExercise] = adaptedDay.exercises.map { adaptedExercise in
                    PlannedExercise(
                        exerciseName: adaptedExercise.exerciseName,
                        sets: adaptedExercise.sets,
                        reps: adaptedExercise.reps,
                        restSeconds: adaptedExercise.restSeconds,
                        rationale: adaptedExercise.rationale
                    )
                }
                return WorkoutDay(
                    dayLabel: adaptedDay.dayLabel,
                    sessionName: adaptedDay.sessionName,
                    exercises: exercises
                )
            }

            let updatedPlan = WorkoutPlan(
                planName: planName,
                goalSummary: goalSummary,
                weeklyDays: weeklyDays
            )

            // Exact pattern from CoachViewModel.applyPlanUpdate() lines 411-427
            try repo.deactivateAllPlans(userId: userId)
            try repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)
        } catch {
            // Non-fatal: best-effort persistence; adaptation summary still displayed
            print("AdaptationService: persistAdaptedPlan failed: \(error)")
        }
    }

    // MARK: - FIX-03: Schedule Workout Reminders After Adaptation

    /// Schedules workout reminders based on the adapted plan's weekly days (per D-06, D-07, D-08).
    /// Cancel+reschedule is handled internally by NotificationScheduler.scheduleWorkoutReminders.
    /// Call sites are inside service (not view layer) per D-08.
    private func scheduleReminders(for response: AdaptedPlanResponse) async {
        let dayOfWeekMap: [String: Int] = [
            "Sunday": 1, "Monday": 2, "Tuesday": 3,
            "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7
        ]
        let planDays: [(weekday: Int, workoutType: String)] = response.weeklyDays.compactMap { day in
            guard let weekday = dayOfWeekMap[day.dayLabel] else { return nil }
            return (weekday: weekday, workoutType: day.sessionName)
        }
        await NotificationScheduler.shared.scheduleWorkoutReminders(
            planDays: planDays,
            currentStreak: 0  // Streak not available in service; 0 produces standard notification copy
        )
    }
}
