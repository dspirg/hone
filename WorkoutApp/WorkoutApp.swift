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
                .fullScreenCover(isPresented: Binding(
                    get: { !disclaimerAcknowledged },
                    set: { _ in }
                )) {
                    // DisclaimerView placeholder — implemented in Plan 03
                    // D-07: .interactiveDismissDisabled enforced in DisclaimerView
                    Text("Disclaimer placeholder")
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
// - Not authenticated: auth screen (Plan 03 replaces placeholder)
// - Authenticated: main tab bar (Plan 03 replaces placeholder)
struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.isAuthenticated {
            // MainTabView placeholder — implemented in Plan 03
            Text("Authenticated - Tab bar coming in Plan 03")
        } else {
            NavigationStack {
                // AuthView placeholder — implemented in Plan 03
                Text("Auth screen coming in Plan 03")
            }
        }
    }
}
