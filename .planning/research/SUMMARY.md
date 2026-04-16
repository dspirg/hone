# Project Research Summary

**Project:** AI Workout App
**Domain:** AI-powered iPhone fitness app with subscription billing
**Researched:** 2026-04-16
**Confidence:** HIGH

## Executive Summary

This is an AI-first subscription fitness app for iPhone targeting all fitness levels. Research consistently shows that the category's biggest differentiator is authentic AI personalization — plans that visibly adapt to what the user actually did, a conversational coach that remembers context, and real-time difficulty feedback. Competitors like Fitbod have AI-driven plans but users routinely complain they feel mechanical. The opportunity is to close that gap with LLM-powered conversation and transparent reasoning. The recommended approach is: SwiftUI + MVVM on iOS, Supabase (PostgreSQL) for the backend, OpenAI two-model routing (GPT-4o for plan generation, GPT-4o mini for chat), Mux for HLS video delivery, and RevenueCat for subscriptions. All LLM calls must route through Supabase Edge Functions — never from the iOS client directly.

The single biggest dependency and critical path item is animatic exercise video content. The exercise library must exist before in-session flow is usable, which must exist before progress tracking is meaningful, which must exist before the AI coach has enough context to be genuinely useful. Sourcing and licensing video content is not an afterthought — it gates the entire core experience and must be resolved in the earliest phase. Licenses must explicitly cover commercial iOS app distribution worldwide, including any embedded music rights, confirmed in writing before acquisition.

The key risks are: AI cost runaway if per-user token usage is not tracked and capped from day one; App Store rejection for health claims if in-app copy implies medical diagnosis or treatment; dangerous AI health advice without system-prompt safety guardrails; and video license traps. All four are avoidable with early structural decisions. Unit economics are sound: at $0.15–$0.40/user/month in AI inference against a $9.99–$19.99 subscription, margins are viable — but subscription pricing must be modeled against Apple's 30% cut before launch, and annual plan conversion must be a deliberate paywall design goal (annual subscribers retain at 2x the rate of monthly).

## Key Findings

### Recommended Stack

The iOS client should use SwiftUI targeting iOS 16+ minimum (unlocks NavigationStack, RevenueCat SDK 5.x, and stable sheet behavior), Swift 6 with async/await throughout, and vanilla MVVM using the `@Observable` macro. CoreData is preferred over SwiftData for local persistence given SwiftData's ongoing memory and migration limitations — this should be revisited when targeting iOS 19+. All AI calls proxy through Supabase Edge Functions (Deno), which inject the OpenAI API key server-side and enforce per-user rate limits. RevenueCat SDK 5.x handles StoreKit 2 subscription management and saves weeks of plumbing. Mux delivers exercise videos as adaptive HLS streams consumed by AVFoundation's AVPlayer.

**Core technologies:**
- SwiftUI + Swift 6: Primary UI and language — 40% less code than UIKit, compile-time concurrency safety
- CoreData: Local workout persistence — safer than SwiftData for production apps today
- Supabase (PostgreSQL): Backend database and auth — relational model fits workout data; RLS enforces per-user isolation
- Supabase Edge Functions: AI gateway — keeps API keys off device, enables server-side rate limiting
- OpenAI GPT-4o / GPT-4o mini: Dual-model routing — GPT-4o for plan generation, mini for chat (16x cheaper per token)
- RevenueCat SDK 5.x: Subscription management — free to $2,500 MRR, StoreKit 2 under the hood
- Mux: Exercise video HLS delivery — adaptive bitrate, analytics, signed URLs
- KeychainAccess: Secure token storage — required for auth tokens; never UserDefaults

### Expected Features

Research confirms 69% of fitness app users churn within 90 days. The retention model depends on: getting users to experience the AI adapting to them within the first three sessions, showing visible progress before day 30, and making the accumulated training history a switching cost that grows over time.

