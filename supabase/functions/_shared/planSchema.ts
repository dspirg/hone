// Single source of truth for plan JSON Schema used by OpenAI Structured Outputs.
// Imported by: generate-plan, coach-chat, adapt-plan, regenerate-plan.
// additionalProperties: false at EVERY level for strict mode compliance.
export const planSchema = {
  type: "object" as const,
  properties: {
    plan_name: { type: "string" as const },
    goal_summary: { type: "string" as const },
    weekly_days: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          day_label: { type: "string" as const },
          session_name: { type: "string" as const },
          exercises: {
            type: "array" as const,
            items: {
              type: "object" as const,
              properties: {
                exercise_name: { type: "string" as const },
                sets: { type: "integer" as const },
                reps: { type: "string" as const },
                rest_seconds: { type: "integer" as const },
                rationale: { type: "string" as const },
              },
              required: ["exercise_name", "sets", "reps", "rest_seconds", "rationale"],
              additionalProperties: false,
            },
          },
        },
        required: ["day_label", "session_name", "exercises"],
        additionalProperties: false,
      },
    },
  },
  required: ["plan_name", "goal_summary", "weekly_days"],
  additionalProperties: false,
};
