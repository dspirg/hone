# Roadmap: AI Workout App

## Milestones

- **v1.0 MVP** — Phases 1-8 (shipped 2026-04-26)
- **v1.1 Polish & Ship** — Phases 9-12 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-8) — SHIPPED 2026-04-26</summary>

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-04-16
- [x] Phase 2: Exercise Library (4/4 plans) — completed 2026-04-17
- [x] Phase 3: AI Onboarding and Plan Generation (5/5 plans) — completed 2026-04-18
- [x] Phase 4: In-Session Workout Experience (5/5 plans) — completed 2026-04-19
- [x] Phase 5: AI Coach Chat (5/5 plans) — completed 2026-04-20
- [x] Phase 6: Progress Tracking (4/4 plans) — completed 2026-04-21
- [x] Phase 7: Subscriptions and Paywall (8/8 plans) — completed 2026-04-24
- [x] Phase 8: Adaptive AI (6/6 plans) — completed 2026-04-25

</details>

### v1.1 Polish & Ship (In Progress)

**Milestone Goal:** Fix integration gaps from v1.0 audit, redesign UI with dark mode + amber brand identity, and ship to the App Store.

- [ ] **Phase 9: Bug Fixes** — Resolve 5 integration gaps identified in v1.0 audit
- [x] **Phase 10: Design System and Visual Identity** — Dark mode, amber accent, video thumbnails, Hone coach branding (completed 2026-04-27)
- [x] **Phase 11: Screen Redesigns** — Rebuild Home, Session, and Summary screens to approved sketches (completed 2026-04-27)
- [x] **Phase 12: App Store Submission** — Icon, screenshots, signing, metadata, and submission (completed 2026-04-28)

## Phase Details

### Phase 9: Bug Fixes
**Goal**: All five v1.0 integration gaps are closed so adaptive AI, progress tracking, and notifications behave correctly without workarounds
**Depends on**: Phase 8 (v1.0 complete)
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04, FIX-05
**Success Criteria** (what must be TRUE):
  1. After a post-session AI adaptation, TrainView shows the updated workout plan immediately without requiring an app relaunch
  2. Missed-session detection sends ISO date strings (YYYY-MM-DD) to the adapt-plan Edge Function, not day-label strings
  3. Workout reminder notifications are rescheduled automatically after every plan generation and plan adaptation
  4. The weekly progress ring shows the user's actual planned days per week from their workout plan, not a hardcoded value
  5. The dead `AppState.isOnboarded` property is removed and no call sites reference it
**Plans:** 2 plans
Plans:
- [x] 09-01-PLAN.md — Wire AdaptationService to persist plans, convert ISO dates, and schedule notifications (FIX-01, FIX-02, FIX-03)
- [x] 09-02-PLAN.md — Dynamic weekly ring + dead property removal (FIX-04, FIX-05)

