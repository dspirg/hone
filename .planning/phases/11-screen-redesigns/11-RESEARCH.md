# Phase 11: Screen Redesigns - Research

**Researched:** 2026-04-27
**Domain:** SwiftUI layout, CoreData queries, tab navigation state management
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Home Screen Layout (D-01 through D-05)**
- D-01: Exact match to Sketch 001-A — full rebuild of HomeView with greeting, adaptation banner, today's workout card with exercise list, weekly streak bar, and quick stats section
- D-02: Greeting shows user's actual name from onboarding profile ("Hey Dan"), with time-of-day prefix ("Good evening"). Falls back to generic greeting if no name available
- D-03: Adaptation banner shows rationale text from the last AdaptationService response, Hone-branded ("Hone adjusted your plan..."). Only displayed when a recent adaptation occurred — not always present
- D-04: Exercise rows in the Home workout card use 40x40 rounded Mux thumbnails (same pattern as ExerciseLibraryRowView), with SF Symbol dumbbell fallback when no video exists
- D-05: Quick stats section shows Sessions, Sets, and PRs in stat pill layout matching Sketch 001-A

**Session Screen Rework (D-06 through D-09)**
- D-06: Video area shrinks from 16:9 to 2:1 aspect ratio per Sketch 002-B. Tappable to expand to fullscreen via existing VideoOverlayView from Phase 10
- D-07: Previous/Best context cards added below set rows — query SessionRepository (CDSetLog/CDSessionLog) for last session's reps and all-time PR per exercise. Cards show "Previous: 10 reps" and "Best: 12 reps" side by side
- D-08: Keep existing horizontal card-slide navigation with progress dots for exercise transitions — no change to navigation UX
- D-09: Context-aware bottom CTA button: "Complete Set" while sets remain for current exercise, switches to "Next Exercise" when all sets done, "Finish Session" on last exercise of the session

**Summary Screen Tightening (D-10 through D-12)**
- D-10: Shrink completion checkmark icon from 56pt to 36pt. Merge duration into the stats row (4 items: Exercises, Sets, Reps, Duration) instead of separate section
- D-11: Keep emoji difficulty picker at 44pt with labels — space savings come from content above the picker, not the picker itself
- D-12: Switch from ScrollView to fixed VStack layout with Spacer distribution — guarantees emoji difficulty picker is always visible without scrolling on standard iPhone displays. PR badges section gets limited height with internal scroll if many PRs

**Cross-Screen Consistency (D-13 through D-16)**
- D-13: "Start Workout" on Home navigates directly to SessionView — no intermediate TrainView step. TrainView remains accessible from the Train tab for plan browsing
- D-14: After "Done" on Summary, user lands back on Home tab with updated stats (streak bar, quick stats reflect completed session). Full loop closure
- D-15: Extract shared components: StatPillView (Home + Summary), WeekStreakBar (Home), ExerciseRowView (Home card + Exercise Library). DRY and visually consistent
- D-16: Session opens from Home as .fullScreenCover — slides up from bottom for immersive feel. Dismiss slides back down to Home

### Claude's Discretion
- Home screen data loading strategy (parallel vs sequential fetches for plan, stats, adaptation status)
- Exact layout spacing and padding values for the Home card-stack
- Context cards positioning within ExerciseCardView (above or below set rows)
- StatPillView and WeekStreakBar component API design
- How to route Summary dismiss back to Home tab (tab selection state management)
- Animation details for the fullScreenCover transition
- Empty states for context cards when no previous session data exists

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-04 | Home screen uses card-stack layout with today's workout, weekly streak, and quick stats (per Sketch 001-A) | HomeView full rebuild; data from WorkoutPlanRepository + ProgressViewModel + AdaptationService |
| UI-05 | Session screen uses compact video layout with Previous/Best context cards (per Sketch 002-B) | ExerciseCardView video aspect ratio change; new SessionRepository queries for previous/best reps |
| UI-07 | Session summary screen uses tighter layout so emoji difficulty picker is visible without scrolling | ScrollView -> fixed VStack conversion; StatCell -> StatPillView merge with duration |
</phase_requirements>

---

## Summary

Phase 11 is a pure SwiftUI layout and data-wiring phase. The codebase is well-factored from prior phases — Theme.swift provides all color/spacing tokens, VideoOverlayView and ExerciseLibraryRowView are reusable, and the @Observable/@MainActor pattern is established throughout. There is no new technology to introduce; everything needed exists in the project.

