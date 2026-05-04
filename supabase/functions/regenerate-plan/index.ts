// Phase 8: Weekly plan regeneration Edge Function
// Requirements: ADPT-02
// Security: T-08-06 (user_id from JWT), T-08-07 (rating enum validation),
//           T-08-08 (rate log), T-08-09 (sanitizeRationale)
//
// Checks the plan_adaptations cache before calling OpenAI — if the user already
// received a regenerated plan this ISO week, returns the cached result immediately.
// On cache miss: assembles a 4-week history summary, calls GPT-4o with exercise
// continuity + progressive overload rules, validates, caches, and updates user_plans.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AdaptedPlanSchema } from "../_shared/adaptedPlanSchema.ts";
import { planSchema } from "../_shared/planSchema.ts";
import { assertPromptBudget, stripRationale, sanitizeRationale } from "../_shared/promptBuilder.ts";

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

// ─── ISO week key helper (D-04, AI-SPEC 4b.5 caching) ───────────────────────

function getISOWeekKey(date: Date): string {
  // WR-02: ISO 8601 week numbering — week 1 is the week containing the first Thursday.
  // The previous approximation produced wrong keys at year boundaries (e.g., Dec 29-31
  // that fall in ISO week 1 of the next year), causing cache misses or double-fires.
  const thursday = new Date(date);
  thursday.setUTCDate(date.getUTCDate() - ((date.getUTCDay() + 6) % 7) + 3);
  const year = thursday.getUTCFullYear();
  const startOfYear = new Date(Date.UTC(year, 0, 1));
  const startOfYearThursday = new Date(startOfYear);
  startOfYearThursday.setUTCDate(1 + ((4 - startOfYear.getUTCDay() + 7) % 7));
  const weekNum = Math.round((thursday.getTime() - startOfYearThursday.getTime()) / 604800000) + 1;
  return `${year}-W${String(weekNum).padStart(2, "0")}`;
}

// ─── History summary helpers ──────────────────────────────────────────────────

function computeAvgCompletionRate(
  setLogs: Array<{ exercise_name: string; target_reps: string; reps_logged: string }>
): number {
  if (setLogs.length === 0) return 0;
  let total = 0;
  let count = 0;
  for (const log of setLogs) {
    const target = parseInt(log.target_reps ?? "0", 10);
    const logged = parseInt(log.reps_logged ?? "0", 10);
    if (target <= 0) continue;
    total += Math.min(logged / target, 1.5);
    count++;
  }
  return count > 0 ? total / count : 0;
}

function topNByCompletionRate(
  setLogs: Array<{ exercise_name: string; target_reps: string; reps_logged: string }>,
  n: number
): string[] {
  const grouped = new Map<string, { total: number; count: number }>();
  for (const log of setLogs) {
    const target = parseInt(log.target_reps ?? "0", 10);
    const logged = parseInt(log.reps_logged ?? "0", 10);
    if (target <= 0) continue;
    const rate = Math.min(logged / target, 1.5);
    const entry = grouped.get(log.exercise_name) ?? { total: 0, count: 0 };
    entry.total += rate;
    entry.count += 1;
    grouped.set(log.exercise_name, entry);
  }
  const sorted = [...grouped.entries()]
    .map(([name, { total, count }]) => ({ name, avg: count > 0 ? total / count : 0 }))
    .sort((a, b) => b.avg - a.avg);
  return sorted.slice(0, n).map((e) => e.name);
}

function bottomNByCompletionRate(
  setLogs: Array<{ exercise_name: string; target_reps: string; reps_logged: string }>,
  n: number
): string[] {
  const grouped = new Map<string, { total: number; count: number }>();
  for (const log of setLogs) {
    const target = parseInt(log.target_reps ?? "0", 10);
    const logged = parseInt(log.reps_logged ?? "0", 10);
    if (target <= 0) continue;
    const rate = Math.min(logged / target, 1.5);
    const entry = grouped.get(log.exercise_name) ?? { total: 0, count: 0 };
    entry.total += rate;
    entry.count += 1;
    grouped.set(log.exercise_name, entry);
  }
  const sorted = [...grouped.entries()]
    .map(([name, { total, count }]) => ({ name, avg: count > 0 ? total / count : 0 }))
    .filter((e) => e.avg > 0) // only include exercises with data
    .sort((a, b) => a.avg - b.avg);
  return sorted.slice(0, n).map((e) => e.name);
}

