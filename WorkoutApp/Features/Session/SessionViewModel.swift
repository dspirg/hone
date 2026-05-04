import Foundation
import Observation
import UserNotifications

// MARK: - SessionViewModel
// @Observable state machine for the in-session workout experience.
// Owns: exercise index, rest timer, set completion tracking, CoreData write-ahead.
//
// Lifecycle:
//   1. init → configure dependencies
//   2. startSession() → creates CDSessionLog, requests notification permission
//   3. completeSet(setIndex:repsLogged:) → writes CDSetLog, starts rest timer
//   4. skipRest() / extendRest() → manages rest timer state
//   5. advanceExercise() → moves to next exercise
//   6. Last set of last exercise → finalizeSession(), isSessionComplete = true
//
// Requirements: SESS-02 (rest timer), SESS-03 (offline write-ahead)

@Observable
@MainActor
final class SessionViewModel {

    // MARK: - State

    private(set) var currentExerciseIndex: Int = 0
    private(set) var isRestTimerActive: Bool = false
    private(set) var timerEndDate: Date? = nil
    private(set) var isSessionComplete: Bool = false
    private(set) var sessionStartDate: Date = Date()
    private(set) var detectedPRs: [PRResult] = []
    /// True if startSession() CoreData write failed permanently — used by SessionView
    /// to show an error banner rather than silently no-oping all completeSet calls.
    private(set) var sessionSetupFailed: Bool = false

    /// Per-exercise set tracking: [exerciseIndex: [setIndex: repsLogged]]
    private(set) var completedSets: [Int: [Int: Int]] = [:]

    // MARK: - Dependencies

    let workoutDay: WorkoutDay
    private let repository: SessionRepository
    private var sessionLog: CDSessionLog?
    private let planId: String
    // Phase 11: made internal (not private) so ExerciseCardView.loadContextData can read it
    // for scoped fetchPreviousReps/fetchBestReps queries (D-07, T-11-05).
    let userId: String
    private let notificationScheduler = NotificationScheduler.shared

    // MARK: - Phase 11: Context Card Access (D-07)

    /// Exposes the current session log's UUID for fetchPreviousReps exclusion.
    /// Returns nil if session has not yet started (startSession not yet awaited).
    var sessionLogId: UUID? { sessionLog?.id }

    // MARK: - Init

    init(
        workoutDay: WorkoutDay,
        planId: String,
        userId: String,
        repository: SessionRepository = SessionRepository()
    ) {
        self.workoutDay = workoutDay
        self.planId = planId
        self.userId = userId
        self.repository = repository
    }

    // MARK: - Computed

    var exercises: [PlannedExercise] { workoutDay.exercises }

    var currentExercise: PlannedExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    /// Returns contextual label for what comes next — shown in rest timer overlay.
    var nextContextLabel: String {
        guard let current = currentExercise else { return "" }
        let completedInCurrent = completedSets[currentExerciseIndex]?.count ?? 0
        let nextSetNumber = completedInCurrent + 1

        if nextSetNumber < current.sets {
            return "Up next: Set \(nextSetNumber + 1) — \(current.exerciseName)"
        } else if currentExerciseIndex + 1 < exercises.count {
            return "Up next: \(exercises[currentExerciseIndex + 1].exerciseName)"
        } else {
            return "Last set — finish strong!"
        }
    }