The three screens divide cleanly by effort. HomeView is the largest piece — a full rebuild from a minimal plan-card to a rich card-stack with five data sources (plan, adaptation rationale, thumbnail URLs, streak, stats). ExerciseCardView is a targeted modification — video aspect ratio change plus a new context card pair that requires two new CoreData fetch methods on SessionRepository. SessionSummaryView is the smallest change — replacing ScrollView with a fixed VStack and merging the duration stat.

The only technically novel element is the fullScreenCover session launch from Home (D-16) with post-dismiss tab state update (D-14). The existing codebase already uses .fullScreenCover for PaywallView and VideoOverlayView, so the pattern is proven. The tab selection routing after dismiss requires a small AppState addition or a binding on MainTabView — this is a well-understood SwiftUI pattern and is low-risk.

**Primary recommendation:** Execute as five plans: (1) shared components extraction, (2) SessionRepository query additions, (3) HomeView rebuild, (4) ExerciseCardView modification, (5) SessionSummaryView conversion. The shared-components plan must complete before Home and Summary can be written.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Home greeting + time-of-day | iOS Client (View) | AppState (user name) | Pure presentation logic; name comes from AppState.currentUser |
| Today's workout card | iOS Client (View) | CoreData / WorkoutPlanRepository | Plan data already in CoreData from prior phase; no network call needed |
| Weekly streak bar | iOS Client (View) | CoreData / ProgressViewModel | Streak computed from CDSessionLog already in ProgressViewModel |
| Quick stats (sessions, sets, PRs) | iOS Client (View) | CoreData / ProgressViewModel | All metrics already computed by ProgressViewModel.loadProgress() |
| Adaptation banner | iOS Client (View) | AdaptationService (state) | AdaptationService.lastAdjustmentSummary is already an @Observable property |
| Exercise thumbnail in Home card | iOS Client (View) | Mux CDN | AsyncImage + thumbnailURL pattern already in ExerciseLibraryRowView |
| Session fullScreenCover launch | iOS Client (View) | AppState / MainTabView | .fullScreenCover from HomeView; tab routing on dismiss via AppState |
| Previous/Best context cards | iOS Client (View) | CoreData / SessionRepository | Two new fetch methods on SessionRepository; data is local CoreData only |
| Compact video + tap-to-expand | iOS Client (View) | VideoOverlayView (reuse) | Aspect ratio change is local layout; fullScreenCover reuse is proven |
| Context-aware CTA ("Complete Set" etc.) | iOS Client (SessionView) | SessionViewModel (completedSets state) | CTA label derived from completedSets dict and currentExerciseIndex |
| Summary fixed VStack layout | iOS Client (View) | — | Pure layout change; no data model changes |
| Post-dismiss tab update to Home | iOS Client (AppState or binding) | MainTabView | TabView selection binding or AppState.selectedTab drives tab switch |

---

## Standard Stack

All capabilities use the established project stack. No new dependencies are introduced in this phase.

### Core (existing — no new installs)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All new views and component modifications | Established in CLAUDE.md; all Phase 10 components are SwiftUI |
| Swift 6 / @Observable | 6.x | ViewModels and state management | All existing ViewModels follow @Observable @MainActor pattern |
| CoreData | iOS 16+ | Session history queries for Previous/Best | Established persistence layer; SessionRepository already owns CDSetLog/CDSessionLog |
| AVFoundation + AVKit | iOS 16+ | Video playback (existing VideoPlayerView) | No change; VideoOverlayView reused as-is |

[VERIFIED: codebase grep — all referenced components confirmed present in WorkoutApp/]

### No New Dependencies
This phase adds zero new Swift Package dependencies. All required capabilities (image loading, video, theming, CoreData) are already installed.

---

## Architecture Patterns

### System Architecture Diagram

```
AppState (currentUser, selectedTab)
    |
    +--- MainTabView (TabView, .fullScreenCover host for session)
    |       |
    |       +--- HomeView (@Observable HomeViewModel)
    |       |       +--- WorkoutPlanRepository -> CDWorkoutPlan (today's workout)
    |       |       +--- ProgressViewModel -> CDSessionLog (streak, stats)
    |       |       +--- AdaptationService.lastAdjustmentSummary (banner)
    |       |       +--- --> .fullScreenCover --> SessionView
    |       |                                          |
    |       |                                          +--- SessionViewModel (completedSets, isSessionComplete)
    |       |                                          +--- ExerciseCardView (video 2:1 + context cards)
    |       |                                          |       +--- SessionRepository --> CDSetLog queries
    |       |                                          +--- SessionSummaryView (fixed VStack)
    |       |                                                    +--- dismiss() --> Home tab (selectedTab)
    |       |
    |       +--- TrainView (unchanged — plan browsing entry point)
    |
    +--- ProgressViewModel (streak + quick stats source)
```

