import SwiftUI

// MARK: - HomeView (Empty State)
// D-05: Welcome greeting with user name/email after authentication
// Empty state — personalized content added in later phases
struct HomeView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 16) {
            // SF Symbol illustration — large, secondary color (UI-SPEC)
            Image(systemName: "house.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // Heading — .title2, semibold; uses email as fallback (display_name may not load yet)
            Text("Welcome, \(appState.currentUser?.email ?? "")!")
                .font(.title2)
                .fontWeight(.semibold)

            // Body — UI-SPEC Copywriting Contract
            Text("Your personalized workout plan is on its way. Complete setup to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
