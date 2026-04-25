// JSON Schema for OpenAI Structured Outputs — adapted plan format.
// Single source of truth. Must stay in sync with adaptedPlanSchema.ts (Zod).
// Rule: additionalProperties: false at EVERY level; every property in required[]

export const adaptedPlanJsonSchema = {
  type: "object" as const,
  properties: {
    adjustment_summary: { type: "string" as const },
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
  required: ["adjustment_summary", "weekly_days"],
  additionalProperties: false,
};
