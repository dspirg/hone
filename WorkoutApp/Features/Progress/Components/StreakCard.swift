import SwiftUI

// MARK: - StreakCard
// Displays current streak (AccentColor largeTitle) and longest streak.
// Zero state: shows "Start your streak today" instead of "0 day streak".
// Card container wrapping is applied in ProgressView (not inside StreakCard).
// UI-SPEC: D-07 — streak number is the primary motivational signal.
// Requirements: PROG-01

struct StreakCard: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        VStack(spacing: 8) {
            if currentStreak == 0 {
                Text("Start your streak today")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(currentStreak)")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))

                Text(currentStreak == 1 ? "day streak" : "days streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if longestStreak > 0 {
                Text("Longest: \(longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            currentStreak > 0
                ? "\(currentStreak) day streak. Longest: \(longestStreak) days."
                : "Start your streak today"
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        StreakCard(currentStreak: 7, longestStreak: 14)
            .padding(16)
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

        StreakCard(currentStreak: 0, longestStreak: 5)
            .padding(16)
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
#endif
