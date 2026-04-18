import Foundation

// MARK: - UserProfile
// Encodable struct representing the user's fitness profile.
// Sent as the JSON request body to the generate-plan Supabase Edge Function.
//
// Design notes:
// - `injuries` is a required String (NOT optional) because OpenAI Structured Outputs
//   strict mode requires all fields in `required[]` — nullable/optional fields are
//   unsupported. An empty string ("") is the sentinel for "no injuries".
// - `equipment` is [String] matching the TEXT[] column in the profiles table.
// - CodingKeys map Swift camelCase to the snake_case expected by the Edge Function.
//
// Requirements: AIPL-01 (profile sent to AI), AIPL-04 (equipment in system prompt)

struct UserProfile: Codable, Equatable, Sendable {
    let goal: String
    let fitnessLevel: String
    let daysPerWeek: Int
    let equipment: [String]
    let injuries: String  // empty string = no injuries (Structured Outputs requires non-optional)

    enum CodingKeys: String, CodingKey {
        case goal
        case fitnessLevel = "fitness_level"
        case daysPerWeek = "days_per_week"
        case equipment, injuries
    }
}
