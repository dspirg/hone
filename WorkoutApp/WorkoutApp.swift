import SwiftUI

// MARK: - App Entry Point
// D-06, SAFE-01: Disclaimer gate fires before any content on first launch
// D-07: Hard block — user must tap "I Understand" to proceed; state in AppStorage
// AUTH-03: .onOpenURL handles workout://auth-callback for password reset deep link
// AppState drives root navigation between auth screen and main content
@main
struct WorkoutApp: App {
    @AppStorage("disclaimerAcknowledged") var disclaimerAcknowledged = false
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .fullScreenCover(isPresented: Binding(
                    get: { !disclaimerAcknowledged },
                    set: { _ in }
                )) {
                    // D-07: .interactiveDismissDisabled enforced inside DisclaimerView
                    // Parent owns the @AppStorage write — DisclaimerView is stateless
                    DisclaimerView(onAcknowledge: {
                        disclaimerAcknowledged = true
                    })
                }
                .onOpenURL { url in
                    // Pitfall 3: URL scheme workout:// registered in Info.plist CFBundleURLTypes
                    // Handles password reset callback from email link (AUTH-03)
                    Task {
                        try? await supabase.auth.session(from: url)
                    }
                }
                .task {
                    // Starts auth state listener; drives isAuthenticated throughout app lifetime
                    await appState.listenForAuthChanges()
                }
        }
    }
}

// MARK: - Root Navigation
// D-14: 3-branch routing based on isAuthenticated + onboardingCompleted:
//   Branch 1: authenticated + onboarded    -> MainTabView (normal app experience)
//   Branch 2: authenticated + not onboarded -> OnboardingFlowView (new user flow)
//   Branch 3: not authenticated             -> AuthView
// T-03-15: Both flags must be true to reach MainTabView; flag is re-fetched from Supabase
//          on every sign-in, so a client-only flag manipulation cannot persist.
struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.isAuthenticated && appState.onboardingCompleted {
            // Branch 1: Authenticated AND onboarded — normal app experience
            MainTabView()
        } else if appState.isAuthenticated && !appState.onboardingCompleted {
            // Branch 2: Authenticated but NOT onboarded — D-14 third routing branch
            Color("AppBackground")
                .ignoresSafeArea()
                .fullScreenCover(isPresented: .constant(true)) {
                    OnboardingFlowView()
                        .environment(appState)
                }
        } else {
            // Branch 3: Not authenticated — auth screen
            NavigationStack {
                AuthView()
            }
        }
    }
}

// MARK: - OnboardingFlowView
// Coordinates the full new-user flow: onboarding cards -> plan generation -> plan preview.
// Presented as a fullScreenCover from ContentView Branch 2.
//
// Flow:
//   1. OnboardingView (5 cards) — user answers goal, fitness level, days, equipment, injuries
//   2. onComplete fires with UserProfile -> showPlanPreview = true
//   3. PlanPreviewView appears; .onAppear calls viewModel.startGeneration()
//      - startGeneration() saves profile to Supabase then starts SSE stream
//   4. Loading screen with pulsing rings + cycling text
//   5. Plan preview with day cards + AI rationale + regenerate button
//   6. User taps "Start Training" -> planService.resetRegenerationCounter() + appState.markOnboardingComplete()
//   7. ContentView re-evaluates: isAuthenticated && onboardingCompleted -> MainTabView
struct OnboardingFlowView: View {
    @Environment(AppState.self) var appState
    @State private var planService = PlanGenerationService()
    @State private var showPlanPreview = false
    @State private var userProfile: UserProfile?

    var body: some View {
        if showPlanPreview, let profile = userProfile {
            PlanPreviewView(
                viewModel: PlanPreviewViewModel(service: planService, profile: profile),
                onStartTraining: {
                    // PlanGenerationService already set onboarding_completed = true in Supabase
                    // (Pitfall 4 strict ordering in Plan 03 — profiles update is Step 3 after plan persistence).
                    // Now update local AppState to trigger ContentView routing change.
                    planService.resetRegenerationCounter()
                    appState.markOnboardingComplete()
                    // ContentView re-evaluates: isAuthenticated && onboardingCompleted -> MainTabView
                }
            )
        } else {
            OnboardingView(onComplete: { profile in
                userProfile = profile
                showPlanPreview = true
                // Plan generation starts automatically via PlanPreviewView.onAppear -> viewModel.startGeneration()
            })
        }
    }
}
