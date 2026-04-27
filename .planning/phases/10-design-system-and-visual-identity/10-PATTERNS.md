# Phase 10: Design System and Visual Identity - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 18 new/modified files
**Analogs found:** 17 / 18

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkoutApp/Core/Theme.swift` | utility | transform | `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` (Color usage) | partial-match |
| `WorkoutApp/Assets.xcassets/AccentColor.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | exact |
| `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/CardBackground.colorset/Contents.json` | exact |
| `WorkoutApp/Assets.xcassets/CardBackground.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | exact |
| `WorkoutApp/Assets.xcassets/SurfaceElevated.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | exact |
| `WorkoutApp/Assets.xcassets/BorderSubtle.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | exact |
| `WorkoutApp/Assets.xcassets/SuccessGreen.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | exact |
| `WorkoutApp/Assets.xcassets/DestructiveRed.colorset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` | exact |
| `WorkoutApp/WorkoutApp.swift` | config | — | self (existing — add one modifier) | exact |
| `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` | component | — | `WorkoutApp/Features/Coach/Components/CoachHeaderView.swift` | role-match |
| `WorkoutApp/Features/Train/VideoOverlayView.swift` | component | file-I/O | `WorkoutApp/Features/Train/VideoPlayerView.swift` | role-match |
| `WorkoutApp/Features/Coach/Components/ChatBubbleView.swift` | component | — | self (existing — restyle) | exact |
| `WorkoutApp/Features/Coach/Components/CoachHeaderView.swift` | component | — | self (existing — restyle) | exact |
| `WorkoutApp/Features/Main/Tabs/CoachView.swift` | component | — | self (existing — restyle streaming bubble) | exact |
| `WorkoutApp/Features/Coach/Components/ChatInputBar.swift` | component | — | self (existing — replace systemGray) | exact |
| `WorkoutApp/Features/Coach/Components/OfflineBannerView.swift` | component | — | self (existing — replace systemGray6) | exact |
| `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` | component | file-I/O | self (existing — add tap-to-fullscreen) | exact |
| `WorkoutApp/Core/Notifications/NotificationScheduler.swift` | service | — | self (existing — update copy strings) | exact |
| `WorkoutApp/Features/Main/Tabs/TrainView.swift` | component | — | self (existing — restyle AdaptationSummaryBanner) | exact |
| `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift` | component | — | self (existing — update copy) | exact |
| `WorkoutApp/Features/Main/MainTabView.swift` | component | — | self (existing — update tint + tab label) | exact |
| `WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift` | component | — | `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` | role-match |

**Note:** The color sweep (D-03) touches all 41 view files. Only the files listed above require structural changes beyond a simple token replacement. All other view files in the color migration inventory require only `Color("AccentColor")` → `Theme.accent`, `Color("AppBackground")` → `Theme.background`, `Color("CardBackground")` → `Theme.surface` substitutions — the same two-line pattern applied repeatedly.

---

## Pattern Assignments

### `WorkoutApp/Core/Theme.swift` (NEW — utility, transform)

**Analog:** No direct codebase analog — greenfield file. Pattern derived from RESEARCH.md Pattern 1 and the existing `Color("AccentColor")` / `Color("AppBackground")` / `Color("CardBackground")` usage spread across ~41 view files.

**Observed color usage pattern across codebase** (from `ExerciseLibraryRowView.swift`, `TrainView.swift`, `HomeView.swift`, `MainTabView.swift`, etc.):
```swift
// Current pattern (lines 33-35 ExerciseLibraryRowView.swift):
Color("CardBackground")
    .frame(width: 52, height: 52)
    .clipShape(RoundedRectangle(cornerRadius: 8))

// Current pattern (MainTabView.swift line 50):
.tint(Color("AccentColor"))

// Current pattern (PlanGenerationLoadingView.swift line 34):
Color("AppBackground").ignoresSafeArea()
```