Data flows:
- Home load: parallel async fetches for plan (WorkoutPlanRepository) + stats (ProgressViewModel) on .task
- Session launch: "Start Workout" sets `showSession = true` on HomeView -> .fullScreenCover
- Context cards load: ExerciseCardView .task queries SessionRepository for previousReps + bestReps per exercise name
- Post-dismiss: Summary "Done" calls dismiss(); HomeViewModel re-fetches stats to reflect completed session

### Recommended Project Structure (new files only)

```
WorkoutApp/Features/Main/
+-- Tabs/
|   +-- HomeView.swift              # Full rebuild (existing file, rewritten)
+-- Components/
    +-- StatPillView.swift          # New shared component (D-15)
    +-- WeekStreakBar.swift          # New shared component (D-15)
    +-- ExerciseRowView.swift        # New shared component (D-15)
    +-- AdaptationBannerView.swift  # New component (D-03)

WorkoutApp/Features/Session/
+-- SessionView.swift               # Modified — context-aware CTA (D-09)
+-- Components/
    +-- ExerciseCardView.swift      # Modified — 2:1 video, tap-to-expand (D-06)
    +-- ContextCardView.swift       # New component (D-07)
    +-- SessionSummaryView.swift    # Modified — fixed VStack, merged stats (D-10 to D-12)

WorkoutApp/Features/CoreData/
+-- SessionRepository.swift        # Modified — two new fetch methods (D-07)
```

### Pattern 1: @Observable HomeViewModel with parallel data fetch

The existing HomeView has a single async `loadActivePlan()`. The rebuild needs five data points. The pattern across the codebase (ProgressViewModel, SessionViewModel) is @Observable @MainActor with a single `load()` entry point using async/await.

```swift
// Source: codebase pattern from ProgressViewModel.swift
@Observable
@MainActor
final class HomeViewModel {
    var activePlan: WorkoutPlan? = nil
    var todayWorkoutDay: WorkoutDay? = nil
    var currentStreak: Int = 0
    var quickStats: HomeQuickStats? = nil
    var adaptationBanner: String? = nil
    var isLoading = true
    var loadError: String? = nil
    var showSession = false

    func load(appState: AppState, context: NSManagedObjectContext) async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = appState.currentUser?.id.uuidString else { return }

        async let planResult = loadPlan(userId: userId, context: context)
        async let statsResult = loadStats(userId: userId, context: context)
        let (plan, stats) = await (planResult, statsResult)
        // ... assign results
    }
}
```

[VERIFIED: codebase — @Observable @MainActor pattern confirmed in ProgressViewModel.swift, AdaptationService.swift, SessionViewModel.swift]

### Pattern 2: SessionRepository new queries for Previous/Best

D-07 requires two new fetch methods. The existing repository uses NSFetchRequest with NSPredicate scoped to userId + exerciseName. The Previous/Best queries follow the same shape.

```swift
// Source: codebase pattern from SessionRepository.swift + ProgressViewModel.detectPRs
/// Returns the reps logged for a given exercise in the most recent prior session (not the current one).
func fetchPreviousReps(exerciseName: String, excludingSessionId: UUID?) throws -> Int? {
    let req = CDSetLog.fetchRequest()
    req.predicate = NSPredicate(format: "exerciseName == %@", exerciseName)
    req.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
    let logs = try context.fetch(req)
    // Filter to different session, return max repsLogged for the most recent session
    // ...
}

/// Returns the all-time max reps for a given exercise across all sessions.
func fetchBestReps(exerciseName: String) throws -> Int? {
    let req = CDSetLog.fetchRequest()
    req.predicate = NSPredicate(format: "exerciseName == %@", exerciseName)
    let logs = try context.fetch(req)
    return logs.map { Int($0.repsLogged) }.max()
}
```

[VERIFIED: codebase — CDSetLog.exerciseName and repsLogged fields confirmed in SessionRepository.swift]

### Pattern 3: fullScreenCover for session launch from Home (D-16)

The codebase already uses .fullScreenCover in two places: PaywallView (from ContentView/HomeView) and VideoOverlayView (from ExerciseLibraryRowView). Same pattern applies to session launch.

```swift
// Source: codebase pattern from HomeView.swift (PaywallView) + ExerciseLibraryRowView.swift (VideoOverlayView)
// In HomeView body:
.fullScreenCover(isPresented: $viewModel.showSession) {
    if let day = viewModel.todayWorkoutDay, let planId = viewModel.activePlan?.planId {
        SessionView(workoutDay: day, planId: planId)
            .environment(\.managedObjectContext, context)
            .environment(adaptationService)
    }
}
```

