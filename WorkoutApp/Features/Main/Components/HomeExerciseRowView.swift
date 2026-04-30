import CoreData
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

    @State private var thumbnailURL: URL?

    private var initialPlaceholder: some View {
        Theme.surface
            .overlay {
                Text(String(exercise.exerciseName.prefix(1)).uppercased())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
    }

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Thumbnail
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    initialPlaceholder
                default:
                    initialPlaceholder
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
        .task {
            let repo = ExerciseRepository.shared
            if let entity = try? repo.fetchByName(exercise.exerciseName) ?? repo.fetchByNameContains(exercise.exerciseName),
               let urlStr = entity.value(forKey: "thumbnailURL") as? String,
               let url = URL(string: urlStr.replacingOccurrences(of: " ", with: "%20")) {
                thumbnailURL = url
            }
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
