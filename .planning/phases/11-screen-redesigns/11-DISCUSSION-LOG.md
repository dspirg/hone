# Phase 11: Screen Redesigns - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 11-screen-redesigns
**Areas discussed:** Home screen layout, Session screen rework, Summary screen tightening, Cross-screen consistency

---

## Home Screen Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Exact match | Greeting + adaptation banner + today's workout card with exercise list + streak bar + quick stats. Full rebuild of HomeView. | ✓ |
| Simplified version | Today's workout card + streak bar + Start button. Skip greeting, adaptation banner, and quick stats. | |
| You decide | Claude picks best balance. | |

**User's choice:** Exact match to Sketch 001-A
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Name from profile | "Hey Dan" — uses user's name from onboarding profile. Falls back to generic. | ✓ |
| Generic only | "Good evening" / "Good morning" based on time of day. No name. | |
| You decide | Claude picks based on available profile data. | |

**User's choice:** Name from profile
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| From last adaptation response | AdaptationService stores rationale from AI's last adaptation. Hone-branded. | ✓ |
| Always show coach tip | If no adaptation, show motivational tip instead. Banner always present. | |
| You decide | Claude picks. | |

**User's choice:** From last adaptation response
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Small thumbnails | 40x40 rounded thumbnail from Mux. SF Symbol fallback. Consistent with rest of app. | ✓ |
| Emoji/icon style | Match sketch exactly with emoji icons in colored squares. | |
| You decide | Claude picks. | |

**User's choice:** Small thumbnails
**Notes:** None

---

## Session Screen Rework

| Option | Description | Selected |
|--------|-------------|----------|
| Compact + tap-to-expand | 2:1 aspect ratio, tap to open fullscreen VideoOverlayView. | ✓ |
| Compact only, no expand | 2:1 aspect ratio, no tap interaction. | |
| You decide | Claude picks. | |

**User's choice:** Compact + tap-to-expand
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Query SessionRepository | Fetch from CDSetLog/CDSessionLog — last session reps + all-time PR per exercise. | ✓ |
| From ProgressViewModel PR data | Reuse existing PR detection. May lack per-exercise granularity for Previous. | |
| You decide | Claude picks. | |

**User's choice:** Query SessionRepository
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Keep card slide | Horizontal slide with progress dots. Established Phase 4 pattern. | ✓ |
| Vertical scroll | All exercises in single vertical scroll. | |
| You decide | Claude picks. | |

**User's choice:** Keep card slide
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Context-aware CTA | "Complete Set" / "Next Exercise" / "Finish Session" based on progress. | ✓ |
| Keep current pattern | "Next Exercise" / "Finish Session" only. Set completion via checkmark buttons. | |
| You decide | Claude picks. | |

**User's choice:** Context-aware CTA
**Notes:** None

---

## Summary Screen Tightening

| Option | Description | Selected |
|--------|-------------|----------|
| Shrink icon + merge stats | Reduce checkmark to 36pt, merge duration into stats row. Keeps all content, more compact. | ✓ |
| Remove icon entirely | Drop checkmark, start with heading. Most aggressive savings. | |
| You decide | Claude picks tightest polished layout. | |

**User's choice:** Shrink icon + merge stats
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Keep 44pt with labels | Current size good for touch targets. Focus savings above picker. | ✓ |
| Shrink to 36pt | Slightly smaller, saves ~20pt vertical. Labels stay. | |
| You decide | Claude picks. | |

**User's choice:** Keep 44pt with labels
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed layout, no scroll | VStack with Spacer distribution. Guarantees picker always visible. PRs get limited height. | ✓ |
| Tighter ScrollView | Keep ScrollView, reduce spacing. Doesn't guarantee picker visibility. | |
| You decide | Claude picks. | |

**User's choice:** Fixed layout, no scroll
**Notes:** None

---

## Cross-Screen Consistency

| Option | Description | Selected |
|--------|-------------|----------|
| Home → Session directly | "Start Workout" goes straight to session. Reduces friction. TrainView stays on Train tab. | ✓ |
| Home → TrainView → Session | Navigate to plan overview first, then start. Two taps. | |
| You decide | Claude picks. | |

**User's choice:** Home → Session directly
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Back to Home | Summary dismiss lands on Home. Stats refresh. Full loop closure. | ✓ |
| Stay on Train tab | Current behavior — pops back to TrainView. | |
| You decide | Claude picks. | |

**User's choice:** Back to Home
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Extract shared components | StatPillView, WeekStreakBar, ExerciseRowView. DRY and consistent. | ✓ |
| Keep separate | Each screen owns components. Simpler, less coupling. | |
| You decide | Claude extracts only clear reuse. | |

**User's choice:** Extract shared components
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Full screen cover | .fullScreenCover — slides up, immersive. Clear modal separation. | ✓ |
| NavigationStack push | Standard push — slides from right. Stays in NavStack. | |
| You decide | Claude picks. | |

**User's choice:** Full screen cover
**Notes:** None

---

## Claude's Discretion

- Home screen data loading strategy (parallel vs sequential)
- Exact layout spacing and padding values
- Context cards positioning within ExerciseCardView
- Shared component API design
- Post-session navigation back to Home tab implementation
- Animation details
- Empty states for context cards

## Deferred Ideas

None.
