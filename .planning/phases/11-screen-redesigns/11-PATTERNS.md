# Phase 11: Screen Redesigns - Pattern Map

**Mapped:** 2026-04-27
**Files analyzed:** 11 (new + modified files from CONTEXT.md and RESEARCH.md)
**Analogs found:** 11 / 11

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `WorkoutApp/Features/Main/Tabs/HomeView.swift` | view (rebuild) | request-response | `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` + `HomeView.swift` (self) | exact — same file, full rewrite |
| `WorkoutApp/Features/Main/Components/StatPillView.swift` | component (new) | transform | `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (`StatCell`) | exact — extract + expand |
| `WorkoutApp/Features/Main/Components/WeekStreakBar.swift` | component (new) | transform | `WorkoutApp/Features/Progress/ProgressViewModel.swift` (`computeStreak`, `computeWeeklyRing`) | role-match — UI expression of existing logic |
| `WorkoutApp/Features/Main/Components/ExerciseRowView.swift` | component (new) | request-response | `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` | exact — same pattern, smaller thumbnail |
| `WorkoutApp/Features/Main/Components/AdaptationBannerView.swift` | component (new) | request-response | `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` | role-match — reuses HoneAvatarView inside banner |
| `WorkoutApp/Features/Session/SessionView.swift` | view (modify) | event-driven | `WorkoutApp/Features/Session/SessionView.swift` (self) | exact — targeted CTA label change |
| `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` | component (modify) | request-response + CRUD | `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` (self) | exact — video ratio + context card addition |
| `WorkoutApp/Features/Session/Components/ContextCardView.swift` | component (new) | CRUD | `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (`StatCell`) | role-match — read-only display card, same shape |
| `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` | component (modify) | transform | `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (self) | exact — layout restructure |
| `WorkoutApp/Features/CoreData/SessionRepository.swift` | repository (modify) | CRUD | `WorkoutApp/Features/Progress/ProgressViewModel.swift` (`detectPRs`, `fetchUserSessionIds`) | exact — same NSFetchRequest + NSPredicate pattern |
| `WorkoutApp/Features/Main/MainTabView.swift` | view (modify) | event-driven | `WorkoutApp/Features/Main/MainTabView.swift` (self) | exact — add `selectedTab` binding to TabView |

---

## Pattern Assignments

### `WorkoutApp/Features/Main/Tabs/HomeView.swift` (view, full rebuild)

**Analog:** Current `HomeView.swift` (same file) + `ProgressViewModel.swift` + `SessionSummaryView.swift`

**Imports pattern** (HomeView.swift lines 1-2, ProgressViewModel.swift lines 1-4):
```swift
import SwiftUI
import CoreData
import Foundation
import Observation
```

**Environment + @State pattern** (HomeView.swift lines 9-12, SessionView.swift lines 26-34):
```swift
struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(AdaptationService.self) var adaptationService
    @Environment(\.managedObjectContext) var context
    @State private var viewModel = HomeViewModel()
}
```

**fullScreenCover pattern for session launch** (HomeView.swift lines 50-52 — existing PaywallView usage):
```swift
// EXISTING PATTERN — copy exactly, substitute SessionView
.fullScreenCover(isPresented: $showPaywall) {
    PaywallView()
}

// NEW USAGE for session launch (D-16):
.fullScreenCover(isPresented: $viewModel.showSession) {
    if let day = viewModel.todayWorkoutDay, let planId = viewModel.activePlan?.planId {
        SessionView(workoutDay: day, planId: planId)
            .environment(\.managedObjectContext, context)
            .environment(adaptationService)
    }
}
```

**Subscription gate preservation** (HomeView.swift lines 19-27):
```swift
// CRITICAL: preserve BlurredPlanGateView for unsubscribed users
if appState.isSubscribed {
    planCard(plan: plan)
} else {
    BlurredPlanGateView(showPaywall: $showPaywall) {
        planCard(plan: plan)
    }
}
```

**Data loading pattern** (ProgressViewModel.swift lines 56-77 — `loadProgress` as template):
```swift
// HomeViewModel follows the same @Observable @MainActor pattern:
@Observable
@MainActor
final class HomeViewModel {
    var activePlan: WorkoutPlan? = nil
    var todayWorkoutDay: WorkoutDay? = nil
    var currentStreak: Int = 0
    var totalSessions: Int = 0
    var totalSets: Int = 0
    var adaptationBanner: String? = nil
    var isLoading = true
    var showSession = false

