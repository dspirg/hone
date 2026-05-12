import SwiftUI

// MARK: - WeekStreakBar
// Weekly streak bar for the Home screen (D-15, UI-SPEC).
// Renders 7 locale-aware day tiles with amber fill for completed days,
// amber border for today (not done), and surfaceElevated for future/past (not done).
//
// RESEARCH Pitfall 6: uses Calendar.current.shortWeekdaySymbols rotated by
// Calendar.current.firstWeekday for locale-safe day order.

struct WeekStreakBar: View {
    /// Set of dates (startOfDay) marking completed workout days this week.
    let completedDates: Set<Date>
    /// Current streak count to display below the tiles.
    let currentStreak: Int

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // MARK: - Day Tiles
            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                    DayTileView(
                        letter: dayLetter(for: day),
                        isCompleted: isCompleted(day),
                        isToday: isToday(day)
                    )
                }
            }

            // MARK: - Streak Label
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.accent)
                Text("\(currentStreak) day streak")
                    .foregroundStyle(.secondary)
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Helpers

    /// Returns the 7 days of the current week in locale-safe order.
    private var weekDays: [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekInterval.start)
        }
    }

    /// Returns a single uppercase letter abbreviation for the given date.
    private func dayLetter(for date: Date) -> String {
        let calendar = Calendar.current
        let symbols = rotatedShortWeekdaySymbols(calendar: calendar)
        // weekday is 1-indexed; firstWeekday is 1-indexed
        let weekday = calendar.component(.weekday, from: date)
        let firstWeekday = calendar.firstWeekday
        let index = ((weekday - firstWeekday + 7) % 7)
        guard index < symbols.count else { return "" }
        return String(symbols[index].prefix(1)).uppercased()
    }

    /// Returns shortWeekdaySymbols rotated so the array starts at Calendar.firstWeekday.
    private func rotatedShortWeekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1 // convert to 0-indexed
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
    }

    /// Returns true if the given date falls in the completedDates set (startOfDay comparison).
    private func isCompleted(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return completedDates.contains(startOfDay)
    }

    /// Returns true if the given date is today.
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - DayTileView

private struct DayTileView: View {
    let letter: String
    let isCompleted: Bool
    let isToday: Bool

    var body: some View {
        Text(letter)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: 36, height: 36)
            .background(backgroundColor)
            .clipShape(Circle())
            .overlay {
                if isToday && !isCompleted {
                    Circle()
                        .stroke(Theme.accent, lineWidth: 2)
                }
            }
    }

    private var backgroundColor: Color {
        isCompleted ? Theme.accent : Theme.surfaceElevated
    }

    private var foregroundColor: Color {
        if isCompleted {
            return Color.black
        }
        return isToday ? Color.primary : Color.secondary
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let calendar = Calendar.current
    let today = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

    let completedDates: Set<Date> = [
        calendar.startOfDay(for: yesterday),
        calendar.startOfDay(for: twoDaysAgo)
    ]

    WeekStreakBar(completedDates: completedDates, currentStreak: 2)
        .padding()
        .background(Theme.background)
}
#endif
