import Foundation

// MARK: - WeekKey
// Hashable, Comparable key for grouping sessions into calendar-week buckets.
// Used by ProgressViewModel.computeWeekBuckets to group sessions by ISO week.

struct WeekKey: Hashable, Comparable {
    let year: Int
    let week: Int

    static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
        (lhs.year, lhs.week) < (rhs.year, rhs.week)
    }
}

// MARK: - WeekBucket
// Aggregated session data for a single calendar week.
// Used as chart data source in the Progress tab history chart.
//
// Requirements: PROG-03

struct WeekBucket: Identifiable {
    let id = UUID()
    let weekLabel: String   // e.g. "Apr 7" — the Monday of the week
    let sessionCount: Int
    let volume: Int         // sum of (totalSets * totalReps) across sessions in the week
}
