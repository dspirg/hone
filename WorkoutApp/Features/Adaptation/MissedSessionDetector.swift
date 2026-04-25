import Foundation
import CoreData

// MARK: - MissedSessionDetector
// Detects planned-but-skipped training days for the current week (D-06, D-07).
// Compares active plan day labels against completed CDSessionLog records.
// Only flags planned training days — NOT rest days (plan only specifies workout days).
//
// Design: Pure struct with static function — no mutable state, fully testable.
// Calendar-week boundary: uses Calendar.dateInterval(of:weekOfYear) for locale-correct week range.
//
// Threat: T-08-12 — Pure local compute, no network calls; no DoS surface.

struct MissedSessionDetector {

    /// Returns the day labels that were planned but not completed in the current week,
    /// and whose scheduled weekday has already passed.
    ///
    /// - Parameters:
    ///   - activePlanDayLabels: Day labels from the active workout plan (e.g. ["Monday", "Wednesday", "Friday"])
    ///   - completedSessions: All CDSessionLog records (filtering to this week is done here)
    ///   - today: The reference date (default: Date() — injectable for testing)
    ///   - calendar: Calendar instance (default: .current — injectable for testing)
    /// - Returns: Day labels that are planned, have passed, and have no completed session this week.
    static func detectMissedSessions(
        activePlanDayLabels: [String],
        completedSessions: [CDSessionLog],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)
        else { return [] }

        // Day labels of completed sessions this week
        let completedLabels = Set(
            completedSessions
                .filter { s in
                    guard let completedAt = s.completedAt else { return false }
                    return weekInterval.contains(completedAt)
                }
                .compactMap { $0.workoutDayLabel }
        )

        // Map day labels to Calendar weekday component index.
        // Swift Calendar: Sunday = 1, Monday = 2, ..., Saturday = 7
        let dayOfWeekMap: [String: Int] = [
            "Sunday": 1,
            "Monday": 2,
            "Tuesday": 3,
            "Wednesday": 4,
            "Thursday": 5,
            "Friday": 6,
            "Saturday": 7
        ]

        let todayWeekday = calendar.component(.weekday, from: today)

        return activePlanDayLabels.filter { label in
            // Only flag if: (a) not completed this week, (b) the planned day is strictly in the past
            guard !completedLabels.contains(label) else { return false }
            guard let plannedWeekday = dayOfWeekMap[label] else { return false }
            return plannedWeekday < todayWeekday
        }
    }
}
