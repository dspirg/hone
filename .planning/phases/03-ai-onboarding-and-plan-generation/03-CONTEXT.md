# Phase 3: AI Onboarding and Plan Generation - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers:
- A guided-card onboarding flow (4 required cards + 1 optional) that captures user fitness profile
- An AI-generated personalized weekly workout plan shown before the paywall
- SSE streaming plan generation via Supabase Edge Function → OpenAI GPT-4o
- Plan preview screen with full week reveal, inline AI rationale, and regenerate capability
- "Start Training" CTA that triggers the subscription paywall (Phase 7)

No subscription billing, no workout session execution, no coach chat in this phase — those belong to Phases 4, 5, and 7.

</domain>

<decisions>
## Implementation Decisions

### Onboarding Flow (Guided Cards)
- **D-01:** Onboarding uses guided full-screen cards (NOT chat bubbles) — confirmed decision. Each card = one question, tap chip auto-advances to next card.
- **D-02:** 4 required cards in order: (1) Goal, (2) Fitness Level, (3) Days/Week, (4) Equipment. Plus 1 optional card: (5) Injuries/Areas to Avoid — has a visible "Skip" button.
- **D-03:** Answer input: large tap chips. Single-select on cards 1–3 (auto-advance on tap). Multi-select on card 4 (Equipment) with a "Continue" button since multiple answers are valid.
- **D-04:** Progress indicator: numbered pill "2 of 5" at top + thin progress bar below it. Both update as user advances.
- **D-05:** Back navigation: swipe back or back chevron returns to the previous card (editable). If user tries to exit mid-flow (dismiss gesture or home button), show "Quit setup?" confirmation sheet — tapping "Quit" exits onboarding, tapping "Continue Setup" dismisses the sheet.

### Plan Preview
- **D-06:** Full week revealed — all 5 workout days visible in the plan preview. No blurring or locking. Signals confidence in the product.
- **D-07:** AI rationale displayed inline under each exercise as a small coach note, e.g. "Why: builds posterior chain to support your muscle-building goal."
- **D-08:** "Regenerate plan" button visible on the plan preview screen. Tapping it triggers a streaming animation — the plan content updates token by token as the new plan streams in.
- **D-09:** Regeneration cap: 3 free regenerations before onboarding completes. Counter shown ("2 regenerations remaining"). After the cap, button is disabled with copy "Save regenerations for the app."
- **D-10:** "Start Training" CTA at the bottom of the plan preview screen triggers the paywall. User gets to read the full plan before being asked to pay.

### AI Call Architecture
- **D-11:** Plan generation uses SSE streaming. iOS client connects to Supabase Edge Function via URLSession SSE; Edge Function calls OpenAI GPT-4o with streaming enabled and forwards tokens. Client renders plan content as tokens arrive.
- **D-12:** User profile stored in the existing `profiles` table — add columns: `goal` (text), `fitness_level` (text), `days_per_week` (int), `equipment` (text array), `injuries` (text, nullable). These fields are injected into every AI system prompt as the persistent user context.
- **D-13:** Generated plan stored in Supabase `workout_plans` table immediately on completion — never regenerated from scratch on next open. Plan is also persisted to CoreData for offline access.
- **D-14:** `onboarding_completed` bool in `profiles` flips to `true` after the plan is stored. ContentView routing checks this flag — authenticated + not onboarded → show OnboardingView instead of MainTabView.

### Loading & Error States
- **D-15:** Plan generation loading screen shows animated 3-phase copy cycling while SSE streams: "Analyzing your goals…" → "Building your schedule…" → "Selecting your exercises…". Each phase cycles every ~3 seconds until plan arrives.
- **D-16:** On generation failure: auto-retry once silently. If second attempt fails, show "Something went wrong" with a "Try Again" button. Never show a dead-end state.
- **D-17:** No timeout UI — SSE connection keeps the loading state alive. If connection drops (network loss), show "Check your connection and try again" with retry button.

### HomeView Post-Onboarding
- **D-18:** After onboarding, HomeView shows today's scheduled workout — exercise list, estimated duration, and primary muscle groups for that session.
- **D-19:** "Start Workout" CTA is visible but disabled in Phase 3 with subtitle "Session tracking coming soon." The button becomes active in Phase 4. This makes the screen feel real without requiring Phase 4 to be built first.

### Claude's Discretion
- Exact OpenAI system prompt structure and JSON schema for workout plan output (use Structured Outputs)
- Supabase Edge Function Deno implementation details
- SwiftUI card transition animation style (slide, scale, etc.) between onboarding cards
- Exact copy for each onboarding card heading and chip labels
- CoreData `WorkoutPlan` entity schema
- `workout_plans` table column details beyond what's implied by the plan structure
- Which workout day counts as "today" when the plan has no fixed schedule (default to Day 1 if no session log exists)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppState.swift` — add `onboardingCompleted: Bool` property; fetch from Supabase `profiles` on sign-in
- `ContentView.swift` — add third routing branch: `isAuthenticated && !onboardingCompleted` → `OnboardingView()`
- `SupabaseClient.swift` — existing client; profile updates and plan storage use this
- `HomeView.swift` — integration point where the generated plan will surface post-onboarding

### Established Patterns
- `@Observable` + `@Environment(AppState.self)` for shared state — OnboardingViewModel follows same pattern
- `fullScreenCover` pattern (used for DisclaimerView) — OnboardingView presented the same way or as a navigation destination
- Supabase async/await throughout — plan generation Edge Function call follows same pattern
- MVVM: ViewModels are `@Observable @MainActor final class`

### Integration Points
- `ContentView` routing — add `onboarding_completed` check between auth and tab bar
- `profiles` table — add 5 new columns (goal, fitness_level, days_per_week, equipment, injuries)
- New Supabase table: `workout_plans` (stores generated plan JSON)
- New Supabase Edge Function: `generate-plan` (proxies OpenAI GPT-4o with streaming)
- `HomeView` — replace empty state with plan summary card post-onboarding
- `TrainView` — Phase 2 will populate with exercises; Phase 3 populates with the plan's scheduled sessions

</code_context>

<specifics>
## Specific Ideas

- Onboarding card layout: full-bleed card, large heading at top ("What's your main goal?"), chip grid below, progress pill + bar at very top
- Goal chip options: "Build Muscle" / "Lose Fat" / "Get Fitter" / "Athletic Performance"
- Fitness level chips: "Beginner" / "Intermediate" / "Advanced"
- Days/week chips: "2 days" / "3 days" / "4 days" / "5 days"
- Equipment chips (multiselect): "No equipment" / "Dumbbells" / "Barbell" / "Pull-up bar" / "Full gym"
- Plan preview: weekly calendar view with Day 1–5 cards, each card shows exercises for that session
- Regenerate button placement: top-right of plan preview, next to plan title
- "Start Training" CTA: sticky bottom button, full width, AccentColor fill

</specifics>

<deferred>
## Deferred Ideas

- Paywall implementation — belongs to Phase 7
- AI coach chat integration — belongs to Phase 5
- Plan adaptation based on feedback — belongs to Phase 8
- Equipment context switching mid-session (AIPL-04 adaptive plans) — noted for Phase 8 refinement

</deferred>

---

*Phase: 03-ai-onboarding-and-plan-generation*
*Context gathered: 2026-04-16*
*Context updated: 2026-04-17*