**New file structure to create:**
```swift
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

**Migration pattern (applied to all 41 view files):**
- `Color("AccentColor")` → `Theme.accent`
- `Color("AppBackground")` → `Theme.background`
- `Color("CardBackground")` → `Theme.surface`
- `Color(.systemGray6)` → `Theme.surface`
- `Color(.systemGray4)` → `Theme.borderSubtle`

---

### Asset Catalog Colorsets (UPDATE + NEW)

**Analog:** `WorkoutApp/Assets.xcassets/AppBackground.colorset/Contents.json` — has both a universal (light) and dark appearance entry. This is the pattern all colorsets must follow.

**Existing AppBackground colorset structure** (lines 1–38, `AppBackground.colorset/Contents.json`):
```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": { "alpha": "1.000", "blue": "0.961", "green": "0.961", "red": "0.961" }
      },
      "idiom": "universal"
    },
    {
      "appearances": [{"appearance": "luminosity", "value": "dark"}],
      "color": {
        "color-space": "srgb",
        "components": { "alpha": "1.000", "blue": "0.059", "green": "0.059", "red": "0.059" }
      },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

**CRITICAL: AccentColor is missing dark entry.** Current `AccentColor.colorset/Contents.json` has only one `"idiom": "universal"` entry (no dark appearance). It must get both entries. The CardBackground dark variant is also slightly off from the target `#161616`.

**Target colorset values for this phase:**

| Colorset | Universal (light) sRGB | Dark appearance sRGB |
|----------|------------------------|----------------------|
| AccentColor | 0.855, 0.620, 0.043 (#d97706 amber-700) | 0.961, 0.620, 0.043 (#f59e0b amber) |
| AppBackground | 0.961, 0.961, 0.961 (#f5f5f5) | 0.039, 0.039, 0.039 (#0a0a0a) |
| CardBackground | 1.000, 1.000, 1.000 (#ffffff) | 0.086, 0.086, 0.086 (#161616) |
| SurfaceElevated (NEW) | 0.949, 0.949, 0.949 (#f2f2f2) | 0.118, 0.118, 0.118 (#1e1e1e) |
| BorderSubtle (NEW) | 0.878, 0.878, 0.878 (#e0e0e0) | 0.165, 0.165, 0.165 (#2a2a2a) |
| SuccessGreen (NEW) | 0.133, 0.604, 0.443 (#22976f) | 0.204, 0.827, 0.600 (#34d399) |
| DestructiveRed (NEW) | 0.878, 0.224, 0.224 (#e03939) | 0.973, 0.443, 0.443 (#f87171) |

**Copy the AppBackground colorset JSON structure exactly** — two entries, first is universal (light), second has `"appearances": [{"appearance": "luminosity", "value": "dark"}]`. Apply correct sRGB components for each new colorset.

---

### `WorkoutApp/WorkoutApp.swift` (MODIFY — add `.preferredColorScheme(.dark)`)

**Analog:** Self. One modifier is added to the existing `ContentView()` call in `WorkoutApp.body`.

**Current root pattern** (lines 14–16, `WorkoutApp.swift`):
```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(appState)
```

**Updated pattern — add modifier after ContentView(), before .environment:**
```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .preferredColorScheme(.dark)   // D-14: force dark app-wide
            .environment(appState)
```

**Placement rule:** On `ContentView()` inside `WindowGroup`, NOT on `MainTabView`. This ensures `fullScreenCover` presentations (PaywallView, DisclaimerView, OnboardingFlowView) inherit dark mode through the window, not the presenting view.

---

### `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` (NEW — component)

**Analog:** `WorkoutApp/Features/Coach/Components/CoachHeaderView.swift` — same component role (coach identity display), same file location, same import pattern.

**CoachHeaderView imports and structure** (lines 1–16, `CoachHeaderView.swift`):
```swift
import SwiftUI

struct CoachHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run")    // ← will be replaced by HoneAvatarView
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
            Text("Coach")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
```

**New HoneAvatarView — copy this structure:**
```swift
// WorkoutApp/Features/Coach/Components/HoneAvatarView.swift
import SwiftUI

struct HoneAvatarView: View {
    let diameter: CGFloat

    var body: some View {
        LinearGradient(
            colors: [Theme.accent, Color(red: 0.976, green: 0.451, blue: 0.086)], // #f97316 orange-500
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(Circle())
        .frame(width: diameter, height: diameter)
    }
}
```

**Usage sizes by context:**
- Chat bubble label: `HoneAvatarView(diameter: 20)`
- Coach header: `HoneAvatarView(diameter: 28)`
- Home screen coach card: `HoneAvatarView(diameter: 48)`
- Adaptation summary banner: `HoneAvatarView(diameter: 20)`

---

### `WorkoutApp/Features/Train/VideoOverlayView.swift` (NEW — component, file-I/O)

**Analog:** `WorkoutApp/Features/Train/VideoPlayerView.swift` — same directory, same import pattern (SwiftUI + AVKit), same integration with MuxPlayerSwift. `VideoOverlayView` is a thin coordinator that presents `VideoPlayerView` via `.fullScreenCover`.

**VideoPlayerView imports + UIViewControllerRepresentable pattern** (lines 1–3, `VideoPlayerView.swift`):
```swift
import SwiftUI
import AVKit
import MuxPlayerSwift
```

**New VideoOverlayView structure:**
```swift
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

**Tap wiring pattern** — copy this into every view that shows a thumbnail (ExerciseLibraryRowView, ExerciseRowView in plan preview, coach chat exercise mentions):
```swift
@State private var showVideo = false

// Applied to the thumbnail view:
thumbnailView
    .onTapGesture { showVideo = true }
    .accessibilityLabel("\(exerciseName) — tap to play video")
    .fullScreenCover(isPresented: $showVideo) {
        VideoOverlayView(
            muxPlaybackId: exercise.muxPlaybackId ?? "",
            exerciseName: exercise.name
        )
    }
```

**DO NOT use AVPlayerLooper** — `VideoPlayerView.swift` lines 13 and 62-63 document this explicitly: "Do NOT use AVPlayerLooper — broken for HLS streams (duplicate downloads)." `VideoOverlayView` reuses `VideoPlayerView` as-is; the seek-to-zero loop is already handled in `VideoPlayerView.Coordinator.setupLooping()`.

---

### `WorkoutApp/Features/Coach/Components/ChatBubbleView.swift` (MODIFY)

**Analog:** Self. Current file is 39 lines. Changes: (1) replace `figure.run` icon + "Coach" text label with `HoneAvatarView(diameter: 20)` + "Hone" text, (2) replace `Color(.systemGray6)` with `Theme.surface`, (3) replace `Color("AccentColor")` user bubble with `Theme.accent`.

**Current file** (full, lines 1–39, `ChatBubbleView.swift`):
```swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .coach {
                    // Coach label with icon (D-27)
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")       // ← REPLACE with HoneAvatarView(diameter: 20)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Coach")                         // ← REPLACE with "Hone"
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(message.content)
                    .padding(12)
                    .background(message.role == .user
                        ? Color("AccentColor")                // ← REPLACE with Theme.accent
                        : Color(.systemGray6))                // ← REPLACE with Theme.surface
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .coach { Spacer(minLength: 60) }
        }
    }
}
```

**Updated coach label block (lines 12–21 replacement):**
```swift
if message.role == .coach {
    HStack(spacing: 6) {
        HoneAvatarView(diameter: 20)
        Text("Hone")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
```

---

### `WorkoutApp/Features/Coach/Components/CoachHeaderView.swift` (MODIFY)

**Analog:** Self. Replace `Image(systemName: "figure.run")` with `HoneAvatarView(diameter: 28)` and `Text("Coach")` with `Text("Hone")`. Replace `Color("AccentColor")` with `Theme.accent`.

**Current file** (full, lines 1–16, `CoachHeaderView.swift`):
```swift
import SwiftUI

struct CoachHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run")    // ← REPLACE with HoneAvatarView(diameter: 28)
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
            Text("Coach")                      // ← REPLACE with "Hone"
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
```

---

### `WorkoutApp/Features/Main/Tabs/CoachView.swift` (MODIFY — streaming bubble)

**Analog:** Self. Two locations need updating in the streaming bubble block (lines 52–77):
1. Lines 56–63: Replace `figure.run` icon + "Coach" label with `HoneAvatarView` + "Hone"
2. Lines 71 and 90: Replace `Color(.systemGray6)` with `Theme.surface`

**Current streaming bubble label** (lines 55–63, `CoachView.swift`):
```swift
VStack(alignment: .leading, spacing: 4) {
    HStack(spacing: 4) {
        Image(systemName: "figure.run")     // ← REPLACE with HoneAvatarView(diameter: 20)
            .font(.caption2)
            .foregroundStyle(.secondary)
        Text("Coach")                        // ← REPLACE with "Hone"
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
```

**Current systemGray6 locations in CoachView.swift:**
- Line 71: `.background(Color(.systemGray6))` (streaming bubble) → `.background(Theme.surface)`
- Line 90: `.background(Color(.systemGray6))` (error bubble) → `.background(Theme.surface)`

---

### `WorkoutApp/Features/Coach/Components/ChatInputBar.swift` (MODIFY)

**Analog:** Self. Replace `Color(.systemGray6)` and `Color(.systemGray4)` with Theme tokens.

**Current file** (full, lines 1–40, `ChatInputBar.swift`) — two color references to update:
- Line 21: `.background(Color(.systemGray6))` → `.background(Theme.surface)`
- Line 32: `.foregroundStyle(canSend ? Color("AccentColor") : Color(.systemGray4))` → `.foregroundStyle(canSend ? Theme.accent : Theme.borderSubtle)`

---

### `WorkoutApp/Features/Coach/Components/OfflineBannerView.swift` (MODIFY)

**Analog:** Self. Single-line change.

**Current file** (full, lines 1–13, `OfflineBannerView.swift`) — one color reference:
- Line 10: `.background(Color(.systemGray6))` → `.background(Theme.surface)`

---

### `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` (MODIFY — add tap-to-fullscreen)

**Analog:** Self. Add `@State private var showVideo = false` and wrap the existing thumbnail block with `onTapGesture` + `fullScreenCover`.

**Current thumbnail block** (lines 23–43, `ExerciseLibraryRowView.swift`):
```swift
AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    default:
        Color("CardBackground")                    // ← REPLACE with Theme.surface
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                Image(systemName: "dumbbell")
                    .font(.body)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
    }
}
.frame(width: 52, height: 52)
```

**Updated pattern — add state + tap + fullScreenCover:**
```swift
@State private var showVideo = false

// Wrap the AsyncImage block:
AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { phase in
    // ... existing phase switch, only update Color("CardBackground") → Theme.surface
}
.frame(width: 52, height: 52)
.onTapGesture {
    guard exercise.muxPlaybackId != nil else { return }
    showVideo = true
}
.accessibilityLabel(exercise.muxPlaybackId != nil
    ? "\(exercise.name) — tap to play video"
    : "\(exercise.name)")
.fullScreenCover(isPresented: $showVideo) {
    VideoOverlayView(
        muxPlaybackId: exercise.muxPlaybackId ?? "",
        exerciseName: exercise.name
    )
}
```

---

### `WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift` (MODIFY — add thumbnail + tap)

**Analog:** `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` — same thumbnail AsyncImage pattern at 52x52, same tap-to-fullscreen approach. `ExerciseRowView` currently shows only text; a thumbnail is added as a leading element.

**Current ExerciseRowView structure** (lines 13–45, `ExerciseRowView.swift`) — no image, only text. The thumbnail needs to be added as a leading 52x52 block matching `ExerciseLibraryRowView.swift` lines 23–43.

**Note:** `ExerciseRowView` uses `PlannedExercise` not `ExerciseModel`. The plan preview exercises do not have `muxPlaybackId` directly on `PlannedExercise` — confirm whether `PlannedExercise` has a playback ID or if the thumbnail should be omitted here. If `PlannedExercise` lacks a `muxPlaybackId`, skip the tap-to-fullscreen for this context and show thumbnail-only from a `thumbnailURL` field if available.

---

### `WorkoutApp/Features/Main/Tabs/TrainView.swift` (MODIFY — restyle AdaptationSummaryBanner)

**Analog:** Self. The `AdaptationSummaryBanner` private struct (lines 181–203) needs:
1. Replace `Image(systemName: "sparkles")` with `HoneAvatarView(diameter: 20)`
2. Add "Hone" label above the summary text (matching RESEARCH.md code example)
3. Replace `Color("AccentColor")` → `Theme.accent` and `Color("CardBackground")` → `Theme.surface`

**Current AdaptationSummaryBanner** (lines 181–203, `TrainView.swift`):
```swift
private struct AdaptationSummaryBanner: View {
    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")        // ← REPLACE with HoneAvatarView(diameter: 20)
                .font(.subheadline)
                .foregroundStyle(Color("AccentColor"))
            Text(summary)                         // ← ADD "Hone" label above, wrap in VStack
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"))      // ← REPLACE with Theme.surface
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("AccentColor").opacity(0.3), lineWidth: 1)  // ← REPLACE with Theme.accent
        )
    }
}
```

---

### `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift` (MODIFY — copy + colors)

**Analog:** Self. Two types of changes:
1. Color token replacements: `Color("AccentColor")` → `Theme.accent`, `Color("AppBackground")` → `Theme.background`
2. Copy update: the `phases` array (lines 26–30) gets Hone branding

**Current phases array** (lines 26–30, `PlanGenerationLoadingView.swift`):
```swift
private let phases = [
    "Analyzing your goals\u{2026}",
    "Building your schedule\u{2026}",
    "Selecting your exercises\u{2026}"
]
```

**Updated phases with Hone voice:**
```swift
private let phases = [
    "Hone is analyzing your goals\u{2026}",
    "Hone is building your schedule\u{2026}",
    "Hone is selecting your exercises\u{2026}"
]
```

**Color locations to update (lines 34, 61, 92, 97–107, 153):** All `Color("AccentColor")` → `Theme.accent`, `Color("AppBackground")` → `Theme.background`.

---

### `WorkoutApp/Features/Main/MainTabView.swift` (MODIFY — tab label + tint)

**Analog:** Self. Two changes:
1. Line 34: `Label("Coach", systemImage: "message")` → `Label("Hone", systemImage: "message")`
2. Line 50: `.tint(Color("AccentColor"))` → `.tint(Theme.accent)`

**Current Coach tab item** (lines 33–36, `MainTabView.swift`):
```swift
CoachView()
    .tabItem {
        Label("Coach", systemImage: "message")   // ← REPLACE "Coach" with "Hone"
    }
```

---

### `WorkoutApp/Core/Notifications/NotificationScheduler.swift` (MODIFY — copy strings)

**Analog:** Self. Four string literals updated in `scheduleWorkoutReminders` and `scheduleReengagementNotificationIfNeeded`.

**Current copy — workout reminders** (lines 107–115, `NotificationScheduler.swift`):
```swift
if currentStreak >= 3 {
    content.title = "\(planDay.workoutType) day is waiting"
    content.body = "You're on a \(currentStreak)-day streak — keep it going!"
} else {
    content.title = "Ready for your \(planDay.workoutType) day?"
    content.body = "Your plan is waiting."
}
```

**Updated copy with Hone branding:**
```swift
if currentStreak >= 3 {
    content.title = "\(planDay.workoutType) day is waiting"
    content.body = "You're on a \(currentStreak)-day streak — keep it going!"
} else {
    content.title = "Hone: your \(planDay.workoutType) session is ready"
    content.body = "Your plan is waiting."
}
```

**Current re-engagement copy** (lines 181–185, `NotificationScheduler.swift`):
```swift
content.title = "Your plan is ready"
let body = "Your plan adapted to your schedule — ready when you are."
```

**Updated re-engagement copy:**
```swift
content.title = "Hone updated your plan"
let body = "Your plan adapted to your schedule — ready when you are."
```

---

## Shared Patterns

### Color Token Replacement (applies to all 41 view files)

**Source:** After `Theme.swift` is created in Wave 1.
**Apply to:** Every `.swift` file in the color migration inventory.

```swift
// BEFORE (any file):
Color("AccentColor")
Color("AppBackground")
Color("CardBackground")
Color(.systemGray6)
Color(.systemGray4)

// AFTER:
Theme.accent
Theme.background
Theme.surface
Theme.surface
Theme.borderSubtle
```

### AsyncImage Thumbnail Pattern (applies to all exercise display contexts)

**Source:** `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` lines 23–43.
**Apply to:** Library rows (52x52), plan preview rows (52x52), coach chat exercise mentions (44x44).
**Do NOT apply to:** `ExerciseCardView` in session — it already shows full `VideoPlayerView`.

```swift
AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: SIZE, height: SIZE)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    default:
        Theme.surface
            .frame(width: SIZE, height: SIZE)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                Image(systemName: "dumbbell")
                    .font(.body)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
    }
}
.frame(width: SIZE, height: SIZE)
```

### Hone Identity Replacement (applies to all Coach-branded locations)

**Source:** Decisions D-05 through D-09 + ChatBubbleView.swift + CoachHeaderView.swift + CoachView.swift.
**Apply to:** ChatBubbleView (coach label), CoachHeaderView, CoachView streaming bubble, MainTabView tab label, PlanGenerationLoadingView copy, AdaptationSummaryBanner.

```swift
// Everywhere "Coach" text label appears:
Text("Coach")  →  Text("Hone")

// Everywhere figure.run icon is used as coach identity:
Image(systemName: "figure.run")  →  HoneAvatarView(diameter: [context-appropriate size])

// Tab bar label (MainTabView):
Label("Coach", systemImage: "message")  →  Label("Hone", systemImage: "message")
```

### fullScreenCover Pattern for Video (applies to VideoOverlayView integration)

**Source:** `WorkoutApp/WorkoutApp.swift` lines 19–28 and `WorkoutApp/Features/Main/Tabs/HomeView.swift` line 50 — both demonstrate the `.fullScreenCover(isPresented:)` pattern already in use.

```swift
// From WorkoutApp.swift lines 19-28 (existing fullScreenCover pattern):
.fullScreenCover(isPresented: Binding(
    get: { !disclaimerAcknowledged },
    set: { _ in }
)) {
    DisclaimerView(onAcknowledge: {
        disclaimerAcknowledged = true
    })
}

// Video overlay variant (simpler — boolean state):
@State private var showVideo = false
// ...
.fullScreenCover(isPresented: $showVideo) {
    VideoOverlayView(muxPlaybackId: exercise.muxPlaybackId ?? "", exerciseName: exercise.name)
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `WorkoutApp/Core/Theme.swift` | utility | transform | No centralized token/theme file exists yet; pattern derived from scattered Color() calls across codebase |

---

## Color Migration Inventory (full file list for Wave 2 sweep)

The planner should structure the color sweep as a single wave covering these 21 files with AccentColor references (30 total), plus all AppBackground and CardBackground files:

**AccentColor files (21 files, ~30 references):**
- `Core/Components/ChipView.swift`
- `Core/Components/OnboardingProgressView.swift`
- `Features/Disclaimer/DisclaimerView.swift`
- `Features/Progress/Components/PRBadgeView.swift`
- `Features/Progress/Components/StreakCard.swift`
- `Features/Progress/Components/WeeklyRingView.swift`
- `Features/Progress/Components/ChartSectionView.swift`
- `Features/Auth/AuthView.swift`
- `Features/Auth/PasswordResetView.swift`
- `Features/Coach/Components/PlanModificationCard.swift`
- `Features/Coach/Components/ChatInputBar.swift`
- `Features/Coach/Components/ChatBubbleView.swift`
- `Features/Coach/Components/CoachHeaderView.swift`
- `Features/Train/ExerciseDetailView.swift`
- `Features/Train/FilterChipRow.swift`
- `Features/Main/Tabs/TrainView.swift`
- `Features/Main/MainTabView.swift`
- `Features/Paywall/Retention/PauseOptionsView.swift`
- `Features/Paywall/Retention/DiscountOfferView.swift`
- `Features/Paywall/PaywallView.swift`
- `Features/PlanPreview/PlanGenerationLoadingView.swift`

**systemGray locations (4 files, 6 references — must be caught by sweep):**
- `Features/Coach/Components/ChatBubbleView.swift` line 27
- `Features/Coach/Components/ChatInputBar.swift` lines 21, 32
- `Features/Coach/Components/OfflineBannerView.swift` line 10
- `Features/Main/Tabs/CoachView.swift` lines 71, 90

---

## Metadata

**Analog search scope:** `/Users/Fish/Desktop/workout/WorkoutApp/` — all 89 Swift source files + 3 existing colorset JSON files
**Files scanned:** 22 Swift files read directly; 3 colorset JSON files; full file list enumerated
**Pattern extraction date:** 2026-04-26
