# Phase 10: Design System and Visual Identity - Research

**Researched:** 2026-04-27
**Domain:** SwiftUI design systems, asset catalog color management, AVFoundation video overlays, iOS dark mode migration
**Confidence:** HIGH — entire codebase was read directly; all patterns verified in source files

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Color System:**
- D-01: Claude's discretion on Theme.swift vs asset-catalog-only — pick best given codebase patterns
- D-02: Claude's discretion on secondary/tertiary palette beyond amber — pick colors that work with dark mode and amber
- D-03: Full sweep of all ~41 views — no screens left inconsistent
- D-04: Colors only for this phase — no typography standards. Typography deferred to Phase 11

**Hone Coach Identity:**
- D-05: Avatar style: warm gradient circle (amber-to-orange abstract gradient, no face/character)
- D-06: Full brand presence — Hone name and avatar appear in chat, adaptation summaries, plan generation loading, notification text, AND the home screen
- D-07: Claude's discretion on tone — premium, warm/encouraging yet confident/direct
- D-08: Distinct chat bubble styling — Hone bubbles get subtle amber tint or gradient border with avatar on left; user bubbles are solid dark card, right-aligned
- D-09: System messages from Hone use the coach name ("Hone suggests..." or similar phrasing)

**Video Thumbnails + Fullscreen:**
- D-10: Thumbnail source: Mux thumbnail API (`image.mux.com/{playback_id}/thumbnail.jpg`) — exercises already have `muxPlaybackId`
- D-11: Claude's discretion on fullscreen video overlay behavior
- D-12: Thumbnails appear everywhere exercises are shown — library rows, session exercise cards, plan preview rows, coach chat exercise mentions
- D-13: Tap-to-fullscreen works from any thumbnail location

**Dark Mode Migration:**
- D-14: Force dark mode via `.preferredColorScheme(.dark)` on root view
- D-15: Keep both light and dark variants in asset catalog
- D-16: Full scope sweep — auth, onboarding, paywall get updated too

