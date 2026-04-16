import SwiftUI

// MARK: - ProfileView (Empty State)
// Placeholder — account settings and preferences added in later phases
struct ProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            // SF Symbol illustration — large, secondary color (UI-SPEC)
            Image(systemName: "person.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // Heading — .title2, semibold (UI-SPEC Typography)
            Text("Your profile")
                .font(.title2)
                .fontWeight(.semibold)

            // Body — UI-SPEC Copywriting Contract
            Text("Account settings and preferences will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
