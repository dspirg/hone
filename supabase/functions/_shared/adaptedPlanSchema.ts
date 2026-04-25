// Zod schema for adapted plan validation (AI-SPEC Section 4b.1).
// Two-layer validation: JSON Schema constrains generation, Zod validates receipt.
import { z } from "https://deno.land/x/zod@v3.23.8/mod.ts";

export const ExerciseSchema = z.object({
  exercise_name: z.string().min(1),
  sets:          z.number().int().min(1).max(10),
  reps:          z.string().min(1),
  rest_seconds:  z.number().int().min(15).max(600),
  rationale:     z.string().min(1),
});

export const TrainingDaySchema = z.object({
  day_label:    z.string().min(1),
  session_name: z.string().min(1),
  exercises:    z.array(ExerciseSchema).min(1).max(15),
});

export const AdaptedPlanSchema = z.object({
  adjustment_summary: z.string().min(10).max(500),
  weekly_days:        z.array(TrainingDaySchema).min(1).max(7),
});

export type AdaptedPlan = z.infer<typeof AdaptedPlanSchema>;
