# Phase 11: Screen Redesigns - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild the three highest-impact screens — Home, Session, and Summary — to match the approved sketch designs (001-A Card Stack, 002-B Compact), giving users a polished and coherent experience across the full workout loop (Home → Session → Summary → Home). Phase 10's design system (Theme.swift, dark mode, amber accent, Hone branding, video thumbnails) is the foundation — this phase applies it to the three screens that matter most.

</domain>

<decisions>
## Implementation Decisions

### Home Screen Layout (D-01 through D-05)
- **D-01:** Exact match to Sketch 001-A — full rebuild of HomeView with greeting, adaptation banner, today's workout card with exercise list, weekly streak bar, and quick stats section
- **D-02:** Greeting shows user's actual name from onboarding profile ("Hey Dan"), with time-of-day prefix ("Good evening"). Falls back to generic greeting if no name available
- **D-03:** Adaptation banner shows rationale text from the last AdaptationService response, Hone-branded ("Hone adjusted your plan..."). Only displayed when a recent adaptation occurred — not always present
- **D-04:** Exercise rows in the Home workout card use 40x40 rounded Mux thumbnails (same pattern as ExerciseLibraryRowView), with SF Symbol dumbbell fallback when no video exists
- **D-05:** Quick stats section shows Sessions, Sets, and PRs in stat pill layout matching Sketch 001-A

### Session Screen Rework (D-06 through D-09)
- **D-06:** Video area shrinks from 16:9 to 2:1 aspect ratio per Sketch 002-B. Tappable to expand to fullscreen via existing VideoOverlayView from Phase 10
- **D-07:** Previous/Best context cards added below set rows — query SessionRepository (CDSetLog/CDSessionLog) for last session's reps and all-time PR per exercise. Cards show "Previous: 10 reps" and "Best: 12 reps" side by side
- **D-08:** Keep existing horizontal card-slide navigation with progress dots for exercise transitions — no change to navigation UX
- **D-09:** Context-aware bottom CTA button: "Complete Set" while sets remain for current exercise, switches to "Next Exercise" when all sets done, "Finish Session" on last exercise of the session

### Summary Screen Tightening (D-10 through D-12)
- **D-10:** Shrink completion checkmark icon from 56pt to 36pt. Merge duration into the stats row (4 items: Exercises, Sets, Reps, Duration) instead of separate section
- **D-11:** Keep emoji difficulty picker at 44pt with labels — space savings come from content above the picker, not the picker itself
- **D-12:** Switch from ScrollView to fixed VStack layout with Spacer distribution — guarantees emoji difficulty picker is always visible without scrolling on standard iPhone displays. PR badges section gets limited height with internal scroll if many PRs

### Cross-Screen Consistency (D-13 through D-16)
- **D-13:** "Start Workout" on Home navigates directly to SessionView — no intermediate TrainView step. TrainView remains accessible from the Train tab for plan browsing
- **D-14:** After "Done" on Summary, user lands back on Home tab with updated stats (streak bar, quick stats reflect completed session). Full loop closure
- **D-15:** Extract shared components: StatPillView (Home + Summary), WeekStreakBar (Home), ExerciseRowView (Home card + Exercise Library). DRY and visually consistent
- **D-16:** Session opens from Home as .fullScreenCover — slides up from bottom for immersive feel. Dismiss slides back down to Home

### Claude's Discretion
- Home screen data loading strategy (parallel vs sequential fetches for plan, stats, adaptation status)
- Exact layout spacing and padding values for the Home card-stack
- Context cards positioning within ExerciseCardView (above or below set rows)
- StatPillView and WeekStreakBar component API design
- How to route Summary dismiss back to Home tab (tab selection state management)
- Animation details for the fullScreenCover transition
- Empty states for context cards when no previous session data exists

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Sketch Designs (Approved Winners)
- `.planning/sketches/MANIFEST.md` — Design direction and sketch winners summary
- `.planning/sketches/001-home-dashboard/index.html` — Sketch 001-A Card Stack (Home screen target)
- `.planning/sketches/002-workout-session/index.html` — Sketch 002-B Compact (Session screen target)
- `.planning/sketches/themes/default.css` — Base theme CSS with color/spacing tokens for reference

