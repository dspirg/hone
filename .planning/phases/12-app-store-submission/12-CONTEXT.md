# Phase 12: App Store Submission - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Prepare the app for App Store distribution: app icon asset, privacy manifest, code signing for distribution, App Store screenshots with marketing overlays, store listing metadata (title, subtitle, description, keywords), privacy policy page, and submission to App Store Connect. No new features — purely packaging and compliance.

</domain>

<decisions>
## Implementation Decisions

### App Icon (SHIP-01)
- **D-01:** App icon is a bold "H" lettermark in amber/orange gradient (#f59e0b → #f97316) on dark background (#0a0a0a). Typographic style inspired by Halide/Headspace — clean, brandable, distinctive on home screen.
- **D-02:** 1024x1024 PNG, no transparency, no alpha channel (App Store requirement). The icon must be created as a design asset and added to `WorkoutApp/Assets.xcassets/AppIcon.appiconset/`.

### Store Listing (SHIP-06)
- **D-03:** App name: "Hone - AI Workout Coach"
- **D-04:** Subtitle: "Custom plans that adapt to you"
- **D-05:** Description tone: warm & motivational — written from the perspective of meeting a coach, not buying software. Lead with "Meet Hone" voice. Example: "Meet Hone, the coach who knows you. Built around your goals, equipment, and schedule."
- **D-06:** Category: Health & Fitness
- **D-07:** Keywords should target: AI workout, personal trainer, custom workout plan, adaptive fitness, workout coach, exercise tracker

### Screenshots (SHIP-05)
- **D-08:** 4 screenshots in this order: (1) Home screen, (2) AI coach chat, (3) Active session, (4) Session summary + PRs
- **D-09:** All screenshots have marketing text overlays — short amber-colored headlines above device frames on dark background:
  1. "Your workout, ready to go"
  2. "Meet Hone, your AI coach"
  3. "Guided sessions, every rep"
  4. "Track your progress"
- **D-10:** Screenshots required for both 6.7" (iPhone 15 Pro Max / 16 Pro Max) and 6.1" (iPhone 15 Pro / 16 Pro) display sizes

### Privacy & Compliance (SHIP-02)
- **D-11:** Create PrivacyInfo.xcprivacy declaring: NSPrivacyAccessedAPICategoryUserDefaults (RevenueCat SDK uses it internally for caching). Check RevenueCat SDK docs for any additional required declarations.
- **D-12:** No ATT prompt needed — app does no cross-app tracking, no IDFA usage
- **D-13:** No tracking domains to declare
- **D-14:** Privacy policy needs to be created — generate a simple static HTML page and host it (GitHub Pages or similar). Must cover: data collected (email, workout history), AI processing (OpenAI), third-party services (Supabase, RevenueCat, Mux)

### Code Signing (SHIP-04)
- **D-15:** Development team 34A8GVG694 already configured with automatic signing. For distribution, verify archive build succeeds with the existing configuration. Fill in Prod.xcconfig with real Supabase and RevenueCat production keys before distribution build.

### StoreKit Products (SHIP-03)
- **D-16:** Verify RevenueCat product IDs match App Store Connect configuration. The sandbox key is already in Dev.xcconfig — production key goes in Prod.xcconfig.

### Claude's Discretion
- Privacy policy page design and hosting approach (as long as it covers the required topics)
- Exact keyword list (optimize for ASO based on competition analysis)
- Screenshot device frame style (standard Apple frames or frameless)
- Description paragraph structure and exact copy (follow warm/motivational tone per D-05)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Configuration
- `Config/Dev.xcconfig` — Development environment keys (Supabase, RevenueCat sandbox)
- `Config/Prod.xcconfig` — Production environment placeholders (must be filled before distribution)
- `WorkoutApp/WorkoutApp.entitlements` — Apple Sign-In entitlement configured

### Asset Locations
- `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json` — App icon slot (1024x1024 entry exists, no image file yet)

### Requirements
- `.planning/REQUIREMENTS.md` §App Store Submission — SHIP-01 through SHIP-06

### Brand Identity
- `WorkoutApp/Core/Theme/Theme.swift` — Color tokens (#f59e0b amber accent, #0a0a0a background)
- `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` — Hone coach avatar warm gradient

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Theme.swift color tokens: use #f59e0b and #0a0a0a for screenshot overlay design consistency
- HoneAvatarView warm gradient: reference for icon gradient direction

### Established Patterns
- xcconfig-based environment switching (Dev/Prod) — production keys go in Prod.xcconfig, not hardcoded
- Automatic code signing with DEVELOPMENT_TEAM = 34A8GVG694

### Integration Points
- `WorkoutApp.xcodeproj/project.pbxproj` — bundle ID `com.danspirgen.hone`, signing config
- RevenueCat SDK already integrated — just needs prod API key in Prod.xcconfig
- No PrivacyInfo.xcprivacy exists yet — must be created and added to Xcode project

</code_context>

<specifics>
## Specific Ideas

- Icon should feel like a premium fitness app, not a generic utility — the H lettermark in amber gradient achieves this
- Screenshot order deliberately front-loads the AI coach (screenshot 2) since that's the key differentiator from competitors like Strong/Hevy
- Description copy should sound like a friend introducing you to a coach, not a feature spec

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-app-store-submission*
*Context gathered: 2026-04-27*
