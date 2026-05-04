// Phase 8: Post-session and missed-session adaptation Edge Function
// Requirements: ADPT-01, ADPT-03
// Security: T-08-06 (user_id from JWT), T-08-07 (rating enum validation),
//           T-08-08 (rate log), T-08-09 (sanitizeRationale), T-08-10 (enum, no injection)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AdaptedPlanSchema } from "../_shared/adaptedPlanSchema.ts";
import { assertPromptBudget, stripRationale, sanitizeRationale } from "../_shared/promptBuilder.ts";
import { adaptedPlanJsonSchema } from "../_shared/adaptedPlanJsonSchema.ts";

// ─── Interfaces ──────────────────────────────────────────────────────────────

interface AdaptPlanRequest {
  trigger_type: "post_session" | "missed_session";
  current_rating?: string;       // "too_easy" | "just_right" | "too_hard"
  missed_sessions?: string[];    // ISO date strings of missed days
}

interface DifficultyRatingEntry {
  session_date: string;
  workout_name: string;
  rating: "too_easy" | "just_right" | "too_hard";
}

interface PerformanceTrend {
  exercise_name: string;
  average_completion_rate: number;
  trend: "improving" | "plateau" | "declining";
}

// ─── OpenAI response types ────────────────────────────────────────────────────

