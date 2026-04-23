// Phase 5: AI Coach Chat Edge Function
// Requirements: CHAT-01, CHAT-02, CHAT-03
// Security: T-05-04 (message length limit), T-05-05 (system prompt placement + history cap),
//           T-05-06 (medical advice safety block), T-05-07 (rate limit logging),
//           T-05-08 (auth header validation), T-05-09 (API key from env)
//
// Receives ChatPayload from iOS client, assembles system prompt from user profile,
// current plan, and session summaries. Routes to:
//   - GPT-4o mini (streaming) for conversational chat
//   - GPT-4o (Structured Outputs, non-streaming) for plan modification execution
//
// Injects [ACTION] metadata event before [DONE] so the iOS CoachSSEClient can
// route the response (chat vs. modify_plan) without parsing the full text.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// JSON Schema for OpenAI Structured Outputs (strict mode).
// additionalProperties: false is required at EVERY object level in strict mode.
// Copied verbatim from generate-plan/index.ts — used for plan modification on execute_modify path.
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
  // Handle CORS preflight — copied verbatim from generate-plan/index.ts lines 54-65
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

  // T-05-09: Fail fast if API key is not set — never hardcode
  // Copied verbatim from generate-plan/index.ts lines 67-77
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

  // T-05-08: Validate Authorization header. iOS client sends Bearer <token> manually
  // because the Supabase Swift SDK invokeWithStreamedResponse drops the JWT (bug #634).
  // Copied verbatim from generate-plan/index.ts lines 79-89
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // Parse ChatPayload
  let payload: {
    message: string;
    message_history: Array<{ role: string; content: string }>;
    profile: {
      goal: string;
      fitness_level: string;
      equipment: string[];
      injuries: string;
      name?: string;
    };
    current_plan: any;
    session_summaries: Array<{
      date: string;
      workout_name: string;
      exercises_completed: number;
      sets_logged: number;
    }>;
    message_count: number;
    action?: string;
    pending_modification?: any;
  };

  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // T-05-04: Validate and sanitize message field (defense-in-depth per Security Domain)
  const MAX_MESSAGE_LEN = 2000;
  if (!payload.message || typeof payload.message !== "string") {
    return new Response(
      JSON.stringify({ error: "message field is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
  const safeMessage = payload.message.slice(0, MAX_MESSAGE_LEN);

  // T-05-05: Cap message_history at 20 entries (Pitfall 5 — prevents context overflow)
  let safeHistory = Array.isArray(payload.message_history)
    ? payload.message_history.slice(-20)
    : [];

  // D-30: Cap session_summaries at 3 most recent
  const safeSummaries = Array.isArray(payload.session_summaries)
    ? payload.session_summaries.slice(0, 3)
    : [];

  // T-05-07: Rate limiting check (per-user, max 60 requests/hour).
  // For MVP, log a warning but do not block. Full rate limiting requires a Redis/KV store
  // not yet in the stack. Console.warn is monitored in Edge Function logs.
  console.warn("coach-chat: rate-limit-check placeholder — implement with KV store when available");

  // D-09, D-14: Handle execute_modify path — GPT-4o with Structured Outputs (non-streaming)
  if (payload.action === "execute_modify") {
    const modificationSystemPrompt = `You are a professional fitness coach modifying a user's workout plan.

User profile:
- Goal: ${payload.profile.goal}
- Fitness Level: ${payload.profile.fitness_level}
- Equipment: ${Array.isArray(payload.profile.equipment) ? payload.profile.equipment.slice(0, 20).join(", ") : ""}
${payload.profile.injuries ? `- Areas to avoid: ${payload.profile.injuries}` : ""}

Current plan:
${JSON.stringify(payload.current_plan)}

Requested modification:
${JSON.stringify(payload.pending_modification)}

Generate the complete updated workout plan incorporating the requested changes. Keep all unaffected days and exercises the same. Only modify what was requested.

SAFETY: You are not a medical professional. Do not recommend exercises that could aggravate reported injuries.`;

    const modifyResponse = await fetch("https://api.openai.com/v1/chat/completions", {
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
          { role: "system", content: modificationSystemPrompt },
          { role: "user", content: "Generate the updated workout plan." },
        ],
      }),
    });

    if (!modifyResponse.ok) {
      const errorBody = await modifyResponse.text();
      console.error(`coach-chat: OpenAI modify error ${modifyResponse.status}: ${errorBody}`);
      return new Response(
        JSON.stringify({ error: "Plan modification failed", status: modifyResponse.status }),
        { status: modifyResponse.status, headers: { "Content-Type": "application/json" } }
      );
    }

    const modifyResult = await modifyResponse.json();
    const updatedPlan = modifyResult.choices?.[0]?.message?.content;

    // Return the modified plan as a non-streaming JSON response
    return new Response(
      JSON.stringify({ action: "execute_modify", plan_delta: updatedPlan }),
      { status: 200, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );
  }

  // D-22: Context summarization — when message count exceeds threshold,
  // summarize older messages server-side and inject summary into system prompt.
  const SUMMARIZATION_THRESHOLD = 50;
  let conversationSummary: string | null = null;

  if (payload.message_count > SUMMARIZATION_THRESHOLD && safeHistory.length > 5) {
    // Summarize all but the last 5 messages (keep recent context raw)
    const olderMessages = safeHistory.slice(0, -5);
    const recentMessages = safeHistory.slice(-5);

    try {
      const summaryResponse = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openAIKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          stream: false,
          max_tokens: 300,
          messages: [
            {
              role: "system",
              content: "Summarize this conversation between a user and their fitness coach in 2-3 sentences. Focus on: topics discussed, any plan changes made, and the user's current concerns or goals. Be concise.",
            },
            ...olderMessages.map((m) => ({
              role: m.role as "user" | "assistant",
              content: m.content,
            })),
          ],
        }),
      });

      if (summaryResponse.ok) {
        const summaryResult = await summaryResponse.json();
        conversationSummary = summaryResult.choices?.[0]?.message?.content ?? null;
      } else {
        console.warn("coach-chat: summarization call failed, falling back to raw history");
      }
    } catch (err) {
      console.warn("coach-chat: summarization error, falling back to raw history:", err);
    }

    // Replace safeHistory with only the recent raw messages when summary succeeds
    if (conversationSummary) {
      safeHistory = recentMessages;
    }
  }

  // D-24 to D-30: Assemble system prompt for conversational chat
  const userName = payload.profile.name || "there";
  const equipmentList = Array.isArray(payload.profile.equipment)
    ? payload.profile.equipment.slice(0, 20).join(", ")
    : "";

  // Session summaries formatted compactly (D-29)
  const summaryText = safeSummaries.length > 0
    ? safeSummaries.map((s) =>
        `- ${s.date}: ${s.workout_name} — ${s.exercises_completed} exercises, ${s.sets_logged} sets`
      ).join("\n")
    : "No recent sessions.";

  const systemPrompt = `You are a direct, expert fitness coach. You are knowledgeable and efficient — you don't waste words. You respond in 3-5 sentences unless the question requires more detail. You occasionally use the user's name (${userName}) naturally, especially in greetings and when discussing plan changes.

User profile:
- Name: ${userName}
- Goal: ${payload.profile.goal}
- Fitness Level: ${payload.profile.fitness_level}
- Equipment: ${equipmentList}
${payload.profile.injuries ? `- Areas to avoid or modify around: ${payload.profile.injuries}` : ""}

Current workout plan:
${JSON.stringify(payload.current_plan)}

Recent sessions (last 3):
${summaryText}
${conversationSummary
    ? `\nConversation summary (older messages):\n${conversationSummary}\n`
    : ""}
PLAN MODIFICATION INSTRUCTIONS:
When the user asks to change, swap, replace, adjust, or modify any part of their workout plan, you MUST:
1. Acknowledge what they want to change
2. Propose the specific change clearly (e.g., "I'd swap Bench Press for Incline DB Press at 3x10")
3. End your response with a JSON block on its own line in this exact format:
[MODIFICATION]{"type":"swap_exercise","description":"Replace Bench Press with Incline DB Press 3x10 on Push Day"}

If the user is NOT asking to modify their plan, do NOT include any [MODIFICATION] block. Just respond conversationally.

SAFETY: You are not a medical professional. Do not diagnose conditions, prescribe treatments, or provide medical advice. If the user mentions pain, injury, or health concerns, recommend they consult a physician. Do not provide nutrition advice beyond general hydration and protein intake guidance.`;

  // Build messages array for OpenAI
  // T-05-05: System prompt placed BEFORE user content — prevents prompt injection via user history
  const messages = [
    { role: "system" as const, content: systemPrompt },
    ...safeHistory.map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content,
    })),
    { role: "user" as const, content: safeMessage },
  ];

  // D-13: Call GPT-4o mini with streaming for conversational chat
  const openAIResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      stream: true,
      messages,
    }),
  });

  if (!openAIResponse.ok) {
    const errorBody = await openAIResponse.text();
    console.error(`coach-chat: OpenAI API error ${openAIResponse.status}: ${errorBody}`);
    return new Response(
      JSON.stringify({ error: "OpenAI API error", status: openAIResponse.status, detail: errorBody }),
      { status: openAIResponse.status, headers: { "Content-Type": "application/json" } }
    );
  }

  // Forward SSE stream with [ACTION] injection (RESEARCH Pattern 4, Option B)
  //
  // Unlike generate-plan (pure passthrough), we read+forward the OpenAI stream so we can
  // accumulate the full response text, detect the [MODIFICATION] tag, and inject the
  // [ACTION] envelope event before [DONE]. The iOS CoachSSEClient detects [ACTION] prefix
  // to route the response (chat vs. modify_plan) without parsing full prose.
  const reader = openAIResponse.body!.getReader();
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();
  let fullResponseText = "";
  let buffer = "";

  const stream = new ReadableStream({
    async start(controller) {
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";

          for (const line of lines) {
            if (!line.startsWith("data: ")) continue;
            const data = line.slice(6);

            if (data === "[DONE]") {
              // Detect intent from accumulated text
              let intentAction = "chat";
              let planDelta: string | null = null;

              const modMatch = fullResponseText.match(/\[MODIFICATION\](\{.*\})\s*$/);
              if (modMatch) {
                intentAction = "modify_plan";
                planDelta = modMatch[1];
                // Note: the [MODIFICATION] tag was already streamed to client as text.
                // The iOS client strips it from the displayed message using the same regex.
              }

              // Inject [ACTION] event before [DONE]
              const actionPayload = JSON.stringify({
                action: intentAction,
                plan_delta: planDelta,
              });
              controller.enqueue(encoder.encode(`data: [ACTION]${actionPayload}\n\n`));
              controller.enqueue(encoder.encode("data: [DONE]\n\n"));
              controller.close();
              return;
            }

            // Forward the SSE line and accumulate text
            controller.enqueue(encoder.encode(`${line}\n\n`));

            try {
              const chunk = JSON.parse(data);
              const content = chunk?.choices?.[0]?.delta?.content;
              if (content) {
                fullResponseText += content;
              }
            } catch {
              // Non-JSON SSE line — forward as-is (already enqueued above)
            }
          }
        }
        // Stream ended without [DONE] — close gracefully
        controller.close();
      } catch (err) {
        console.error("coach-chat: stream processing error:", err);
        controller.error(err);
      }
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
