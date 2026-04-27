import SwiftUI

// MARK: - HomeExerciseRowView
// Exercise row with thumbnail for the Home screen workout card (D-04, D-15, UI-SPEC).
// Named HomeExerciseRowView (not ExerciseRowView) to avoid collision with
// WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift.
//
// Layout: HStack — 40x40 thumbnail | exercise name + sets label | Spacer
// Same AsyncImage phase-switch pattern as ExerciseLibraryRowView (lines 25-44),
// resized to 40x40 per D-04 spec.

struct HomeExerciseRowView: View {
    let exercise: PlannedExercise

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Thumbnail
            AsyncImage(url: nil) { phase in
                // PlannedExercise does not carry a thumbnailURL;
                // thumbnails are looked up via ExerciseRepository in the full HomeView rebuild.
                // For now, always render the dumbbell fallback (D-04 SF Symbol spec).
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                default:
                    Theme.surface
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "dumbbell")
                                .font(.body)
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                        }
                }
            }
            .frame(width: 40, height: 40)

            // MARK: - Exercise Info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(setsLabel)
                    .font(.body)
                    .foregroundStyle(Theme.accent)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.exerciseName), \(setsLabel)")
    }

    // MARK: - Helpers

    private var setsLabel: String {
        "\(exercise.sets) x \(exercise.reps)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        HomeExerciseRowView(exercise: PlannedExercise(
            exerciseName: "Bench Press",
            sets: 3,
            reps: "8-10",
            restSeconds: 60,
            rationale: "Primary push movement"
        ))
        Divider()
        HomeExerciseRowView(exercise: PlannedExercise(
            exerciseName: "Pull-Up",
            sets: 3,
            reps: "6-8",
            restSeconds: 90,
            rationale: "Primary pull movement"
        ))
    }
    .padding()
    .background(Theme.surface)
}
#endif
