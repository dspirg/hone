import Foundation

// MARK: - AdaptedPlanResponse
// Response from adapt-plan and regenerate-plan Edge Functions.
// Matches the Zod AdaptedPlanSchema defined in _shared/adaptedPlanSchema.ts.
// Keys use snake_case to match the Edge Function JSON response.
//
// Threat: T-08-11 — Bearer token is supplied by AdaptationService; never stored in this model.

struct AdaptedPlanResponse: Codable, Sendable {
    let adjustmentSummary: String
    let weeklyDays: [AdaptedDay]

    enum CodingKeys: String, CodingKey {
        case adjustmentSummary = "adjustment_summary"
        case weeklyDays = "weekly_days"
    }
}

struct AdaptedDay: Codable, Sendable {
    let dayLabel: String
    let sessionName: String
    let exercises: [AdaptedExercise]

    enum CodingKeys: String, CodingKey {
        case dayLabel = "day_label"
        case sessionName = "session_name"
        case exercises
    }
}

struct AdaptedExercise: Codable, Sendable {
    let exerciseName: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let rationale: String

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case sets, reps
        case restSeconds = "rest_seconds"
        case rationale
    }
}

// MARK: - AdaptPlanRequest
// Request body sent to adapt-plan Edge Function.
// trigger_type enum: "post_session" | "missed_session" | "weekly"

struct AdaptPlanRequest: Codable, Sendable {
    let triggerType: String
    let currentRating: String?
    let missedSessions: [String]?

    enum CodingKeys: String, CodingKey {
        case triggerType = "trigger_type"
        case currentRating = "current_rating"
        case missedSessions = "missed_sessions"
    }
}
