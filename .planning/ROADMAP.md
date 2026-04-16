# Roadmap: AI Workout App

## Overview

This roadmap builds a conversational AI personal trainer for iPhone in eight phases. The dependency chain is strict: auth and content sourcing must exist before the exercise library, the exercise library before plan generation, plans before in-session tracking, and session history before the AI coach has meaningful context to work with. Subscriptions gate the product only after users have experienced the core loop. Adaptive AI closes the loop by acting on accumulated session data to continuously evolve the training program.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - iOS project, Supabase auth, backend schema, safety guardrails, and video content sourcing
- [ ] **Phase 2: Exercise Library** - Animatic video delivery via Mux, exercise browse/search/detail UI
- [ ] **Phase 3: AI Onboarding and Plan Generation** - Conversational onboarding, AI-generated personalized plan, pre-paywall plan preview
- [ ] **Phase 4: In-Session Workout Experience** - Offline-first session tracking, video playback, timers, rep/set logging
- [ ] **Phase 5: AI Coach Chat** - Persistent conversational coach with full user context and plan modification
- [ ] **Phase 6: Progress Tracking** - Workout history, streaks, volume charts, personal record notifications
- [ ] **Phase 7: Subscriptions and Paywall** - Animated paywall, free trial, monthly/annual IAP, cancellation retention flow
- [ ] **Phase 8: Adaptive AI** - Post-session adaptation, AI plan evolution, smart push notifications

## Phase Details

### Phase 1: Foundation
**Goal**: Users can create and access their account; the backend schema and AI safety infrastructure are in place; video content is licensed and ready for integration
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, SAFE-01, SAFE-02
**Success Criteria** (what must be TRUE):
  1. User can create an account with email and password and stay logged in across app sessions
  2. User can sign in with Apple from the authentication screen
  3. User can reset a forgotten password via email link
  4. App displays a visible physician-consult disclaimer on first launch
  5. AI system prompt includes safety guardrails that block medical diagnosis or treatment advice (verified by red-team test prompts before any user-facing AI is live)
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell

### Phase 2: Exercise Library
**Goal**: Users can browse, search, and view instructional animatic videos for any exercise; videos cache locally for offline use
**Depends on**: Phase 1
**Requirements**: EXRC-01, EXRC-02, EXRC-03, EXRC-04
**Success Criteria** (what must be TRUE):
  1. Every exercise in the app has a playable animatic-style video with proper form demonstration
  2. User can search and filter exercises by muscle group, equipment, and difficulty level
  3. User can open an exercise detail page showing the video, description, muscles worked, and form tips
  4. A video played during a session plays back offline without re-downloading
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell
**UI hint**: yes

### Phase 3: AI Onboarding and Plan Generation
**Goal**: New users complete a short conversational onboarding and see a fully personalized AI-generated workout plan before hitting the subscription paywall
**Depends on**: Phase 2
**Requirements**: ONBD-01, ONBD-02, ONBD-03, AIPL-01, AIPL-02, AIPL-03, AIPL-04
**Success Criteria** (what must be TRUE):
  1. User completes onboarding through a chat-style flow of 5 screens or fewer and it takes under 90 seconds
  2. User sees an AI-generated weekly workout plan referencing real exercises before any paywall appears
  3. The plan includes a visible AI rationale explaining why each exercise was selected
  4. User can ask the AI to regenerate or adjust their plan from the plan view
  5. AI generates equipment-appropriate plans when the user indicates a different equipment context
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell
**UI hint**: yes

### Phase 4: In-Session Workout Experience
**Goal**: Users can execute a full workout session — watching exercise videos, logging sets and reps, and resting between sets — entirely offline, with data syncing when connectivity returns
**Depends on**: Phase 3
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04
**Success Criteria** (what must be TRUE):
  1. User can watch the animatic video and log completed sets and reps for each exercise during a session
  2. A rest timer automatically activates between sets with a duration the user can configure
  3. Session logging continues without interruption when the device has no internet connection; data syncs automatically when connectivity is restored
  4. User sees a completion summary at the end of each session showing exercises completed, sets, and reps
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell
**UI hint**: yes

### Phase 5: AI Coach Chat
**Goal**: Users can have a persistent conversation with an AI coach that knows their goals, plan, and workout history — and can modify the plan through natural conversation
**Depends on**: Phase 4
**Requirements**: CHAT-01, CHAT-02, CHAT-03, CHAT-04
**Success Criteria** (what must be TRUE):
  1. User can ask any fitness-related question and receive a contextually accurate response from the AI coach at any time
  2. User can modify their workout plan (swap exercise, reschedule day) by telling the AI coach in plain language
  3. AI coach responses reference the user's profile, current plan, and recent workout history — not generic advice
  4. AI coach sends proactive check-in messages based on the user's recent activity and progress patterns
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell
**UI hint**: yes

### Phase 6: Progress Tracking
**Goal**: Users can see their full workout history, streaks, volume trends, and receive notifications when they hit personal records
**Depends on**: Phase 4
**Requirements**: PROG-01, PROG-02, PROG-03, PROG-04
**Success Criteria** (what must be TRUE):
  1. User can scroll through a complete history of every workout session they have completed
  2. User can see their current streak, longest streak, and weekly consistency score
  3. User receives an in-app notification when they set a new personal record on an exercise
  4. User can view charts showing workout volume over time, sessions per week, and performance trends
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell
**UI hint**: yes

### Phase 7: Subscriptions and Paywall
**Goal**: Users are presented with a compelling paywall after seeing their personalized plan; monthly and annual subscription options are offered with a free trial; a cancellation retention flow is active
**Depends on**: Phase 3
**Requirements**: SUBS-01, SUBS-02, SUBS-03, SUBS-04
**Success Criteria** (what must be TRUE):
  1. Paywall is shown after the user sees their AI-generated plan preview; annual plan is pre-selected and shown at a discount
  2. New users receive a free trial period before billing begins
  3. User can purchase a monthly or annual subscription through the paywall without leaving the app
  4. When a user attempts to cancel, they are shown a retention flow offering to pause or apply a discount before completing cancellation
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell
**UI hint**: yes

### Phase 8: Adaptive AI
**Goal**: The AI actively adapts each user's next workout based on post-session feedback and accumulated performance data; smart notifications re-engage lapsed users
**Depends on**: Phase 6
**Requirements**: ADPT-01, ADPT-02, ADPT-03
**Success Criteria** (what must be TRUE):
  1. After rating a session's difficulty, the user's next workout visibly reflects the adjustment (harder or easier)
  2. After several weeks of sessions, the user's training plan has evolved to reflect accumulated performance data
  3. When a user skips or misses sessions, the remaining plan for that week updates accordingly rather than stacking the missed work
**Plans**: 3 plans
Plans:
- [ ] 01-01-PLAN.md — Xcode project scaffold, Supabase backend, core infrastructure
- [ ] 01-02-PLAN.md — AI safety system prompt and red-team tests
- [ ] 01-03-PLAN.md — Auth UI, disclaimer, tab bar shell

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/3 | Planned | - |
| 2. Exercise Library | 0/TBD | Not started | - |
| 3. AI Onboarding and Plan Generation | 0/TBD | Not started | - |
| 4. In-Session Workout Experience | 0/TBD | Not started | - |
| 5. AI Coach Chat | 0/TBD | Not started | - |
| 6. Progress Tracking | 0/TBD | Not started | - |
| 7. Subscriptions and Paywall | 0/TBD | Not started | - |
| 8. Adaptive AI | 0/TBD | Not started | - |
