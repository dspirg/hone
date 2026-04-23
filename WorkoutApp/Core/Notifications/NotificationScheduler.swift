import Foundation
import UserNotifications
import CoreData

// MARK: - NotificationScheduler
// Local notification scheduling service for workout reminders.
//
// Scheduling strategy:
//   - Repeating UNCalendarNotificationTrigger at 7pm on each planned workout day
//   - Identifier pattern "workout-reminder-{weekday}" allows cancel/replace per weekday
//   - DateComponents always includes TimeZone.current to avoid GMT default (Pitfall 1)
//   - Streak-aware copy when currentStreak >= 3 (D-23)
//   - Permission requested via earned moment pattern — after first session completes (D-24)
//
// Guard logic:
//   - hasLoggedSessionToday filters by userId (T-06-05 mitigation)
//   - Notification failure is non-fatal — errors are logged, never thrown to caller
//
// Requirements: PROG-03

@MainActor
final class NotificationScheduler {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext

    // MARK: - Init

    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? PersistenceController.shared.container.viewContext
    }

    // MARK: - Permission

    /// Requests notification authorization if status is .notDetermined.
    /// Called after the first session completes (earned moment per D-24).
    /// Safe to call multiple times — system will not re-prompt once determined.
    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("NotificationScheduler: requestPermissionIfNeeded failed: \(error)")
        }
    }

    // MARK: - Schedule

    /// Schedules repeating workout reminders at 7pm on each planned workout day.
    /// Cancels all existing workout reminders before rescheduling.
    ///
    /// - Parameters:
    ///   - planDays: Array of (weekday: Int, workoutType: String) tuples.
    ///              weekday uses 1-based Calendar convention (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    ///   - currentStreak: Active workout streak count; >= 3 triggers motivational copy (D-23)
    func scheduleWorkoutReminders(
        planDays: [(weekday: Int, workoutType: String)],
        currentStreak: Int
    ) async {
        guard await shouldScheduleNotifications() else { return }

        await cancelAllWorkoutReminders()

        let center = UNUserNotificationCenter.current()

        for planDay in planDays {
            let content = UNMutableNotificationContent()
            content.sound = .default

            if currentStreak >= 3 {
                // Streak-motivated copy (D-23)
                content.title = "\(planDay.workoutType) day is waiting"
                content.body = "You're on a \(currentStreak)-day streak — keep it going!"
            } else {
                // Standard copy (D-22)
                content.title = "Ready for your \(planDay.workoutType) day?"
                content.body = "Your plan is waiting."
            }

            // DateComponents with TimeZone.current prevents GMT default (Pitfall 1)
            var components = DateComponents()
            components.weekday = planDay.weekday
            components.hour = 19
            components.minute = 0
            components.timeZone = TimeZone.current

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )

            let identifier = "workout-reminder-\(planDay.weekday)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("NotificationScheduler: scheduleWorkoutReminders failed for weekday \(planDay.weekday): \(error)")
            }
        }
    }

    // MARK: - Cancel

    /// Cancels all pending workout reminder notifications.
    /// Filters by "workout-reminder-" prefix to avoid removing rest-timer notifications.
    func cancelAllWorkoutReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let workoutReminderIds = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix("workout-reminder-") }
        center.removePendingNotificationRequests(withIdentifiers: workoutReminderIds)
    }

    // MARK: - Session Guard

    /// Returns true if the user has already completed a session today.
    /// Prevents duplicate reminders on days a workout has been logged (D-25).
    ///
    /// T-06-05 mitigation: predicate filters by userId — never checks sessions across users.
    func hasLoggedSessionToday(userId: String) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return false
        }

        let req = CDSessionLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "completedAt >= %@ AND completedAt < %@ AND userId == %@",
            today as CVarArg,
            tomorrow as CVarArg,
            userId
        )
        req.fetchLimit = 1

        do {
            let results = try context.fetch(req)
            return !results.isEmpty
        } catch {
            print("NotificationScheduler: hasLoggedSessionToday failed: \(error)")
            return false
        }
    }

    // MARK: - Authorization Check

    /// Returns true only when notification authorization is .authorized.
    /// Scheduling is skipped if .denied or .notDetermined.
    func shouldScheduleNotifications() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