**Must have (table stakes):**
- Conversational onboarding capturing fitness level, goals, equipment — max 5 screens, max 90 seconds
- AI-generated personalized workout plan shown at end of onboarding, before paywall
- In-session workflow: exercise display, set/rep/weight logging, rest timer
- Exercise library with animatic video demonstrations (~100-150 core movements minimum)
- Equipment context toggle: bodyweight / home gym / full commercial gym
- Workout history and progress tracking: sessions, volume, personal records
- Progressive overload suggestions grounded in logged performance data
- Post-workout difficulty feedback ("too easy / too hard / just right")
- Conversational AI coach chat for plan modifications and questions
- Streak tracking (completion-focused, not performance-focused)
- Monthly + annual subscription with 7-day free trial
- Animated paywall with personalized plan preview before purchase gate
- Apple Health write integration (one-way, low effort, satisfies "health data in one place")

**Should have (competitive differentiators):**
- AI explains its recommendations — "based on your last chest session..." builds trust and perceived intelligence
- Real-time workout adaptation — if sets feel easy, AI bumps weight; if struggling, backs off
- Adaptive plan that evolves visibly over months — primary long-term retention hook
- Personal record celebrations — specific and personalized, not generic
- Smart push notifications — personalized timing, streak-aware, not daily 9am blasts
- Cancellation flow showing progress stats — reduces hard cancels significantly

**Defer to v2+:**
- Apple Watch companion app — validate iOS retention first
- Social sharing beyond exportable summary cards
- Wearable data read integration (Oura, Garmin)
- AR form correction — technically immature in gym environments
- Android — ship iOS first, validate business model

### Architecture Approach

The architecture follows feature-module MVVM: Views bind to `@Observable` ViewModels, ViewModels call protocol-typed Services, Services abstract Supabase/AI/video I/O. Workout sessions must be offline-first — writes go to CoreData immediately, Supabase sync happens in a background `Task.detached`. Network is never in the critical path during an active session. AI context assembly (system prompt + sliding window history + current plan) happens server-side in Edge Functions, not on the iOS client. Subscription entitlement is double-gated: client-side UI gate via RevenueCat + server-side check in Edge Functions before any AI call executes.

**Major components:**
1. iOS SwiftUI App — feature modules (Onboarding, WorkoutSession, AICoach, ExerciseLibrary, Progress, Subscription), each owning its views and viewmodels
2. Supabase Backend — PostgreSQL for relational workout data, Auth for Apple Sign-In and JWT, Edge Functions as AI gateway (generate-plan, chat, adapt-session, update-plan)
3. AI Gateway (Edge Functions) — context assembly, OpenAI proxying with streaming SSE, per-user rate limiting, subscription verification before AI calls
4. Mux Video CDN — HLS animatic video delivery with signed URLs issued per session, adaptive bitrate
5. RevenueCat — subscription state, entitlement verification, StoreKit 2 receipt validation, webhook to Supabase for server-side subscription sync

### Critical Pitfalls

1. **AI gives dangerous or medically irresponsible advice** — Add hard system-prompt rules that immediately deflect any mention of pain, injury, medical conditions, or chest symptoms to a doctor recommendation. Display a prominent "not medical advice" disclaimer on first launch and in chat. Red-team test with 20 health/injury prompts before any user-facing AI goes live. This must happen in the AI foundation phase, not after launch.

2. **App Store rejection for health claims (Guideline 1.4.1)** — Audit every piece of in-app copy before submission. Avoid language implying the app measures, diagnoses, or treats health conditions. Do not integrate HealthKit read access in v1 (triggers additional scrutiny). Include a visible physician-consult recommendation inside the app, not only in terms of service.

3. **LLM cost runaway** — Set hard `max_tokens` caps on every call. Implement tiered model routing (GPT-4o mini for conversational turns, GPT-4o only for plan generation). Track per-user token spend daily from day one with soft and hard alert thresholds. Simulate 10K-user monthly cost from test data before setting subscription pricing.

4. **Video content licensing trap** — Get licenses in writing confirming commercial iOS App Store distribution, worldwide, in perpetuity, including all music rights (master recording AND publishing). "Royalty-free" is not sufficient — verify scope explicitly. Confirm before acquiring any video content.

5. **Subscription pricing ignores Apple's 30% cut** — Model per-user unit economics before setting prices: monthly subscription gross minus Apple's cut (30% year one, 15% year two or under Small Business Program) minus average AI cost ($0.15–$0.40/user/month) equals actual margin. Default-highlight annual plan on paywall; annual subscribers retain at 2x the rate of monthly. Never hardcode prices in UI — use `product.displayPrice` from StoreKit.

