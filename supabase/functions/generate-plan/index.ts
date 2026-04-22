// Phase 3: AI Plan Generation Edge Function
// Requirements: AIPL-01, AIPL-02, AIPL-04
// Security: T-03-01 (API key from env), T-03-02 (injuries as structured slot), T-03-05 (auth header)
//
// Receives user profile, constructs system prompt, calls OpenAI GPT-4o with
// Structured Outputs and SSE streaming, then forwards the stream to the client.
//
// The iOS client MUST send Authorization: Bearer <token> manually because the
// Supabase Swift SDK invokeWithStreamedResponse does not forward the JWT (bug #634).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// JSON Schema for OpenAI Structured Outputs (strict mode).
// additionalProperties: false is required at EVERY object level in strict mode.
// The injuries field is NOT in the output schema — it only affects the system prompt.
// All fields must appear in required[] for strict mode compliance.
const planSchema = {
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

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
      },
    });
  }

  // T-03-01: Fail fast if API key is not set — never hardcode
  const openAIKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAIKey) {
    return new Response(
      JSON.stringify({ error: "OPENAI_API_KEY is not configured" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // T-03-05: Validate Authorization header. iOS client sends Bearer <token> manually
  // because the Supabase Swift SDK invokeWithStreamedResponse drops the JWT (bug #634).
  // Hard-reject requests with no Bearer token — Supabase Edge Functions do NOT
  // auto-verify JWTs unless verify_jwt = true is set in config.toml (off by default).
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  let profile: {
    goal: string;
    fitness_level: string;
    days_per_week: number;
    equipment: string[];
    injuries: string;
  };

  try {
    profile = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // Validate required fields
  if (!profile.goal || !profile.fitness_level || !profile.days_per_week || !profile.equipment) {
    return new Response(
      JSON.stringify({ error: "Missing required profile fields: goal, fitness_level, days_per_week, equipment" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // Build system prompt injecting all user profile fields (AIPL-04, D-12)
  // T-03-02: injuries goes into a structured slot within the system prompt —
  // OpenAI safety layer and Structured Outputs schema provide secondary defense.
  const equipmentList = Array.isArray(profile.equipment)
    ? profile.equipment.join(", ")
    : String(profile.equipment);

  let systemPrompt = `You are a professional fitness coach. Generate a personalized ${profile.days_per_week}-day weekly workout plan.

User profile:
- Goal: ${profile.goal}
- Fitness Level: ${profile.fitness_level}
- Training Days: ${profile.days_per_week} days per week
- Available Equipment: ${equipmentList}`;

  // Only include injuries section when the user provided input (SAFE-02, D-12)
  if (typeof profile.injuries === "string" && profile.injuries.trim() !== "") {
    systemPrompt += `\n- Areas to avoid or modify around: ${profile.injuries}`;
  }

  systemPrompt += `

For each exercise, provide a rationale explaining why it was chosen for this user's specific goal and available equipment. This rationale will be displayed to the user as a coach note.

Generate exactly ${profile.days_per_week} training days.

SAFETY: You are not a medical professional. Do not diagnose conditions, prescribe treatments, or provide medical advice. If the user mentions pain, injury, or health concerns, recommend they consult a physician before training.`;

  // Call OpenAI with Structured Outputs and SSE streaming
  const openAIResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-2024-08-06",  // minimum version for Structured Outputs
      stream: true,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "workout_plan",
          strict: true,
          schema: planSchema,
        },
      },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: "Generate my personalized weekly workout plan." },
      ],
    }),
  });

  // On OpenAI API error, return error JSON — not a 200 with error text in the stream
  if (!openAIResponse.ok) {
    const errorBody = await openAIResponse.text();
    console.error(`generate-plan: OpenAI API error ${openAIResponse.status}: ${errorBody}`);
    return new Response(
      JSON.stringify({
        error: "OpenAI API error",
        status: openAIResponse.status,
        detail: errorBody,
      }),
      {
        status: openAIResponse.status,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // Forward the SSE stream directly to the client (passthrough)
  return new Response(openAIResponse.body, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
