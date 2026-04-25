-- Phase 8: Adaptive AI — Data Foundation
-- Requirements: ADPT-01, ADPT-02
-- Security: T-08-01 (CHECK constraint on difficulty_rating), T-08-02 (RLS on plan_adaptations)

-- 1. Add difficulty_rating column to session_logs
-- CHECK constraint limits to 3 valid values matching DifficultyRating Swift enum raw values.
-- NULL is allowed (pre-Phase 8 sessions and sessions where user skips rating).
ALTER TABLE public.session_logs
    ADD COLUMN difficulty_rating TEXT CHECK (difficulty_rating IN ('too_easy', 'just_right', 'too_hard'));

-- 2. Create plan_adaptations audit table
-- Stores every AI-generated adaptation with token counts for cost auditing.
-- No client INSERT policy — only service role (Edge Function) can write to this table.
CREATE TABLE public.plan_adaptations (
    id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    adapted_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    trigger_type       TEXT        NOT NULL CHECK (trigger_type IN ('post_session', 'weekly', 'missed_session')),
    adaptation_summary TEXT        NOT NULL,
    previous_plan      JSONB       NOT NULL,
    adapted_plan       JSONB       NOT NULL,
    cache_key          TEXT        UNIQUE,
    prompt_tokens      INTEGER,
    completion_tokens  INTEGER
);

-- 3. Index for efficient per-user queries ordered by recency
CREATE INDEX idx_plan_adaptations_user_id
    ON public.plan_adaptations (user_id, adapted_at DESC);

-- 4. Enable Row Level Security
ALTER TABLE public.plan_adaptations ENABLE ROW LEVEL SECURITY;

-- 5. Users can view their own adaptations (SELECT only — no INSERT/UPDATE/DELETE for clients)
-- Service role key (used by Edge Functions) bypasses RLS for writes.
CREATE POLICY "Users can view own adaptations"
    ON public.plan_adaptations
    FOR SELECT
    USING (auth.uid() = user_id);