## Implications for Roadmap

Based on the dependency chain in FEATURES.md and the build order in ARCHITECTURE.md, eight phases emerge. The critical constraint is that animatic video content gates everything from phase 2 onward, so content sourcing must be treated as a parallel track starting in phase 1.

### Phase 1: Foundation — Auth, Supabase, and Content Sourcing

**Rationale:** Auth is required for everything. Supabase schema must be established before any feature can write data. Video content must begin sourcing immediately because it is the critical path blocker for the entire core experience — this runs in parallel with technical foundation work.
**Delivers:** Working auth flow (Apple Sign-In + email), Supabase schema (users, profiles, plans, sessions, exercises, chat), Edge Function infrastructure, AI safety guardrails in system prompt, and a confirmed video content license in writing.
**Addresses:** User profile capture, equipment context model
**Avoids:** LLM API key in iOS client (Edge Function proxy established here); AI medical advice liability (safety guardrails in system prompt before any user-facing AI)
**Research flag:** Standard patterns — needs no additional research

### Phase 2: Exercise Library and Video Delivery

**Rationale:** Exercise library must exist before in-session flow is usable. This is the second gate. AVPlayer + Mux HLS integration is straightforward but video signing and caching patterns need to be established correctly.
**Delivers:** Exercise library UI with animatic video playback, Mux integration, signed URL generation via Edge Function, local video caching after first play
**Uses:** AVFoundation + Mux HLS, Supabase Edge Functions for signed URL generation
**Implements:** VideoService, ExerciseLibrary feature module
**Avoids:** Storing videos in Supabase Storage (use Mux); loading all videos on app launch (lazy load); YouTube embeds (ToS violation)
**Research flag:** Standard patterns — HLS + AVPlayer is well-documented

### Phase 3: AI Plan Generation and Onboarding

**Rationale:** Plan generation requires the exercise library (Phase 2) to reference real exercises. Onboarding must show a generated plan before the paywall — this is the core conversion moment.
**Delivers:** Conversational onboarding (3-5 screens, under 90 seconds), AI plan generation via Edge Function with streaming SSE, plan displayed before subscription gate, OpenAI Structured Outputs for typed plan schema
**Uses:** OpenAI GPT-4o with Structured Outputs, Supabase Edge Function generate-plan, SSE streaming via AsyncThrowingStream
**Implements:** Onboarding feature module, PlanGenerationViewModel, AIService SSE parser
**Avoids:** Account creation required before seeing content; onboarding exceeding 5 screens; calling OpenAI directly from iOS client
**Research flag:** Needs research — context window management, Structured Outputs JSON schema design for workout plans, Edge Function SSE streaming patterns

### Phase 4: In-Session Workout Experience

**Rationale:** In-session flow is the core daily-use loop. Must be offline-first from the start — retrofitting offline capability is a rewrite. Session data collected here powers progress tracking (Phase 6) and AI adaptation (Phase 8).
**Delivers:** Exercise display with video playback, set/rep/weight logging, rest timer (background-safe), session state persisted to CoreData on every set, background Supabase sync, post-workout difficulty feedback
**Uses:** CoreData for offline-first session state, Swift Actors for timer thread safety, background Tasks for Supabase sync
**Implements:** WorkoutSession feature module with composed TimerController, ExerciseProgressTracker, VideoCoordinator
**Avoids:** Network-dependent session writes; single massive SessionViewModel; workout timer that doesn't survive phone calls
**Research flag:** Standard patterns — offline-first CoreData + background sync is well-documented

### Phase 5: AI Coach Chat

**Rationale:** The conversational coach builds on the plan and session context established in Phases 3-4. Without workout history in the database, the coach cannot give contextually accurate advice and would feel like a generic chatbot. Chat comes after the data pipeline is established.
**Delivers:** Persistent AI chat interface, streaming response rendering (token-by-token), plan modifications via conversation, sliding window context management, "swap exercise" and "reschedule day" intents
**Uses:** OpenAI GPT-4o mini for conversational turns, Supabase Edge Function chat with server-side context assembly, AsyncThrowingStream for streaming
**Implements:** AICoach feature module, ChatViewModel, context sliding window in Edge Function
**Avoids:** Sending full workout history as context (use summarization after 10+ sessions); generic motivational responses; AI that ignores stated injuries from onboarding
**Research flag:** Needs research — context summarization strategies, intent parsing for plan modification requests, handling safety deflection gracefully in streaming responses

