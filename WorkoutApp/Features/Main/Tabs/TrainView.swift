import SwiftUI

// MARK: - TrainView (Empty State)
// Placeholder — workout sessions appear here after plan generation (Phase 2+)
struct TrainView: View {
    var body: some View {
        VStack(spacing: 16) {
            // SF Symbol illustration — large, secondary color (UI-SPEC)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // Heading — .title2, semibold (UI-SPEC Typography)
            Text("Your workouts live here")
                .font(.title2)
                .fontWeight(.semibold)

            // Body — UI-SPEC Copywriting Contract
            Text("Once your plan is ready, your weekly sessions will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
