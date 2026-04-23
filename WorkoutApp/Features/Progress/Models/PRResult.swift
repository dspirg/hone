import Foundation

// MARK: - PRResult
// Represents a personal record detected after a session completes.
// Used by ProgressViewModel.detectPRs(for:) to identify exercises where
// the user set a new max-reps record compared to all prior sessions.
//
// Requirements: PROG-04
// Threat mitigations:
//   T-06-02: detectPRs scopes prior CDSetLog queries to cachedUserId

struct PRResult: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let newRecord: Int       // max reps logged in current session
    let previousBest: Int    // max reps in all prior sessions (0 if first time)
}