    func load(appState: AppState, adaptationService: AdaptationService, context: NSManagedObjectContext) async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = appState.currentUser?.id.uuidString else { return }

        // Parallel async fetch — see ProgressViewModel.loadProgress() pattern (lines 56-77)
        async let planResult = loadPlan(userId: userId, context: context)
        async let statsResult = loadStats(userId: userId, context: context)
        let (plan, stats) = await (planResult, statsResult)

        activePlan = plan
        todayWorkoutDay = plan?.weeklyDays.first  // or today-matching logic
        currentStreak = stats.currentStreak
        totalSessions = stats.sessionCount
        totalSets = stats.totalSets
        // Show adaptation banner only if within 24h (RESEARCH Pitfall 5)
        if let date = adaptationService.lastAdjustmentDate,
           Date().timeIntervalSince(date) < 86400 {
            adaptationBanner = adaptationService.lastAdjustmentSummary
        }
    }
}
```

**Error handling pattern** (ProgressViewModel.swift lines 73-76, HomeView.swift lines 86-93):
```swift
// Silently fail — show empty state (matches HomeView existing pattern)
do {
    activePlan = try repo.fetchActivePlan(userId: userId)
} catch {
    // Silently fail — show empty state
}
isLoading = false
```

**Card layout pattern** (HomeView.swift lines 59-77 — planCard function):
```swift
// Copy .padding(16) / .background(Theme.surface) / .clipShape(RoundedRectangle(cornerRadius: 16)) structure
VStack(alignment: .leading, spacing: 8) { ... }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
```

**Post-session stats refresh — .onChange pattern** (MainTabView.swift lines 54-60 as analog):
```swift
// On HomeView: refresh stats when session cover dismisses
.onChange(of: viewModel.showSession) { _, isShowing in
    if !isShowing {
        Task { await viewModel.load(appState: appState, adaptationService: adaptationService, context: context) }
    }
}
```

---

### `WorkoutApp/Features/Main/Components/StatPillView.swift` (component, new)

**Analog:** `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — `StatCell` struct (lines 128-142)

**Extract and expand StatCell** (SessionSummaryView.swift lines 124-142):
```swift
// EXISTING StatCell to extract:
struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
```

**New StatPillView** (expand StatCell with pill background — per RESEARCH.md Code Examples):
```swift
// Add .background(Theme.surfaceElevated) + .clipShape(RoundedRectangle) + .frame(maxWidth: .infinity)
// to produce the pill layout used by both HomeView quick stats and SessionSummaryView
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

---

### `WorkoutApp/Features/Main/Components/WeekStreakBar.swift` (component, new)

**Analog:** `WorkoutApp/Features/Progress/ProgressViewModel.swift` — `computeStreak` (lines 99-138) and `computeWeeklyRing` (lines 169-182)

**Calendar.current pattern** (ProgressViewModel.swift lines 99-107):
```swift
// Use Calendar.current.startOfDay for date comparisons — matches ProgressViewModel
let calendar = Calendar.current
let uniqueDays: [Date] = sessions
    .compactMap { $0.completedAt }
    .map { calendar.startOfDay(for: $0) }
    ...
```

**Weekly interval pattern** (ProgressViewModel.swift lines 170-174):
```swift
// Use dateInterval(of: .weekOfYear) for current week days — matches computeWeeklyRing
guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return }
let completed = sessions.filter { session in
    guard let completedAt = session.completedAt else { return false }
    return weekInterval.contains(completedAt)
}
```

**WeekStreakBar view structure** (follows HStack ForEach pattern from SessionSummaryView stats row, lines 47-52):
```swift
// Locale-safe: use Calendar.current.shortWeekdaySymbols rotated by firstWeekday (RESEARCH Pitfall 6)
struct WeekStreakBar: View {
    let completedDates: Set<Date>  // Set of calendar.startOfDay dates from sessions
    let currentStreak: Int

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(weekDays, id: \.date) { day in
                    streakTile(label: day.label, isCompleted: completedDates.contains(day.date))
                }
            }
            Text("🔥 \(currentStreak) day streak")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

