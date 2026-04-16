# Phase 2: Exercise Library - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers a fully browseable, searchable exercise library inside the Train tab:
- Muscle-group-organized browse experience with search and filter chips
- Exercise detail view with inline HLS video playback (Mux), auto-looping, and structured how-to content
- Dual taxonomy: primary muscle group category + equipment filter
- Offline caching for recently viewed and plan-active exercises
- Placeholder state for exercises whose videos are not yet licensed

No AI features, no workout session logging, no plan generation in this phase — those belong to Phases 3–4.

</domain>

<decisions>
## Implementation Decisions

### Browse & Search Experience
- Exercise library is organized by muscle group (sectioned list) with a search bar at the top of the Train tab
- Search covers exercise name + muscle group tags (fuzzy match) — more forgiving for users
- Filter UI uses horizontal scrolling filter chips below the search bar (modern iOS pattern)
- Empty search state shows "No results for [query]" with 3 popular exercise suggestions

### Exercise Detail & Video Playback
- Video plays inline in the detail view; tap-to-fullscreen is supported
- Standard AVKit controls are used (AVPlayerViewController) with a custom play/pause button overlay when paused
- Detail view shows: exercise name, primary muscle groups (tags), 3–5 how-to bullet steps, form tips
- Video auto-loops — exercise demos benefit from repetition; user does not need to tap replay

### Exercise Data & Categories
- Dual taxonomy: primary muscle group (drives browse sections) + equipment tag (secondary filter chip)
- 8 standard muscle groups: Chest, Back, Shoulders, Arms, Core, Legs, Glutes, Full Body
- Target exercise count for v1: 50–100 exercises (sufficient for varied AI-generated plans)
- Unlicensed/missing video exercises are shown with metadata + a placeholder thumbnail — queued for video later, not hidden

### Offline Caching
- Cache scope: recently viewed exercises (last 20–30) + all exercises in the user's active workout plan
- Cache size limit: 500MB max; auto-evict oldest assets when exceeded; cache size visible in Profile/Settings
- Cache invalidation: check for updated video versions on app launch when connected (stale-while-revalidate); no manual clear required by default

### Claude's Discretion
- Exact Mux HLS URL format and AVAssetDownloadTask implementation details
- CoreData schema for exercise entity (fields beyond the decided taxonomy)
- Supabase query structure for exercise data fetch
- Animation/transition for TrainView → ExerciseDetailView navigation
- Placeholder thumbnail design (SF Symbol or static asset)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MainTabView.swift` — Train tab (`TrainView`) is the integration point; replace empty state with ExerciseLibraryView
- `AppState.swift` — shared environment object; exercise/plan state can extend here
- `SupabaseClient.swift` — existing Supabase client; exercise data fetches use this

### Established Patterns
- SwiftUI MVVM: `@Observable` ViewModels, `@Environment(AppState.self)` for app-wide state
- Empty state pattern: SF Symbol (64pt) + `.title2` heading + `.secondary` body + `.horizontal` padding 32
- Tab tint: `Color("AccentColor")` — exercise filter chip selection should use same token
- Navigation: standard SwiftUI NavigationStack push (established in auth flow)

### Integration Points
- `TrainView.swift` — replace empty state body with ExerciseLibraryView
- Supabase `exercises` table (to be created this phase) — fetches exercise metadata
- Mux HLS URLs stored in Supabase, consumed by AVPlayer
- CoreData — new Exercise entity for offline cache; extends existing CoreData stack
- `ProfileView` — cache size display (minor addition, Phase 2 scope)

</code_context>

<specifics>
## Specific Ideas

- Train tab: top section = search bar + filter chips, bottom section = muscle-group sectioned list
- Filter chips: "All", "Chest", "Back", "Shoulders", "Arms", "Core", "Legs", "Glutes", "Full Body" + equipment chips ("Bodyweight", "Dumbbells", "Barbell", "Machine")
- Detail view layout: video player at top (~40% of screen), name + muscle tags below, scrollable how-to steps and tips beneath
- Placeholder for unlicensed video: static gradient card with exercise name and "Video coming soon" caption

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-exercise-library*
*Context gathered: 2026-04-16*
