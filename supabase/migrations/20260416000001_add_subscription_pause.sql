-- Phase 7: Add subscription_pause_until for in-app pause UX (D-11)
--
-- IMPORTANT: Apple has NO native subscription pause API (RESEARCH Pitfall 5).
-- This column stores the user-chosen pause end date as an in-app UX convention.
-- The app checks this date to hide workout content during the "pause" period.
-- Apple billing continues regardless -- the user is directed to Apple's
-- subscription management URL to actually cancel if they choose.
--
-- subscription_status expanded to include 'grace_period' for D-16
-- (3-day billing grace period on payment failure, managed by RevenueCat)

ALTER TABLE public.profiles
    ADD COLUMN subscription_pause_until TIMESTAMPTZ DEFAULT NULL;

-- Expand subscription_status CHECK to include 'grace_period' for D-16
ALTER TABLE public.profiles
    DROP CONSTRAINT profiles_subscription_status_check;

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_subscription_status_check
    CHECK (subscription_status IN ('free', 'subscribed', 'grace_period'));

-- RLS policy: prevent users from updating their own subscription_status directly.
-- Only the webhook Edge Function (using service_role key) should set this column.
-- Users can still update subscription_pause_until (self-service pause UX).
-- T-07-06: prevents client-side entitlement spoofing.
--
-- NOTE: The existing "Users can update own profile" policy (from 00000000000000_create_profiles.sql)
-- allows UPDATE on all columns. This new policy adds a WITH CHECK that enforces
-- subscription_status cannot change via a user JWT. The service_role key bypasses
-- RLS entirely and is used exclusively by the webhook Edge Function.
CREATE POLICY "Users cannot update subscription_status directly"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (
        -- subscription_status must remain unchanged when updated by an authenticated user
        -- (not service_role -- service_role bypasses RLS entirely)
        subscription_status = (SELECT p.subscription_status FROM public.profiles p WHERE p.id = auth.uid())
    );