### Phase 6: Progress Tracking and History

**Rationale:** Session data from Phase 4 now has enough volume to build meaningful progress views. The "progress history as switching cost" retention mechanic is only valuable if users can see it clearly.
**Delivers:** Workout history view, volume over time charts, personal record tracking and celebration, streak tracking UI, visible progress within first two weeks (micro-progress indicators)
**Uses:** CoreData queries for historical data, Supabase for cross-device history
**Implements:** Progress feature module, ProgressViewModel
**Avoids:** Waiting 30 days to show any progress; empty state with no guidance for new users
**Research flag:** Standard patterns

### Phase 7: Subscriptions and Paywall

**Rationale:** Build the product worth paying for first. Paywall is introduced after users have seen their personalized plan (Phase 3) and experienced at least one session (Phase 4). The paywall shows their generated plan and gates the first workout start.
**Delivers:** Animated paywall with plan preview, 7-day free trial, monthly and annual IAP products, RevenueCat entitlement management, subscription state synced to Supabase via RevenueCat webhook, cancellation flow with progress summary, pause option
**Uses:** RevenueCat SDK 5.x, StoreKit 2, Supabase webhook handler
**Implements:** Subscription feature module, PurchaseService, double-gated entitlement (client + server)
**Avoids:** Hardcoded prices; DIY StoreKit receipt validation; annual plan not prominently featured; subscription pricing without unit economics model
**Research flag:** Needs research — RevenueCat paywall configuration, animated paywall implementation, App Store Small Business Program enrollment, sandbox testing end-to-end renewal flows

### Phase 8: Adaptive AI and Polish

**Rationale:** Real-time workout adaptation requires session history to be meaningful. This is the "it knows me" feature that drives long-term retention but requires the full data pipeline from all prior phases.
**Delivers:** Post-session AI analysis (adapt-session Edge Function adjusts next session difficulty), AI explanations of recommendations, smart push notifications (personalized timing, streak-aware), re-engagement flows at day 7 and day 21 inactivity, Apple Health write integration
**Uses:** Supabase Edge Function adapt-session, CoreData session history
**Implements:** Adaptive difficulty logic, notification scheduling, HealthKit write
**Avoids:** Apple Watch integration (Phase 8 or v2); HealthKit read access in v1 (triggers App Store scrutiny)
**Research flag:** Standard patterns for HealthKit write; needs research for adaptive difficulty algorithm design

### Phase Ordering Rationale

- Content sourcing runs in parallel from Phase 1 — video content is the critical path, not a phase 2 activity
- Subscriptions come last — the product must demonstrate value before gating it; post-onboarding paywall with plan preview is the proven conversion pattern
- AI chat (Phase 5) comes after plan + session foundation because the coach needs that context to be useful rather than generic
- Adaptive AI (Phase 8) comes last because it requires the full data pipeline and enough session history to be calibrated
- Offline-first session architecture (Phase 4) is established from scratch, not retrofitted — this is a structural requirement

### Research Flags

Phases needing deeper research during planning:
- **Phase 3 (AI Plan Generation):** Context window management for plan generation, Structured Outputs JSON schema design, Edge Function SSE streaming to iOS — these are newer integration patterns with limited consolidated documentation
- **Phase 5 (AI Coach Chat):** Context summarization after 10+ turns, intent parsing for plan modifications, streaming safety deflection — nuanced LLM integration patterns
- **Phase 7 (Subscriptions):** RevenueCat animated paywall configuration, end-to-end sandbox subscription test flows, App Store Small Business Program details