### Phase 10: Design System and Visual Identity
**Goal**: The app uses a consistent dark mode + amber design language throughout, exercise videos are surfaced as thumbnails, and the AI coach presents as "Hone" with a distinct branded identity
**Depends on**: Phase 9
**Requirements**: UI-01, UI-02, UI-03, UI-06
**Success Criteria** (what must be TRUE):
  1. Every screen in the app uses a dark background with amber (#f59e0b) as the primary accent color — no white or light-mode surfaces remain
  2. Exercise list rows display the video's first-frame thumbnail instead of an emoji icon
  3. Tapping an exercise thumbnail opens a fullscreen video overlay that can be dismissed
  4. The coach chat interface displays the name "Hone", a warm gradient avatar, and personality-driven copy consistent with the Sketch 003-C design
**Plans:** 4/4 plans complete
Plans:
**Wave 1**
- [x] 10-01-PLAN.md — Design system foundation: Theme.swift, asset catalog colors, dark mode forcing, HoneAvatarView, VideoOverlayView

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 10-02-PLAN.md — Color sweep: migrate all 35 non-Coach view files to Theme.* tokens
- [x] 10-03-PLAN.md — Hone identity: coach branding, chat restyling, notification copy, tab label
- [x] 10-04-PLAN.md — Thumbnails + fullscreen: tap-to-play video from library, detail, and plan preview
**UI hint**: yes

### Phase 11: Screen Redesigns
**Goal**: The three highest-impact screens — Home, Session, and Summary — match the approved sketch designs, giving users a polished and coherent experience across a full workout loop
**Depends on**: Phase 10
**Requirements**: UI-04, UI-05, UI-07
**Success Criteria** (what must be TRUE):
  1. The Home screen uses a card-stack layout showing today's workout, weekly streak, and quick stats matching Sketch 001-A
  2. The Session screen uses a compact video layout with Previous and Best context cards visible alongside the exercise, matching Sketch 002-B
  3. The Session Summary screen fits the emoji difficulty picker on screen without scrolling on a standard iPhone display
**Plans:** 4/4 plans complete
Plans:
**Wave 1**
- [x] 11-01-PLAN.md — Shared components + data layer: StatPillView, WeekStreakBar, HomeExerciseRowView, AdaptationBannerView, ContextCardView, SessionRepository queries, AppState.selectedTab

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 11-02-PLAN.md — HomeView full rebuild: greeting, adaptation banner, workout card, streak bar, quick stats, fullScreenCover session launch
- [x] 11-03-PLAN.md — Session modifications: compact 2:1 video, context cards, three-state CTA, MainTabView tab selection
- [x] 11-04-PLAN.md — SessionSummaryView conversion: fixed VStack, merged stats, capped PR section
**UI hint**: yes

### Phase 12: App Store Submission
**Goal**: The app is fully configured for App Store distribution — signed, asset-complete, metadata-complete — and ready to submit for review
**Depends on**: Phase 11
**Requirements**: SHIP-01, SHIP-02, SHIP-03, SHIP-04, SHIP-05, SHIP-06
**Success Criteria** (what must be TRUE):
  1. The app has a 1024x1024 icon registered in the asset catalog and no missing icon warnings in Xcode
  2. A PrivacyInfo.xcprivacy manifest is present and declares all required API usage and tracking domains
  3. StoreKit product IDs registered in App Store Connect match the RevenueCat configuration exactly
  4. An archive build succeeds with the distribution signing configuration and can be uploaded to App Store Connect
  5. App Store screenshots exist for 6.7" and 6.1" display sizes and the App Store listing is complete with title, subtitle, description, keywords, category, and privacy policy URL
**Plans:** 4/4 plans complete
Plans:
**Wave 1**
- [x] 12-01-PLAN.md — Privacy manifest, Prod.xcconfig, AppIcon catalog entry, privacy policy HTML (SHIP-01, SHIP-02, SHIP-04, SHIP-06)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 12-02-PLAN.md — App icon design asset, RevenueCat production key, archive build verification (SHIP-01, SHIP-04)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 12-03-PLAN.md — App Store Connect setup, subscription products, screenshots, listing metadata, submission (SHIP-03, SHIP-05, SHIP-06)
- [x] 12-04-PLAN.md — [GAP CLOSURE] Generate AppIcon-1024.png programmatically (SHIP-01)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-04-16 |
| 2. Exercise Library | v1.0 | 4/4 | Complete | 2026-04-17 |
| 3. AI Onboarding and Plan Generation | v1.0 | 5/5 | Complete | 2026-04-18 |
| 4. In-Session Workout Experience | v1.0 | 5/5 | Complete | 2026-04-19 |
| 5. AI Coach Chat | v1.0 | 5/5 | Complete | 2026-04-20 |
| 6. Progress Tracking | v1.0 | 4/4 | Complete | 2026-04-21 |
| 7. Subscriptions and Paywall | v1.0 | 8/8 | Complete | 2026-04-24 |
| 8. Adaptive AI | v1.0 | 6/6 | Complete | 2026-04-25 |
| 9. Bug Fixes | v1.1 | 0/2 | Planning complete | - |
| 10. Design System and Visual Identity | v1.1 | 4/4 | Complete    | 2026-04-27 |
| 11. Screen Redesigns | v1.1 | 4/4 | Complete    | 2026-04-27 |
| 12. App Store Submission | v1.1 | 4/4 | Complete   | 2026-04-28 |
