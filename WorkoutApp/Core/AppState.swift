import Foundation
import Observation
import Supabase

// MARK: - AppState
// Observable root state driving auth routing — @Observable macro (Swift 6 / iOS 17+ idiom)
// Not @ObservableObject — uses Observation framework for finer-grained invalidation
@Observable
@MainActor
final class AppState {
    var isAuthenticated: Bool = false
    var currentUser: User? = nil
    var showPasswordResetForm: Bool = false

    // D-14: Onboarding completion flag — fetched from Supabase profiles on every sign-in.
    // Drives ContentView third routing branch:
    //   authenticated + !onboardingCompleted -> OnboardingFlowView
    //   authenticated + onboardingCompleted  -> MainTabView
    // Reset on sign-out so return visits re-fetch from server (T-03-15).
    var onboardingCompleted: Bool = false

    // MARK: - Auth State Listener
    // Subscribes to Supabase authStateChanges AsyncStream
    // Drives root navigation: auth screen vs. main tab bar
    func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                self.isAuthenticated = session != nil
                self.currentUser = session?.user
                // Fetch onboarding flag from server whenever a session is established.
                // T-03-15: Every sign-in re-fetches the flag — prevents stale local state.
                if session != nil {
                    await fetchOnboardingStatus()
                }
            case .signedOut:
                self.isAuthenticated = false
                self.currentUser = nil
                // T-03-14: Reset local flag on sign-out so it cannot be spoofed across sessions.
                self.onboardingCompleted = false
            case .passwordRecovery:
                // AUTH-03: deep link callback triggers password reset form
                self.showPasswordResetForm = true
            default:
                break
            }
        }
    }

    // MARK: - Onboarding Flag

    /// Fetches onboarding_completed from Supabase profiles table.
    /// Called after every successful sign-in / session refresh event.
    /// Defaults to false on any error — safe fallback sends user through onboarding.
    private func fetchOnboardingStatus() async {
        guard let userId = currentUser?.id else { return }
        do {
            struct ProfileRow: Decodable {
                let onboarding_completed: Bool
            }
            let response: ProfileRow = try await supabase
                .from("profiles")
                .select("onboarding_completed")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            self.onboardingCompleted = response.onboarding_completed
        } catch {
            // Default to false on error — user will see onboarding (safe fallback).
            // T-03-14: Client cannot bypass onboarding by corrupting the local flag;
            // the flag resets to false on any fetch failure and is re-fetched on next sign-in.
            self.onboardingCompleted = false
        }
    }

    /// Updates the local onboarding flag after the user taps "Start Training".
    /// PlanGenerationService has already written onboarding_completed = true to Supabase
    /// (Pitfall 4 strict ordering in Plan 03) before this is called.
    func markOnboardingComplete() {
        self.onboardingCompleted = true
    }

    // MARK: - Exercise / Train State (Phase 2)

    /// Set of exercise UUIDs that belong to the user's active workout plan.
    /// Used by ExerciseCacheManager to prioritise caching plan exercises over recently-viewed ones.
    /// Populated when the active plan is loaded; cleared on sign-out.
    var activePlanExerciseIDs: Set<UUID> = []
}