interface OpenAIChatResponse {
  choices: Array<{
    message: {
      content: string;
      refusal?: string;
    };
    finish_reason: "stop" | "length" | "content_filter" | "tool_calls";
  }>;
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

// ─── Performance trend computation ───────────────────────────────────────────

function computePerformanceTrends(
  setLogs: Array<{ exercise_name: string; target_reps: string; reps_logged: string }>
): PerformanceTrend[] {
  // Group set_logs by exercise_name
  const grouped = new Map<string, { completionRates: number[] }>();

  for (const log of setLogs) {
    const target = parseInt(log.target_reps ?? "0", 10);
    const logged = parseInt(log.reps_logged ?? "0", 10);
    if (target <= 0) continue;
    const rate = Math.min(logged / target, 1.5); // cap at 150% to avoid outliers

    if (!grouped.has(log.exercise_name)) {
      grouped.set(log.exercise_name, { completionRates: [] });
    }
    grouped.get(log.exercise_name)!.completionRates.push(rate);
  }

  const trends: PerformanceTrend[] = [];

  for (const [exercise_name, { completionRates }] of grouped.entries()) {
    if (completionRates.length === 0) continue;
    const average_completion_rate =
      completionRates.reduce((s, r) => s + r, 0) / completionRates.length;

    // Trend: compare last 2 entries vs average
    let trend: "improving" | "plateau" | "declining" = "plateau";
    if (completionRates.length >= 2) {
      const recent = completionRates.slice(-2);
      const recentAvg = (recent[0] + recent[1]) / 2;
      if (recentAvg > average_completion_rate + 0.05) {
        trend = "improving";
      } else if (recentAvg < average_completion_rate - 0.05) {
        trend = "declining";
      }
    }

    trends.push({ exercise_name, average_completion_rate, trend });
  }

  // Return top 5 by completion rate (highest completion rate first)
  return trends
    .sort((a, b) => b.average_completion_rate - a.average_completion_rate)
    .slice(0, 5);
}

// ─── System prompt builder ────────────────────────────────────────────────────

function buildAdaptationSystemPrompt(
  profile: { goal: string; fitness_level: string; equipment: string[]; injuries?: string },
  currentPlan: Record<string, unknown>,
  recentRatings: DifficultyRatingEntry[],
  performanceTrends: PerformanceTrend[],
  missedSessions: string[],
  weeksOnPlan: number,
  exerciseNameList?: string,
): string {
  const compactPlan = stripRationale(currentPlan);

  const ratingsBlock = recentRatings.length > 0
    ? recentRatings
        .map((r) => `- ${r.session_date}: ${r.workout_name} — ${r.rating.replace(/_/g, " ")}`)
        .join("\n")
    : "No difficulty ratings recorded yet.";

  const trendsBlock = performanceTrends.length > 0
    ? performanceTrends
        .map(
          (t) =>
            `- ${t.exercise_name}: ${Math.round(t.average_completion_rate * 100)}% completion, ${t.trend}`
        )
        .join("\n")
    : "Insufficient data for trends.";

  const missedBlock =
    missedSessions.length > 0
      ? `Missed planned training days: ${missedSessions.join(", ")}`
      : "No missed sessions.";

  const injuriesLine = profile.injuries ? `\n- Limitations: ${profile.injuries}` : "";

  return `You are a professional fitness coach adapting a user's workout plan based on their feedback.

User profile:
- Goal: ${profile.goal}
- Fitness Level: ${profile.fitness_level}
- Equipment: ${Array.isArray(profile.equipment) ? profile.equipment.join(", ") : profile.equipment}${injuriesLine}

Current plan (${weeksOnPlan} week(s) on this plan):
${JSON.stringify(compactPlan)}

Recent session difficulty ratings (last 4 sessions):
${ratingsBlock}

Exercise completion trends (top exercises by volume):
${trendsBlock}

${missedBlock}

ADAPTATION RULES:
1. Two or more consecutive "too hard" ratings: reduce working volume by 10-15% — remove 1 set per exercise or reduce reps by 2. Do not increase difficulty anywhere in the plan during this adjustment.
2. Three or more consecutive "too easy" ratings: increase volume by 10-15% — add 1 set or increase reps by 2. Never increase volume for any exercise with completion rate below 80%.
3. "Just right" ratings or mixed signals: maintain current volume. Fine-tune rest periods if needed. Swap a stale accessory exercise only if the user has been on this plan 4+ weeks.
4. Missed sessions: redistribute key compound exercises (squat, deadlift, bench press, row) from the missed day across remaining training days at reduced volume (not full volume). Drop isolation work from missed days — never stack it.
5. Exercise continuity: do not replace an exercise the user has been completing at 80%+ unless an adaptation rule requires it. Strength gains are movement-specific.

In adjustment_summary: write 1-2 sentences in coach voice (second person, no jargon) explaining what changed and why. This text is shown directly to the user. Example: "Pulled back the pressing volume slightly — you rated the last two sessions as too hard. Everything else stays the same."

SAFETY: You are not a medical professional. Do not prescribe exercises that could aggravate reported injuries or limitations. Do not frame this as medical advice.` + (exerciseNameList ? `

IMPORTANT: When swapping exercises, you MUST only use exercise names from this list. Use the exact name as written.

Available exercises: ${exerciseNameList}` : "");
}

// ─── OpenAI call helper (supports retry) ─────────────────────────────────────

async function callOpenAI(
  openAIKey: string,
  systemPrompt: string,
  isRetry: boolean
): Promise<{ ok: false; status: number; error: string } | { ok: true; response: OpenAIChatResponse }> {
  const userMessage = isRetry
    ? [
        "Generate the adapted workout plan based on the feedback data.",
        "IMPORTANT: Ensure every exercise has all five required fields: exercise_name, sets, reps, rest_seconds, rationale.",
        "Ensure adjustment_summary is between 10 and 500 characters.",
      ].join(" ")
    : "Generate the adapted workout plan based on the feedback data.";

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-2024-08-06",
      stream: false,
      max_completion_tokens: 2000,
      temperature: 0.3,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "adapted_plan",
          strict: true,
          schema: adaptedPlanJsonSchema,
        },
      },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userMessage },
      ],
    }),
  });

  if (!res.ok) {
    const errorBody = await res.text();
    console.error(`adapt-plan: OpenAI error ${res.status}: ${errorBody}`);
    return { ok: false, status: res.status, error: "OpenAI API error" };
  }

  const json = (await res.json()) as OpenAIChatResponse;
  return { ok: true, response: json };
}

