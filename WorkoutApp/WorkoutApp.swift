import SwiftUI

// MARK: - App Entry Point
// D-06, SAFE-01: Disclaimer gate fires before any content on first launch
// D-07: Hard block — user must tap "I Understand" to proceed; state in AppStorage
// AUTH-03: .onOpenURL handles workout://auth-callback for password reset deep link
// AppState drives root navigation between auth screen and main content
// Phase 7: RevenueCat SDK configured here before auth listener starts (D-17)
@main
struct WorkoutApp: App {
    @AppStorage("disclaimerAcknowledged") var disclaimerAcknowledged = false
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
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
                    // Phase 7: Configure RevenueCat SDK BEFORE starting the auth listener.
                    // configure() does not pass appUserID — logIn() is called later in
                    // listenForAuthChanges() after Supabase auth resolves (RESEARCH Pitfall 1).
                    appState.revenueCatService.configure()
                    // Synchronous cache read — prevents paywall flash for subscribed users
                    // on subsequent app launches (RESEARCH Pitfall 6: "Paywall Flashing")
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--force-paywall") {
                        appState.isSubscribed = false  // UI test: force paywall visible
                        appState.isAuthenticated = true
                        appState.onboardingCompleted = true
                    } else {
                        appState.isSubscribed = true  // Bypass paywall in debug builds
                    }
                    #else
                    appState.isSubscribed = appState.revenueCatService.cachedIsSubscribed()
                    #endif
                    // Starts auth state listener; drives isAuthenticated throughout app lifetime
                    if !ProcessInfo.processInfo.arguments.contains("--force-paywall") {
                        await appState.listenForAuthChanges()
                    }
                }
        }
    }
}

// MARK: - Root Navigation
// Phase 7 paywall gate added: D-13 hard paywall — no free tier after trial/subscription expiry.
//
// Routing logic (evaluated in order):
//   1. Not authenticated                              -> AuthView
//   2. Authenticated + not onboarded                 -> OnboardingFlowView
//   3. Authenticated + onboarded + !isSubscribed     -> MainTabView with paywall fullScreenCover
//   4. Authenticated + onboarded + isSubscribed      -> MainTabView (full access)
//
// The fullScreenCover binding getter — `isAuthenticated && !isSubscribed` — re-evaluates
// whenever AppState changes. The setter is a no-op: the cover only dismisses when
// isSubscribed becomes true after a successful purchase calls refreshEntitlements().
// .interactiveDismissDisabled(true) prevents swipe-to-dismiss (D-13 hard paywall).
//
// T-03-15: onboardingCompleted re-fetched from Supabase on every sign-in.
// T-07-01: isSubscribed is a UX gate only; backend AI proxy reads profiles.subscription_status.
struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.isAuthenticated && appState.onboardingCompleted {
            // Branches 3 & 4: Authenticated AND onboarded — show MainTabView
            // Paywall fullScreenCover appears when !isSubscribed (D-13 hard paywall)
            MainTabView()
                .fullScreenCover(isPresented: Binding(
                    get: { appState.isAuthenticated && !appState.isSubscribed },
                    set: { _ in } // no-op: only dismissed by isSubscribed becoming true
                )) {
                    // Full custom paywall — replaced placeholder from Plan 01.
                    // PaywallView calls appState.refreshEntitlements() on purchase success
                    // to flip isSubscribed and dismiss this cover (D-13).
                    PaywallView()
                }
        } else if appState.isAuthenticated && !appState.onboardingCompleted {
            // Branch 2: Authenticated but NOT onboarded — D-14 third routing branch
            Color("AppBackground")
                .ignoresSafeArea()
                .fullScreenCover(isPresented: .constant(true)) {
                    OnboardingFlowView()
                        .environment(appState)
                }
        } else {
            // Branch 1: Not authenticated — auth screen
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
