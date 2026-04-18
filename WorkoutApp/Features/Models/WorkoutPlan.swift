import Foundation

// MARK: - WorkoutPlan
// Codable struct mirroring the OpenAI Structured Outputs JSON schema exactly.
// CodingKeys map Swift camelCase properties to JSON snake_case keys produced by GPT-4o.
// The schema contract is defined in supabase/functions/generate-plan/index.ts.
// Requirements: AIPL-01 (AI-generated plans), AIPL-02 (rationale per exercise)

struct WorkoutPlan: Codable, Equatable, Sendable {
    let planName: String
    let goalSummary: String
    let weeklyDays: [WorkoutDay]

    enum CodingKeys: String, CodingKey {
        case planName = "plan_name"
        case goalSummary = "goal_summary"
        case weeklyDays = "weekly_days"
    }
}

struct WorkoutDay: Codable, Equatable, Identifiable, Sendable {
    let dayLabel: String
    let sessionName: String
    let exercises: [PlannedExercise]

    // Identifiable conformance — dayLabel is stable within a plan
    var id: String { dayLabel }

    enum CodingKeys: String, CodingKey {
        case dayLabel = "day_label"
        case sessionName = "session_name"
        case exercises
    }
}

struct PlannedExercise: Codable, Equatable, Identifiable, Sendable {
    let exerciseName: String
    let sets: Int
    let reps: String          // String allows "8-12" rep ranges
    let restSeconds: Int
    let rationale: String     // AIPL-02: coach explanation, non-optional, required by schema

    // Identifiable conformance — exerciseName is stable within a day
    var id: String { exerciseName }

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case sets, reps
        case restSeconds = "rest_seconds"
        case rationale
    }
}

// MARK: - PlanPromptBuilder
// Constructs the AI system prompt from the user's profile.
// Mirrors the prompt logic in the Deno Edge Function for local unit testing.
// AIPL-04: equipment array from user profile appears in system prompt text.
// SAFE-02: safety guardrail instructs model not to provide medical advice.
enum PlanPromptBuilder {
    static func buildSystemPrompt(profile: UserProfile) -> String {
        var prompt = """
        You are a professional fitness coach. Generate a personalized \(profile.daysPerWeek)-day weekly workout plan.

        User profile:
        - Goal: \(profile.goal)
        - Fitness Level: \(profile.fitnessLevel)
        - Training Days: \(profile.daysPerWeek) days per week
        - Available Equipment: \(profile.equipment.joined(separator: ", "))
        """

        // Only include injuries section if the user provided input (D-12)
        if !profile.injuries.isEmpty {
            prompt += "\n        - Areas to avoid or modify around: \(profile.injuries)"
        }

        prompt += """

        For each exercise, provide a rationale explaining why it was chosen for this user's specific goal and available equipment.

        SAFETY: You are not a medical professional. Do not diagnose conditions or prescribe treatments. If the user mentions pain or injury, recommend consulting a physician.
        """

        return prompt
    }
}