### `WorkoutApp/Features/Main/Components/ExerciseRowView.swift` (component, new)

**Analog:** `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` (entire file, lines 1-77)

**AsyncImage thumbnail pattern — exact copy, resize to 40x40** (ExerciseLibraryRowView.swift lines 25-44):
```swift
// Source: ExerciseLibraryRowView.swift lines 25-44
// Change: frame(width: 52, height: 52) → frame(width: 40, height: 40)
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

**Naming note** (ExerciseLibraryRowView.swift lines 7-9 comment):
```swift
// NAMING: Use HomeExerciseRowView to avoid collision with existing
// WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift
// (ExerciseLibraryRowView comment line 7-9 explicitly documents this conflict)
```

**Row HStack layout** (ExerciseLibraryRowView.swift lines 23-75):
```swift
// Copy HStack(spacing: 12) structure — thumbnail leading, name + muscle trailing, Spacer()
HStack(spacing: 12) {
    // thumbnail (40x40)
    VStack(alignment: .leading, spacing: 2) {
        Text(exercise.exerciseName)
            .font(.subheadline.weight(.semibold))
        Text(exercise.muscleGroup)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    Spacer()
}
.accessibilityLabel("\(exercise.exerciseName)")
```

---

### `WorkoutApp/Features/Main/Components/AdaptationBannerView.swift` (component, new)

**Analog:** `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` (reused inside) + `SyncFailureBanner` in `SessionView.swift` (lines 195-212) as layout reference

**HoneAvatarView reuse** (HoneAvatarView.swift lines 3-15):
```swift
// Reuse directly: HoneAvatarView(diameter: 32) as leading avatar in banner HStack
HoneAvatarView(diameter: 32)
```

**Inline banner layout pattern** (SessionView.swift SyncFailureBanner lines 196-211):
```swift
// SyncFailureBanner is the closest layout analog for AdaptationBannerView —
// HStack + padding + Theme.surface + RoundedRectangle
HStack(spacing: 8) {
    HoneAvatarView(diameter: 32)         // Hone branding (replaces exclamationmark icon)
    VStack(alignment: .leading, spacing: 2) {
        Text("Hone adjusted your plan")
            .font(.subheadline.weight(.semibold))
        Text(rationale)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
    Spacer()
}
.padding(.vertical, 12)
.padding(.horizontal, 16)
.background(Theme.surface)
.clipShape(RoundedRectangle(cornerRadius: 12))
.overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderSubtle, lineWidth: 1))
.padding(.horizontal, 16)
```

**Conditional display** (HomeView.swift lines 28-29 — `if let plan = activePlan` pattern):
```swift
// Only show when banner text exists — same optional-binding guard as plan card
if let banner = viewModel.adaptationBanner {
    AdaptationBannerView(rationale: banner)
}
```

---

### `WorkoutApp/Features/Session/SessionView.swift` (view, targeted modification)

**Analog:** Self — targeted change to CTA button label and action (lines 126-135)

**Existing CTA pattern to replace** (SessionView.swift lines 126-135):
```swift
// CURRENT (lines 126-135) — two-state button:
let isLast = vm.currentExerciseIndex == vm.exercises.count - 1
Button(isLast ? "Finish Session" : "Next Exercise") {
    vm.advanceExercise()
}
.buttonStyle(.borderedProminent)
.frame(maxWidth: .infinity)
.frame(height: 52)
.padding(.horizontal, 16)
.padding(.bottom, 16)
.accessibilityLabel(isLast ? "Finish Session" : "Next Exercise")
```

**New three-state CTA** (RESEARCH.md Pattern — ctaLabel computation):
```swift
// REPLACEMENT — three-state button (D-09):
// ctaLabel computed from completedSets + currentExerciseIndex
private func ctaLabel(vm: SessionViewModel) -> String {
    guard let currentExercise = vm.currentExercise else { return "Next Exercise" }
    let completedCount = vm.completedSets[vm.currentExerciseIndex]?.count ?? 0
    let allSetsComplete = completedCount >= currentExercise.sets
    let isLastExercise = vm.currentExerciseIndex == vm.exercises.count - 1

    if !allSetsComplete { return "Complete Set" }
    else if isLastExercise { return "Finish Session" }
    else { return "Next Exercise" }
}