function summarizeRatingsTrend(
  sessionLogs: Array<{ difficulty_rating?: string | null; started_at: string }>
): string {
  const ratings = sessionLogs
    .filter((l) => l.difficulty_rating != null)
    .map((l) => l.difficulty_rating as string);
  if (ratings.length === 0) return "no ratings recorded";
  const counts = { too_easy: 0, just_right: 0, too_hard: 0 };
  for (const r of ratings) {
    if (r === "too_easy") counts.too_easy++;
    else if (r === "just_right") counts.just_right++;
    else if (r === "too_hard") counts.too_hard++;
  }
  const parts: string[] = [];
  if (counts.too_easy > 0) parts.push(`${counts.too_easy} too easy`);
  if (counts.just_right > 0) parts.push(`${counts.just_right} just right`);
  if (counts.too_hard > 0) parts.push(`${counts.too_hard} too hard`);
  return parts.join(", ");
}

// ─── OpenAI call helper (supports retry) ─────────────────────────────────────

async function callOpenAIForRegeneration(
  openAIKey: string,
  systemPrompt: string,
  isRetry: boolean
): Promise<{ ok: false; status: number; error: string } | { ok: true; response: OpenAIChatResponse }> {
  const userMessage = isRetry
    ? [
        "Generate the regenerated weekly workout plan based on the history data.",
        "IMPORTANT: Ensure every exercise has all five required fields: exercise_name, sets, reps, rest_seconds, rationale.",
        "Ensure the plan includes plan_name, goal_summary, and weekly_days.",
      ].join(" ")
    : "Generate the regenerated weekly workout plan based on the history data.";

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-2024-08-06",
      stream: false,
      max_completion_tokens: 2500,
      temperature: 0.4,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "regenerated_plan",
          strict: true,
          schema: planSchema,
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
    console.error(`regenerate-plan: OpenAI error ${res.status}: ${errorBody}`);
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

  // Parse body (empty body is valid — user_id comes from JWT)
  try {
    const bodyText = await req.text();
    if (bodyText.trim() !== "" && bodyText.trim() !== "{}") {
      // Allow empty or empty-object body; ignore other content
    }
  } catch {
    // Body parsing failure is non-fatal — we do not require any body fields
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
  console.warn(`regenerate-plan: invoked by user ${userId} at ${new Date().toISOString()}`);

  // Service-role client for data queries
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // ── Cache check (D-04, AI-SPEC 4b.5 Pitfall 5) ────────────────────────────
  // Prevent duplicate Monday calls — if a regenerated plan exists for this ISO week, return it
  const isoWeek = getISOWeekKey(new Date());

  const { data: cached } = await supabase
    .from("plan_adaptations")
    .select("adapted_plan")
    .eq("cache_key", `${userId}-${isoWeek}`)
    .eq("trigger_type", "weekly")
    .single();

  if (cached?.adapted_plan) {
    return new Response(JSON.stringify(cached.adapted_plan), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "X-Cache": "HIT",
      },
    });
  }

  // ── Data assembly on cache miss ───────────────────────────────────────────
  const fourWeeksAgo = new Date();
  fourWeeksAgo.setDate(fourWeeksAgo.getDate() - 28);
  const fourWeeksAgoISO = fourWeeksAgo.toISOString();

  const [currentPlanResult, profileResult, sessionLogsResult] = await Promise.all([
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
    supabase
      .from("session_logs")
      .select("difficulty_rating, started_at, workout_day_label")
      .eq("user_id", userId)
      .gte("started_at", fourWeeksAgoISO)
      .order("started_at", { ascending: false })
      .limit(50),
  ]);

  if (currentPlanResult.error || !currentPlanResult.data) {
    console.error(`regenerate-plan: no active plan for user ${userId}:`, currentPlanResult.error);
    return new Response(JSON.stringify({ error: "No active plan found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (profileResult.error || !profileResult.data) {
    console.error(`regenerate-plan: profile not found for user ${userId}:`, profileResult.error);
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

  const sessionLogs = (sessionLogsResult.data ?? []) as Array<{
    difficulty_rating?: string | null;
    started_at: string;
    workout_day_label?: string;
  }>;

  // Fetch set_logs for the same period (limit 200 as per plan spec)
  const { data: setLogsData } = await supabase
    .from("set_logs")
    .select("exercise_name, target_reps, reps_logged")
    .eq("user_id", userId)
    .gte("completed_at", fourWeeksAgoISO)
    .order("completed_at", { ascending: false })
    .limit(200);

  const setLogs = (setLogsData ?? []) as Array<{
    exercise_name: string;
    target_reps: string;
    reps_logged: string;
  }>;

  // ── Compute history summary (AI-SPEC Section 4b.4) ─────────────────────────
  // Summary stays under ~100 tokens vs 2000+ for raw logs
  const historySummary = {
    total_sessions_completed: sessionLogs.length,
    average_completion_rate: Math.round(computeAvgCompletionRate(setLogs) * 100) / 100,
    strongest_exercises: topNByCompletionRate(setLogs, 3),
    weakest_exercises: bottomNByCompletionRate(setLogs, 2),
    recent_ratings_trend: summarizeRatingsTrend(sessionLogs),
  };

  // Weeks on current plan (approximate from session history)
  const weeksOnPlan = Math.max(1, Math.ceil(sessionLogs.length / 3));

  // Fetch exercise names so AI only uses exercises with videos
  let exerciseNameList = "";
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

  // ── Build system prompt ───────────────────────────────────────────────────
  const compactPlan = stripRationale(currentPlan);
  const injuriesLine = profile.injuries ? `\n- Limitations: ${profile.injuries}` : "";
  const equipmentStr = Array.isArray(profile.equipment)
    ? profile.equipment.join(", ")
    : String(profile.equipment);

  const systemPrompt = `You are a professional fitness coach regenerating a user's weekly workout plan based on their training history.

User profile:
- Goal: ${profile.goal}
- Fitness Level: ${profile.fitness_level}
- Equipment: ${equipmentStr}${injuriesLine}

Current plan (${weeksOnPlan} week(s) on this plan):
${JSON.stringify(compactPlan)}

4-week training history summary:
${JSON.stringify(historySummary)}

ADAPTATION RULES:
1. Two or more consecutive "too hard" ratings: reduce working volume by 10-15% — remove 1 set per exercise or reduce reps by 2. Do not increase difficulty anywhere in the plan during this adjustment.
2. Three or more consecutive "too easy" ratings: increase volume by 10-15% — add 1 set or increase reps by 2. Never increase volume for any exercise with completion rate below 80%.
3. "Just right" ratings or mixed signals: maintain current volume. Fine-tune rest periods if needed. Swap a stale accessory exercise only if the user has been on this plan 4+ weeks.
4. Missed sessions: redistribute key compound exercises (squat, deadlift, bench press, row) from the missed day across remaining training days at reduced volume (not full volume). Drop isolation work from missed days — never stack it.
5. Exercise continuity: do not replace an exercise the user has been completing at 80%+ unless an adaptation rule requires it. Strength gains are movement-specific.

REGENERATION CONTEXT: This is a weekly plan refresh. Maintain exercise continuity — keep core compound movements (squat, deadlift, bench, row patterns) from the current plan. Rotate accessory exercises only if the user has been on this plan 4+ weeks. Progressive overload: increase volume by no more than 10% week-over-week when ratings indicate 'just right' or 'too easy'.

SAFETY: You are not a medical professional. Do not prescribe exercises that could aggravate reported injuries or limitations. Do not frame this as medical advice.` + (exerciseNameList ? `

CRITICAL RULE — EXERCISE NAMES:
You MUST copy exercise names EXACTLY from the list below. Do not paraphrase, abbreviate, combine words, or invent exercise names. Every exercise_name in your response must be a verbatim copy-paste from this list. If you cannot find an exact match, pick the closest alternative from the list.

Available exercises:
${exerciseNameList}` : "");

  // AI-SPEC Section 4: token budget check
  assertPromptBudget(systemPrompt, 1800, "regenerate-plan");

  // ── OpenAI call ──────────────────────────────────────────────────────────
  const result = await callOpenAIForRegeneration(openAIKey, systemPrompt, false);

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
    console.error("regenerate-plan: response truncated (finish_reason=length) — raise max_completion_tokens or reduce prompt");
    return new Response(JSON.stringify({ error: "Response truncated" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (choice?.finish_reason === "content_filter" || choice?.message?.refusal) {
    console.error("regenerate-plan: model refusal:", choice?.message?.refusal);
    return new Response(JSON.stringify({ error: "Plan regeneration refused by safety filter" }), {
      status: 422,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse JSON from structured output
  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(choice.message.content);
  } catch (err) {
    console.error("regenerate-plan: JSON.parse failed:", (err as Error).message);
    console.error("regenerate-plan: raw content (first 300 chars):", choice.message.content?.slice(0, 300));
    return new Response(JSON.stringify({ error: "Plan JSON parse failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── Validate the weekly_days structure with Zod ─────────────────────────
  // The full plan includes plan_name/goal_summary (from planSchema) plus weekly_days.
  // Validate inner structure with AdaptedPlanSchema applied to a synthetic object
  // that wraps weekly_days — then reconstruct the full plan with all top-level fields.
  const parsed = parsedJson as Record<string, unknown>;
  const innerValidation = AdaptedPlanSchema.safeParse({
    adjustment_summary: "Weekly plan regenerated based on your training history.",
    weekly_days: parsed.weekly_days,
  });

  if (!innerValidation.success) {
    console.error("regenerate-plan: Zod validation failed — issues:", JSON.stringify(innerValidation.error.issues, null, 2));
    console.warn("regenerate-plan: attempting one retry after Zod validation failure");

    // Retry once with augmented user message
    const retryResult = await callOpenAIForRegeneration(openAIKey, systemPrompt, true);

    if (!retryResult.ok) {
      return new Response(JSON.stringify({ error: "Plan regeneration failed after retry" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const retryChoice = retryResult.response.choices?.[0];

    if (retryChoice?.finish_reason === "length" || retryChoice?.message?.refusal) {
      return new Response(JSON.stringify({ error: "Plan regeneration failed after retry" }), {
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

    const retryFull = retryParsed as Record<string, unknown>;
    const retryInnerValidation = AdaptedPlanSchema.safeParse({
      adjustment_summary: "Weekly plan regenerated based on your training history.",
      weekly_days: retryFull.weekly_days,
    });

    if (!retryInnerValidation.success) {
      console.error("regenerate-plan: Zod validation failed after retry:", JSON.stringify(retryInnerValidation.error.issues, null, 2));
      return new Response(JSON.stringify({ error: "Generated plan failed validation after retry" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Use retry result
    parsedJson = retryParsed;
  }

  const fullPlan = parsedJson as Record<string, unknown>;

  // ── T-08-09: Sanitize clinical language (AI-SPEC Section 6) ─────────────
  // Sanitize rationale fields in weekly_days
  const sanitizedWeeklyDays = (fullPlan.weekly_days as Array<Record<string, unknown>>)?.map(
    (day) => ({
      ...day,
      exercises: (day.exercises as Array<Record<string, unknown>>)?.map((ex) => ({
        ...ex,
        rationale: sanitizeRationale((ex.rationale as string) ?? ""),
      })),
    })
  );

  const sanitizedPlan = {
    ...fullPlan,
    weekly_days: sanitizedWeeklyDays,
  };

  // ── Write audit log to plan_adaptations with cache_key ───────────────────
  const cacheKey = `${userId}-${isoWeek}`;
  const { error: insertError } = await supabase.from("plan_adaptations").insert({
    user_id: userId,
    trigger_type: "weekly",
    adaptation_summary: `Weekly plan regenerated for ${isoWeek}`,
    previous_plan: currentPlan,
    adapted_plan: sanitizedPlan,
    cache_key: cacheKey,
    prompt_tokens: openAIResult.usage?.prompt_tokens ?? null,
    completion_tokens: openAIResult.usage?.completion_tokens ?? null,
  });

  if (insertError) {
    console.error("regenerate-plan: failed to insert plan_adaptations:", insertError);
    // Non-fatal — return the regenerated plan even if audit log fails
  }

  // ── Update user_plans with regenerated plan ──────────────────────────────
  const { error: updateError } = await supabase
    .from("workout_plans")
    .update({ plan_json: sanitizedPlan })
    .eq("id", planId)
    .eq("user_id", userId);

  if (updateError) {
    console.error("regenerate-plan: failed to update user_plans:", updateError);
    return new Response(JSON.stringify({ error: "Failed to save regenerated plan" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify(sanitizedPlan), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "X-Cache": "MISS",
    },
  });
});
