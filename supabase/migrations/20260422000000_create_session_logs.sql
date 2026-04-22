-- Phase 4: Create session_logs and set_logs tables with RLS
-- Requirements: SESS-01, SESS-03, SESS-04
-- Decision: write-ahead CoreData; sync to Supabase on reconnect via upsert

CREATE TABLE public.session_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.workout_plans(id) ON DELETE SET NULL,
    workout_day_label TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    total_exercises INT NOT NULL DEFAULT 0,
    total_sets INT NOT NULL DEFAULT 0,
    total_reps INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.session_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own session logs"
    ON public.session_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own session logs"
    ON public.session_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own session logs"
    ON public.session_logs FOR UPDATE
    USING (auth.uid() = user_id);

CREATE TABLE public.set_logs (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.session_logs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    set_number INT NOT NULL,
    target_reps TEXT NOT NULL,
    reps_logged INT NOT NULL CHECK (reps_logged >= 0 AND reps_logged <= 999),
    completed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.set_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own set logs"
    ON public.set_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own set logs"
    ON public.set_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own set logs"
    ON public.set_logs FOR UPDATE
    USING (auth.uid() = user_id);
