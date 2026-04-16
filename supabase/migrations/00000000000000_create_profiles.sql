-- Phase 1: profiles table, RLS, auto-create trigger
-- Requirements: AUTH-01, AUTH-02 (profile created on sign-up)
-- Decisions: D-08 (auth + profiles only), D-09 (columns), D-10 (RLS)

-- 1. Create profiles table (D-09)
CREATE TABLE public.profiles (
    id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_status TEXT NOT NULL DEFAULT 'free'
        CHECK (subscription_status IN ('free', 'subscribed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id)
);

-- 2. Enable RLS (D-10)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. RLS policies (D-10) -- users can only read/write their own row
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- 4. Trigger function -- SECURITY DEFINER required for cross-schema INSERT (Pitfall 5)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data ->> 'display_name',
        NEW.raw_user_meta_data ->> 'avatar_url'
    );
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log but do not hard-fail signup if profile creation fails (Pitfall 2)
    RAISE WARNING 'handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- 5. Attach trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
