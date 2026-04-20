-- Phase 2 / Quick 260420-a0: add video_url column and expand CHECK constraints
-- Adds Supabase Storage URL field alongside mux_playback_id (keeps Mux migration path open).
-- Expands equipment_tag constraint to include Resistance Band, Cable, Kettlebell.

-- 1. Add video_url column
ALTER TABLE public.exercises
    ADD COLUMN IF NOT EXISTS video_url TEXT;

-- 2. Drop existing CHECK constraints on primary_muscle and equipment_tag
--    PostgreSQL auto-names inline constraints as {table}_{column}_check
ALTER TABLE public.exercises DROP CONSTRAINT IF EXISTS exercises_primary_muscle_check;
ALTER TABLE public.exercises DROP CONSTRAINT IF EXISTS exercises_equipment_tag_check;

-- 3. Add expanded CHECK constraints
ALTER TABLE public.exercises
    ADD CONSTRAINT exercises_primary_muscle_check
    CHECK (primary_muscle IN ('Chest','Back','Shoulders','Arms','Core','Legs','Glutes','Full Body'));

ALTER TABLE public.exercises
    ADD CONSTRAINT exercises_equipment_tag_check
    CHECK (equipment_tag IN ('Bodyweight','Dumbbells','Barbell','Machine','Resistance Band','Cable','Kettlebell'));
