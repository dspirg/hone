import Foundation
import Observation

// MARK: - HomeViewModel
// Stub for Phase 11 Home screen rebuild (Plan 02).
// Properties are declared here so Wave 0 test stubs compile before the full rebuild.
// Full implementation in Plan 02 (HomeView rebuild).
//
// Requirements: UI-04, UI-05

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - State

    var isLoading: Bool = true
    var activePlan: WorkoutPlan? = nil
    var totalPRs: Int = 0
    var totalSessions: Int = 0
    var totalSets: Int = 0
    var showSession: Bool = false

    // MARK: - Computed

    /// Time-of-day greeting prefix ("Good morning", "Good afternoon", "Good evening")
    /// based on the current hour. Falls back gracefully when hour is outside expected ranges.
    var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
}