// Button updated — "Complete Set" logs current incomplete set; others advance:
Button(ctaLabel(vm: vm)) {
    let completedCount = vm.completedSets[vm.currentExerciseIndex]?.count ?? 0
    let allSetsComplete = completedCount >= (vm.currentExercise?.sets ?? 0)
    if !allSetsComplete {
        // trigger completeSet via ExerciseCardView's active set — or surface action on vm
        vm.completeCurrentSet()   // new thin method on SessionViewModel
    } else {
        vm.advanceExercise()
    }
}
.buttonStyle(.borderedProminent)
.frame(maxWidth: .infinity)
.frame(height: 52)
.padding(.horizontal, 16)
.padding(.bottom, 16)
```

---

### `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` (component, modify)

**Analog:** Self — two targeted changes: video aspect ratio and context card insertion

**Video area — aspect ratio change** (ExerciseCardView.swift lines 52-60):
```swift
// CURRENT (line 55): .aspectRatio(16 / 9, contentMode: .fit)
// CHANGE TO (D-06):  .aspectRatio(2 / 1, contentMode: .fit)
Group {
    if let pid = muxPlaybackId, !pid.isEmpty {
        VideoPlayerView(muxPlaybackId: pid, localAssetURL: localAssetURL)
            .aspectRatio(2 / 1, contentMode: .fit)   // was 16/9
            // Tap to expand — fullScreenCover (same pattern as ExerciseLibraryRowView line 53)
            .onTapGesture { showVideoOverlay = true }
    } else {
        ExercisePlaceholderView(exerciseName: exercise.exerciseName)
            .aspectRatio(2 / 1, contentMode: .fit)   // was 16/9
    }
}
.fullScreenCover(isPresented: $showVideoOverlay) {
    VideoOverlayView(muxPlaybackId: muxPlaybackId ?? "", exerciseName: exercise.exerciseName)
}
```

**fullScreenCover for video expand** (ExerciseLibraryRowView.swift lines 53-58 — exact pattern):
```swift
// ExerciseLibraryRowView.swift lines 53-58 — copy this pattern for tap-to-expand:
@State private var showVideo = false
// ...
.fullScreenCover(isPresented: $showVideo) {
    VideoOverlayView(
        muxPlaybackId: exercise.muxPlaybackId ?? "",
        exerciseName: exercise.name
    )
}
```

**Context cards insertion — .task(id:) pattern** (ExerciseCardView.swift lines 97-103 for .task anchor):
```swift
// Insert ContextCardView below the ForEach set rows, before Spacer(minLength: 24)
// Load with .task(id: exerciseIndex) to re-fetch on card change (RESEARCH Pitfall 1):
.task(id: exerciseIndex) {
    await loadContextData()
}

// ContextCardView placement (below set rows):
HStack(spacing: Theme.Spacing.md) {
    ContextCardView(label: "Previous", value: previousReps.map { "\($0) reps" } ?? "—")
    ContextCardView(label: "Best", value: bestReps.map { "\($0) reps" } ?? "—")
}
.padding(.horizontal, 16)
.padding(.top, 8)

Spacer(minLength: 24)
```

---

### `WorkoutApp/Features/Session/Components/ContextCardView.swift` (component, new)

**Analog:** `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — `StatCell` (lines 128-142)

**Pattern to copy** (SessionSummaryView.swift lines 128-142):
```swift
// ContextCardView is StatCell + background pill — same shape as StatPillView but smaller:
struct ContextCardView: View {
    let label: String   // "Previous" or "Best"
    let value: String   // "10 reps" or "—"

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
```

---

### `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` (component, modify)

**Analog:** Self — two targeted changes: ScrollView to fixed VStack, stats row expansion

**ScrollView removal** (SessionSummaryView.swift lines 26-27):
```swift
// CURRENT (line 26): ScrollView {
// CHANGE TO: replace outer ScrollView with plain VStack filling screen
// Use Spacer(minLength:) between sections so iPhone SE doesn't overflow (RESEARCH Pitfall 3)
VStack(spacing: 0) {
    Spacer(minLength: 16)
    // checkmark icon — shrink from 56 to 36 (D-10):
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 36))           // was .system(size: 56)
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("Session complete")
    // headings (unchanged)
    Spacer(minLength: 20)
    // 4-stat row — add Duration (D-10):
    HStack(spacing: 16) {
        StatPillView(label: "Exercises", value: "\(totalExercises)")
        StatPillView(label: "Sets",      value: "\(totalSets)")
        StatPillView(label: "Reps",      value: "\(totalReps)")
        StatPillView(label: "Duration",  value: formattedDuration)
    }
    .padding(.horizontal, 16)
    // ...
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.background(Theme.background.ignoresSafeArea())
```