### Claude's Discretion
- Theme architecture: centralized Theme.swift vs asset-catalog-only (D-01)
- Secondary color palette beyond amber (D-02)
- Hone's personality tone (D-07)
- Fullscreen video overlay implementation approach (D-11)
- Error/empty state styling for missing thumbnails
- Transition animations for fullscreen video overlay

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-01 | App uses dark mode as the default color scheme with amber (#f59e0b) as the primary accent color | Verified: 3 colorsets in xcassets need updating; `.preferredColorScheme(.dark)` on `ContentView`; 98 Color() references need migration to Theme tokens |
| UI-02 | Exercise lists display video thumbnails (first frame from exercise video) instead of emoji icons | Verified: `ExerciseLibraryRowView` already has AsyncImage pattern; `ExerciseModel.thumbnailURL` exists; need to extend thumbnail to session cards, plan preview rows, coach chat |
| UI-03 | Tapping an exercise video thumbnail opens a fullscreen video preview overlay | Verified: existing `VideoPlayerView` uses `UIViewControllerRepresentable` + `AVPlayerViewController`; `fullScreenCover` is the correct presentation pattern; AVPlayerLooper is broken for HLS — use seek-to-zero loop instead |
| UI-06 | Coach chat displays "Hone" branded identity with warm gradient avatar and personality-driven copy (per Sketch 003-C) | Verified: `ChatBubbleView`, `CoachHeaderView`, `CoachView` streaming bubble, `NotificationScheduler` — 5 distinct files need "Coach" → "Hone" text replacement + new `HoneAvatarView` component |
</phase_requirements>

---

## Summary

Phase 10 is a visual identity migration across a mature SwiftUI codebase (~80 Swift source files, ~41 view files). The codebase already has solid infrastructure to build on: a 3-color asset catalog with dark variants, `AsyncImage` thumbnails in `ExerciseLibraryRowView`, and `AVPlayerViewController` wrapped in `UIViewControllerRepresentable`. This is not a greenfield design problem — it is a systematic sweep that replaces every direct `Color("AccentColor")`, `Color("AppBackground")`, and `Color("CardBackground")` reference with typed `Theme.*` tokens, updates three asset catalog colorsets (plus adds four new ones), creates two new reusable components (`HoneAvatarView` and `VideoOverlayView`), and renames/restyled the coach identity across five files.

The UI-SPEC (10-UI-SPEC.md) is already complete and serves as the authoritative design contract. Research confirms all decisions are technically sound and implementable with SwiftUI native primitives — no third-party dependencies are introduced in this phase. The most nuanced tasks are (1) the fullscreen video overlay implementation (HLS looping caveat), and (2) ensuring `.preferredColorScheme(.dark)` is placed on `ContentView` and not deeper in the tree to guarantee it propagates through `fullScreenCover` presentations.

**Primary recommendation:** Work in four sequential waves — (1) asset catalog + Theme.swift foundation, (2) color sweep across all views, (3) Hone identity components, (4) thumbnail + video overlay propagation. This ordering ensures each wave builds on stable foundations without cascading merge conflicts.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Color token definition | iOS Client (Theme.swift) | Asset Catalog | SwiftUI reads named colors from xcassets; Theme.swift is a type-safe wrapper — no backend involvement |
| Dark mode forcing | iOS Client (ContentView modifier) | — | `.preferredColorScheme(.dark)` is a SwiftUI view modifier applied at the root scene; propagates automatically to all child views including fullScreenCover sheets |
| Video thumbnail fetching | iOS Client (AsyncImage) | Mux CDN | `AsyncImage` resolves URLs asynchronously; thumbnails are served from `image.mux.com` — no local processing, no backend changes needed |
| Fullscreen video playback | iOS Client (AVPlayerViewController) | Mux HLS | `AVPlayerViewController` wraps Mux playback; client-only, no backend changes |
| Hone avatar rendering | iOS Client (HoneAvatarView) | — | Pure SwiftUI `LinearGradient` clipped to a `Circle`; no asset files, no server |
| Notification copy | iOS Client (NotificationScheduler) | — | UNUserNotificationCenter strings are set locally; copy changes are Swift string literals only |
| Adaptation summary display | iOS Client (TrainView / AdaptationSummaryBanner) | — | `lastAdjustmentSummary` is already in `AdaptationService`; banner exists, needs Hone attribution prefix prepended to the string |

---

## Standard Stack

### Core (all already in project — no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All UI views | Already the project's primary framework — CLAUDE.md |
| AVFoundation + AVKit | iOS 16+ | Video playback, `AVPlayerViewController` | Already used in `VideoPlayerView.swift`; HLS-native |
| MuxPlayerSwift | (existing) | Mux playback ID → `AVPlayerViewController` | Already integrated; `VideoPlayerView` uses `AVPlayerViewController(playbackID:playbackOptions:)` |
| UIKit (UIViewControllerRepresentable) | iOS 16+ | Bridge for `AVPlayerViewController` | Already used in `VideoPlayerView.swift` |

### No New Dependencies

This phase introduces zero new SPM packages. All capabilities are achievable with:
- SwiftUI native views and modifiers (`LinearGradient`, `Circle`, `.fullScreenCover`, `.preferredColorScheme`)
- The existing `AVPlayerViewController` / `MuxPlayerSwift` integration
- Asset catalog color sets

**Installation:** None required.

---

## Architecture Patterns

### System Architecture Diagram

```
User taps thumbnail anywhere in app
           |
           v
    [Any view holding ThumbnailView]
           |
    .fullScreenCover(isPresented: $showVideo)
           |
           v
    [VideoOverlayView]
    - Color.black.ignoresSafeArea()
    - VideoPlayerView(muxPlaybackId:localAssetURL:)   ← reuses existing component
           |
           v
    [AVPlayerViewController via UIViewControllerRepresentable]
    - Mux Smart Cache (online path)
    - Local asset URL (offline path)
    - seek-to-zero loop (NOT AVPlayerLooper — HLS incompatible)
           |
           v
    User dismisses (native X button or swipe-down)
```

```
Color reference call site (any view)
           |
           v
    Theme.accent / Theme.background / Theme.surface / etc.
           |
           v
    Color("AccentColor") / Color("AppBackground") / Color("CardBackground")  [static wrapper]
           |
           v
    xcassets dark variant activated automatically
    (because .preferredColorScheme(.dark) on ContentView forces dark appearance)
```

### Recommended Project Structure

```
WorkoutApp/
├── Core/
│   ├── Theme.swift                  ← NEW: color + spacing tokens
│   └── Components/
│       └── (existing chips, progress)
├── Features/
│   ├── Coach/
│   │   └── Components/
│   │       ├── ChatBubbleView.swift        ← MODIFY: Hone style
│   │       ├── CoachHeaderView.swift       ← MODIFY: Hone name + avatar
│   │       └── HoneAvatarView.swift        ← NEW: reusable gradient circle
│   └── Train/
│       ├── ExerciseLibraryRowView.swift    ← MODIFY: add tap-to-fullscreen
│       └── VideoOverlayView.swift          ← NEW: fullScreenCover wrapper
└── Assets.xcassets/
    ├── AccentColor.colorset         ← UPDATE: burnt orange → amber #f59e0b
    ├── AppBackground.colorset       ← UPDATE: add dark variant #0a0a0a
    ├── CardBackground.colorset      ← UPDATE: update dark variant #161616
    ├── SurfaceElevated.colorset     ← NEW
    ├── BorderSubtle.colorset        ← NEW
    ├── SuccessGreen.colorset        ← NEW
    └── DestructiveRed.colorset      ← NEW
```

### Pattern 1: Theme.swift Centralized Token File

**What:** A Swift file of static computed `Color` properties that wrap asset catalog named colors, plus a `Spacing` enum with fixed CGFloat constants.

**When to use:** Every view in the app — replace direct `Color("AccentColor")` calls with `Theme.accent`.

**Why this approach over raw asset catalog calls:**
- Single rename point if a color name changes in xcassets
- Autocomplete and compile-time safety (typos in `Color("AccentColor")` fail silently at runtime)
- Consistent with the existing 3-color pattern; extensible to 7 colors

**Example:**
```swift
// Source: CONTEXT.md D-01, UI-SPEC Design System section
// WorkoutApp/Core/Theme.swift

import SwiftUI

enum Theme {
    // MARK: - Colors (backed by asset catalog dark variants)
    static let accent = Color("AccentColor")           // #f59e0b amber
    static let background = Color("AppBackground")      // #0a0a0a
    static let surface = Color("CardBackground")        // #161616
    static let surfaceElevated = Color("SurfaceElevated") // #1e1e1e
    static let borderSubtle = Color("BorderSubtle")     // #2a2a2a
    static let successGreen = Color("SuccessGreen")     // #34d399
    static let destructiveRed = Color("DestructiveRed") // #f87171

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
}
```

**Migration:** After Theme.swift exists, every `Color("AccentColor")` → `Theme.accent`, `Color("AppBackground")` → `Theme.background`, `Color("CardBackground")` → `Theme.surface`.

### Pattern 2: Forcing Dark Mode at Root

**What:** A single `.preferredColorScheme(.dark)` modifier on `ContentView` forces the entire app into dark appearance.

**Critical placement rule:** Must be on `ContentView` (or higher), NOT on `MainTabView`. The reason: `fullScreenCover` presentations inherit color scheme from their hosting window, not from the view that presents them. If applied to `MainTabView`, the `PaywallView` and `DisclaimerView` fullScreenCovers may render in light mode on older iOS versions.

**Example:**
```swift
// Source: CONTEXT.md D-14, UI-SPEC Dark Mode Migration Contract
// WorkoutApp/WorkoutApp.swift — apply to ContentView

struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)   // ← ADD HERE, not on MainTabView
                .environment(appState)
                // ...
        }
    }
}
```

**Verification after applying:** Xcode Simulator → Features → Toggle Appearance. No white surfaces should remain.

### Pattern 3: HoneAvatarView (Reusable Gradient Circle)

**What:** A SwiftUI `View` that renders a `LinearGradient` filled circle in amber-to-orange.

**When to use:** Chat header, chat bubble leading avatar, home screen coach card. Pass `diameter` as a parameter to match context-specific sizes (36pt chat, 48pt home).

**Example:**
```swift
// Source: CONTEXT.md D-05, UI-SPEC Hone Avatar Gradient section
// WorkoutApp/Features/Coach/Components/HoneAvatarView.swift

import SwiftUI

struct HoneAvatarView: View {
    let diameter: CGFloat

    var body: some View {
        LinearGradient(
            colors: [Theme.accent, Color(red: 0.976, green: 0.451, blue: 0.086)], // #f97316
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(Circle())
        .frame(width: diameter, height: diameter)
    }
}
```

### Pattern 4: VideoOverlayView (Fullscreen Tap-to-Play)

**What:** A view that wraps the existing `VideoPlayerView` inside a `.fullScreenCover` to present full-screen video from any exercise thumbnail.

**Decision basis (D-11):** `.fullScreenCover` over `.sheet` because sheets show a partial cover on iPad and are dismissible by swipe on iPhone by default — `.fullScreenCover` maps better to a video viewing UX. The existing `VideoPlayerView.swift` is reused as-is; `VideoOverlayView` is a thin coordinator.

**HLS looping caveat (CRITICAL — verified in VideoPlayerView.swift):** The existing codebase comment is authoritative: "Do NOT use AVPlayerLooper — broken for HLS streams (duplicate downloads)." The correct loop pattern is `seek(to: .zero)` in an `AVPlayerItemDidPlayToEndTime` observer. This is already implemented in `VideoPlayerView.swift` and must NOT be changed.

**Example:**
```swift
// Source: CONTEXT.md D-11, VideoPlayerView.swift existing implementation
// WorkoutApp/Features/Train/VideoOverlayView.swift

import SwiftUI
import AVKit

struct VideoOverlayView: View {
    let muxPlaybackId: String
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoPlayerView(muxPlaybackId: muxPlaybackId, localAssetURL: nil)
        }
        .ignoresSafeArea()
    }
}
```

**Thumbnail tap wiring:**
```swift
// In any view that shows a thumbnail:
@State private var showVideo = false

// Thumbnail:
thumbnailView
    .onTapGesture { showVideo = true }
    .accessibilityLabel("\(exerciseName) — tap to play video")
    .fullScreenCover(isPresented: $showVideo) {
        VideoOverlayView(muxPlaybackId: exercise.muxPlaybackId ?? "", exerciseName: exercise.name)
    }
```

### Pattern 5: Chat Bubble Hone Restyling

**What:** `ChatBubbleView` needs two changes: (1) replace "Coach" text + `figure.run` icon with "Hone" text + `HoneAvatarView`, and (2) replace `Color(.systemGray6)` assistant bubble background with `Theme.surface` + 1pt `Theme.borderSubtle` stroke.

**The streaming bubble in `CoachView.swift`** has an inline duplicate of the coach label (lines 57-64 in CoachView.swift) — it must also be updated in sync with `ChatBubbleView`.

**Example:**
```swift
// Source: CONTEXT.md D-08, UI-SPEC Chat Bubble Styling table
// In ChatBubbleView.swift — assistant label (role == .coach):
HStack(spacing: 6) {
    HoneAvatarView(diameter: 20)
    Text("Hone")
        .font(.caption2)
        .foregroundStyle(.secondary)
}
```

### Anti-Patterns to Avoid

- **AVPlayerLooper for HLS:** Causes duplicate network downloads. The `VideoPlayerView.swift` codebase comment documents this explicitly — use seek-to-zero loop instead. [VERIFIED: codebase]
- **Hardcoded hex colors in Swift:** `Color(hex: "#f59e0b")` in views bypasses the asset catalog dark variant system. All colors must go through named color sets. [VERIFIED: UI-SPEC]
- **`.preferredColorScheme(.dark)` on `MainTabView`:** Does not propagate into `fullScreenCover` presentations. Must be on `ContentView` (or `WindowGroup`). [ASSUMED — behavior is documented in Apple developer docs but not directly tested here]
- **Applying thumbnail tap handling only to ExerciseLibraryRowView:** D-12 requires thumbnails in all four exercise display contexts. The session `ExerciseCardView` shows a full `VideoPlayerView` already — it does NOT need a thumbnail, it needs a different analysis (see Open Questions).
- **`.sheet` for video overlay:** Shows partial cover on iPad, undesirable for video viewing. Use `.fullScreenCover`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mux thumbnail URL construction | Custom URL builder | `ExerciseModel.thumbnailURL` (already exists) | Pattern is already correct: `image.mux.com/{id}/thumbnail.jpg?time=0&width=200` |
| HLS video looping | AVPlayerLooper | seek-to-zero in AVPlayerItemDidPlayToEndTime observer | AVPlayerLooper is documented as broken for HLS; VideoPlayerView.swift already has the correct implementation |
| Color token system | Custom property wrapper | Theme.swift static Color constants (asset catalog backed) | Asset catalog handles dark/light variants automatically; static properties give compile-time safety |
| Dark mode adoption | Per-view `.colorScheme` overrides | Single `.preferredColorScheme(.dark)` on root | Per-view overrides create maintenance burden and may conflict with system sheet styling |
| Gradient avatar | PNG/SVG asset | SwiftUI `LinearGradient` + `.clipShape(Circle())` | No asset to manage; scales perfectly to any size; easily animated later |
| Notification copy strings | Centralized string catalog | Direct string literals in NotificationScheduler | These are 4 string literals in one file; a string catalog would be over-engineering for this scope |

**Key insight:** The existing codebase already contains 80% of the infrastructure. This phase connects and recolors existing pieces more than it builds new ones.

---

## Common Pitfalls

### Pitfall 1: `.preferredColorScheme(.dark)` on the Wrong View

**What goes wrong:** Dark mode is forced only on views that are direct children of the modified view. `fullScreenCover` presentations (PaywallView, DisclaimerView, PaywallView from HomeView) may render in light mode because they use a separate UIHostingController that inherits from the window, not the presenting view.

**Why it happens:** `fullScreenCover` creates a new presentation context. The `.preferredColorScheme` modifier propagates through the SwiftUI view tree but NOT through UIKit presentation boundaries unless applied high enough in the tree.

**How to avoid:** Apply `.preferredColorScheme(.dark)` in `WorkoutApp.body` on the `ContentView()` call — or on the `WindowGroup` itself. Both propagate through presentation boundaries correctly.

**Warning signs:** PaywallView or DisclaimerView appears with white backgrounds after migration.

### Pitfall 2: `Color(.systemGray6)` Surviving the Sweep

**What goes wrong:** Six locations in the codebase use `Color(.systemGray6)` or `Color(.systemGray4)` — these are light-mode-biased system colors. In forced dark mode they render as dark grays, but their exact shade will not match the `Theme.surface` / `Theme.borderSubtle` tokens, creating visual inconsistency.

**Why it happens:** These were added for chat bubbles before the dark mode decision. They weren't part of the original named color sweep.

**How to avoid:** The sweep must explicitly include these locations. Verified locations:
- `ChatBubbleView.swift:27` — `Color(.systemGray6)` assistant bubble → `Theme.surface`
- `ChatInputBar.swift:21` — `Color(.systemGray6)` input field background → `Theme.surface`
- `ChatInputBar.swift:32` — `Color(.systemGray4)` disabled send button → `Theme.borderSubtle`
- `OfflineBannerView.swift:10` — `Color(.systemGray6)` → `Theme.surface`
- `CoachView.swift:71` — `Color(.systemGray6)` streaming bubble → `Theme.surface`
- `CoachView.swift:90` — `Color(.systemGray6)` error bubble → `Theme.surface`

**Warning signs:** Chat bubbles look a different shade of dark than other cards after migration.

### Pitfall 3: ExerciseCardView Thumbnail Misunderstanding

**What goes wrong:** Assuming `ExerciseCardView` (session view) needs a thumbnail added like the other contexts.

**Why it happens:** D-12 says "thumbnails everywhere exercises are shown" — but `ExerciseCardView` already shows a FULL `VideoPlayerView` (16:9 embedded player) at the top of the card. It does NOT use a thumbnail. Adding a thumbnail tap affordance to the session card would be redundant — the full video is already playing.

**How to avoid:** The thumbnail + tap-to-fullscreen pattern applies to: library rows (52x52), plan preview rows (52x52), and coach chat mentions (44x44). The session card has its own in-context player and is already complete.

**Warning signs:** Double video players or redundant UI in SessionView.

### Pitfall 4: AccentColor Colorset Missing Light Variant

**What goes wrong:** The current `AccentColor.colorset` has only a universal (light) entry — no dark-specific entry. The dark mode value was implicitly the same burnt-orange color. After migration to amber, the colorset must have explicit dark AND light entries.

**Why it happens:** The original colorset was created before dark mode was a design concern.

**How to avoid:** When updating `AccentColor.colorset`, add both a universal (or light) entry (`#d97706` amber-700) AND a dark appearance entry (`#f59e0b` amber). The dark entry is what actually shows since `.preferredColorScheme(.dark)` forces dark appearance.

**Warning signs:** Accent color appears different from expected amber after dark mode forcing.

### Pitfall 5: AVPlayerLooper Confusion in New VideoOverlayView

**What goes wrong:** Developer creates `VideoOverlayView` and reaches for `AVPlayerLooper` for looping, not realizing the project already solved this differently.

**Why it happens:** `AVPlayerLooper` is the "obvious" SwiftUI-era solution for looping video.

**How to avoid:** `VideoOverlayView` should reuse `VideoPlayerView` as-is. The seek-to-zero loop pattern is already in `VideoPlayerView.Coordinator.setupLooping()`. The new overlay just presents the existing `VideoPlayerView` inside a `.fullScreenCover`.

**Warning signs:** Video downloads run twice, or loop stutters on HLS content.

### Pitfall 6: Tab Bar "Coach" Label

**What goes wrong:** The tab bar label "Coach" in `MainTabView.swift` is not updated to "Hone" during the identity sweep.

**Why it happens:** `MainTabView.swift` is not in the Coach/ feature directory — it's easy to miss in a file-by-file sweep of the Coach feature.

**How to avoid:** D-06 specifies full brand presence. The tab bar label `Label("Coach", systemImage: "message")` must become `Label("Hone", systemImage: "message")`.

**Warning signs:** Coach tab shows "Hone" at the top but "Coach" at the bottom tab bar.

---

## Code Examples

### Asset Catalog Color Value (Amber in JSON)

```json
// Source: CONTEXT.md D-01, UI-SPEC Asset Catalog Updates table
// WorkoutApp/Assets.xcassets/AccentColor.colorset/Contents.json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "alpha": "1.000",
          "red": "0.961",
          "green": "0.620",
          "blue": "0.043"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [{"appearance": "luminosity", "value": "dark"}],
      "color": {
        "color-space": "srgb",
        "components": {
          "alpha": "1.000",
          "red": "0.961",
          "green": "0.620",
          "blue": "0.043"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": {"author": "xcode", "version": 1}
}
```

Note: #f59e0b = sRGB (0.961, 0.620, 0.043). The `AccentColor` needs both a universal and dark appearance entry; currently only has one universal entry.

### Notification Copy Update

```swift
// Source: CONTEXT.md D-09, UI-SPEC Copywriting Contract, NotificationScheduler.swift (verified)
// NotificationScheduler.scheduleWorkoutReminders() — updated copy

if currentStreak >= 3 {
    content.title = "\(planDay.workoutType) day is waiting"
    content.body = "You're on a \(currentStreak)-day streak — keep it going!"
} else {
    content.title = "Hone: your \(planDay.workoutType) session is ready"
    content.body = "Your plan is waiting."
}

// Re-engagement notification:
content.title = "Hone updated your plan"
content.body = "Your plan adapted to your schedule — ready when you are."
```

### Adaptation Summary Banner Attribution

```swift
// Source: CONTEXT.md D-09, TrainView.swift AdaptationSummaryBanner (verified)
// The adjustment summary text arrives from the Edge Function. A "Hone" prefix
// is prepended in AdaptationSummaryBanner to give it the coach voice.
// No changes to AdaptationService or the Edge Function are needed.

private struct AdaptationSummaryBanner: View {
    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HoneAvatarView(diameter: 20)    // ← replace sparkles icon with avatar
            VStack(alignment: .leading, spacing: 2) {
                Text("Hone")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
```

---

## Color Migration Inventory

The planner needs the exact count and file list to structure tasks correctly.

**Total `Color(` references: 98** (verified via grep)

**Breakdown by token:**
- `Color("AccentColor")`: 30 occurrences across 21 files [VERIFIED: grep]
- `Color("AppBackground")`: 14 occurrences across 9 files [VERIFIED: grep]
- `Color("CardBackground")`: 35 occurrences across 20+ files [VERIFIED: grep]
- `Color(.systemGray6)` / `Color(.systemGray4)`: 6 occurrences in 4 files [VERIFIED: grep]

**Files with AccentColor (30 total):**
- `Core/Components/ChipView.swift`
- `Core/Components/OnboardingProgressView.swift`
- `Features/Disclaimer/DisclaimerView.swift`
- `Features/Progress/Components/PRBadgeView.swift` (2x)
- `Features/Progress/Components/StreakCard.swift`
- `Features/Progress/Components/WeeklyRingView.swift`
- `Features/Progress/Components/ChartSectionView.swift` (3x)
- `Features/Auth/AuthView.swift` (2x)
- `Features/Auth/PasswordResetView.swift`
- `Features/Coach/Components/PlanModificationCard.swift`
- `Features/Coach/Components/ChatInputBar.swift`
- `Features/Coach/Components/ChatBubbleView.swift`
- `Features/Coach/Components/CoachHeaderView.swift`
- `Features/Train/ExerciseDetailView.swift`
- `Features/Train/FilterChipRow.swift`
- `Features/Main/Tabs/TrainView.swift` (2x) — including AdaptationSummaryBanner
- `Features/Main/MainTabView.swift`
- `Features/Paywall/Retention/PauseOptionsView.swift` (2x)
- `Features/Paywall/Retention/DiscountOfferView.swift` (3x)
- `Features/Paywall/PaywallView.swift` (2x)
- `Features/PlanPreview/PlanGenerationLoadingView.swift` (4x)

**Files with AppBackground or CardBackground (49 total):** Broad distribution across all feature directories. Full sweep is required per D-03.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AVPlayerLooper` for HLS looping | seek-to-zero in `AVPlayerItemDidPlayToEndTime` | Always broken for HLS | Phase 10 must NOT introduce AVPlayerLooper in VideoOverlayView |
| Per-view color literals | Centralized Theme.swift + asset catalog | Phase 10 introduces this | All new code must use Theme.* tokens, not Color("name") |
| "Coach" brand identity | "Hone" brand identity | Phase 10 | 5 files updated; tab label + header + bubble label + notification copy |

**Deprecated/outdated in this codebase:**
- `Color(.systemGray6)`: Light-mode-biased system color used in chat components — replaced by `Theme.surface` in this phase
- `Image(systemName: "figure.run")` as coach icon — replaced by `HoneAvatarView`

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `.preferredColorScheme(.dark)` applied to `ContentView` (or on `WindowGroup`) propagates through all `fullScreenCover` presentations | Pattern 2, Pitfall 1 | PaywallView or DisclaimerView might render light — verify in simulator after applying |
| A2 | ExerciseCardView (session view) does not need a thumbnail because it already shows full VideoPlayerView | Pitfall 3 | If D-12 is interpreted to mean "add thumbnail to session too", a 80x80 thumbnail and tap behavior would be added to ExerciseCardView — confirm with user if ambiguous |

---

## Open Questions

1. **ExerciseCardView in Session: thumbnail or not?**
   - What we know: `ExerciseCardView` currently shows a full 16:9 `VideoPlayerView` embedded at the card top. D-12 says "thumbnails appear everywhere exercises are shown."
   - What's unclear: "Everywhere exercises are shown" could mean the session card too, adding a redundant thumbnail before the already-visible video.
   - Recommendation: The planner should exclude `ExerciseCardView` from thumbnail propagation — the session card already has full video. Flag in plan commentary for user awareness.

2. **Coach tab label: "Coach" or "Hone"?**
   - What we know: D-06 specifies "full brand presence — Hone name appears in chat, adaptation summaries, plan generation loading, notification text, AND the home screen." Tab bar is not explicitly mentioned.
   - What's unclear: Should the tab bar item label say "Hone" or stay "Coach" (per navigation convention)?
   - Recommendation: Change to "Hone" per D-06 spirit. If the user wants "Coach" to remain as a functional label, this is a one-line revert.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies introduced — this phase uses existing SwiftUI, AVFoundation, and Mux infrastructure already in the project).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None configured — no test targets found in project |
| Config file | None — no xctest bundle in project directory |
| Quick run command | Build in Xcode Simulator (no automated test runner) |
| Full suite command | Manual UI walkthrough per verification checklist |

No automated test infrastructure exists in this project. Validation is via Xcode Simulator visual inspection and the verification checklist.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | All screens dark background + amber accent | visual | Xcode Simulator → Toggle Appearance | n/a — manual |
| UI-02 | Exercise lists show thumbnails not emoji | visual | Run in simulator, navigate to Train tab | n/a — manual |
| UI-03 | Tap thumbnail opens fullscreen video overlay | visual | Tap any exercise thumbnail in simulator | n/a — manual |
| UI-06 | Chat shows "Hone" name, gradient avatar, Hone-voiced copy | visual | Navigate to Coach tab in simulator | n/a — manual |

### Sampling Rate
- **Per task commit:** Build succeeds in Xcode (no compiler errors)
- **Per wave merge:** Full visual walkthrough in dark mode simulator
- **Phase gate:** All four requirements visually verified before `/gsd-verify-work`

### Wave 0 Gaps
None — no test infrastructure to create; this phase relies on visual verification.

---

## Security Domain

This phase makes no changes to authentication, networking, data storage, or cryptography. It is a pure UI/visual migration.

- No new network calls introduced
- No new data storage introduced
- No API keys or secrets touched
- `NotificationScheduler` copy changes are string literals only — no logic changes

Security domain: NOT APPLICABLE for Phase 10.

---

## Project Constraints (from CLAUDE.md)

| Directive | Phase 10 Impact |
|-----------|----------------|
| SwiftUI only (no UIKit as primary) | `VideoOverlayView` uses `.fullScreenCover` (SwiftUI); `AVPlayerViewController` bridged via existing `UIViewControllerRepresentable` pattern — compliant |
| Swift Package Manager only (no CocoaPods) | No new dependencies in this phase — compliant |
| No OpenAI calls from iOS client | Not applicable to this phase |
| CoreData for local workout history | Not touched in this phase |
| RevenueCat for subscriptions | `PaywallView` gets color sweep but no logic changes |
| Supabase Edge Functions for AI proxy | Not touched in this phase |

---

## Sources

### Primary (HIGH confidence — verified via direct codebase read)

- `WorkoutApp/Features/Coach/Components/ChatBubbleView.swift` — current chat bubble implementation, systemGray6 usage confirmed
- `WorkoutApp/Features/Coach/Components/CoachHeaderView.swift` — "Coach" string literal confirmed
- `WorkoutApp/Features/Main/Tabs/CoachView.swift` — streaming bubble duplicate "Coach" label confirmed
- `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` — existing AsyncImage thumbnail pattern confirmed
- `WorkoutApp/Features/Train/VideoPlayerView.swift` — AVPlayerLooper prohibition and seek-to-zero pattern confirmed
- `WorkoutApp/Models/ExerciseModel.swift` — thumbnailURL field confirmed
- `WorkoutApp/Core/Notifications/NotificationScheduler.swift` — all 4 copy strings confirmed
- `WorkoutApp/Features/Adaptation/AdaptationService.swift` — lastAdjustmentSummary confirmed
- `WorkoutApp/Features/Main/Tabs/TrainView.swift` — AdaptationSummaryBanner location and sparkles icon confirmed
- `WorkoutApp/WorkoutApp.swift` — ContentView root, fullScreenCover placements confirmed
- `WorkoutApp/Assets.xcassets/` — 3 existing colorsets structure confirmed (AccentColor missing dark variant)
- grep audit — 98 total Color() references; 30 AccentColor, 14 AppBackground, 35 CardBackground, 6 systemGray
- `.planning/phases/10-design-system-and-visual-identity/10-UI-SPEC.md` — full design contract

### Secondary (HIGH confidence — project planning documents)

- `.planning/phases/10-design-system-and-visual-identity/10-CONTEXT.md` — locked decisions D-01 through D-16
- `.planning/REQUIREMENTS.md` — UI-01, UI-02, UI-03, UI-06 definitions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — entire codebase read, existing patterns verified
- Architecture: HIGH — all integration points identified in source files, no guesswork
- Pitfalls: HIGH — most are verified directly in source code (systemGray6 locations, VideoPlayerView looping comment, AccentColor missing dark variant)
- Color migration inventory: HIGH — grep counts verified

**Research date:** 2026-04-27
**Valid until:** 2026-05-27 (stable domain; SwiftUI/AVFoundation APIs unlikely to change in 30 days)
