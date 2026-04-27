import SwiftUI

// MARK: - SessionSummaryView
// Session completion screen shown after the last set of the last exercise is confirmed.
// Displays total exercises, sets, reps, session duration, and PR badges.
// Done button dismisses SessionView (pops back to TrainView via NavigationStack).
//
// Difficulty rating captured via emoji picker (D-01, D-02) — required before dismissal.
// No weight logging — deferred per CONTEXT.md.
//
// UI-SPEC: Phase 11 Screen 3 "SessionSummaryView — Completion Screen"
// Requirements: SESS-04, PROG-03, UI-07
//
// D-10: Checkmark 36pt, stats merged into 4-item row using StatPillView
// D-11: Emoji difficulty picker always visible without scrolling
// D-12: PR badges section capped at 80pt with internal ScrollView; outer ScrollView removed

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
        VStack(spacing: 0) {
            Spacer().frame(height: 16)

            // Completion icon -- shrunk from 56pt to 36pt (D-10)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("Session complete")

            // Headings
            VStack(spacing: 4) {
                Text("Great work.")
                    .font(.title2.weight(.semibold))  // was .title -- consolidated to Heading tier

                Text("\(workoutDayLabel) complete")
                    .font(.body)  // was .subheadline -- consolidated to Body tier
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            Spacer().frame(height: 20)

            // 4-stat row -- Duration merged into row (D-10)
            HStack(spacing: 16) {
                StatPillView(label: "Exercises", value: "\(totalExercises)")
                StatPillView(label: "Sets", value: "\(totalSets)")
                StatPillView(label: "Reps", value: "\(totalReps)")
                StatPillView(label: "Duration", value: formattedDuration)
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            // PR badges -- capped height with internal scroll (D-12)
            if !prs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Record")
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 16)
                    ScrollView {
                        PRBadgeView(prs: prs)
                            .padding(.horizontal, 16)
                    }
                    .frame(maxHeight: 80)
                }
            }

            Spacer(minLength: 12)

            // Difficulty rating -- UNCHANGED per D-11 (44pt emoji, labels, spring animation)
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

            Spacer(minLength: 16)

            // Done button -- unchanged behavior
            Button("Done") {
                if let rating = selectedRating {
                    onDone(rating)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .padding(.horizontal, 16)
            .disabled(selectedRating == nil)
            .opacity(selectedRating == nil ? 0.5 : 1.0)

            Spacer().frame(height: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
