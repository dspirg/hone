import SwiftUI

// MARK: - ExerciseRowView
// Renders a single planned exercise inside a WorkoutDayCardView.
// Shows exercise name, sets/reps/rest, and AI rationale coach note (D-07, AIPL-02).
//
// UI-SPEC: ExerciseRowView contract
// Typography: exercise name = .subheadline semibold, sets/reps = .subheadline secondary,
//             rationale = .subheadline tertiary with quote.opening icon.
// Accessibility: .accessibilityElement(children: .combine) — VoiceOver reads entire row
//                as one element: "[name], [sets] sets, [reps] reps, [rest]s rest. Why: [rationale]"

struct ExerciseRowView: View {
    let exercise: PlannedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {  // xs (4pt) spacing between lines
            // Exercise name — .subheadline semibold (15pt, 600)
            Text(exercise.exerciseName)
                .font(.subheadline.weight(.semibold))

            // Sets/reps/rest — .subheadline regular (15pt, 400), .secondary color
            // Format: "4 sets × 8-10 — 90s rest"
            Text("\(exercise.sets) sets \u{00D7} \(exercise.reps) \u{2014} \(exercise.restSeconds)s rest")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // AI rationale — .subheadline regular (15pt, 400), .tertiary color (AIPL-02 / D-07)
            // quote.opening SF Symbol at 11pt as inline leading decoration
            HStack(alignment: .firstTextBaseline, spacing: 4) {  // xs gap
                Image(systemName: "quote.opening")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Why: \(exercise.rationale)")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)  // md (16pt) inside card
        .padding(.vertical, 8)     // sm (8pt) top and bottom
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        // VoiceOver will read: "[exerciseName], [sets] sets × [reps] — [restSeconds]s rest. Why: [rationale]"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ExerciseRowView(exercise: PlannedExercise(
        exerciseName: "Barbell Back Squat",
        sets: 4,
        reps: "6-8",
        restSeconds: 120,
        rationale: "Primary lower body compound movement targeting quads, glutes, and hamstrings"
    ))
    .background(Theme.surface)
}
#endif
