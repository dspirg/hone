import Foundation

// MARK: - PlanPreviewViewModel
// Thin ViewModel bridging PlanGenerationService state to UI-friendly computed properties.
// Consumed by PlanPreviewView. PlanPreviewView is the "aha moment" screen where the user
// sees their personalized workout plan before being asked to subscribe (Phase 7).
//
// Requirements: ONBD-03 (post-onboarding plan preview), AIPL-02 (AI rationale display),
//               AIPL-03 (regeneration with counter)

@Observable
@MainActor
final class PlanPreviewViewModel {
    let service: PlanGenerationService
    private(set) var userProfile: UserProfile

    init(service: PlanGenerationService, profile: UserProfile) {
        self.service = service
        self.userProfile = profile
    }

    // MARK: - Computed Properties for UI Binding

    /// True when service is in .idle or .streaming state (generation not yet complete).
    var isLoading: Bool {
        switch service.state {
        case .idle, .streaming:
            return true
        default:
            return false
        }
    }

    /// The completed workout plan, or nil if not yet available.
    var plan: WorkoutPlan? {
        if case .completed(let plan) = service.state { return plan }
        return nil
    }

    /// Partial streaming text while the AI is generating.
    var streamingText: String {
        if case .streaming(let text) = service.state { return text }
        return ""
    }

    /// Error message if generation failed, nil otherwise.
    var errorMessage: String? {
        if case .error(let msg) = service.state { return msg }
        return nil
    }

    /// True only during active streaming (plan loading but tokens arriving).
    var isStreaming: Bool {
        if case .streaming = service.state { return true }
        return false
    }

    /// How many regenerations the user has remaining (max 3, from AppStorage counter).
    var regenerationsRemaining: Int { service.regenerationsRemaining }

    /// True when user can tap Regenerate: counter > 0 AND not currently streaming (D-09).
    /// Threat T-03-13: Button disabled during streaming prevents regeneration spam.
    var canRegenerate: Bool { service.canRegenerate && !isStreaming }

    /// True when Start Training CTA should be enabled: plan is loaded and not mid-stream.
    var canStartTraining: Bool { plan != nil && !isStreaming }

    // MARK: - Actions

    /// Saves the user profile, then starts plan generation.
    /// Called from PlanPreviewView.onAppear when plan is nil and no error exists.
    func startGeneration() {
        Task {
            try? await service.saveProfile(userProfile)
            service.generatePlan(profile: userProfile)
        }
    }

    /// Triggers a regeneration (consumes one from the counter).
    func regenerate() {
        service.regeneratePlan(profile: userProfile)
    }

    /// Retries generation after an error (does NOT consume a regeneration counter slot).
    func retry() {
        service.generatePlan(profile: userProfile)
    }
}
