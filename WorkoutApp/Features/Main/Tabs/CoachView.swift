import SwiftUI

// MARK: - CoachView (Empty State)
// Placeholder — AI coach chat interface added in Phase 3+
struct CoachView: View {
    var body: some View {
        VStack(spacing: 16) {
            // SF Symbol illustration — large, secondary color (UI-SPEC)
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // Heading — .title2, semibold (UI-SPEC Typography)
            Text("Meet your AI coach")
                .font(.title2)
                .fontWeight(.semibold)

            // Body — UI-SPEC Copywriting Contract
            Text("Your personal coach will be ready after onboarding.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
