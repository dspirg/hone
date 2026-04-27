import SwiftUI

// MARK: - SessionSummaryView
// Session completion screen shown after the last set of the last exercise is confirmed.
// Displays total exercises, sets, reps, session duration, and PR badges.
// Done button dismisses SessionView (pops back to TrainView via NavigationStack).
//
// Difficulty rating captured via emoji picker (D-01, D-02) — required before dismissal.
// No weight logging — deferred per CONTEXT.md.
//
// UI-SPEC: Phase 4 "SessionSummaryView — Completion Screen"
// Requirements: SESS-04, PROG-03

struct SessionSummaryView: View {
    let workoutDayLabel: String    // e.g., "Monday"
    let totalExercises: Int
    let totalSets: Int
    let totalReps: Int
    let duration: TimeInterval     // sessionDuration from SessionViewModel
    let prs: [PRResult]            // Personal records detected this session (D-14)
    let onDone: (DifficultyRating) -> Void  // Dismisses SessionView with rating

    @State private var selectedRating: DifficultyRating? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 16)

                // Completion icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Session complete")

                // Headings
                VStack(spacing: 4) {
                    Text("Great work.")
                        .font(.title.weight(.semibold))

                    Text("\(workoutDayLabel) complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Stats row — Exercises / Sets / Reps
                HStack(spacing: 32) {
                    StatCell(label: "Exercises", value: "\(totalExercises)")
                    StatCell(label: "Sets", value: "\(totalSets)")
                    StatCell(label: "Reps", value: "\(totalReps)")
                }
                .accessibilityElement(children: .combine)

                // Duration stat
                StatCell(label: "Duration", value: formattedDuration)

                // PR badges — shown when personal records detected this session (D-14, D-15)
                if !prs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Record")
                            .font(.title2.weight(.semibold))
                        PRBadgeView(prs: prs)
                    }
                }

                // Difficulty rating (D-01: emoji scale, D-02: required before dismissal)
                VStack(spacing: 12) {
                    Text("How was that?")
                        .font(.headline)

                    HStack(spacing: 24) {
                        ForEach(DifficultyRating.allCases, id: \.self) { rating in
                            Button {
                                selectedRating = rating
                            } label: {
                                VStack(spacing: 4) {
                                    Text(rating.emoji)
                                        .font(.system(size: 44))
                                        .opacity(selectedRating == nil || selectedRating == rating ? 1.0 : 0.3)
                                        .scaleEffect(selectedRating == rating ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                                    Text(rating.label)
                                        .font(.caption2)
                                        .foregroundStyle(selectedRating == rating ? .primary : .secondary)
                                }
                            }
                            .accessibilityLabel(rating.label)
                        }
                    }
                }

                Spacer()

                Button("Done") {
                    if let rating = selectedRating {
                        onDone(rating)
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .disabled(selectedRating == nil)
                .opacity(selectedRating == nil ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
        }
        .navigationBarBackButtonHidden(true)
        .background(Theme.background.ignoresSafeArea())
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
            prs: [],
            onDone: { _ in }
        )
    }
}
#endif
