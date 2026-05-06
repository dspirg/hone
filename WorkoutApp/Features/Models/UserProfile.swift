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
    let sessionMinutes: Int
    let equipment: [String]
    let injuries: String  // empty string = no injuries (Structured Outputs requires non-optional)
    var weightUnit: String = "lbs"

    enum CodingKeys: String, CodingKey {
        case goal
        case fitnessLevel = "fitness_level"
        case daysPerWeek = "days_per_week"
        case sessionMinutes = "session_minutes"
        case equipment, injuries
        case weightUnit = "weight_unit"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decode(String.self, forKey: .goal)
        fitnessLevel = try container.decode(String.self, forKey: .fitnessLevel)
        daysPerWeek = try container.decode(Int.self, forKey: .daysPerWeek)
        sessionMinutes = try container.decode(Int.self, forKey: .sessionMinutes)
        equipment = try container.decode([String].self, forKey: .equipment)
        injuries = try container.decode(String.self, forKey: .injuries)
        weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit) ?? "lbs"
    }

    init(
        goal: String,
        fitnessLevel: String,
        daysPerWeek: Int,
        sessionMinutes: Int,
        equipment: [String],
        injuries: String,
        weightUnit: String = "lbs"
    ) {
        self.goal = goal
        self.fitnessLevel = fitnessLevel
        self.daysPerWeek = daysPerWeek
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.injuries = injuries
        self.weightUnit = weightUnit
    }
}