[VERIFIED: codebase — .fullScreenCover(isPresented:) pattern confirmed in HomeView.swift line 50 and ExerciseLibraryRowView.swift line 53]

### Pattern 4: Tab selection routing after session dismiss (D-14)

SwiftUI TabView selection is controlled by a binding. AppState does not currently expose a `selectedTab` property — this is a Claude's Discretion item. Two proven approaches exist:

**Option A — AppState.selectedTab (recommended):**
Add `var selectedTab: Int = 0` to AppState. MainTabView binds TabView selection to it. SessionSummaryView's "Done" closure sets `appState.selectedTab = 0` before calling dismiss(). HomeView .task triggers on re-appear, re-fetching stats.

**Option B — Notification pattern:**
Post a NotificationCenter notification from SessionSummaryView "Done". HomeView listens via .onReceive. No AppState change needed. Slightly more decoupled but adds indirect coupling via string key.

Option A is preferred — it matches the project's pattern of using AppState for cross-cutting navigation state (appState.isAuthenticated, appState.onboardingCompleted already drive routing decisions). [ASSUMED: no existing selectedTab property on AppState — verified AppState.swift has no such property at line 8-60]

### Pattern 5: Fixed VStack layout for Summary (D-12)

The current SessionSummaryView uses `ScrollView { VStack(spacing: 20) }`. The fix replaces the outer ScrollView with a plain VStack filling the screen, with `Spacer()` distributing space. On iPhone SE (375pt height) this is the tightest case.