    /// Total elapsed session time in seconds.
    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartDate)
    }

    // MARK: - Lifecycle

    /// Starts the session: creates CDSessionLog via repository and requests notification permission.
    /// Non-fatal if CoreData write fails — session continues in memory.
    /// CR-02: async so callers can await completion before allowing set logging,
    /// eliminating the race where completeSet fires before sessionLog is set.
    func startSession() async {
        sessionStartDate = Date()
        do {
            sessionLog = try repository.startSession(
                day: workoutDay,
                planId: planId,
                userId: userId
            )
        } catch {
            // CoreData write failure is non-fatal — session continues in memory.
            // No timer/sync until sessionLog is non-nil.
            sessionSetupFailed = true
            print("SessionViewModel: startSession CoreData write failed: \(error)")
        }
        // Notification permission is requested after first session completes (D-24 earned moment),
        // not at session start. See completeSet → finalizeSession flow.
    }

    // MARK: - Set Logging

    /// Records a completed set, writes to CoreData, and triggers rest timer or finalizes session.
    /// - Parameters:
    ///   - setIndex: 0-indexed set position within the current exercise.
    ///   - repsLogged: Actual reps performed (clamped in repository to 0–999).
    func completeSet(setIndex: Int, repsLogged: Int) {
        guard let exercise = currentExercise else { return }
        guard let session = sessionLog else {
            // If setup definitively failed, the error banner in SessionView should already
            // be visible via sessionSetupFailed. Either way, silently return — there is
            // no session to write to.
            if sessionSetupFailed {
                print("SessionViewModel: completeSet called but sessionSetupFailed — set not recorded")
            }
            return
        }

        // Record in local state
        if completedSets[currentExerciseIndex] == nil {
            completedSets[currentExerciseIndex] = [:]
        }
        completedSets[currentExerciseIndex]?[setIndex] = repsLogged

        // Write-ahead to CoreData (non-blocking background task in repository)
        repository.completeSet(
            session: session,
            exercise: exercise,
            setNumber: setIndex + 1,
            repsLogged: repsLogged
        )

        let isLastSetOfCurrentExercise = (setIndex + 1) >= exercise.sets
        let isLastExercise = currentExerciseIndex == exercises.count - 1

        if isLastSetOfCurrentExercise && isLastExercise {
            // Session complete — finalize
            Task {
                try? repository.finalizeSession(session)

                // PR detection (PROG-03, D-12, T-06-07: scoped by userId)
                // Default context matches repository's context (both use PersistenceController.shared)
                let progressVM = ProgressViewModel()
                progressVM.setUserIdForTesting(userId)
                if let prs = try? progressVM.detectPRs(for: session, userId: userId) {
                    detectedPRs = prs
                }

                // Notification permission — earned moment after first session (D-24)
                await notificationScheduler.requestPermissionIfNeeded()

                isSessionComplete = true
            }
        } else {
            // Start rest timer using plan-specified duration
            let duration = restDuration(for: exercise)
            let endDate = Date().addingTimeInterval(duration)
            timerEndDate = endDate
            isRestTimerActive = true
            scheduleRestNotification(at: endDate, sessionId: session.id?.uuidString ?? "")
        }
    }

    /// Completes the next incomplete set for the current exercise using the default rep count.
    /// Called by the "Complete Set" CTA button in SessionView (D-09).
    /// T-11-06: uses same completeSet path with T-04-01 repsLogged clamping.
    func completeCurrentSet() {
        guard let exercise = currentExercise else { return }
        let completedCount = completedSets[currentExerciseIndex]?.count ?? 0
        guard completedCount < exercise.sets else { return }
        // Parse lower bound of rep range as the default (e.g., "8-12" → 8, "10" → 10)
        let defaultReps = Int(
            exercise.reps
                .split(separator: "-")
                .first
                .flatMap { Int(String($0)) }
                ?? Int(exercise.reps)
                ?? 8
        ) ?? 8
        completeSet(setIndex: completedCount, repsLogged: defaultReps)
    }

    // MARK: - Rest Timer

    /// Cancels the rest timer immediately; cancels pending notification.
    func skipRest() {
        isRestTimerActive = false
        cancelRestNotification()
        timerEndDate = nil
    }

    /// Extends the current rest timer by 30 seconds; reschedules notification.
    func extendRest() {
        guard let current = timerEndDate else { return }
        let newEnd = current.addingTimeInterval(30)
        timerEndDate = newEnd
        if let session = sessionLog {
            cancelRestNotification()
            scheduleRestNotification(at: newEnd, sessionId: session.id?.uuidString ?? "")
        }
    }

    /// Called by RestTimerOverlay when the countdown reaches zero.
    /// Clears timer state and cancels notification (already expired).
    func handleTimerExpired() {
        isRestTimerActive = false
        cancelRestNotification()
        timerEndDate = nil
    }

    // MARK: - Exercise Navigation

    /// Advances to the next exercise; clears timer state.
    /// No-op if already on the last exercise.
    func goToExercise(_ index: Int) {
        guard index >= 0, index < exercises.count else { return }
        isRestTimerActive = false
        timerEndDate = nil
        cancelRestNotification()
        currentExerciseIndex = index
    }

    func advanceExercise() {
        guard currentExerciseIndex < exercises.count - 1 else { return }
        isRestTimerActive = false
        timerEndDate = nil
        cancelRestNotification()   // WR-06: cancel pending "Rest complete" notification so it
                                   // doesn't fire after the user has already moved to the next exercise
        currentExerciseIndex += 1
    }

    // MARK: - Rest Duration

    /// Returns the plan-specified rest duration for an exercise.
    /// Defaults to 60s if restSeconds is 0 (not specified in plan).
    private func restDuration(for exercise: PlannedExercise) -> TimeInterval {
        let seconds = exercise.restSeconds
        return TimeInterval(seconds > 0 ? seconds : 60)
    }

    // MARK: - Notifications

    private func scheduleRestNotification(at endDate: Date, sessionId: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set"
        content.sound = .default

        let duration = endDate.timeIntervalSinceNow
        guard duration > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rest-timer-\(sessionId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelRestNotification() {
        guard let session = sessionLog,
              let idStr = session.id?.uuidString else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["rest-timer-\(idStr)"])
    }

    // MARK: - Difficulty Rating

    /// Saves the user's difficulty rating for the completed session (D-01, D-02).
    /// Called when the user taps Done on SessionSummaryView.
    func saveDifficultyRating(_ rating: DifficultyRating) {
        guard let session = sessionLog else { return }
        do {
            try repository.saveDifficultyRating(rating, for: session)
        } catch {
            print("SessionViewModel: saveDifficultyRating failed: \(error)")
        }
    }

    // MARK: - Testing Hooks

    /// For unit tests only — forces timer state without requiring a sessionLog.
    /// Not intended for production use.
    func forceTimerActiveForTesting(endDate: Date) {
        timerEndDate = endDate
        isRestTimerActive = true
    }
}
