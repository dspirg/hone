import SwiftUI

// MARK: - SessionSummaryView
// Session completion screen shown after the last set of the last exercise is confirmed.
// Displays total exercises, sets, reps, and session duration.
// Done button dismisses SessionView (pops back to TrainView via NavigationStack).
//
// No difficulty rating — deferred to Phase 8 per CONTEXT.md.
// No weight logging — deferred per CONTEXT.md.
//
// UI-SPEC: Phase 4 "SessionSummaryView — Completion Screen"
// Requirements: SESS-04

struct SessionSummaryView: View {
    let workoutDayLabel: String    // e.g., "Monday"
    let totalExercises: Int
    let totalSets: Int
    let totalReps: Int
    let duration: TimeInterval     // sessionDuration from SessionViewModel
    let onDone: () -> Void         // Dismisses SessionView

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 48)  // 2xl breathing room above icon

                // Completion icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color("AccentColor"))
                    .accessibilityLabel("Session complete")

                // Headings
                VStack(spacing: 8) {
                    Text("Great work.")
                        .font(.title.weight(.semibold))

                    Text("\(workoutDayLabel) complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer().frame(height: 8)  // sm between headings and stats

                // Stats row — Exercises / Sets / Reps
                HStack(spacing: 32) {
                    StatCell(label: "Exercises", value: "\(totalExercises)")
                    StatCell(label: "Sets", value: "\(totalSets)")
                    StatCell(label: "Reps", value: "\(totalReps)")
                }
                .accessibilityElement(children: .combine)

                // Duration stat
                StatCell(label: "Duration", value: formattedDuration)

                Spacer()

                // Done button — no difficulty rating (Phase 8 scope per CONTEXT.md deferred)
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color("AppBackground").ignoresSafeArea())
    }

    // MARK: - Duration Formatting

    /// Formats duration as "42m 07s". Under 1 minute: "0m 45s".
    private var formattedDuration: String {
        let total = Int(max(duration, 0))
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }
}

// MARK: - StatCell

/// Reusable stat display cell: value (large semibold) above label (small secondary).
/// UI-SPEC: VStack(spacing: 4) with value (.title2 semibold) above label (.subheadline regular, .secondary)
struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SessionSummaryView(
            workoutDayLabel: "Monday",
            totalExercises: 5,
            totalSets: 15,
            totalReps: 120,
            duration: 2527,
            onDone: {}
        )
    }
}
#endif
