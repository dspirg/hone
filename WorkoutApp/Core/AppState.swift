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

    // MARK: - Phase 7: Subscription State
    // isSubscribed reflects the "pro" entitlement from RevenueCat (D-18).
    // Drives the fullScreenCover paywall gate in ContentView (D-13 hard paywall).
    // Source of truth: RevenueCat customerInfo.entitlements["pro"]?.isActive
    // Set to false by default — paywall shows until subscription confirmed (safe default, T-07-01)
    #if DEBUG
    var isSubscribed: Bool = true  // Bypass paywall in debug builds for testing
    #else
    var isSubscribed: Bool = false
    #endif

    // isOnboarded mirrors onboardingCompleted for SUBS-03 compatibility.
    // Phase 3 populates this; Phase 7 gates paywall on authenticated + onboarded + !isSubscribed
    var isOnboarded: Bool = false

    // Dependency-injected RevenueCat service. Replaced with MockRevenueCatService in tests.
    var revenueCatService: RevenueCatServiceProtocol = RevenueCatService()

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
                // CRITICAL: logIn with Supabase UUID immediately after auth resolves (D-18, RESEARCH Pitfall 1)
                // Without this, ALL webhook payloads contain $RCAnonymousID, breaking
                // the revenuecat-webhook -> profiles.subscription_status pipeline entirely
                if let userId = session?.user.id.uuidString {
                    #if DEBUG
                    _ = try? await revenueCatService.logIn(userId: userId)
                    self.isSubscribed = true  // Bypass paywall in debug builds
                    #else
                    let subscribed = (try? await revenueCatService.logIn(userId: userId)) ?? false
                    self.isSubscribed = subscribed
                    #endif
                }
            case .signedOut:
                self.isAuthenticated = false
                self.currentUser = nil
                // T-03-14: Reset local flag on sign-out so it cannot be spoofed across sessions.
                self.onboardingCompleted = false
                // Clear subscription state and RC identity on sign-out
                try? await revenueCatService.logOut()
                self.isSubscribed = false
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
        self.isOnboarded = true
    }

    // MARK: - Phase 7: Entitlement Refresh

    /// Re-fetches the current entitlement state from RevenueCat.
    /// Called after a successful purchase to dismiss the paywall.
    /// Also called on foreground resume to catch server-side subscription changes.
    func refreshEntitlements() async {
        let subscribed = await revenueCatService.refreshEntitlements()
        self.isSubscribed = subscribed
    }

    // MARK: - Exercise / Train State (Phase 2)

    /// Set of exercise UUIDs that belong to the user's active workout plan.
    /// Used by ExerciseCacheManager to prioritise caching plan exercises over recently-viewed ones.
    /// Populated when the active plan is loaded; cleared on sign-out.
    var activePlanExerciseIDs: Set<UUID> = []
}
