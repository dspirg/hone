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

    // MARK: - Auth State Listener
    // Subscribes to Supabase authStateChanges AsyncStream
    // Drives root navigation: auth screen vs. main tab bar
    func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                self.isAuthenticated = session != nil
                self.currentUser = session?.user
            case .signedOut:
                self.isAuthenticated = false
                self.currentUser = nil
            case .passwordRecovery:
                // AUTH-03: deep link callback triggers password reset form
                self.showPasswordResetForm = true
            default:
                break
            }
        }
    }
}
