import SwiftUI
import CoreData

// MARK: - SessionHistoryRow
// Row component for displaying a completed session in the history list.
// Wrapped in NavigationLink in ProgressView — NavigationLink handles 44pt touch target.
// Displays: workout name (.body.semibold), date + exercise/set counts (.caption .secondary).
// Trailing chevron: chevron.right SF Symbol.
// UI-SPEC: SessionHistoryRow component — D-05
// Requirements: PROG-04

struct SessionHistoryRow: View {
    let session: CDSessionLog

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.workoutDayLabel ?? "Workout")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(session.totalExercises) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(session.totalSets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Date Formatting

    private var formattedDate: String {
        guard let date = session.completedAt else { return "Unknown date" }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private var accessibilityDescription: String {
        let name = session.workoutDayLabel ?? "Workout"
        return "\(name), \(formattedDate), \(session.totalExercises) exercises, \(session.totalSets) sets"
    }
}
