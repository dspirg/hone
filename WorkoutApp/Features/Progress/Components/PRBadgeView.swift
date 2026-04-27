import SwiftUI

// MARK: - PRBadgeView
// Displays personal record badges in the session completion summary screen.
// Shown for each exercise where the user set a new rep record (D-14, D-15).
//
// Design: Understated — AccentColor tint, no animation, no haptic (D-16).
// Each badge shows exercise name, new record reps, and previous best (if > 0).
//
// UI-SPEC: Phase 6 "PR Badge"
// Requirements: PROG-03

struct PRBadgeView: View {
    let prs: [PRResult]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(prs) { pr in
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.exerciseName)
                            .font(.body.weight(.semibold))
                        Text("New record: \(pr.newRecord) reps")
                            .font(.body)
                        if pr.previousBest > 0 {
                            Text("Previous best: \(pr.previousBest) reps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        PRBadgeView(prs: [
            PRResult(
                exerciseName: "Push-ups",
                newRecord: 20,
                previousBest: 15
            ),
            PRResult(
                exerciseName: "Squats",
                newRecord: 12,
                previousBest: 0
            )
        ])
        .padding()
    }
    .background(Theme.background.ignoresSafeArea())
}
#endif