**Existing formattedDuration to preserve** (SessionSummaryView.swift lines 116-121):
```swift
// KEEP AS-IS — extract to shared utility if needed elsewhere:
private var formattedDuration: String {
    let total = Int(max(duration, 0))
    let minutes = total / 60
    let seconds = total % 60
    return "\(minutes)m \(String(format: "%02d", seconds))s"
}
```

**PR badge section with capped height** (SessionSummaryView.swift lines 57-64 — add maxHeight):
```swift
// CURRENT (lines 57-64): VStack with PRBadgeView, no height cap
// CHANGE (D-12): wrap in ScrollView with maxHeight:
if !prs.isEmpty {
    ScrollView {
        PRBadgeView(prs: prs)
    }
    .frame(maxHeight: 80)
}
```

**Difficulty picker — preserve unchanged** (SessionSummaryView.swift lines 67-90):
```swift
// KEEP ENTIRELY UNCHANGED — 44pt emoji, labels, spring animation (D-11):
VStack(spacing: 12) {
    Text("How was that?").font(.headline)
    HStack(spacing: 24) {
        ForEach(DifficultyRating.allCases, id: \.self) { rating in
            Button { selectedRating = rating } label: {
                VStack(spacing: 4) {
                    Text(rating.emoji).font(.system(size: 44))
                        .opacity(selectedRating == nil || selectedRating == rating ? 1.0 : 0.3)
                        .scaleEffect(selectedRating == rating ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                    Text(rating.label).font(.caption2)
                        .foregroundStyle(selectedRating == rating ? .primary : .secondary)
                }
            }
            .accessibilityLabel(rating.label)
        }
    }
}
```

---

### `WorkoutApp/Features/CoreData/SessionRepository.swift` (repository, modify)

**Analog:** `WorkoutApp/Features/Progress/ProgressViewModel.swift` — `detectPRs` (lines 253-301) and `fetchUserSessionIds` (lines 305-311)

**NSFetchRequest + NSPredicate pattern** (ProgressViewModel.swift lines 274-290):
```swift
// Copy this pattern for fetchPreviousReps and fetchBestReps —
// same predicate construction, same userId scoping via fetchUserSessionIds:
let priorRequest = CDSetLog.fetchRequest()
priorRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
    NSPredicate(format: "exerciseName == %@", exerciseName),
    NSPredicate(format: "sessionId != %@", currentSessionId as CVarArg)
])
let priorSetLogs = try context.fetch(priorRequest)
// userId scope (T-06-02 pattern):
let userSessionIds = try fetchUserSessionIds(userId: userId)
let scopedLogs = priorSetLogs.filter { userSessionIds.contains($0.sessionId ?? UUID()) }
```

**fetchUserSessionIds pattern** (ProgressViewModel.swift lines 305-311 — copy into SessionRepository):
```swift
// Copy from ProgressViewModel — move into SessionRepository so context cards can scope to userId:
private func fetchUserSessionIds(userId: String) throws -> Set<UUID> {
    let request = CDSessionLog.fetchRequest()
    request.predicate = NSPredicate(format: "userId == %@", userId)
    request.propertiesToFetch = ["id"]
    let sessions = try context.fetch(request)
    return Set(sessions.compactMap { $0.id })
}
```

