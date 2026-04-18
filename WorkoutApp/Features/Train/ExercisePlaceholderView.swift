import SwiftUI

// MARK: - ExercisePlaceholderView
// Gradient card shown in place of video for exercises where mux_playback_id is nil
// (i.e., video content not yet licensed/uploaded).
//
// UI-SPEC: LinearGradient from #1C1C1E to #2C2C2E, video.slash icon (40pt), "Video coming soon" label.
// Aspect ratio: 16:9 — same frame as VideoPlayerView so layout is stable across both states.
//
// Requirements: EXRC-01 (unlicensed video exercises shown with placeholder, not hidden)

struct ExercisePlaceholderView: View {
    let exerciseName: String

    var body: some View {
        ZStack {
            // Gradient background: secondary dark tones per UI-SPEC color contract
            LinearGradient(
                colors: [
                    Color(.secondarySystemBackground),
                    Color(.tertiarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                Image(systemName: "video.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Video coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("\(exerciseName) — video coming soon")
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ExercisePlaceholderView(exerciseName: "Push-up")
        .padding()
}
#endif