```swift
// Source: UI-SPEC 11-UI-SPEC.md Screen 3 specification
VStack(spacing: 0) {
    Spacer().frame(height: 16)
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 36))          // was 56pt
        .foregroundStyle(Theme.accent)
    VStack(spacing: 4) { ... }            // headings
    Spacer().frame(height: 20)
    HStack(spacing: 24) {                 // 4 stats merged (D-10)
        StatPillView("Exercises", ...)
        StatPillView("Sets", ...)
        StatPillView("Reps", ...)
        StatPillView("Duration", ...)     // was separate row
    }
    Spacer().frame(height: 16)
    if !prs.isEmpty {
        ScrollView { PRBadgeView(prs: prs) }
            .frame(maxHeight: 80)         // PR section capped
    }
    Spacer(minLength: 12)
    // difficulty picker (44pt emoji — unchanged)
    Spacer(minLength: 16)
    // Done button
    Spacer().frame(height: 32)
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

[VERIFIED: codebase — current SessionSummaryView.swift confirmed ScrollView wrapping; checkmark icon at line 32-35 uses .system(size: 56)]

### Anti-Patterns to Avoid

- **Nesting ScrollViews:** The Home card is inside a ScrollView. Do not embed another ScrollView for the exercise list within the workout card — use a plain VStack with dividers. Nested scrolls fight gesture recognizers on iOS. [ASSUMED — general SwiftUI pitfall, well-documented]
- **Fetching ProgressViewModel data separately in HomeViewModel:** ProgressViewModel already computes streak and session count. HomeViewModel should re-use the computation logic or share the ProgressViewModel instance via @Environment, rather than duplicating NSFetchRequests.
- **Creating SessionRepository with default init inside ExerciseCardView .task:** The card view is rendered in a ZStack and may appear/disappear. Repository initialization should happen at SessionView level and be passed down, consistent with how SessionView already owns the repository.
- **Using .sheet instead of .fullScreenCover for session:** D-16 explicitly requires .fullScreenCover for the immersive slide-up transition. .sheet shows a partial card that can be dismissed by drag, which is wrong UX for an in-session experience.
- **Calling dismiss() before setting selectedTab:** If selectedTab is set after dismiss(), the tab switch animation may be janky. Set selectedTab first, then call dismiss().

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exercise thumbnail loading with fallback | Custom image cache + placeholder logic | AsyncImage with phase switch | AsyncImage handles loading states, failure, and memory pressure automatically; ExerciseLibraryRowView already has the exact pattern |
| Time-of-day greeting | Custom date/calendar logic | Calendar.current.component(.hour, from: Date()) | One line; no external dependency needed |
| Duration formatting | Custom formatter | Integer division with String(format:) | Already implemented as `formattedDuration` in SessionSummaryView — extract to shared utility |
| Streak computation | Custom calendar logic | Reuse ProgressViewModel.computeStreak() | Already tested in ProgressViewModelTests.swift; extracting to a shared util avoids duplication |
| Previous/Best reps fetch | Custom Core Data stack | NSFetchRequest on existing SessionRepository | All CoreData plumbing already in SessionRepository; just add two methods |
| Tab selection state | Custom navigation coordinator | AppState.selectedTab binding | TabView supports Binding<Hashable> selection natively; AppState is already @Observable and injected everywhere |

**Key insight:** The project's biggest risk in this phase is duplication — building new data-fetch logic when ProgressViewModel already owns session history, or building new thumbnail logic when ExerciseLibraryRowView has the exact pattern. Reuse first.

---

## Common Pitfalls

### Pitfall 1: ExerciseCardView context cards query blocks main thread
**What goes wrong:** If `fetchPreviousReps` and `fetchBestReps` are called synchronously on appear, they block the main actor during the NSFetchRequest, causing a visible stutter when swiping to a new exercise card.
**Why it happens:** SessionRepository is @MainActor and its fetch methods run on the view context synchronously. For a 3-exercise session this is usually fine (<1ms per fetch), but a 10-exercise session with many historical set logs could be perceptible.
**How to avoid:** Wrap context card loading in `.task(id: exerciseIndex)` (re-runs when the card becomes active) rather than `.task` (runs once). The re-run-on-id-change pattern ensures data is loaded lazily per exercise rather than all at load time.
**Warning signs:** Janky card-slide animation when advancing exercises with many historical sessions.

### Pitfall 2: fullScreenCover AVPlayer state during session
**What goes wrong:** If session launch from Home uses NavigationStack .navigationDestination instead of .fullScreenCover, tapping the tap-to-expand video inside the session triggers another NavigationStack push that destroys the AVPlayer instance.
**Why it happens:** NavigationStack replaces views on push; AVPlayer state is lost.
**How to avoid:** D-16 mandates .fullScreenCover — honour it. The existing comment in SessionView.swift (line 139) documents this exact pitfall: "fullScreenCover pauses AVPlayer; ZStack overlay does not". The tap-to-expand uses .fullScreenCover inside an already-.fullScreenCover-presented view — this is nested fullScreenCover, which is supported on iOS 16+. [VERIFIED: codebase comment in SessionView.swift line 139]

### Pitfall 3: SessionSummaryView fixed VStack overflows on small screens
**What goes wrong:** On iPhone SE (375 x 667pt), a fixed VStack without careful `Spacer(minLength:)` constraints can push content off screen, ironically making the difficulty picker invisible — the exact problem D-12 is solving.
**Why it happens:** Fixed `Spacer().frame(height:)` does not flex; if total fixed heights exceed screen height, content overflows or clips.
**How to avoid:** Use `Spacer(minLength: N)` for spacers between content blocks (they shrink on small screens). Only use `Spacer().frame(height: N)` for the top and bottom padding where fixed values are intentional. Test on iPhone SE simulator before shipping.
**Warning signs:** Difficulty picker cut off on SE, or Done button pushed below safe area.

### Pitfall 4: HomeView loads stats from ProgressViewModel but shows stale data after session
**What goes wrong:** HomeView loads streak/stats on `.task` at appear time. After a session completes and the user is returned to Home, the .task does not re-run (the view was not destroyed — it was hidden under the .fullScreenCover). Stats display the pre-session values.
**Why it happens:** `.task` runs once when the view appears for the first time. If the view is already in the hierarchy (just covered), it does not re-appear.
**How to avoid:** Add `.task(id: appState.refreshToken)` or observe a session-completion signal. Simpler: add an `.onAppear` hook that calls `viewModel.reload()` when `viewModel.lastSessionDate != ProgressViewModel.sessions.first?.completedAt`. Even simpler: in HomeViewModel, hook the `showSession` binding's `onChange(of: false)` (when session dismisses) to trigger a reload. [ASSUMED — SwiftUI .task re-run behavior on covered view; well-documented in community]

### Pitfall 5: AdaptationBannerView shows stale adaptation text
**What goes wrong:** `AdaptationService.lastAdjustmentSummary` persists across sessions. If the user opens Home the next day, a 24-hour-old adaptation message still shows.
**Why it happens:** AdaptationService is injected as a @State on MainTabView with lifetime tied to the app session. The property is never cleared.
**How to avoid:** The UI-SPEC (line 286-288) specifies: shown when adaptation occurred "within the last 24 hours". AdaptationService needs a `lastAdjustmentDate: Date?` companion property. HomeViewModel checks if `lastAdjustmentDate` is within 24 hours before showing the banner. [VERIFIED: UI-SPEC line 286 — "within the last 24 hours" is the specified visibility rule]

### Pitfall 6: WeekStreakBar day order depends on locale
**What goes wrong:** Building the 7-day streak bar as a hardcoded M-T-W-T-F-S-S array fails for locales where the week starts on Sunday or Saturday.
**Why it happens:** Calendar.current.firstWeekday varies by locale.
**How to avoid:** Use `Calendar.current.shortWeekdaySymbols` rotated by `Calendar.current.firstWeekday` to build the day labels. For the streak bar, only the visual order matters — the completion status is keyed to a Date, not a weekday name. The sketch shows M-S which is a Monday-first layout; the implementation should use Calendar to be locale-safe. [ASSUMED — standard iOS locale pitfall; well-documented in community]

---

## Code Examples

### AsyncImage thumbnail pattern (40x40 in Home exercise rows)
```swift
// Source: codebase — WorkoutApp/Features/Train/ExerciseLibraryRowView.swift (lines 25-44)
// Adapt for 40x40 Home card rows (D-04 specifies 40x40, ExerciseLibraryRowView uses 52x52)
AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    default:
        Theme.surface
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                Image(systemName: "dumbbell")
                    .font(.body)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
    }
}
.frame(width: 40, height: 40)
```

### Time-of-day greeting
```swift
// Source: [ASSUMED] standard Swift Calendar usage
private var timeOfDayGreeting: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<21: return "Good evening"
    default: return "Good night"
    }
}
```

### Context-aware CTA label computation (D-09)
```swift
// Source: codebase — SessionViewModel.swift (completedSets structure)
// This logic lives in SessionView or ExerciseCardView, reading from SessionViewModel
private var ctaLabel: String {
    guard let currentExercise = viewModel.currentExercise else { return "Next Exercise" }
    let completedCount = viewModel.completedSets[viewModel.currentExerciseIndex]?.count ?? 0
    let allSetsComplete = completedCount >= currentExercise.sets
    let isLastExercise = viewModel.currentExerciseIndex == viewModel.exercises.count - 1

    if !allSetsComplete {
        return "Complete Set"
    } else if isLastExercise {
        return "Finish Session"
    } else {
        return "Next Exercise"
    }
}
```

### StatPillView (new shared component)
```swift
// Source: UI-SPEC 11-UI-SPEC.md Component Inventory + existing StatCell in SessionSummaryView.swift
struct StatPillView: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
```

### WeekStreakBar — locale-safe day order
```swift
// Source: [ASSUMED] standard Calendar approach for locale-correct week display
struct WeekStreakBar: View {
    let completedDates: Set<Date>   // Set of Calendar.startOfDay dates for sessions this week
    let currentStreak: Int