**New methods to add** (following `fetchUnsyncedSessions` structure at SessionRepository.swift lines 145-152):
```swift
// Pattern: same @MainActor context, NSFetchRequest with predicate, sort, throws
// Insert after saveDifficultyRating method:

/// Returns the max reps logged for exerciseName in the most recent prior session
/// (excludes currentSessionId). Scoped to userId (T-06-02 pattern).
/// - Returns: Max repsLogged from prior session, or nil if no history.
func fetchPreviousReps(
    exerciseName: String,
    excludingSessionId: UUID?,
    userId: String
) throws -> Int? {
    let req = CDSetLog.fetchRequest()
    req.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
    let allLogs = try context.fetch(req)
    let userSessionIds = try fetchUserSessionIds(userId: userId)
    let filtered = allLogs.filter { log in
        guard let name = log.exerciseName, name == exerciseName else { return false }
        guard let sid = log.sessionId, userSessionIds.contains(sid) else { return false }
        if let excludeId = excludingSessionId { return sid != excludeId }
        return true
    }
    // Group by session, take the most recent session's max reps
    guard let mostRecentSessionId = filtered.first?.sessionId else { return nil }
    let mostRecentLogs = filtered.filter { $0.sessionId == mostRecentSessionId }
    return mostRecentLogs.map { Int($0.repsLogged) }.max()
}

/// Returns the all-time max reps logged for exerciseName across all sessions
/// for the given userId (T-06-02 pattern).
func fetchBestReps(exerciseName: String, userId: String) throws -> Int? {
    let req = CDSetLog.fetchRequest()
    let allLogs = try context.fetch(req)
    let userSessionIds = try fetchUserSessionIds(userId: userId)
    let filtered = allLogs.filter { log in
        guard let name = log.exerciseName, name == exerciseName else { return false }
        guard let sid = log.sessionId else { return false }
        return userSessionIds.contains(sid)
    }
    return filtered.map { Int($0.repsLogged) }.max()
}

private func fetchUserSessionIds(userId: String) throws -> Set<UUID> {
    let request = CDSessionLog.fetchRequest()
    request.predicate = NSPredicate(format: "userId == %@", userId)
    request.propertiesToFetch = ["id"]
    let sessions = try context.fetch(request)
    return Set(sessions.compactMap { $0.id })
}
```

---

### `WorkoutApp/Features/Main/MainTabView.swift` (view, modify)

**Analog:** Self — add `selectedTab` binding to TabView

**Existing TabView pattern** (MainTabView.swift lines 23-48):
```swift
// CURRENT: TabView with no selection binding (lines 23-48)
TabView {
    HomeView().tabItem { Label("Home", systemImage: "house") }
    // ...
}
.tint(Theme.accent)
.environment(adaptationService)
```

**Updated pattern with selectedTab** (AppState.swift lines 8-129 — add property):
```swift
// Step 1: Add to AppState.swift (after activePlanExerciseIDs line 128):
var selectedTab: Int = 0   // 0 = Home, 1 = Train, 2 = Coach, 3 = Progress, 4 = Profile

// Step 2: MainTabView binds TabView to it:
@Bindable var appState: AppState  // change from let to @Bindable for two-way binding
TabView(selection: $appState.selectedTab) {
    HomeView()
        .tabItem { Label("Home", systemImage: "house") }
        .tag(0)
    TrainView()
        .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
        .tag(1)
    // ... (tags 2-4)
}

// Step 3: SessionSummaryView "Done" sets tab before dismiss:
// (In SessionView onDone closure, lines 77-85)
onDone: { rating in
    vm.saveDifficultyRating(rating)
    Task { await adaptationService.requestPostSessionAdaptation(rating: rating) }
    appState.selectedTab = 0   // Switch to Home tab first
    dismiss()                  // Then dismiss (RESEARCH Pattern 4: set tab before dismiss)
}
```

---

## Shared Patterns

### @Observable @MainActor ViewModel
**Source:** `WorkoutApp/Features/Session/SessionViewModel.swift` lines 19-21, `WorkoutApp/Features/Progress/ProgressViewModel.swift` lines 21-23
**Apply to:** `HomeViewModel` (new), any view model created for HomeView
```swift
@Observable
@MainActor
final class HomeViewModel {
    // state vars...
    var isLoading: Bool = false
    var loadError: String? = nil
}
```

### Theme color tokens
**Source:** `WorkoutApp/Core/Theme.swift` lines 5-22
**Apply to:** All new and modified views — never use raw Color values
```swift
// Available tokens:
Theme.accent          // amber accent
Theme.background      // app background
Theme.surface         // card surface
Theme.surfaceElevated // elevated card (use for StatPillView pills)
Theme.borderSubtle    // subtle borders
Theme.successGreen
Theme.destructiveRed

// Available spacing:
Theme.Spacing.xs  // 4pt
Theme.Spacing.sm  // 8pt
Theme.Spacing.md  // 16pt
Theme.Spacing.lg  // 24pt
Theme.Spacing.xl  // 32pt
```

