-- Phase 3: Add fitness profile columns to profiles table
-- Requirements: AIPL-01, AIPL-04 (user profile fields for AI plan generation)
-- Decision: D-12 (profile columns for goal, fitness_level, days_per_week, equipment, injuries)
-- Injected into AI system prompt on every plan generation call

ALTER TABLE public.profiles
    ADD COLUMN goal TEXT NOT NULL DEFAULT '',
    ADD COLUMN fitness_level TEXT NOT NULL DEFAULT '',
    ADD COLUMN days_per_week INT NOT NULL DEFAULT 3,
    ADD COLUMN equipment TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN injuries TEXT NOT NULL DEFAULT '';

-- No new RLS policies needed: existing SELECT/UPDATE policies on profiles
-- already scope to auth.uid() = id (from migration 00000000000000).