### Current Screen Implementations (Files Being Rebuilt)
- `WorkoutApp/Features/Main/Tabs/HomeView.swift` — Current Home screen (single plan card, needs full rebuild)
- `WorkoutApp/Features/Session/SessionView.swift` — Current Session container (ZStack card-slide, rest timer overlay)
- `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` — Current exercise card (16:9 video + scrollable sets)
- `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — Current Summary (ScrollView, generous spacing)

### Design System (From Phase 10)
- `WorkoutApp/Core/Theme/Theme.swift` — Theme tokens (accent, background, surface colors)
- `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` — Hone avatar (for adaptation banner)
- `WorkoutApp/Features/Train/Components/VideoOverlayView.swift` — Fullscreen video overlay (reuse for session tap-to-expand)

### Data Sources
- `WorkoutApp/Core/Data/SessionRepository.swift` — CDSessionLog, CDSetLog (Previous/Best context cards)
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` — Adaptation rationale (Home banner)
- `WorkoutApp/Core/Data/WorkoutPlanRepository.swift` — Active plan fetch (Home workout card)
- `WorkoutApp/Features/Progress/ProgressViewModel.swift` — Streak, stats data (Home quick stats)
- `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` — AsyncImage thumbnail pattern (reuse in Home)

### Requirements
- `.planning/REQUIREMENTS.md` §UI Redesign — UI-04, UI-05, UI-07

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **VideoOverlayView**: Fullscreen video overlay from Phase 10 — reuse for session tap-to-expand from compact 2:1 video
- **ExerciseLibraryRowView**: AsyncImage thumbnail pattern with 40x40 rounded corners and SF Symbol fallback — reuse for Home workout card exercise rows
- **StatCell**: Existing component in SessionSummaryView — refactor into shared StatPillView
- **Theme.swift**: Centralized color tokens (accent, background, surface) — all new components use these
- **HoneAvatarView**: Warm gradient avatar — reuse in Home adaptation banner

### Established Patterns
- **@Observable @MainActor**: All ViewModels follow this pattern — new Home/Session ViewModels should too
- **Theme.* color tokens**: Phase 10 established centralized theming — all new views use Theme.accent, Theme.background, Theme.surface
- **AsyncImage with phase switch**: Thumbnail loading with .success/.failure/placeholder — extend to Home card
- **ZStack card-slide with spring animation**: Session exercise navigation — preserved, not changed
- **.fullScreenCover**: Used for PaywallView already — same pattern for session launch from Home

### Integration Points
- **HomeView**: Full rebuild — new greeting, adaptation banner, workout card, streak bar, stats
- **ExerciseCardView**: Modify video aspect ratio (16:9 → 2:1), add context cards, restructure layout
- **SessionSummaryView**: Convert ScrollView to fixed VStack, merge duration into stats row, shrink icon
- **SessionView**: Add context-aware CTA logic (Complete Set / Next Exercise / Finish Session)
- **MainTabView**: Handle post-session navigation back to Home tab
- **SessionRepository**: Add query methods for previous session reps and all-time PR per exercise

</code_context>

<specifics>
## Specific Ideas

- Home screen should feel like Sketch 001-A's card-stack: greeting at top, workout card as the hero element, streak bar and stats below
- Session context cards (Previous/Best) give users historical reference while logging — key differentiator from basic set logging
- The workout loop (Home → Session → Summary → Home) should feel like one continuous experience, not jumping between disconnected tabs
- "Start Workout" from Home is the primary entry point — one tap to start training

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-screen-redesigns*
*Context gathered: 2026-04-27*