    private var weekDays: [(label: String, date: Date)] { ... }  // computed from Calendar.current

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(weekDays, id: \.date) { day in
                    streakTile(label: day.label, date: day.date)
                }
            }
            Text("fire_emoji \(currentStreak) day streak")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SessionSummaryView with ScrollView | Fixed VStack + Spacer distribution | Phase 11 (this phase) | Eliminates scroll requirement; emoji picker always visible |
| HomeView minimal plan card | Card-stack with greeting + workout + streak + stats | Phase 11 (this phase) | Full workout loop visible from Home |
| 16:9 video in ExerciseCardView | 2:1 compact video with tap-to-expand | Phase 11 (this phase) | More screen space for set logging; context cards visible |
| CTA: "Next Exercise" / "Finish Session" | Three-state CTA: "Complete Set" / "Next Exercise" / "Finish Session" | Phase 11 (this phase) | Better contextual affordance; explicit set completion action |
| Session launched from TrainView | Session launched from HomeView .fullScreenCover | Phase 11 (this phase) | Direct workout loop: Home -> Session -> Summary -> Home |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AppState has no `selectedTab` property — must be added | Architecture Patterns / Pattern 4 | If AppState already had this, no work needed; if not, adding it is safe and low-risk |
| A2 | .task does not re-run on a view that is covered by .fullScreenCover | Common Pitfalls / Pitfall 4 | If .task does re-run on fullScreenCover dismiss, the stats-refresh issue is auto-solved; if not, explicit reload needed |
| A3 | Time-of-day greeting thresholds (morning 5-12, afternoon 12-17, evening 17-21) | Code Examples | Subjective UX choice; wrong thresholds won't break anything but may feel off |
| A4 | Calendar.current.shortWeekdaySymbols rotated by firstWeekday gives correct locale-safe week display | Common Pitfalls / Pitfall 6 | Minor visual bug in non-Monday-first locales; app is English-only for v1.1 so low real-world risk |
| A5 | fetchPreviousReps should return max reps from the immediately prior session (not any prior session) | Architecture Patterns / Pattern 2 | Affects what "Previous" means; if user had 10 reps then 8 reps in prior session, showing 8 vs 10 affects reference value shown |

---

## Open Questions (RESOLVED)