### fullScreenCover pattern
**Source:** `WorkoutApp/Features/Main/Tabs/HomeView.swift` lines 50-52 (PaywallView) and `WorkoutApp/Features/Train/ExerciseLibraryRowView.swift` lines 53-58 (VideoOverlayView)
**Apply to:** Session launch from HomeView (D-16), video tap-to-expand in ExerciseCardView (D-06)
```swift
// Proven pattern — copy exactly:
.fullScreenCover(isPresented: $showSession) {
    DestinationView()
        .environment(someService)
}
```

### Silently-fail error handling
**Source:** `WorkoutApp/Features/Main/Tabs/HomeView.swift` lines 86-93 and `WorkoutApp/Features/Adaptation/AdaptationService.swift` lines 67-70
**Apply to:** All new data-loading methods where UI can display empty state
```swift
do {
    result = try repo.fetch(...)
} catch {
    // Silently fail — show empty state
    // OR: print("ClassName: methodName failed: \(error)") for diagnostics
}
```

### NSFetchRequest + userId scoping
**Source:** `WorkoutApp/Features/Progress/ProgressViewModel.swift` lines 82-92 (`fetchCompletedSessions`) and lines 305-311 (`fetchUserSessionIds`)
**Apply to:** All new CoreData fetch methods in `SessionRepository` (D-07 context card queries)
```swift
// Always include userId predicate (T-06-01, T-06-02):
request.predicate = NSPredicate(format: "... AND userId == %@", userId)
// When CDSetLog has no direct userId: scope via fetchUserSessionIds Set<UUID>
```

### .task vs .task(id:) selection
**Source:** `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` line 103 vs RESEARCH.md Pitfall 1
**Apply to:** ExerciseCardView context card loading, any data that must refresh on parameter change
```swift
// Use .task for one-time load on appear:
.task { await loadData() }

// Use .task(id:) for data that re-runs when a dependency changes:
.task(id: exerciseIndex) { await loadContextData() }   // re-runs on each new card
```

### XCTest @MainActor test structure
**Source:** `WorkoutApp/WorkoutAppTests/SessionRepositoryTests.swift` lines 14-61 and `WorkoutApp/WorkoutAppTests/SessionViewModelTests.swift` lines 11-53
**Apply to:** `HomeViewModelTests` (new), new test methods in `SessionRepositoryTests`, new tests in `SessionViewModelTests`
```swift
@MainActor
final class SomeTests: XCTestCase {
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var repository: SessionRepository!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = SessionRepository(context: context, container: persistenceController.container)
    }

    override func tearDownWithError() throws {
        repository = nil
        context = nil
        persistenceController = nil
    }
}
```

---

## No Analog Found

No files in this phase are without a codebase analog. All patterns are grounded in existing source files.

---

## Critical Naming Note

The naming conflict documented in `ExerciseLibraryRowView.swift` lines 7-9 applies directly to the new Home card row component. The existing `ExerciseRowView` in `WorkoutApp/Features/PlanPreview/Components/` conflicts with the D-15 name. Use **`HomeExerciseRowView`** as the final filename and type name to avoid Swift compiler ambiguity.

---

## Metadata

**Analog search scope:**
- `WorkoutApp/Features/Main/` — HomeView, MainTabView
- `WorkoutApp/Features/Session/` — SessionView, ExerciseCardView, SessionSummaryView, SessionViewModel
- `WorkoutApp/Features/Progress/` — ProgressViewModel
- `WorkoutApp/Features/Train/` — ExerciseLibraryRowView, VideoOverlayView
- `WorkoutApp/Features/Coach/Components/` — HoneAvatarView
- `WorkoutApp/Features/Adaptation/` — AdaptationService
- `WorkoutApp/Features/CoreData/` — SessionRepository
- `WorkoutApp/Core/` — Theme, AppState
- `WorkoutApp/WorkoutAppTests/` — SessionRepositoryTests, SessionViewModelTests, ProgressViewModelTests

**Files scanned:** 18 source files read directly
**Pattern extraction date:** 2026-04-27