// ─── Entry point ──────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  // CORS preflight
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

  // T-08-01: Fail fast on missing API key
  const openAIKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAIKey) {
    return new Response(JSON.stringify({ error: "OPENAI_API_KEY not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // T-08-06: Validate Bearer token — user_id comes from the JWT, never from the request body
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const token = authHeader.slice(7);

  // Parse body
  let body: AdaptPlanRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // T-08-07: Validate trigger_type enum
  const allowedTriggers = ["post_session", "missed_session"] as const;
  if (!allowedTriggers.includes(body.trigger_type as typeof allowedTriggers[number])) {
    return new Response(
      JSON.stringify({ error: "Invalid trigger_type. Must be 'post_session' or 'missed_session'" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Validate current_rating for post_session triggers
  const allowedRatings = ["too_easy", "just_right", "too_hard"] as const;
  if (body.trigger_type === "post_session") {
    if (!body.current_rating || !allowedRatings.includes(body.current_rating as typeof allowedRatings[number])) {
      return new Response(
        JSON.stringify({ error: "current_rating is required for post_session trigger and must be 'too_easy', 'just_right', or 'too_hard'" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  }

  // T-08-06: Extract user_id from the Supabase JWT
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Verify JWT and extract user_id via anon client
  const anonClient = createClient(supabaseUrl, supabaseAnonKey);
  const { data: { user }, error: authError } = await anonClient.auth.getUser(token);

  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized: invalid or expired token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userId = user.id;

  // T-08-08: Rate of calls log — placeholder for future rate limiting
  console.warn(`adapt-plan: invoked by user ${userId} at ${new Date().toISOString()} trigger=${body.trigger_type}`);

  // Service-role client for data queries
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // ── Parallel data assembly (AI-SPEC Section 4b.2) ──────────────────────────
  const [sessionLogsResult, currentPlanResult, profileResult] = await Promise.all([
    supabase
      .from("session_logs")
      .select("difficulty_rating, started_at, workout_day_label")
      .eq("user_id", userId)
      .not("difficulty_rating", "is", null)
      .order("started_at", { ascending: false })
      .limit(4),
    supabase
      .from("workout_plans")
      .select("plan_json, id")
      .eq("user_id", userId)
      .eq("is_active", true)
      .single(),
    supabase
      .from("profiles")
      .select("goal, fitness_level, equipment, injuries")
      .eq("id", userId)
      .single(),
  ]);

  if (currentPlanResult.error || !currentPlanResult.data) {
    console.error(`adapt-plan: no active plan for user ${userId}:`, currentPlanResult.error);
    return new Response(JSON.stringify({ error: "No active plan found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (profileResult.error || !profileResult.data) {
    console.error(`adapt-plan: profile not found for user ${userId}:`, profileResult.error);
    return new Response(JSON.stringify({ error: "User profile not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const currentPlan = currentPlanResult.data.plan_json as Record<string, unknown>;
  const planId = currentPlanResult.data.id as string;
  const profile = profileResult.data as {
    goal: string;
    fitness_level: string;
    equipment: string[];
    injuries?: string;
  };

  // Build recent ratings from session_logs
  const sessionLogs = (sessionLogsResult.data ?? []) as Array<{
    difficulty_rating: string;
    started_at: string;
    workout_day_label: string;
  }>;

  const recentRatings: DifficultyRatingEntry[] = sessionLogs.map((log) => ({
    session_date: log.started_at.slice(0, 10),
    workout_name: log.workout_day_label ?? "Session",
    rating: log.difficulty_rating as "too_easy" | "just_right" | "too_hard",
  }));

  // ── Set logs for performance trends ────────────────────────────────────────
  const { data: setLogsData } = await supabase
    .from("set_logs")
    .select("exercise_name, target_reps, reps_logged")
    .eq("user_id", userId)
    .order("completed_at", { ascending: false })
    .limit(100);

  const setLogs = (setLogsData ?? []) as Array<{
    exercise_name: string;
    target_reps: string;
    reps_logged: string;
  }>;

  const performanceTrends = computePerformanceTrends(setLogs);

  // WR-03: Sanitize missed_sessions before injecting into the system prompt.
  // User-controlled strings must be validated as ISO date format only (YYYY-MM-DD)
  // and capped at 7 entries to prevent prompt injection and token budget overrun.
  const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
  const missedSessions = (body.missed_sessions ?? [])
    .slice(0, 7)
    .filter((s): s is string => typeof s === "string" && ISO_DATE_RE.test(s));

  // Estimate weeks on current plan (approximate from session_log history)
  const weeksOnPlan = Math.max(1, Math.ceil(sessionLogs.length / 3));

  // Fetch exercise names so AI only uses exercises with videos
  let exerciseNameList: string | undefined;
  try {
    const { data: exercises } = await supabase
      .from("exercises")
      .select("name")
      .not("video_url", "is", null)
      .order("name");
    if (exercises && exercises.length > 0) {
      exerciseNameList = exercises.map((e: { name: string }) => e.name).join(", ");
    }
  } catch {
    // Continue without constraint
  }

  // ── Build system prompt ──────────────────────────────────────────────────────
  const systemPrompt = buildAdaptationSystemPrompt(
    profile,
    currentPlan,
    recentRatings,
    performanceTrends,
    missedSessions,
    weeksOnPlan,
    exerciseNameList,
  );

  // AI-SPEC Section 4: token budget check
  assertPromptBudget(systemPrompt, 1400, "adapt-plan");

  // ── OpenAI call ───────────────────────────────────────────────────────────
  const result = await callOpenAI(openAIKey, systemPrompt, false);

  if (!result.ok) {
    return new Response(JSON.stringify({ error: result.error }), {
      status: result.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const openAIResult = result.response;
  const choice = openAIResult.choices?.[0];

  // Always check finish_reason before trusting content (AI-SPEC Section 3, Pitfall 2)
  if (choice?.finish_reason === "length") {
    console.error("adapt-plan: response truncated (finish_reason=length) — raise max_completion_tokens or reduce prompt");
    return new Response(JSON.stringify({ error: "Response truncated" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (choice?.finish_reason === "content_filter" || choice?.message?.refusal) {
    console.error("adapt-plan: model refusal:", choice?.message?.refusal);
    return new Response(JSON.stringify({ error: "Plan adaptation refused by safety filter" }), {
      status: 422,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse JSON from structured output
  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(choice.message.content);
  } catch (err) {
    console.error("adapt-plan: JSON.parse failed:", (err as Error).message);
    console.error("adapt-plan: raw content (first 300 chars):", choice.message.content?.slice(0, 300));
    return new Response(JSON.stringify({ error: "Plan JSON parse failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── Zod validation (AI-SPEC Section 4b.1) ────────────────────────────────
  let parseResult = AdaptedPlanSchema.safeParse(parsedJson);

  if (!parseResult.success) {
    console.error("adapt-plan: Zod validation failed — issues:", JSON.stringify(parseResult.error.issues, null, 2));
    console.warn("adapt-plan: attempting one retry after Zod validation failure");

    // Retry once with augmented user message
    const retryResult = await callOpenAI(openAIKey, systemPrompt, true);

    if (!retryResult.ok) {
      return new Response(JSON.stringify({ error: "Plan adaptation failed after retry" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const retryChoice = retryResult.response.choices?.[0];

    if (retryChoice?.finish_reason === "length" || retryChoice?.message?.refusal) {
      return new Response(JSON.stringify({ error: "Plan adaptation failed after retry" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    let retryParsed: unknown;
    try {
      retryParsed = JSON.parse(retryChoice.message.content);
    } catch {
      return new Response(JSON.stringify({ error: "Plan JSON parse failed after retry" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    parseResult = AdaptedPlanSchema.safeParse(retryParsed);

    if (!parseResult.success) {
      console.error("adapt-plan: Zod validation failed after retry:", JSON.stringify(parseResult.error.issues, null, 2));
      return new Response(JSON.stringify({ error: "Generated plan failed validation after retry" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  const adaptedPlan = parseResult.data;

  // ── T-08-09: Sanitize clinical language (AI-SPEC Section 6) ──────────────
  const sanitizedSummary = sanitizeRationale(adaptedPlan.adjustment_summary);
  const sanitizedPlan = {
    ...adaptedPlan,
    adjustment_summary: sanitizedSummary,
    weekly_days: adaptedPlan.weekly_days.map((day) => ({
      ...day,
      exercises: day.exercises.map((ex) => ({
        ...ex,
        rationale: sanitizeRationale(ex.rationale),
      })),
    })),
  };

  // ── Write audit log to plan_adaptations ──────────────────────────────────
  const { error: insertError } = await supabase.from("plan_adaptations").insert({
    user_id: userId,
    trigger_type: body.trigger_type,
    adaptation_summary: sanitizedSummary,
    previous_plan: currentPlan,
    adapted_plan: sanitizedPlan,
    cache_key: null, // post_session and missed_session are not cached
    prompt_tokens: openAIResult.usage?.prompt_tokens ?? null,
    completion_tokens: openAIResult.usage?.completion_tokens ?? null,
  });

  if (insertError) {
    console.error("adapt-plan: failed to insert plan_adaptations:", insertError);
    // Non-fatal — return the adapted plan even if audit log fails
  }

  // ── Update user_plans with adapted plan ───────────────────────────────────
  const { error: updateError } = await supabase
    .from("workout_plans")
    .update({ plan_json: sanitizedPlan })
    .eq("id", planId)
    .eq("user_id", userId);

  if (updateError) {
    console.error("adapt-plan: failed to update user_plans:", updateError);
    return new Response(JSON.stringify({ error: "Failed to save adapted plan" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify(sanitizedPlan), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
