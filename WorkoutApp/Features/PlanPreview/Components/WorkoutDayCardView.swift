import SwiftUI

// MARK: - WorkoutDayCardView
// Renders a single workout day as a card with session name, day label,
// and a list of ExerciseRowView items separated by inset dividers.
//
// UI-SPEC: Day card contract
// - CardBackground fill, 16pt corner radius, md (16pt) horizontal outer margin
// - Session name: .title2 semibold with .accessibilityAddTraits(.isHeader)
// - Day label: .subheadline secondary
// - Exercises separated by Divider with 16pt leading inset

struct WorkoutDayCardView: View {
    let day: WorkoutDay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Session name — .title2 (22pt, semibold), accessibility header trait
            Text(day.sessionName)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)  // md
                .padding(.top, 16)         // md
                .accessibilityAddTraits(.isHeader)

            // Day label — e.g. "Day 1" or "Day 1 - Monday"
            Text(day.dayLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)  // xs

            Spacer().frame(height: 8)  // sm gap before divider
            Divider().padding(.leading, 16)

            // Exercise rows with inset dividers between them
            ForEach(day.exercises) { exercise in
                ExerciseRowView(exercise: exercise)
                // Inset divider between exercises, but not after the last one
                if exercise.id != day.exercises.last?.id {
                    Divider().padding(.leading, 16)
                }
            }

            Spacer().frame(height: 8)  // sm bottom padding
        }
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)  // md outer margin from scroll view edges
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    WorkoutDayCardView(day: WorkoutDay(
        dayLabel: "Day 1",
        sessionName: "Upper Body Strength",
        exercises: [
            PlannedExercise(
                exerciseName: "Bench Press",
                sets: 4,
                reps: "8-10",
                restSeconds: 90,
                rationale: "Primary chest compound that maximizes pectoral activation with compound pressing"
            ),
            PlannedExercise(
                exerciseName: "Barbell Row",
                sets: 4,
                reps: "8-10",
                restSeconds: 90,
                rationale: "Back compound that balances the pressing movement and builds posterior strength"
            )
        ]
    ))
    .background(Color("AppBackground"))
}
#endif
