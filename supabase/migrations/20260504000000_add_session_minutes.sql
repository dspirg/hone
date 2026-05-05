-- Add session_minutes column to profiles table
-- Default 45 minutes for existing users
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS session_minutes INTEGER DEFAULT 45;