1. **HomeViewModel vs. re-using ProgressViewModel for streak/stats**
   - What we know: ProgressViewModel.loadProgress() already fetches sessions, computes streak, weeklyCompleted, weekBuckets.
   - What's unclear: Should HomeView create its own ProgressViewModel instance, or share the one from WorkoutProgressView? Creating two instances means two CoreData fetches for the same data on app start.
   - Recommendation: Create a lightweight HomeViewModel that calls ProgressViewModel's public methods directly (sharing the logic but not the instance), or pass a shared ProgressViewModel via @Environment. Since MainTabView does not currently inject ProgressViewModel, the simplest path is HomeViewModel creating its own instance — the CoreData cost is negligible for the data sizes involved.
   - RESOLVED: HomeViewModel creates its own instance with dedicated loadStats() method. The CoreData query cost is negligible for the data volumes involved, and this avoids coupling HomeView to ProgressViewModel's lifecycle.

2. **"Previous" rep definition in context cards**
   - What we know: D-07 says "query SessionRepository for last session's reps". CDSetLog stores exerciseName, repsLogged, and sessionId. Multiple sets in one session produce multiple CDSetLog rows.
   - What's unclear: "Previous reps" — is this the max reps logged in the prior session, or the last set logged, or the average?
   - Recommendation: Use max reps from the most recent prior session (highest rep count achieved), matching how "Best" is defined. This makes Previous and Best semantically comparable: "I did 10 before, my best is 12."
   - RESOLVED: fetchPreviousReps returns max reps from the most recent prior session (excludingSessionId filters out the current session). This makes Previous and Best semantically parallel.

3. **ExerciseRowView vs. ExerciseLibraryRowView naming conflict**
   - What we know: ExerciseLibraryRowView.swift has a comment (line 8) explicitly noting the naming conflict with ExerciseRowView in PlanPreviewView. The UI-SPEC names the new Home card row component `ExerciseRowView` in `Features/Main/Components/`.
   - What's unclear: Will a new `ExerciseRowView` in Main/Components/ conflict with the existing `ExerciseRowView` in PlanPreview/Components/?
   - Recommendation: Name the new Home component `HomeExerciseRowView` to avoid any collision, or confirm the existing PlanPreview ExerciseRowView is in a different module scope. Read the existing file before naming. [ASSUMED — need to verify PlanPreview/Components/ file contents]
   - RESOLVED: Named `HomeExerciseRowView` in all plans to avoid collision with the existing PlanPreview ExerciseRowView. Single-target Swift project means no module scoping — same-named structs would conflict at compile time.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 11 is purely iOS client code (SwiftUI layout + CoreData queries). No external CLIs, services, or runtimes beyond the existing Xcode/SPM toolchain are required. All dependencies are already installed.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (native Apple; no additional install required) |
| Config file | WorkoutAppTests/ (existing XCTest target) |
| Quick run command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing WorkoutAppTests/SessionViewModelTests` |
| Full suite command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-04 | Home greeting uses time-of-day prefix | unit | `SessionViewModelTests` is existing; new `HomeViewModelTests` needed | Wave 0 (Plan 01) |
| UI-04 | Home data loads plan + streak in parallel without blocking | unit | `HomeViewModelTests.testParallelLoad` | Wave 0 (Plan 01) |
| UI-05 | Previous reps query returns max reps from most recent prior session | unit | `SessionRepositoryTests.testFetchPreviousReps` | Wave 0 (Plan 01) |
| UI-05 | Best reps query returns all-time max across all sessions | unit | `SessionRepositoryTests.testFetchBestReps` | Wave 0 (Plan 01) |
| UI-05 | CTA label is "Complete Set" when sets remain | unit | `SessionViewModelTests.testCTALabel` | Wave 0 (Plan 01) |
| UI-05 | CTA label is "Next Exercise" when all sets done, more exercises remain | unit | `SessionViewModelTests.testCTALabel` | Wave 0 (Plan 01) |
| UI-05 | CTA label is "Finish Session" on last exercise all sets done | unit | `SessionViewModelTests.testCTALabel` | Wave 0 (Plan 01) |
| UI-07 | Summary fixed VStack shows difficulty picker without scroll on SE | manual (visual) | Launch on iPhone SE simulator | N/A — manual only |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing WorkoutAppTests/SessionRepositoryTests -only-testing WorkoutAppTests/SessionViewModelTests`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Test Coverage
- [x] `WorkoutAppTests/HomeViewModelTests.swift` — covers UI-04 data loading (created in Plan 01, Task 0)
- [x] Add `testFetchPreviousReps` and `testFetchBestReps` to existing `WorkoutAppTests/SessionRepositoryTests.swift` (created in Plan 01, Task 0)
- [x] Add CTA label tests to existing `WorkoutAppTests/SessionViewModelTests.swift` (created in Plan 01, Task 0)

