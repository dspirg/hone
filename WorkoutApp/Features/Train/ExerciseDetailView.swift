import SwiftUI

// MARK: - ExerciseDetailView
// Exercise detail view with inline HLS video playback and structured exercise metadata.
// Implemented in Plan 02-03, Task 2.
// Placeholder replaced by full implementation below.

struct ExerciseDetailView: View {
    let exercise: ExerciseModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Video player or placeholder based on exercise.hasVideo
                if let playbackId = exercise.muxPlaybackId {
                    VideoPlayerView(
                        muxPlaybackId: playbackId,
                        localAssetURL: exercise.localAssetURL.flatMap { URL(string: $0) }
                    )
                    .aspectRatio(16 / 9, contentMode: .fit)
                } else if let videoUrl = exercise.videoUrl, let url = URL(string: videoUrl) {
                    VideoPlayerView(
                        muxPlaybackId: "",
                        localAssetURL: url
                    )
                    .aspectRatio(16 / 9, contentMode: .fit)
                } else {
                    ExercisePlaceholderView(exerciseName: exercise.name)
                }

                // Metadata section
                VStack(alignment: .leading, spacing: 16) {
                    // Exercise name
                    Text(exercise.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Tag pills: primary muscle (accent), equipment, difficulty
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagPill(text: exercise.primaryMuscle, isAccent: true)
                            TagPill(text: exercise.equipmentTag, isAccent: false)
                            TagPill(text: exercise.difficulty, isAccent: false)
                        }
                    }

                    Divider()

                    // How-To steps (numbered list)
                    if !exercise.howToSteps.isEmpty {
                        Text("How To")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(exercise.howToSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 20, alignment: .leading)
                                    Text(step)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    // Form Tips section
                    if let tips = exercise.formTips, !tips.isEmpty {
                        Divider()
                        Text("Form Tips")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(tips)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 32)  // xl spacing per UI-SPEC
                .padding(.top, 24)          // lg spacing below video
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Track last viewed for LRU cache eviction (EXRC-04)
            ExerciseRepository.shared.updateLastViewed(exerciseId: exercise.id)
        }
    }
}

// MARK: - TagPill

private struct TagPill: View {
    let text: String
    let isAccent: Bool

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isAccent ? Theme.accent : Theme.surface)
            .foregroundStyle(isAccent ? .white : .primary)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: ExerciseModel(
            id: UUID(),
            name: "Barbell Back Squat",
            primaryMuscle: "Legs",
            equipmentTag: "Barbell",
            difficulty: "Intermediate",
            howToSteps: [
                "Stand with feet shoulder-width apart, barbell across upper back.",
                "Brace your core and push your hips back.",
                "Lower until thighs are parallel to the floor.",
                "Drive through your heels to return to standing."
            ],
            formTips: "Keep your chest up and knees tracking over your toes throughout the movement.",
            muxPlaybackId: nil,
            thumbnailURL: nil,
            localAssetURL: nil,
            lastViewedAt: nil
        ))
    }
}
#endif
