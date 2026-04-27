# Phase 10: Design System and Visual Identity - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Transform the app from default light/dark appearance to a cohesive dark-mode-first visual identity with amber (#f59e0b) accent, video thumbnails replacing emoji icons for exercises, and "Hone" coach branding with full presence across the app. All 41+ views get updated — full color sweep, no screens left behind.

</domain>

<decisions>
## Implementation Decisions

### Color System (D-01 through D-04)
- **D-01:** Claude's discretion on whether to use a centralized Theme.swift or asset-catalog-only approach — pick the best option given the existing codebase patterns (currently 3 color sets in xcassets, ~41 views referencing colors)
- **D-02:** Claude's discretion on secondary/tertiary color palette beyond amber (#f59e0b) — pick colors that work with dark mode and amber accent for success states, warnings, and text hierarchy
- **D-03:** Full sweep of all ~41 views in the color migration — no screens left inconsistent. Every view gets updated to use the new color system in this phase
- **D-04:** Colors only for this phase — no typography standards. Typography will emerge naturally during Phase 11 screen redesigns

### Hone Coach Identity (D-05 through D-09)
- **D-05:** Avatar style: warm gradient circle (amber-to-orange abstract gradient, no face/character) — modern, clean, scales well
- **D-06:** Full brand presence — Hone name and avatar appear in chat, adaptation summaries, plan generation loading, notification text, AND the home screen. Coach feels present across the entire experience
- **D-07:** Claude's discretion on tone — pick a personality that fits the dark/amber premium aesthetic. Balance between warm/encouraging and confident/direct
- **D-08:** Distinct chat bubble styling — Hone bubbles get subtle amber tint or gradient border with avatar on left; user bubbles are solid dark card, right-aligned. Clear visual separation
- **D-09:** System messages from Hone (adaptation summaries, plan generation) should use the coach name ("Hone suggests..." or similar phrasing)

### Video Thumbnails + Fullscreen (D-10 through D-13)
- **D-10:** Thumbnail source: Mux thumbnail API (image.mux.com/{playback_id}/thumbnail.jpg) — exercises already have muxPlaybackId. Zero local processing
- **D-11:** Claude's discretion on fullscreen video overlay behavior — pick the approach that fits existing codebase patterns (sheet overlay with AVPlayer vs custom overlay)
- **D-12:** Thumbnails appear everywhere exercises are shown — library rows, session exercise cards, plan preview rows, and coach chat exercise mentions. Full consistency
- **D-13:** Tap-to-fullscreen works from any thumbnail location, not just the exercise library

### Dark Mode Migration (D-14 through D-16)
- **D-14:** Force dark mode via `.preferredColorScheme(.dark)` on the root view — one line, forces every screen dark, asset catalog dark variants activate automatically
- **D-15:** Keep both light and dark variants in asset catalog — dark is forced at app level, but infrastructure is ready if light mode is added later
- **D-16:** Trust the full color sweep — auth, onboarding, and paywall screens get updated along with everything else, no special-casing needed

### Claude's Discretion
- Theme architecture: centralized Theme.swift vs asset-catalog-only (D-01)
- Secondary color palette beyond amber (D-02)
- Hone's personality tone (D-07)
- Fullscreen video overlay implementation approach (D-11)
- Error/empty state styling for missing thumbnails
- Transition animations for fullscreen video overlay

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design Direction
- `.planning/sketches/MANIFEST.md` — Sketch winners: 001-A card stack, 002-B compact session, 003-C personality coach
- `.planning/sketches/004-color-comparison/index.html` — Color comparison sketch for dark/amber palette
- `.planning/sketches/005-video-thumbnails/index.html` — Video thumbnail layout sketch
- `.planning/sketches/themes/default.css` — Base theme CSS from sketch sessions

### Asset Catalog (Current State)
- `WorkoutApp/Assets.xcassets/AccentColor.colorset/` — Current accent: rgb(1.0, 0.42, 0.21) → needs to become amber #f59e0b
- `WorkoutApp/Assets.xcassets/AppBackground.colorset/` — Light: near-white (#F5F5F5), Dark: near-black (#0F0F0F)
- `WorkoutApp/Assets.xcassets/CardBackground.colorset/` — Light: white, Dark: #1C1C1E

### Existing Thumbnail Infrastructure
- `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` — Already uses AsyncImage with exercise.thumbnailURL + dumbbell placeholder
- `WorkoutApp/Models/ExerciseModel.swift` — Has thumbnailURL, videoUrl, muxPlaybackId fields
- `WorkoutApp/Models/ExerciseDTO.swift` — DTO with thumbnailUrl and muxPlaybackId from Supabase

### Coach Chat (Current State)
- `WorkoutApp/Features/Coach/Components/ChatBubbleView.swift` — Current chat bubble styling
- `WorkoutApp/Features/Coach/Components/ChatInputBar.swift` — Chat input bar
- `WorkoutApp/Features/Main/Tabs/CoachView.swift` — Coach tab view

### Requirements
- `.planning/REQUIREMENTS.md` §UI Redesign — UI-01, UI-02, UI-03, UI-06

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **ExerciseLibraryRowView**: Already has AsyncImage thumbnail pattern with placeholder — extend to all exercise display contexts
- **ExerciseModel.thumbnailURL**: Computed from muxPlaybackId or direct thumbnailUrl — thumbnail infrastructure exists
- **AsyncImage**: Used for thumbnails already — same pattern scales to session cards, plan preview, chat
- **Asset catalog color sets**: 3 existing sets (AccentColor, AppBackground, CardBackground) — foundation to build on

### Established Patterns
- **@Observable @MainActor**: All ViewModels follow this pattern
- **Color("name")**: Views reference named colors from asset catalog — consistent pattern across codebase
- **AsyncImage with phase switch**: Thumbnail loading pattern with .success/.failure/placeholder handling
- **SF Symbols for placeholders**: dumbbell.fill used as fallback when no thumbnail available

### Integration Points
- **41 view files use Color references**: Full sweep touches every view — need systematic approach
- **MainTabView or App scene**: Root view where .preferredColorScheme(.dark) is applied
- **ChatBubbleView**: Needs restyling for Hone identity (distinct assistant vs user bubbles)
- **CoachView/CoachViewModel**: Need Hone name, avatar gradient, and personality-driven system prompt updates
- **NotificationScheduler**: Notification copy needs "Hone" branding in text
- **PlanGenerationLoadingView**: Loading state needs "Hone is building your plan" messaging
- **AdaptationService**: Adaptation summary text needs "Hone" attribution

</code_context>

<specifics>
## Specific Ideas

- Sketch MANIFEST established reference points: Fitbod (dark premium), Hevy (modern friendly), Strong (speed-first logging). Target: Fitbod's premium feel + warmer, more personal coach presence.
- "Premium gym at night" aesthetic — dark walls, warm lighting, clean equipment
- Coach should feel human and approachable, not clinical

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 10-design-system-and-visual-identity*
*Context gathered: 2026-04-27*
