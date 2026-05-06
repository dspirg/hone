-- Weight tracking: add weight_logged to set_logs, weight_unit to profiles,
-- and create exercise_weights table for last-used weight memory.

-- 1. Add weight_logged column to set_logs (nullable — NULL = bodyweight or not entered)
ALTER TABLE public.set_logs ADD COLUMN IF NOT EXISTS weight_logged REAL;

-- 2. Add weight_unit preference to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weight_unit TEXT DEFAULT 'lbs'
    CHECK (weight_unit IN ('lbs', 'kg'));

-- 3. Create exercise_weights table (last-used weight per exercise per user)
CREATE TABLE IF NOT EXISTS public.exercise_weights (
    user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_name  TEXT NOT NULL,
    last_weight    REAL NOT NULL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, exercise_name)
);

ALTER TABLE public.exercise_weights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own exercise weights"
    ON public.exercise_weights FOR SELECT
    TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own exercise weights"
    ON public.exercise_weights FOR INSERT
    TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own exercise weights"
    ON public.exercise_weights FOR UPDATE
    TO authenticated USING (auth.uid() = user_id);
