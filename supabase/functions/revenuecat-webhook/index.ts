// Phase 7: RevenueCat webhook handler (D-19)
//
// Receives subscription lifecycle events from RevenueCat and updates
// profiles.subscription_status in Supabase.
//
// SECURITY (T-07-02): Authorization header verified against RC_WEBHOOK_SECRET
// before any event processing.
//
// IDEMPOTENCY (RESEARCH Pitfall 7): Uses state-driven update mapping -- the
// same event type always produces the same status value. RevenueCat may deliver
// the same event more than once; duplicate processing is safe because the
// update is idempotent (SET status = X where it may already be X).
//
// ANONYMOUS ID GUARD (RESEARCH Pitfall 1): Rejects payloads where app_user_id
// starts with "$RCAnonymousID" -- these indicate Purchases.shared.logIn() was
// not called with the Supabase UUID, meaning the database update would fail
// silently (no matching profile row).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const ACTIVE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "BILLING_ISSUE_RESOLVED",
  "PRODUCT_CHANGE",
  "TRANSFER",
])

const GRACE_EVENTS = new Set([
  "BILLING_ISSUE",
])

const INACTIVE_EVENTS = new Set([
  "CANCELLATION",
  "EXPIRATION",
  "SUBSCRIPTION_PAUSED",  // Google Play concept; included for completeness
])

serve(async (req: Request) => {
  // 1. Verify authorization header (T-07-02: spoofing mitigation)
  const authHeader = req.headers.get("Authorization")
  const secret = Deno.env.get("RC_WEBHOOK_SECRET")
  if (!secret || authHeader !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 })
  }

  // 2. Parse event payload (RevenueCat sends { api_version, event: { type, app_user_id, id } })
  let payload: { api_version?: string; event: { type: string; app_user_id: string; id: string } }
  try {
    payload = await req.json()
  } catch {
    console.error("[revenuecat-webhook] Failed to parse JSON payload")
    return new Response("Invalid JSON", { status: 400 })
  }

  const rcEvent = payload.event
  if (!rcEvent) {
    console.error("[revenuecat-webhook] Missing 'event' object in payload")
    return new Response("Missing event object", { status: 400 })
  }

  const appUserId: string = rcEvent.app_user_id
  const eventType: string = rcEvent.type
  const eventId: string = rcEvent.id

  // 3. Reject anonymous IDs (RESEARCH Pitfall 1)
  // If logIn() was never called with the Supabase UUID, RevenueCat assigns
  // $RCAnonymousID:xxx which does not match any profiles.id row.
  if (!appUserId || appUserId.startsWith("$RCAnonymousID")) {
    console.error(
      `[revenuecat-webhook] REJECTED: Anonymous ID received: ${appUserId}. ` +
      `This means Purchases.shared.logIn(supabaseUserId) was not called. ` +
      `Event: ${eventType}, Event ID: ${eventId}`
    )
    // Return 200 to prevent RevenueCat retries on a permanently bad payload.
    // The root cause is a client-side bug (missing logIn call), not transient.
    return new Response("Anonymous ID rejected -- logIn() not called", { status: 200 })
  }

  // 4. Validate UUID format (basic check, T-07-03)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(appUserId)) {
    console.error(`[revenuecat-webhook] Invalid UUID format: ${appUserId}`)
    return new Response("Invalid user ID format", { status: 200 })
  }

  // 5. Map event type to subscription status (state-driven, idempotent -- Pitfall 7)
  let status: string
  if (ACTIVE_EVENTS.has(eventType)) {
    status = "subscribed"
  } else if (GRACE_EVENTS.has(eventType)) {
    status = "grace_period"
  } else if (INACTIVE_EVENTS.has(eventType)) {
    status = "free"
  } else {
    // Unknown or non-subscription event (e.g., NON_RENEWING_PURCHASE)
    console.log(`[revenuecat-webhook] Unhandled event type: ${eventType}. Acknowledging.`)
    return new Response("OK", { status: 200 })
  }

  // 6. Update profiles table using service_role key (bypasses RLS -- T-07-06)
  // service_role key is required because the RLS policy prevents authenticated users
  // from modifying subscription_status on their own row (T-07-06 mitigation)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const { error } = await supabase
    .from("profiles")
    .update({ subscription_status: status })
    .eq("id", appUserId)

  if (error) {
    console.error(
      `[revenuecat-webhook] Failed to update profile ${appUserId}: ${error.message}. ` +
      `Event: ${eventType}, Status target: ${status}`
    )
    // Return 500 so RevenueCat retries (up to 5x with exponential backoff)
    return new Response("Update failed", { status: 500 })
  }

  console.log(`[revenuecat-webhook] Updated ${appUserId} -> ${status} (event: ${eventType})`)

  // 7. Must return 200 within 60s or RevenueCat retries
  return new Response("OK", { status: 200 })
})
