# Milestones

## v1.0 MVP (Shipped: 2026-04-26)

**Phases completed:** 8 phases, 40 plans, 37 tasks

**Key accomplishments:**

- Xcode project scaffolded with Supabase Swift SDK + KeychainAccess via SPM, SupabaseClient singleton with PKCE/Keychain, AppState with authStateChanges routing, profiles table with RLS + SECURITY DEFINER trigger, and xcconfig env var injection
- AI coach safety system prompt with 4 guardrail categories and 10 adversarial red-team test prompts, ready for Phase 3 Edge Function injection
- One-liner:
- 1. [Rule 3 - Blocking] Wrong file paths from previous worktree agent
- ExerciseLibraryViewModel
- One-liner:
- One-liner:
- GPT-4o SSE streaming Edge Function with Structured Outputs, CoreData WorkoutPlan persistence, and Swift Codable models with 10 passing tests covering rationale, equipment prompt injection, and safety guardrails
- PlanSSEClient
- SwiftUI plan preview with 3-ring pulsing loading animation, cycling copy, @Observable ViewModel bridging PlanGenerationService state, day cards with AI rationale coach notes, regenerate button with streaming guard, and sticky Start Training CTA
- One-liner:
- One-liner:
- One-liner:
- SessionSummaryView
- One-liner:
- One-liner:
- One-liner:
- PRResult.swift
- StreakCard.swift
- One-liner:
- One-liner:
- Task 1: StoreKit Configuration file
- RevenueCat webhook now correctly parses nested `{ api_version, event: { type, app_user_id, id } }` payload format
- Expired/lapsed users now see blurred plan preview with tap-to-subscribe on Home tab (D-14, D-15)
- StoreKit config prices corrected to $12.99/$79.99/$6.49 and DiscountOfferView shows specific D-12 pricing copy
- Automated 20/23 verification items; 3 remaining require App Store Connect product registration
- Supabase migration with difficulty_rating and plan_adaptations, CoreData model extension, DifficultyRating Swift enum, planSchema extracted to _shared/ with Zod validation and prompt builder helpers
- Post-session 3-emoji difficulty picker wired from SessionSummaryView through SessionViewModel to CDSessionLog.difficultyRating, with Done button gated on selection
- One-liner:
- AdaptationService wires post-session ratings (Plan 02) to adapt-plan/regenerate-plan Edge Functions (Plan 03): weekly Monday regen, missed session detection, and post-session AI adjustment all trigger from the iOS client via scenePhase and onDone hooks
- Re-engagement notification pipeline complete: guilt blocklist + 2+ miss threshold (D-08) + 2/week frequency cap (D-10) + supportive copy (D-09) wired into AdaptationService foreground check

---

## v1.0 MVP (Shipped: 2026-04-26)

**Phases completed:** 8 phases, 40 plans, 37 tasks

**Key accomplishments:**

- Xcode project scaffolded with Supabase Swift SDK + KeychainAccess via SPM, SupabaseClient singleton with PKCE/Keychain, AppState with authStateChanges routing, profiles table with RLS + SECURITY DEFINER trigger, and xcconfig env var injection
- AI coach safety system prompt with 4 guardrail categories and 10 adversarial red-team test prompts, ready for Phase 3 Edge Function injection
- One-liner:
- 1. [Rule 3 - Blocking] Wrong file paths from previous worktree agent
- ExerciseLibraryViewModel
- One-liner:
- One-liner:
- GPT-4o SSE streaming Edge Function with Structured Outputs, CoreData WorkoutPlan persistence, and Swift Codable models with 10 passing tests covering rationale, equipment prompt injection, and safety guardrails
- PlanSSEClient
- SwiftUI plan preview with 3-ring pulsing loading animation, cycling copy, @Observable ViewModel bridging PlanGenerationService state, day cards with AI rationale coach notes, regenerate button with streaming guard, and sticky Start Training CTA
- One-liner:
- One-liner:
- One-liner:
- SessionSummaryView
- One-liner:
- One-liner:
- One-liner:
- PRResult.swift
- StreakCard.swift
- One-liner:
- One-liner:
- Task 1: StoreKit Configuration file
- RevenueCat webhook now correctly parses nested `{ api_version, event: { type, app_user_id, id } }` payload format
- Expired/lapsed users now see blurred plan preview with tap-to-subscribe on Home tab (D-14, D-15)
- StoreKit config prices corrected to $12.99/$79.99/$6.49 and DiscountOfferView shows specific D-12 pricing copy
- Automated 20/23 verification items; 3 remaining require App Store Connect product registration
- Supabase migration with difficulty_rating and plan_adaptations, CoreData model extension, DifficultyRating Swift enum, planSchema extracted to _shared/ with Zod validation and prompt builder helpers
- Post-session 3-emoji difficulty picker wired from SessionSummaryView through SessionViewModel to CDSessionLog.difficultyRating, with Done button gated on selection
- One-liner:
- AdaptationService wires post-session ratings (Plan 02) to adapt-plan/regenerate-plan Edge Functions (Plan 03): weekly Monday regen, missed session detection, and post-session AI adjustment all trigger from the iOS client via scenePhase and onDone hooks
- Re-engagement notification pipeline complete: guilt blocklist + 2+ miss threshold (D-08) + 2/week frequency cap (D-10) + supportive copy (D-09) wired into AdaptationService foreground check

---
