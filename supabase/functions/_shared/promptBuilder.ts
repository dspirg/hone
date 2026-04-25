// Shared prompt construction helpers for Phase 8 adaptation Edge Functions.
// Token budget: system prompt must stay under 1400 tokens.

export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

export function assertPromptBudget(prompt: string, budgetTokens: number, fnName: string): void {
  const estimate = estimateTokens(prompt);
  if (estimate > budgetTokens) {
    console.warn(
      `${fnName}: system prompt ~${estimate} tokens exceeds budget of ${budgetTokens} — increase max_completion_tokens or reduce context`
    );
  }
}

// Strips rationale fields from plan before injecting into prompts — saves ~400 tokens
export function stripRationale(plan: Record<string, unknown>): Record<string, unknown> {
  const weeklyDays = plan.weekly_days as Array<Record<string, unknown>>;
  return {
    plan_name: plan.plan_name,
    goal_summary: plan.goal_summary,
    weekly_days: weeklyDays?.map((day) => ({
      day_label: day.day_label,
      session_name: day.session_name,
      exercises: (day.exercises as Array<Record<string, unknown>>)?.map(
        ({ rationale: _r, ...rest }) => rest
      ),
    })),
  };
}

// Clinical language blocklist (AI-SPEC Section 6)
const CLINICAL_LANGUAGE_PATTERNS = [
  /rehabilitat/i,
  /treat(ment|ing)?/i,
  /diagnos/i,
  /physical therap/i,
  /medical advice/i,
  /clinical/i,
  /therapeutic/i,
  /injury management/i,
  /recovery protocol/i,
];

export function passesLanguageGuardrail(text: string): boolean {
  return !CLINICAL_LANGUAGE_PATTERNS.some((pattern) => pattern.test(text));
}

// Replaces clinical language in rationale fields with safe default
export function sanitizeRationale(text: string): string {
  if (passesLanguageGuardrail(text)) return text;
  return "Adjusted based on your recent feedback.";
}
