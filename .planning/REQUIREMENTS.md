# Requirements: AI Workout App — v1.1

**Defined:** 2026-04-26
**Milestone:** v1.1 Polish & Ship
**Goal:** Fix v1.0 integration bugs, redesign UI with dark mode + amber brand, prepare App Store submission.

## v1.1 Requirements

### Bug Fixes (from v1.0 audit)

- [ ] **FIX-01**: Adapted workout plan is written to CoreData immediately after AI adaptation, so TrainView shows the updated plan without app relaunch
- [ ] **FIX-02**: Missed session detector sends ISO date strings (YYYY-MM-DD) to adapt-plan Edge Function, not day-label strings
- [ ] **FIX-03**: Workout reminder notifications are scheduled after plan generation and plan adaptation
- [ ] **FIX-04**: Weekly progress ring shows the user's actual planned days per week, not a hardcoded value of 4
- [ ] **FIX-05**: Dead `AppState.isOnboarded` property is removed

### UI Redesign

- [ ] **UI-01**: App uses dark mode as the default color scheme with amber (#f59e0b) as the primary accent color
- [ ] **UI-02**: Exercise lists display video thumbnails (first frame from exercise video) instead of emoji icons
- [ ] **UI-03**: Tapping an exercise video thumbnail opens a fullscreen video preview overlay
- [ ] **UI-04**: Home screen uses card-stack layout with today's workout, weekly streak, and quick stats (per Sketch 001-A)
- [ ] **UI-05**: Session screen uses compact video layout with Previous/Best context cards (per Sketch 002-B)
- [ ] **UI-06**: Coach chat displays "Hone" branded identity with warm gradient avatar and personality-driven copy (per Sketch 003-C)
- [ ] **UI-07**: Session summary screen uses tighter layout so emoji difficulty picker is visible without scrolling

### App Store Submission

- [ ] **SHIP-01**: App has a 1024x1024 app icon registered in the asset catalog
- [ ] **SHIP-02**: Privacy manifest (PrivacyInfo.xcprivacy) declares all required API usage and tracking domains
- [ ] **SHIP-03**: StoreKit product IDs are registered in App Store Connect matching RevenueCat configuration
- [ ] **SHIP-04**: Development team and code signing are configured for distribution builds
- [ ] **SHIP-05**: App Store screenshots are generated for 6.7" and 6.1" display sizes
- [ ] **SHIP-06**: App Store listing is complete (title, subtitle, description, keywords, category, privacy policy URL)

## Out of Scope

| Feature | Reason |
|---------|--------|
| New features | v1.1 is polish-only — no new user-facing capabilities |
| Android | Still iPhone-first |
| Light mode support | Dark mode only for v1.1; light mode can be added later |
| Localization | English only for initial App Store submission |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIX-01 | TBD | Pending |
| FIX-02 | TBD | Pending |
| FIX-03 | TBD | Pending |
| FIX-04 | TBD | Pending |
| FIX-05 | TBD | Pending |
| UI-01 | TBD | Pending |
| UI-02 | TBD | Pending |
| UI-03 | TBD | Pending |
| UI-04 | TBD | Pending |
| UI-05 | TBD | Pending |
| UI-06 | TBD | Pending |
| UI-07 | TBD | Pending |
| SHIP-01 | TBD | Pending |
| SHIP-02 | TBD | Pending |
| SHIP-03 | TBD | Pending |
| SHIP-04 | TBD | Pending |
| SHIP-05 | TBD | Pending |
| SHIP-06 | TBD | Pending |

**Coverage:**
- v1.1 requirements: 18 total
- Bug fixes: 5
- UI redesign: 7
- App Store: 6

---
*Requirements defined: 2026-04-26*
