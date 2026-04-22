import SwiftUI

// MARK: - ExerciseLibraryRowView
// Exercise list row for ExerciseLibraryView.
// Layout: leading 52x52 thumbnail (AsyncImage), trailing VStack with name + muscle group label.
//
// Note: Named ExerciseLibraryRowView (not ExerciseRowView) to avoid naming conflict with
// WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift which defines ExerciseRowView
// for the plan preview context (displays PlannedExercise with sets/reps/rest/rationale).
//
// UI-SPEC: Exercise list row
// - Thumbnail: 52x52, cornerRadius 8; placeholder = CardBackground + dumbbell SF Symbol
// - Name: .subheadline semibold
// - Muscle group label: .subheadline regular, .secondary color
// - Accessibility: .accessibilityLabel("[name], [primaryMuscle]")

struct ExerciseLibraryRowView: View {
    let exercise: ExerciseModel

    var body: some View {
        HStack(spacing: 12) {
            // MARK: Thumbnail
            AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                default:
                    // Placeholder: CardBackground with dumbbell SF Symbol (RESEARCH.md Pattern 8)
                    Color("CardBackground")
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "dumbbell")
                                .font(.body)
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                        }
                }
            }
            .frame(width: 52, height: 52)

            // MARK: Exercise Info
            VStack(alignment: .leading, spacing: 2) {
                // Exercise name — .subheadline semibold (15pt, 600)
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)

                // Primary muscle — .subheadline regular (15pt, 400), .secondary color
                Text(exercise.primaryMuscle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()
        }
        .accessibilityLabel("\(exercise.name), \(exercise.primaryMuscle)")
    }
}

// MARK: - Preview

#if DEBUG
private extension ExerciseModel {
    static var preview: ExerciseModel {
        let dto = ExerciseDTO(
            id: UUID(),
            name: "Push-Up",
            primaryMuscle: "Chest",
            equipmentTag: "Bodyweight",
            difficulty: "Beginner",
            howToSteps: ["Start in plank position", "Lower chest to floor", "Push back up"],
            formTips: "Keep core tight throughout",
            muxPlaybackId: nil,
            thumbnailUrl: nil,
            videoUrl: nil,
            updatedAt: Date()
        )
        return ExerciseModel(from: dto)
    }
}

#Preview {
    ExerciseLibraryRowView(exercise: .preview)
        .padding()
        .background(Color("CardBackground"))
}
#endif
