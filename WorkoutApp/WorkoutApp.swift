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
// Routes based on appState.isAuthenticated:
// - Not authenticated: NavigationStack wrapping AuthView
// - Authenticated: MainTabView (4-tab shell)
struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.isAuthenticated {
            MainTabView()
        } else {
            NavigationStack {
                AuthView()
            }
        }
    }
}
