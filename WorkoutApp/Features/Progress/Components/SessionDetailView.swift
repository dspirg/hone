import SwiftUI
import CoreData

// MARK: - SessionDetailView
// Navigation push destination from SessionHistoryRow.
// Displays a completed session's exercise breakdown, grouped by exercise name.
// Each exercise is shown as a card with its set logs (setNumber, repsLogged).
// Data: CDSessionLog.setLogs (NSOrderedSet) cast to [CDSetLog].
// Security: receives CDSessionLog already filtered by userId from ProgressViewModel (T-06-03).
// UI-SPEC: SessionDetailView — D-06
// Requirements: PROG-04

struct SessionDetailView: View {
    let session: CDSessionLog

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary header card
                summaryCard

                // Exercise breakdown cards
                let exerciseGroups = groupedExercises
                if exerciseGroups.isEmpty {
                    Text("No set data recorded for this session.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                } else {
                    ForEach(exerciseGroups, id: \.0) { exerciseName, setLogs in
                        exerciseCard(exerciseName: exerciseName, setLogs: setLogs)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("AppBackground").ignoresSafeArea())
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        let label = session.workoutDayLabel ?? "Session"
        if let date = session.completedAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(label) · \(formatter.string(from: date))"
        }
        return label
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryStatCell(value: "\(session.totalExercises)", label: "Exercises")
            Divider().frame(height: 40)
            summaryStatCell(value: "\(session.totalSets)", label: "Sets")
            Divider().frame(height: 40)
            summaryStatCell(value: "\(session.totalReps)", label: "Reps")
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.totalExercises) exercises, \(session.totalSets) sets, \(session.totalReps) reps")
    }

    private func summaryStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise Groups

    /// Groups CDSetLog records by exerciseName, preserving order of first occurrence.
    private var groupedExercises: [(String, [CDSetLog])] {
        let setLogs = (session.setLogs?.array as? [CDSetLog]) ?? []
        var seen: [String] = []
        var groups: [String: [CDSetLog]] = [:]

        for setLog in setLogs {
            let name = setLog.exerciseName ?? "Unknown Exercise"
            if groups[name] == nil {
                seen.append(name)
                groups[name] = []
            }
            groups[name]?.append(setLog)
        }

        return seen.map { name in (name, groups[name] ?? []) }
    }

    // MARK: - Exercise Card

    private func exerciseCard(exerciseName: String, setLogs: [CDSetLog]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exerciseName)
                .font(.body.weight(.semibold))

            Divider()

            ForEach(setLogs, id: \.id) { setLog in
                HStack {
                    Text("Set \(setLog.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(setLog.repsLogged) reps")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
