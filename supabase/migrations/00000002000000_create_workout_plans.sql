-- Phase 3: Create workout_plans table with RLS
-- Requirements: AIPL-01 (AI-generated workout plans stored per user)
-- Decision: D-13 (generated plan stored in Supabase workout_plans table immediately on completion)

CREATE TABLE public.workout_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_name TEXT NOT NULL,
    goal_summary TEXT NOT NULL,
    plan_json JSONB NOT NULL,       -- full plan JSON blob for re-rendering and offline sync
    days_per_week INT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS: T-03-03 -- user cannot read or write other users' plans
ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own plans"
    ON public.workout_plans FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own plans"
    ON public.workout_plans FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own plans"
    ON public.workout_plans FOR UPDATE
    USING (auth.uid() = user_id);

-- WR-06: DELETE policy so row owners can delete their own plans via the Supabase client.
-- Without this policy, RLS blocks all DELETE attempts even from the row owner.
-- Current v1 app uses UPDATE (is_active = false) for deactivation, but a missing DELETE
-- policy would silently fail any future client-side delete feature.
CREATE POLICY "Users can delete own plans"
    ON public.workout_plans FOR DELETE
    USING (auth.uid() = user_id);