*(Existing test infrastructure: XCTest target confirmed at `WorkoutAppTests/` — no framework install needed)*

---

## Security Domain

This phase makes no changes to authentication, session management, access control, cryptography, or network communication. All changes are SwiftUI layout and local CoreData read queries.

The two new SessionRepository methods (`fetchPreviousReps`, `fetchBestReps`) are read-only CoreData fetches scoped to exerciseName. They do not expose user data across accounts — the existing `fetchUserSessionIds` userId-scoping pattern in ProgressViewModel should be applied to the new queries if they are not already constrained by the session relationship chain.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | partial | New CoreData fetch methods must scope to userId — same pattern as existing SessionRepository.fetchUnsyncedSessions() and ProgressViewModel.detectPRs() |
| V5 Input Validation | no | No new user input in this phase |
| V6 Cryptography | no | — |

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 11 |
|-----------|-------------------|
| SwiftUI throughout (no UIKit) | All new views are SwiftUI — compliant |
| Swift 6, @Observable/@MainActor for ViewModels | New HomeViewModel must follow @Observable @MainActor pattern |
| CoreData (not SwiftData) for local persistence | Session history queries use NSFetchRequest on CoreData — compliant |
| No CocoaPods/Carthage — SPM only | No new dependencies this phase |
| No direct OpenAI calls from iOS client | Not applicable to this phase |
| KeychainAccess for auth tokens | Not applicable to this phase |
| RevenueCat for subscriptions | Not applicable — paywall gate (BlurredPlanGateView) already exists in HomeView; preserve it in rebuild |
| AVFoundation + Mux HLS for video | VideoPlayerView and VideoOverlayView reused as-is — compliant |

**Critical preservation note:** The current HomeView (line 24) contains a `BlurredPlanGateView` subscription gate for non-subscribed users. The rebuilt HomeView must preserve this gate — the "Start Workout" button and workout card content must remain gated for unsubscribed users.

---

## Sources

### Primary (HIGH confidence)
- Codebase direct reads — all Swift source files confirmed via file tool:
  - `WorkoutApp/Features/Main/Tabs/HomeView.swift` — current implementation
  - `WorkoutApp/Features/Session/SessionView.swift` — current session container
  - `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` — current exercise card
  - `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — current summary
  - `WorkoutApp/Core/Theme.swift` — all color + spacing tokens
  - `WorkoutApp/Features/CoreData/SessionRepository.swift` — CDSetLog, CDSessionLog, existing methods
  - `WorkoutApp/Features/Progress/ProgressViewModel.swift` — streak/stats computation
  - `WorkoutApp/Features/Main/MainTabView.swift` — TabView structure
  - `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` — thumbnail pattern
  - `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` — avatar component
  - `WorkoutApp/Features/Train/VideoOverlayView.swift` — fullscreen video overlay
  - `WorkoutApp/Features/Adaptation/AdaptationService.swift` — lastAdjustmentSummary
  - `WorkoutApp/Core/AppState.swift` — auth + subscription state
  - `WorkoutApp/Features/Session/SessionViewModel.swift` — completedSets, currentExerciseIndex
- `.planning/phases/11-screen-redesigns/11-UI-SPEC.md` — approved UI design contract
- `.planning/phases/11-screen-redesigns/11-CONTEXT.md` — locked decisions D-01 through D-16
- `.planning/sketches/001-home-dashboard/index.html` — Sketch 001-A Card Stack (Home target)
- `.planning/sketches/002-workout-session/index.html` — Sketch 002-B Compact (Session target)
- `.planning/REQUIREMENTS.md` — UI-04, UI-05, UI-07 requirement text

### Secondary (MEDIUM confidence)
- None required — all research grounded in codebase inspection and approved design artifacts

### Tertiary (LOW confidence / ASSUMED)
- General SwiftUI .task re-run behavior on covered views (A2) — community knowledge, not tested in this session
- Locale-safe weekday ordering via Calendar.shortWeekdaySymbols (A4) — standard iOS pattern

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries confirmed present in codebase; no new dependencies
- Architecture: HIGH — all integration points verified by reading source files
- Pitfalls: MEDIUM — pitfalls 1/2/3/5 verified via code inspection; 4/6 are assumed from general SwiftUI/iOS knowledge
- UI spec: HIGH — 11-UI-SPEC.md is the approved contract from gsd-ui-researcher/checker

**Research date:** 2026-04-27
**Valid until:** 2026-05-27 (stable SwiftUI/CoreData platform; no rapidly-changing dependencies)
