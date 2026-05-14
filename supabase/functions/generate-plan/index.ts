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
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { planSchema } from "../_shared/planSchema.ts";
import { getAllowedEquipmentTags, fetchFilteredExercises } from "../_shared/equipmentFilter.ts";

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
    session_minutes: number;
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

  // T-03-02: Length limits on user-supplied strings — prevents prompt injection and token abuse.
  // The Edge Function is an independent API surface; the iOS client's UI constraints do not
  // protect against direct HTTP callers.
  const MAX_GOAL_LEN = 100;
  const MAX_LEVEL_LEN = 50;
  const MAX_INJURIES_LEN = 500;

  if (
    profile.goal.length > MAX_GOAL_LEN ||
    profile.fitness_level.length > MAX_LEVEL_LEN ||
    (typeof profile.injuries === "string" && profile.injuries.length > MAX_INJURIES_LEN) ||
    profile.days_per_week < 1 || profile.days_per_week > 7 ||
    !Array.isArray(profile.equipment) || profile.equipment.length > 20
  ) {
    return new Response(
      JSON.stringify({ error: "Profile field exceeds allowed length or range" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Truncate as defense-in-depth even after validation (prevents races on boundary values).
  const safeGoal = profile.goal.slice(0, MAX_GOAL_LEN);
  const safeLevel = profile.fitness_level.slice(0, MAX_LEVEL_LEN);
  const safeInjuries = typeof profile.injuries === "string"
    ? profile.injuries.slice(0, MAX_INJURIES_LEN)
    : "";

  // Filter exercises by user's available equipment
  const userEquipment: string[] = Array.isArray(profile.equipment)
    ? profile.equipment.map((e: string) => e.trim())
    : [];
  const allowedTags = getAllowedEquipmentTags(userEquipment);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  let exerciseNameList = "";
  let exerciseNameSet = new Set<string>();
  let exerciseNameLower = new Map<string, string>();
  try {
    const db = createClient(supabaseUrl, supabaseServiceKey);
    const result = await fetchFilteredExercises(db, allowedTags);
    exerciseNameList = result.nameList;
    exerciseNameSet = result.nameSet;
    exerciseNameLower = result.nameLower;
  } catch {
    // If fetch fails, continue without constraint — AI will use generic names
  }

  // Build system prompt injecting all user profile fields (AIPL-04, D-12)
  // T-03-02: injuries goes into a structured slot within the system prompt —
  // OpenAI safety layer and Structured Outputs schema provide secondary defense.
  const equipmentList = Array.isArray(profile.equipment)
    ? profile.equipment.slice(0, 20).join(", ")
    : String(profile.equipment);

  const sessionMinutes = profile.session_minutes || 45;

  let systemPrompt = `You are a professional fitness coach. Generate a personalized ${profile.days_per_week}-day weekly workout plan.

User profile:
- Goal: ${safeGoal}
- Fitness Level: ${safeLevel}
- Training Days: ${profile.days_per_week} days per week
- Session Length: ${sessionMinutes} minutes per session
- Available Equipment: ${equipmentList}`;

  // Only include injuries section when the user provided input (SAFE-02, D-12)
  if (safeInjuries.trim() !== "") {
    systemPrompt += `\n- Areas to avoid or modify around: ${safeInjuries}`;
  }

  systemPrompt += `

For each exercise, provide a rationale explaining why it was chosen for this user's specific goal and available equipment. This rationale will be displayed to the user as a coach note.

Generate exactly ${profile.days_per_week} training days.

VOLUME REQUIREMENTS — fit each session into ${sessionMinutes} minutes:
- 30 min sessions: 4-5 exercises, 12-16 total sets, favor compound supersets, shorter rest (45-60s)
- 45 min sessions: 5-6 exercises, 16-20 total sets, 2-3 compounds + 2-3 accessories, 60-90s rest
- 60 min sessions: 6-8 exercises, 20-25 total sets, 2-3 compounds (3-4 sets) + 3-5 accessories (3 sets), 60-90s rest
- 90 min sessions: 8-10 exercises, 25-32 total sets, 3-4 compounds (4 sets) + 4-6 accessories (3 sets), 90-120s rest on compounds
Choose the row matching ${sessionMinutes} minutes. Adjust rest_seconds per exercise accordingly.

CARDIO GUIDELINES:
- For goals like "Tone & Sculpt", "Lose Fat", "Get Fitter", or "Stay Active": include 1-2 cardio exercises per session as a warmup, finisher, or dedicated cardio block.
- For "Build Muscle" or "Athletic Performance": include a 5-min cardio warmup as the first exercise.
- Cardio exercises use the existing schema: sets=1, reps="duration and settings" (e.g. "20 min — Speed 3, Incline 5"), rest_seconds=0.
- If the user has Full gym equipment, use specific machines with settings: Treadmill (speed + incline), Stairclimber (level), Stationary Bike (resistance + RPM), Rowing Machine (pace).
- If No equipment or limited equipment: use bodyweight cardio like "Jumping Jacks", "High Knees", "Burpees", or "Jump Rope" with timed intervals (e.g. "3 rounds — 40 sec on, 20 sec rest").
- Cardio exercises do NOT need to match the exercise name database — you may use generic names for cardio machines.
- Always include specific, actionable settings (speed, incline, resistance, duration) so the user knows exactly what to do.`;

  // Constrain exercise names to database entries (ensures videos/thumbnails exist)
  if (exerciseNameList) {
    systemPrompt += `

CRITICAL RULE — EXERCISE NAMES:
You MUST copy exercise names EXACTLY from the list below. Do not paraphrase, abbreviate, combine words, or invent exercise names. Every exercise_name in your response must be a verbatim copy-paste from this list. If you cannot find an exact match, pick the closest alternative from the list.

For example:
- WRONG: "Barbell Overhead Press" (not in list)
- RIGHT: "Barbell seated overhead press" (exact match from list)
- WRONG: "Cable Tricep Pressdown" (not in list)
- RIGHT: "cable triceps push down straight bar" (exact match from list)

Available exercises:
${exerciseNameList}`;
  }

  systemPrompt += `

SAFETY: You are not a medical professional. Do not diagnose conditions, prescribe treatments, or provide medical advice. If the user mentions pain, injury, or health concerns, recommend they consult a physician before training.`;

  // Call OpenAI with Structured Outputs — NON-streaming so we can validate
  const openAIResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-2024-08-06",
      stream: false,
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

  if (!openAIResponse.ok) {
    const errorBody = await openAIResponse.text();
    console.error(`generate-plan: OpenAI API error ${openAIResponse.status}: ${errorBody}`);
    return new Response(
      JSON.stringify({ error: "OpenAI API error", status: openAIResponse.status, detail: errorBody }),
      { status: openAIResponse.status, headers: { "Content-Type": "application/json" } }
    );
  }

  // Parse the complete response
  const result = await openAIResponse.json();
  const planJSON = result.choices?.[0]?.message?.content ?? "{}";

  // Validate and correct exercise names against the database
  let plan;
  try {
    plan = JSON.parse(planJSON);
  } catch {
    return new Response(
      JSON.stringify({ error: "Failed to parse AI response" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  if (plan.weekly_days && exerciseNameSet.size > 0) {
    for (const day of plan.weekly_days) {
      if (!day.exercises) continue;
      for (const exercise of day.exercises) {
        const aiName = exercise.exercise_name;
        if (!aiName) continue;

        // Already exact match
        if (exerciseNameSet.has(aiName)) continue;

        // Case-insensitive match
        const lowerMatch = exerciseNameLower.get(aiName.toLowerCase());
        if (lowerMatch) {
          exercise.exercise_name = lowerMatch;
          continue;
        }

        // Word-based search: find an exercise containing all significant words (any order)
        const words = aiName.split(/\s+/).filter((w: string) => w.length > 2).map((w: string) => w.toLowerCase());
        let found = false;
        for (const [dbLower, dbName] of exerciseNameLower) {
          if (words.every((w: string) => dbLower.includes(w))) {
            exercise.exercise_name = dbName;
            found = true;
            break;
          }
        }
        if (found) continue;

        // Best-overlap match: score each DB exercise by how many AI words it contains,
        // pick the one with the highest overlap. This handles cases where the AI adds
        // or changes a word (e.g., "Seated" instead of "Standing").
        let bestScore = 0;
        let bestMatch = "";
        for (const [dbLower, dbName] of exerciseNameLower) {
          const dbWords = dbLower.split(/\s+/);
          let score = 0;
          for (const w of words) {
            if (dbLower.includes(w)) score += 2; // AI word found in DB name
          }
          for (const dw of dbWords) {
            if (dw.length > 2 && words.some((w: string) => w === dw)) score += 1; // exact word match bonus
          }
          if (score > bestScore) {
            bestScore = score;
            bestMatch = dbName;
          }
        }
        // Require at least half the AI words to match
        if (bestScore >= words.length && bestMatch) {
          exercise.exercise_name = bestMatch;
        }
      }
    }
  }

  // Re-serialize the corrected plan and stream it as SSE (client expects SSE format)
  const correctedJSON = JSON.stringify(plan);
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      // Send the plan in chunks to simulate streaming (client shows progressive text)
      const chunkSize = 20;
      for (let i = 0; i < correctedJSON.length; i += chunkSize) {
        const chunk = correctedJSON.slice(i, i + chunkSize);
        const sseChunk = {
          choices: [{ delta: { content: chunk }, index: 0, finish_reason: null }],
        };
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(sseChunk)}\n\n`));
      }
      // Send finish + [DONE]
      const finishChunk = {
        choices: [{ delta: {}, index: 0, finish_reason: "stop" }],
      };
      controller.enqueue(encoder.encode(`data: ${JSON.stringify(finishChunk)}\n\n`));
      controller.enqueue(encoder.encode("data: [DONE]\n\n"));
      controller.close();
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
