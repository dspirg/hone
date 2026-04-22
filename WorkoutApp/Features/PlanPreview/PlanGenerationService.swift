import Foundation
import Supabase
import SwiftUI  // for @AppStorage

// MARK: - Generation State
// Represents the current state of plan generation in the UI state machine.
enum GenerationState: Equatable {
    case idle
    case streaming(partialText: String)
    case completed(WorkoutPlan)
    case error(String)

    static func == (lhs: GenerationState, rhs: GenerationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.streaming(let a), .streaming(let b)): return a == b
        case (.completed(let a), .completed(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - PlanGenerationService
// Orchestrates the full plan generation lifecycle:
//   1. Profile UPSERT to Supabase profiles table
//   2. SSE streaming via PlanSSEClient (manual JWT auth, bypasses SDK bug #634)
//   3. JSON parsing on [DONE] event ONLY (never during streaming — Pitfall 3)
//   4. Persistence in strict sequential order (Pitfall 4):
//      a. Supabase workout_plans INSERT
//      b. CoreData save via WorkoutPlanRepository
//      c. profiles.onboarding_completed = true
//   5. Silent auto-retry once on first failure (D-16)
//   6. Regeneration counter management via @AppStorage (D-09, Pitfall 6)
//
// Security: T-03-08 — JWT auth delegated to PlanSSEClient which uses manual URLRequest.
@Observable
@MainActor
final class PlanGenerationService {
    var state: GenerationState = .idle

    // D-09: 3 free regenerations during onboarding.
    // PITFALL 6: @AppStorage persists across ViewModel recreation when user backgrounds the app.
    // Without @AppStorage, regenCountUsed resets to 0 on every ViewModel init,
    // allowing unlimited regenerations by backgrounding and returning.
    // @ObservationIgnored prevents @Observable from double-tracking @AppStorage property.
    @ObservationIgnored
    @AppStorage("regenCountUsed") private var regenCountUsed: Int = 0

    var regenerationsRemaining: Int {
        max(0, 3 - regenCountUsed)
    }

    var canRegenerate: Bool {
        regenerationsRemaining > 0
    }

    private let sseClient = PlanSSEClient()

    // Lazy-initialized to avoid forcing @MainActor constraints at init time.
    @ObservationIgnored private var repository: WorkoutPlanRepository?

    // Track current stream task so it can be cancelled on regeneration.
    @ObservationIgnored private var currentStreamTask: Task<Void, Never>?

    // MARK: - Plan Generation

    /// Generate a plan from the user profile.
    ///
    /// D-16: Auto-retries once silently on first failure. Shows error only on second failure.
    ///
    /// PITFALL 4: Persistence order is strictly sequential:
    ///   1. Write plan to Supabase `workout_plans` table
    ///   2. Write plan to CoreData via WorkoutPlanRepository
    ///   3. Set `profiles.onboarding_completed = true`
    /// Never use concurrent `async let` for these — sequential `await` only.
    func generatePlan(profile: UserProfile, isRetry: Bool = false) {
        currentStreamTask?.cancel()
        state = .streaming(partialText: "")

        currentStreamTask = Task {
            do {
                var accumulatedText = ""

                for try await event in sseClient.streamPlan(profile: profile) {
                    if Task.isCancelled { return }

                    switch event {
                    case .token(let chunk):
                        accumulatedText += chunk
                        state = .streaming(partialText: accumulatedText)

                    case .completed(let fullJSON):
                        // Parse complete JSON into WorkoutPlan.
                        // PITFALL 3: This only runs after [DONE] — never during streaming.
                        guard let jsonData = fullJSON.data(using: .utf8) else {
                            throw PlanSSEError.decodingFailed(
                                underlying: NSError(
                                    domain: "PlanGenerationService",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "UTF-8 conversion failed on completed JSON"]
                                )
                            )
                        }
                        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: jsonData)

                        // PERSIST — strict sequential order per Pitfall 4.
                        // Step 1: Write plan to Supabase workout_plans table.
                        let supabaseId = try await savePlanToSupabase(plan: plan, profile: profile)

                        // Step 2: Write plan to CoreData.
                        let userId = try await supabase.auth.session.user.id.uuidString
                        let repo = getRepository()
                        try repo.deactivateAllPlans(userId: userId)
                        try repo.save(plan: plan, supabaseId: supabaseId, userId: userId)

                        // Step 3: Set onboarding_completed = true AFTER plan persistence completes.
                        try await setOnboardingCompleted()

                        state = .completed(plan)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                print("🔴 PlanGenerationService error (isRetry=\(isRetry)): \(error)")

                // D-16: Silent auto-retry once on first failure.
                // isRetry=false -> fires retry silently (user sees no error).
                // isRetry=true -> second failure, show error to user.
                //
                // WR-01: Wrap the retry in a new Task so it starts after this task's
                // catch block fully unwinds. A direct recursive call would overwrite
                // currentStreamTask while the current Task is still on the call stack,
                // making it impossible to cancel the old task and allowing two concurrent
                // streaming tasks to write to state simultaneously.
                if !isRetry {
                    Task { self.generatePlan(profile: profile, isRetry: true) }
                } else {
                    state = .error("Something went wrong generating your plan. Please try again.")
                }
            }
        }
    }

    // MARK: - Regeneration

    /// Regenerate the plan. Decrements counter per D-09. Blocked when counter reaches 0.
    /// PITFALL 6: Counter is @AppStorage — survives ViewModel recreation across app backgrounding.
    func regeneratePlan(profile: UserProfile) {
        guard canRegenerate else { return }
        regenCountUsed += 1
        generatePlan(profile: profile)
    }

    // MARK: - Profile Save

    /// Save user profile to Supabase profiles table.
    /// Called before plan generation starts to persist the onboarding answers.
    func saveProfile(_ profile: UserProfile) async throws {
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("profiles")
            .update([
                "goal": AnyJSON.string(profile.goal),
                "fitness_level": AnyJSON.string(profile.fitnessLevel),
                "days_per_week": AnyJSON.integer(profile.daysPerWeek),
                "equipment": AnyJSON.array(profile.equipment.map { AnyJSON.string($0) }),
                "injuries": AnyJSON.string(profile.injuries)
            ])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Counter Reset

    /// Reset regeneration counter after onboarding completes.
    /// Prevents stale count if user repeats onboarding flow.
    func resetRegenerationCounter() {
        regenCountUsed = 0
    }

    // MARK: - Private Helpers

    private func getRepository() -> WorkoutPlanRepository {
        if let repo = repository { return repo }
        let repo = WorkoutPlanRepository()
        repository = repo
        return repo
    }

    /// Inserts the plan into Supabase workout_plans and returns the new row's UUID string.
    /// Deactivates existing active plans first to maintain the single-active-plan invariant.
    private func savePlanToSupabase(plan: WorkoutPlan, profile: UserProfile) async throws -> String {
        let userId = try await supabase.auth.session.user.id

        // Deactivate existing active plans for this user before inserting
        try await supabase
            .from("workout_plans")
            .update(["is_active": AnyJSON.bool(false)])
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Encode the full plan JSON for the plan_json column (raw storage)
        let planJSON = try JSONEncoder().encode(plan)
        let planJSONString = String(data: planJSON, encoding: .utf8) ?? "{}"

        // Insert new plan row
        struct PlanRow: Encodable {
            let user_id: String
            let plan_name: String
            let goal_summary: String
            let plan_json: String
            let days_per_week: Int
            let is_active: Bool
        }

        let row = PlanRow(
            user_id: userId.uuidString,
            plan_name: plan.planName,
            goal_summary: plan.goalSummary,
            plan_json: planJSONString,
            days_per_week: profile.daysPerWeek,
            is_active: true
        )

        let response = try await supabase
            .from("workout_plans")
            .insert(row)
            .select("id")
            .single()
            .execute()

        // Extract the UUID of the inserted row.
        // CR-03: Do NOT fall back to a random UUID — a phantom ID breaks plan management
        // (update/delete by supabaseId) and corrupts CoreData linkage silently.
        // Let the decode error propagate so the caller's retry path handles it.
        struct InsertResult: Decodable { let id: String }
        let result = try JSONDecoder().decode(InsertResult.self, from: response.data)
        return result.id
    }

    /// Sets onboarding_completed = true on the profiles table.
    /// Called AFTER plan persistence is complete (Step 3 of Pitfall 4 sequence).
    private func setOnboardingCompleted() async throws {
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("profiles")
            .update(["onboarding_completed": AnyJSON.bool(true)])
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
