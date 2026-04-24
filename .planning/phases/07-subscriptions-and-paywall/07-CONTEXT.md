# Phase 7: Subscriptions and Paywall - Context

**Gathered:** 2026-04-16 (updated 2026-04-24)
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers:
- A compelling paywall screen triggered by "Start Training" CTA from the Phase 3 plan preview
- Monthly ($9.99) and annual ($59.99/year) subscription options via RevenueCat SDK 5.x + StoreKit 2
- 14-day free trial on both plans
- Annual plan pre-selected with "Most Popular" badge
- Cancellation retention flow (pause → discount) accessible from Profile tab
- Hard paywall on trial expiry with blurred plan preview ("Your plan is waiting")
- 3-day grace period on payment failure (RevenueCat-managed)

No workout execution, no AI features, no coach chat changes in this phase.

</domain>

<decisions>
## Implementation Decisions

### Pricing & Trial
- **D-01:** Monthly plan: $12.99/month (updated from $9.99 based on competitive research — conversational AI coach differentiator justifies mid-tier pricing between FitnessAI and Fitbod)
- **D-02:** Annual plan: $79.99/year (~$6.67/month equivalent, ~49% off monthly) (updated from $59.99 — 50% discount was too steep per industry benchmarks of 25-35%; still undercuts Fitbod's $95.99/yr)
- **D-03:** Free trial: 14 days on both plans — allows users to complete 5-6 sessions and form habits before billing begins
- **D-04:** Only two tiers: monthly and annual. No weekly, lifetime, or family plans in v1.

### Paywall Design
- **D-05:** Paywall style: feature showcase — 3-4 value prop bullets above pricing cards. Example bullets: "AI plan built for you", "500+ exercises with video", "Coach chat anytime", "Adapts as you improve"
- **D-06:** Annual price displayed as monthly equivalent: "$6.67/month, billed $79.99/year" — makes the discount feel concrete
- **D-07:** Social proof: "Join [X] members" count displayed below value props. Start with a believable seed number, update as the app grows.
- **D-08:** Annual plan is the default selected state, highlighted with a "Most Popular" badge. Monthly shown below it. Both tappable to switch selection.

### Cancellation Retention Flow
- **D-09:** Retention flow triggered when user taps "Manage Subscription" in Profile tab — shows in-app retention screen before redirecting to App Store settings
- **D-10:** Offer order: pause first, then discount. Pause has less friction (no money), discount is the stronger offer held in reserve.
- **D-11:** Pause options: 1 month, 2 months, or 3 months — user picks from a segmented control or chip set
- **D-12:** Discount offer (shown if pause is declined): 50% off for 3 months — "$6.49/month for 3 months, then $12.99/month". Implemented via RevenueCat promotional offer.

### Expired & Lapsed State
- **D-13:** Hard paywall on trial or subscription expiry — no free tier. Show paywall screen again.
- **D-14:** Expired state shows plan preview blurred/dimmed behind paywall with copy: "Your plan is waiting" — reminds user what they're missing
- **D-15:** Tapping anywhere on blurred content triggers the paywall — frictionless re-entry
- **D-16:** 3-day grace period on payment failure — RevenueCat handles this automatically; app stays unlocked during grace period

### RevenueCat Integration
- **D-17:** RevenueCat SDK 5.x via SPM (`purchases-ios`). Configure products in RevenueCat dashboard matching App Store Connect product IDs.
- **D-18:** Entitlement: "pro" — gates all workout content. Check `Purchases.shared.customerInfo.entitlements["pro"]?.isActive` before showing content.
- **D-19:** `subscription_status` in Supabase `profiles` table updated via RevenueCat webhook → Supabase Edge Function (server-side source of truth for AI gating)

### Claude's Discretion
- Exact RevenueCat product ID naming convention
- Paywall SwiftUI layout details (card border radius, shadow, spacing)
- Exact value prop copy for the 3-4 bullets
- RevenueCat webhook → Edge Function implementation details
- App Store Connect subscription group configuration

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `profiles` table already has `subscription_status` column (free/subscribed) — Phase 7 updates this via webhook
- `AppState.swift` — add `isSubscribed: Bool` computed from RevenueCat entitlement check
- `ContentView.swift` — add paywall gate: authenticated + onboarded + !isSubscribed → PaywallView
- Phase 3 plan preview "Start Training" CTA → triggers PaywallView presentation

### Established Patterns
- `@Observable @MainActor final class` for PaywallViewModel
- RevenueCat async/await APIs integrate cleanly with Swift Concurrency
- `fullScreenCover` or `sheet` for paywall presentation (consistent with DisclaimerView pattern)

### Integration Points
- Phase 3: "Start Training" CTA passes control to PaywallView
- `AppState` — `isSubscribed` property gates MainTabView content
- Supabase `profiles.subscription_status` — updated server-side via RevenueCat webhook
- Profile tab "Manage Subscription" → CancellationRetentionView

</code_context>

<specifics>
## Specific Ideas

- Paywall card layout: AccentColor "Most Popular" badge top-right of annual card, checkmark bullets for value props, CTA "Start 14-Day Free Trial" (primary, AccentColor fill)
- Fine print below CTA: "Cancel anytime. $79.99/year after trial."
- Retention screen 1 (pause): "Life gets busy — take a break" heading, 3-chip pause selector, "Pause Membership" CTA + "I still want to cancel" link
- Retention screen 2 (discount): "Stay for half price" heading, 3-month offer, "Accept Offer" CTA + "Cancel anyway" link

</specifics>

<deferred>
## Deferred Ideas

- Family/couple plan pricing — v2
- Referral program with subscription credits — v2
- Annual plan upgrade prompt for monthly subscribers — could add in v2
- Promotional codes — RevenueCat supports this, v2 feature

</deferred>

---

*Phase: 07-subscriptions-and-paywall*
*Context gathered: 2026-04-16*