Phases with standard well-documented patterns:
- **Phase 1 (Foundation):** Supabase auth + schema setup is well-documented
- **Phase 2 (Exercise Library):** AVFoundation + HLS + Mux is well-documented
- **Phase 4 (In-Session):** Offline-first CoreData + background sync is well-documented
- **Phase 6 (Progress):** Standard data query and chart UI patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core choices verified against official docs and multiple independent sources; SwiftData vs CoreData recommendation is MEDIUM (community consensus on performance issues, not yet official Apple guidance) |
| Features | HIGH | Competitor analysis is thorough; subscription and retention data from RevenueCat industry reports; churn figures from multiple benchmark sources |
| Architecture | HIGH (iOS patterns) / MEDIUM (AI integration) | MVVM, offline-first, and SwiftUI patterns are well-established; AI context management via Edge Functions is emerging best practice with confirmed working examples |
| Pitfalls | HIGH | App Store guidelines from official sources; AI liability from legal case precedents; LLM cost math from current pricing data; video licensing from industry-specific legal sources |

**Overall confidence:** HIGH

### Gaps to Address

- **AI cost projections at scale:** Current estimates are based on average user behavior. Heavy users engaging the coach 30+ minutes/day could exceed model projections by 5-10x. Instrument per-user cost tracking before the first 100 users and run a 90-day cost simulation before setting subscription pricing.
- **Video content availability and licensing timeline:** The number of animatic exercise sources with explicit commercial iOS app licenses is narrow (ExerciseAnimatic.com is the most cited). Sourcing time is unknown. This needs to be validated before committing to a Phase 2 timeline.
- **Subscription pricing:** No pricing has been set. The unit economics model (Apple cut + AI cost + desired margin) must be run before Phase 7 planning. Target range from competitor analysis is $14.99–$19.99/month, but this needs validation against the actual cost model.
- **SwiftData vs CoreData final call:** Research recommends CoreData today, but if the iOS 16 minimum target is raised to iOS 18+, SwiftData becomes viable. This decision should be revisited at Phase 1 planning.
- **OpenAI vs Anthropic:** Both providers are viable. OpenAI is recommended here for Structured Outputs documentation quality. This decision can be revisited at Phase 3 planning without architectural impact (both route through Edge Functions).

## Sources

### Primary (HIGH confidence)
- Apple App Store Review Guidelines — https://developer.apple.com/app-store/review/guidelines/
- OpenAI Structured Outputs — https://developers.openai.com/api/docs/guides/structured-outputs
- Supabase Swift SDK docs — https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui
- Supabase Edge Functions OpenAI streaming — https://supabase.com/docs/guides/ai/examples/openai
- RevenueCat SDK 5.0 release — https://www.revenuecat.com/blog/engineering/revenuecat-sdk-5-0-the-storekit-2-update/
- AVFoundation + HLS — https://www.createwithswift.com/hls-streaming-with-avkit-and-swiftui/
- Mux vs Cloudflare Stream — https://www.mux.com/compare/cloudflare-stream

### Secondary (MEDIUM confidence)
- SwiftData vs CoreData 2025 — https://distantjob.com/blog/core-data-vs-swiftdata/ (community consensus)
- MVVM vs TCA 2025 — https://7span.com/blog/mvvm-vs-clean-architecture-vs-tca (community analysis)
- Adapty State of In-App Subscriptions 2026 — https://adapty.io/state-of-in-app-subscriptions/ (industry report)
- RevenueCat State of Subscription Apps 2025 — https://www.revenuecat.com/state-of-subscription-apps-2025/
- AI chatbot liability precedent — https://www.forthepeople.com/blog/when-ai-chats-go-too-far-lawsuits-raise-alarming-questions-about-chatbots-mental-health-and/
- Fitbod blog best AI fitness apps 2026 — https://fitbod.me/blog/best-ai-fitness-apps-2026-the-complete-guide-to-ai-powered-muscle-building-apps/
- Autentika: Why users abandon fitness apps — https://autentika.com/blog/why-do-users-abandon-fitness-apps

### Tertiary (MEDIUM-LOW confidence)
- OpenAI pricing — https://intuitionlabs.ai/articles/ai-api-pricing-comparison-grok-gemini-openai-claude (verify against platform.openai.com/pricing at time of implementation; prices have dropped ~80% in 12 months)
- ExerciseAnimatic commercial license scope — https://www.exerciseanimatic.com/license (verify in writing before acquisition)

---
*Research completed: 2026-04-16*
*Ready for roadmap: yes*
