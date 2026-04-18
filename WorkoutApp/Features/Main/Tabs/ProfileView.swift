import SwiftUI

// MARK: - ProfileView
// Displays user profile placeholder and storage usage information.
// Storage section shows current exercise video cache size from ExerciseCacheManager.
// Account settings and preferences will be added in later phases.
//
// Requirements: EXRC-04 (cache size visibility in Profile/Settings — 02-CONTEXT.md)
struct ProfileView: View {
    var body: some View {
        List {
            Section {
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("Storage") {
                HStack {
                    Text("Exercise video cache")
                        .font(.subheadline)
                    Spacer()
                    Text(ExerciseCacheManager.shared.formattedCacheSize())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
