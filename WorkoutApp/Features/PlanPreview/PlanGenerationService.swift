import Foundation

// MARK: - GenerationState
// Represents the state of AI plan generation.
// This file is a STUB for plan 03-04 compilation.
// The full implementation is provided by plan 03-03 (PlanGenerationService).
// When the worktrees are merged, this stub will be replaced by the 03-03 implementation.

enum GenerationState: Equatable {
    case idle
    case streaming(partialText: String)
    case completed(WorkoutPlan)
    case error(String)
}

// MARK: - PlanGenerationService (Stub)
// Full implementation lives in 03-03. This stub allows 03-04 UI to compile.

@Observable
@MainActor
final class PlanGenerationService {
    var state: GenerationState = .idle

    // Tracks how many regenerations the user has used (stored in UserDefaults)
    @AppStorage("regenCountUsed") private var regenCountUsed: Int = 0
    private let maxRegenerations = 3

    var regenerationsRemaining: Int {
        max(0, maxRegenerations - regenCountUsed)
    }

    var canRegenerate: Bool {
        regenerationsRemaining > 0
    }

    /// Starts plan generation (initial or retry after error).
    func generatePlan(profile: UserProfile, isRetry: Bool = false) {
        // Stub: full SSE streaming implementation in 03-03
        state = .idle
    }

    /// Counts as one regeneration against the user's cap (D-09).
    func regeneratePlan(profile: UserProfile) {
        guard canRegenerate else { return }
        regenCountUsed += 1
        generatePlan(profile: profile)
    }

    /// Persists the user profile to Supabase before generation.
    func saveProfile(_ profile: UserProfile) async throws {
        // Stub: full implementation in 03-03
    }
}
