import Foundation
import Observation
import Supabase

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

    // MARK: - Private

    private let supabaseURL: String
    private let supabaseAnonKey: String

    // ISO week key to prevent duplicate Monday regeneration calls (T-08-12).
    // Format: "YYYY-Www" e.g. "2026-W17" — unique per user session since service is @MainActor.
    private var lastWeeklyCheckKey: String = ""

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

        // Weekly regeneration — Monday (weekday 2) only, once per ISO week
        if weekday == 2 && isoWeekKey != lastWeeklyCheckKey {
            lastWeeklyCheckKey = isoWeekKey
            await requestWeeklyRegeneration()
        }

        // Missed session detection — pure local compute, then network call only if needed
        let missedDays = MissedSessionDetector.detectMissedSessions(
            activePlanDayLabels: activePlanDayLabels,
            completedSessions: completedSessions,
            today: today,
            calendar: calendar
        )
        if !missedDays.isEmpty {
            await requestMissedSessionAdaptation(missedDays: missedDays)
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
}
