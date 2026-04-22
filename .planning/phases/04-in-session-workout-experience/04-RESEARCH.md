# Phase 4: In-Session Workout Experience - Research

**Researched:** 2026-04-22
**Domain:** SwiftUI session navigation, CoreData entities for session/set logging, offline-first sync with NWPathMonitor, rest timer with circular progress ring, local notifications, Supabase insert patterns
**Confidence:** HIGH (stack is locked from CONTEXT.md; patterns verified against official Apple docs via Context7 and existing codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Session Navigation:** Linear, one-at-a-time exercise flow — full-screen card per exercise, swipe or tap Next to advance
- **Progress indicator:** "Exercise 2 of 6" + segmented progress bar at N% fill — at top of each card
- **No jumping:** User moves through the AI plan in order; no skipping or reordering mid-session
- **Video placement:** Video player lives at the top of the exercise card; set logging rows below it
- **Set/rep logging:** +/- stepper per set row — pre-filled with target reps from the AI plan
- **Direct rep input:** Tap the rep number to open a number pad for direct override
- **Set completion:** Checkmark tap confirms set complete and triggers rest timer automatically
- **Set display:** Sets displayed in order (Set 1, Set 2, etc.) with target reps as placeholder until logged
- **Rest timer trigger:** Auto-starts as full-screen overlay when a set is marked complete
- **Rest timer display:** Countdown timer (circular progress ring) with next set/exercise context shown below
- **Rest timer controls:** [+30s] to extend, [Skip Rest] to dismiss immediately
- **Rest timer defaults:** 60s for strength exercises, 30s for cardio/bodyweight (set in plan metadata)
- **Rest timer haptics:** Haptic feedback + soft sound when timer expires; notification if app is backgrounded
- **Offline strategy:** Write-ahead local — all set logs written to CoreData immediately
- **Sync:** On reconnect, CoreData → Supabase sync runs silently in background — no user-visible action
- **No conflict resolution needed:** Session data is append-only (past sessions are never edited)
- **Sync failure banner:** Show subtle banner only if sync fails after 3 retries
- **Session completion:** Summary screen at end showing exercises completed, total sets, total reps, duration
- **Summary tone:** "Great work" moment — simple, non-gamified; shows what was done, not a score
- **Data save timing:** Data saved before summary shown — session committed to CoreData on last set logged

### Claude's Discretion

- Exact CoreData entity schema for session logs (SessionLog, SetLog entities)
- Supabase `session_logs` and `set_logs` table column details
- SwiftUI transition animation between exercise cards (slide, scale, etc.)
- Circular progress ring implementation for rest timer
- Background sync implementation (NWPathMonitor vs URLSession background configuration)
- Exact copy for rest timer screen and session completion summary

### Deferred Ideas (OUT OF SCOPE)

- Weight logging per set (e.g., "135 lbs × 8 reps") — Phase 4 logs reps only; weight tracking for Phase 6+
- Workout modification mid-session (swap/skip exercise) — Phase 5 AI Coach handles plan changes via chat
- Apple Watch companion for timer/logging — out of scope for v1
- Social sharing of session summary — v1 is individual-focused
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESS-01 | User can watch the exercise animatic video and log completed reps and sets during a workout | Existing `VideoPlayerView` + `AVPlayer` reused directly; set logging rows driven by `SessionViewModel` |
| SESS-02 | Automatic rest timer activates between sets with configurable duration | `ProgressView(timerInterval:countsDown:)` for circular progress ring; `UNUserNotificationCenter` for background notification; `SensoryFeedback` for haptic |
| SESS-03 | Session tracking works fully offline; data syncs to server when internet is restored | CoreData write-ahead + `NWPathMonitor` for reconnect detection + Supabase batch insert on sync |
| SESS-04 | User sees a completion summary at the end of each workout showing what was accomplished | `SessionSummaryView` rendered from completed `CDSessionLog` — exercises, sets, reps, duration |
</phase_requirements>

---

## Summary

Phase 4 builds the core workout execution loop: a full-screen card-per-exercise navigator, set/rep logging, an automatic rest timer, and offline-first data persistence syncing to Supabase when connectivity returns.

The most technically complex piece is the **rest timer** — it must continue counting down when the app is backgrounded, and fire a local notification when it expires. The recommended approach is to record `timerEndDate` at start time and use `ProgressView(timerInterval:countsDown:)` (iOS 16+, `[VERIFIED: Context7 Apple SwiftUI docs]`) for the visual ring. This ProgressView auto-updates to the correct percentage when the app returns to foreground because it is date-based, not tick-based. The background notification is scheduled via `UNUserNotificationCenter` at timer start and cancelled on skip/dismiss.

The **offline sync** is architecturally simple because session data is append-only. `NWPathMonitor` (Network framework, no import beyond `import Network`) detects reconnect events on a background queue. On reconnect, a sync service reads all unsynced `CDSessionLog` and `CDSetLog` records from CoreData and upserts them to Supabase in a single batch. No conflict resolution is needed because the primary key is a UUID generated on-device; duplicates are handled by Supabase `upsert(onConflict: "id")`.

The **session navigation** uses a `@State var currentExerciseIndex: Int` driving a `TabView(.page)` or a custom ZStack with `offset` animation. The CONTEXT.md decision to allow swipe-to-advance makes `TabView(.page)` with `indexDisplayMode(.never)` the cleanest primitive — but a custom ZStack gives more control over the transition animation. Research recommends the custom ZStack approach to match the "full-screen card" aesthetic specified in CONTEXT.md.

**Primary recommendation:** Use date-anchored `ProgressView(timerInterval:)` for the rest timer (avoids background timer maintenance), `NWPathMonitor` for offline detection, CoreData with `automaticallyMergesChangesFromParent = true` for write-ahead logging, and Supabase batch upsert for sync.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Session card navigation (exercise flow) | iOS Client (SwiftUI) | — | Pure local UI state; no server involvement mid-session |
| Set/rep logging (write-ahead) | iOS Client (CoreData) | — | Must work offline; CoreData is the write-ahead log |
| Rest timer countdown display | iOS Client (SwiftUI) | — | Date-anchored ProgressView auto-recovers from background |
| Rest timer background notification | iOS Client (UserNotifications) | — | Local notification; no server needed |
| Haptic feedback on timer expire | iOS Client | — | `SensoryFeedback` modifier — pure device |
| Offline detection / sync trigger | iOS Client (NWPathMonitor) | — | `Network` framework; fires sync callback on reconnect |
| Session sync (CoreData → Supabase) | iOS Client → Backend (Supabase) | — | Client reads unsynced records, batch upserts to Supabase |
| Session log persistence (remote) | Backend (Supabase PostgreSQL) | — | `session_logs` + `set_logs` tables with RLS |
| Session completion summary | iOS Client (SwiftUI) | CoreData | Reads from completed CDSessionLog; no server call needed |
| Video playback during session | iOS Client (AVPlayer / Mux HLS) | — | Reuses `VideoPlayerView` from Phase 2; cached HLS for offline |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Session card UI, timer overlay, completion summary | Locked by CLAUDE.md; `ProgressView(timerInterval:)` available iOS 16+ |
| CoreData | iOS 16+ | Write-ahead log for session/set records | Locked by CLAUDE.md for local persistence |
| Network (NWPathMonitor) | iOS 12+ (system) | Connectivity detection for sync trigger | Apple-native; no third-party needed |
| UserNotifications | iOS 10+ (system) | Local notification when rest timer expires while backgrounded | Apple-native; required for backgrounded timer UX |
| AVFoundation / AVKit | iOS 16+ | Video playback during session | Already integrated via `VideoPlayerView` in Phase 2 |
| Supabase Swift | 2.x | Batch insert session/set logs on sync | Already integrated; `.upsert(onConflict:)` for idempotent sync |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AudioToolbox | System | Soft sound when rest timer expires | Only needed if implementing audio cue; `AudioServicesPlaySystemSound` for a brief system sound |
| MuxPlayerSwift | Existing (Phase 2) | Mux HLS playback in exercise card | Already installed; reuse `VideoPlayerView` directly |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ProgressView(timerInterval:)` | Manual `Timer.publish` + `@State` countdown | Date-anchored ProgressView recovers from background automatically; manual Timer approach requires `scenePhase` tracking and time-elapsed math on foreground |
| NWPathMonitor | `URLSession` connectivity check | NWPathMonitor delivers push events on reconnect; polling URLSession is less efficient and misses the exact reconnect moment |
| `fullScreenCover` for rest timer overlay | Custom ZStack with opacity | `fullScreenCover` presents a new view, breaking the exercise card's video player state; ZStack overlay preserves context underneath |

**Installation:** No new SPM packages required — all dependencies are system frameworks or already installed.

---

## Architecture Patterns

### System Architecture Diagram

```
WorkoutDay (from CDWorkoutPlan)
        │
        ▼
SessionViewModel
  ├── currentExerciseIndex: Int
  ├── sessionLog: CDSessionLog     ◄── CoreData write-ahead
  ├── setLogs: [CDSetLog]         ◄── one per completed set
  ├── timerEndDate: Date?          ◄── drives rest timer overlay
  └── isRestTimerActive: Bool
        │                │
        ▼                ▼
ExerciseCardView    RestTimerOverlay
  ├── VideoPlayer      ├── ProgressView(timerInterval:)  ← date-anchored
  ├── SetLogRow[n]     ├── +30s / Skip buttons
  └── Next button      └── UNUserNotificationCenter schedule/cancel
        │
        ▼
SessionSummaryView
  └── reads CDSessionLog on CoreData for totals
        │
        ▼ (on reconnect via NWPathMonitor)
SessionSyncService
  └── Supabase upsert(session_logs) + upsert(set_logs)
```

### Recommended Project Structure

```
WorkoutApp/Features/Session/
├── SessionView.swift                   # Root — launches from TrainView
├── SessionViewModel.swift              # @Observable; owns exercise index, timer, sync
├── Components/
│   ├── ExerciseCardView.swift          # Full-screen card: video + set rows
│   ├── SetLogRow.swift                 # Stepper + checkmark per set
│   ├── RestTimerOverlay.swift          # Full-screen overlay with circular ring
│   ├── SessionProgressBar.swift        # "Exercise N of M" + segmented bar
│   └── SessionSummaryView.swift        # Completion screen
WorkoutApp/Features/CoreData/
└── SessionRepository.swift             # CoreData CRUD for CDSessionLog + CDSetLog
WorkoutApp/Core/Sync/
└── SessionSyncService.swift            # NWPathMonitor + Supabase batch upsert
supabase/migrations/
└── YYYYMMDDHHMMSS_create_session_logs.sql
```

### Pattern 1: Date-Anchored Rest Timer

**What:** Record `timerEndDate = Date().addingTimeInterval(durationSeconds)` when a set is marked complete. Pass `Date()...timerEndDate` to `ProgressView(timerInterval:countsDown:)`. Schedule a `UNUserNotificationCenter` local notification at `timerEndDate`. On skip, cancel the pending notification and nil out `timerEndDate`.

**When to use:** Any countdown that must survive the app being backgrounded without keeping a background process alive.

**Why it works:** `ProgressView(timerInterval:)` is date-anchored — when the app returns from background it reads the current time against the recorded end date and renders the correct percentage. No `Timer.publish`, no `scenePhase` bookkeeping needed.

```swift
// Source: Context7 — Apple SwiftUI developer docs
// ProgressView with timerInterval — iOS 16+
ProgressView(timerInterval: startDate...endDate, countsDown: true) {
    Text("Rest")
}
.progressViewStyle(.circular)
.tint(Color("AccentColor"))
```

**Timer expire detection:** Use a `onChange(of:)` watcher on `currentDate` from a lightweight `TimelineView(.animation)` or a single `Timer.publish(every: 0.5)` that fires only while the overlay is visible to detect expiry and trigger haptic + dismiss.

```swift
// Lightweight expire check while overlay is on screen
.onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
    if now >= timerEndDate {
        handleTimerExpired()
    }
}
```

### Pattern 2: Write-Ahead CoreData Logging

**What:** Every `SetLogRow` checkmark tap calls `sessionViewModel.completeSet(index:repsLogged:)` which immediately inserts a `CDSetLog` into CoreData via `container.performBackgroundTask`. The `CDSessionLog` row is created when the session starts and `completedAt` is populated when the last exercise's last set is logged.

**When to use:** Always — this is how offline-first works.

**Example:**

```swift
// Background context write pattern — mirrors WorkoutPlanRepository
container.performBackgroundTask { backgroundContext in
    let setLog = CDSetLog(context: backgroundContext)
    setLog.id = UUID()
    setLog.sessionId = sessionLog.id
    setLog.exerciseName = exercise.exerciseName
    setLog.setNumber = Int16(setIndex + 1)
    setLog.repsLogged = Int16(repsLogged)
    setLog.completedAt = Date()
    setLog.syncedToSupabase = false
    try? backgroundContext.save()
}
```

### Pattern 3: NWPathMonitor Connectivity Detection

**What:** `NWPathMonitor` (from `import Network`) is initialized once in `SessionSyncService` and started on a background queue. When `path.status == .satisfied`, the service triggers a sync pass.

**When to use:** Any feature needing reconnect events for deferred sync.

```swift
// Source: [VERIFIED: Apple Network framework documentation]
import Network

final class SessionSyncService {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.workoutapp.network-monitor")

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { await self?.syncPendingLogs() }
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
```

### Pattern 4: Supabase Batch Upsert for Idempotent Sync

**What:** Read all `CDSessionLog` where `syncedToSupabase == false`, build Encodable structs, call `supabase.from("session_logs").upsert(rows, onConflict: "id").execute()`. Same for `CDSetLog`. On success, mark CoreData records `syncedToSupabase = true` and save.

**When to use:** Sync on reconnect and on every app foreground while session records exist unsync'd.

```swift
// Source: Context7 — Supabase Swift SDK docs
struct SessionLogRow: Encodable {
    let id: String
    let userId: String
    let planId: String
    let workoutDay: String
    let startedAt: Date
    let completedAt: Date
    let totalSets: Int
    let totalReps: Int
}

try await supabase
    .from("session_logs")
    .upsert(rows, onConflict: "id")
    .execute()
```

**Retry logic:** Wrap the upsert in a loop with `retryCount` (max 3). On final failure, call a closure to surface the sync banner. `[ASSUMED]` — retry count of 3 matches CONTEXT.md decision but the exact retry delay strategy (immediate vs. exponential backoff) is Claude's discretion.

### Pattern 5: Haptic Feedback on Timer Expire

**What:** Use SwiftUI `sensoryFeedback` modifier (iOS 17+) or fall back to `UINotificationFeedbackGenerator` for the timer-expired haptic. CONTEXT.md specifies "haptic feedback + soft sound" — sound uses `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)` or a brief system sound ID.

```swift
// Source: Context7 — Apple SwiftUI developer docs
.sensoryFeedback(.success, trigger: timerJustExpired)
// timerJustExpired is a Bool that flips true when timer hits zero
```

### Pattern 6: Local Notification for Backgrounded Timer

**What:** When rest timer starts, schedule a `UNUserNotificationCenter` local notification at `timerEndDate`. When the user taps [Skip Rest], cancel that pending notification by identifier.

```swift
// Source: [VERIFIED: Apple UserNotifications framework]
let content = UNMutableNotificationContent()
content.title = "Rest complete"
content.body = "Time for your next set"
content.sound = .default

let trigger = UNTimeIntervalNotificationTrigger(
    timeInterval: durationSeconds,
    repeats: false
)
let request = UNNotificationRequest(
    identifier: "rest-timer-\(sessionId)",
    content: content,
    trigger: trigger
)
UNUserNotificationCenter.current().add(request)
```

**Permission:** Request notification permission once during session start (`UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`). If denied, timer still works — notification is silently skipped.

### Pattern 7: Full-Screen Exercise Card Navigation

**What:** `@State var currentExerciseIndex: Int` in `SessionViewModel`. The view renders the card at `exercises[currentExerciseIndex]` with an `offset` + `animation(.spring())` transition. On "Next" tap or swipe-right gesture, increment index with animation.

**Why not `TabView(.page)`:** `TabView` with `indexDisplayMode(.never)` would work but offers less control over the transition direction and the "Next" button tap behavior. A custom ZStack with animated offset gives the exact full-screen card slide specified in CONTEXT.md.

```swift
// Custom card transition pattern
ZStack {
    ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
        ExerciseCardView(exercise: exercise, sessionViewModel: viewModel)
            .offset(x: CGFloat(index - currentExerciseIndex) * UIScreen.main.bounds.width)
    }
}
.animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentExerciseIndex)
```

### Anti-Patterns to Avoid

- **Timer.publish for rest timer:** A `Timer.publish` countdown stops or drifts when the app is backgrounded. Use the date-anchored `ProgressView(timerInterval:)` approach instead.
- **AVPlayerLooper with HLS:** Documented in Phase 2 — use seek-to-zero pattern. `VideoPlayerView` already implements this correctly.
- **fullScreenCover for rest timer overlay:** Presenting a `fullScreenCover` creates a new view hierarchy and interrupts AVPlayer. Use a ZStack overlay within the exercise card view.
- **In-memory-only session data:** If app crashes mid-session, all logs are lost. CoreData write-ahead on every set tap prevents this.
- **Sync on every set save:** Hammers the network and doesn't handle offline gracefully. Batch sync on reconnect is the right strategy.
- **Starting NWPathMonitor on main thread:** `NWPathMonitor.start(queue:)` must use a background `DispatchQueue`. Starting on `.main` causes a runtime warning and potential UI stutter.
- **Multiple NWPathMonitor instances:** Create one instance in `SessionSyncService` and share it. Multiple monitors create redundant OS-level network callbacks.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Circular progress ring countdown | Custom `Canvas` or `Shape` drawing | `ProgressView(timerInterval:countsDown:)` with `.progressViewStyle(.circular)` | Date-anchored; auto-updates on foreground resume; 3 lines of code |
| Background timer management | Background task + `Date` arithmetic | Date-anchored `ProgressView` + `UNUserNotificationCenter` | iOS suspends background tasks for simple timers; this approach requires no background entitlement |
| Connectivity polling | `Timer.publish` + URLSession ping | `NWPathMonitor` | Push-based; fires exactly on state change; no polling overhead |
| Idempotent sync | Custom "already synced?" logic | Supabase `upsert(onConflict: "id")` | UUID primary key generated on device; upsert handles duplicates transparently |
| Haptic feedback | `UIImpactFeedbackGenerator` in Swift 6 | `SensoryFeedback` modifier (iOS 17+) | SwiftUI-native; declarative; no UIKit import needed |

**Key insight:** The rest timer is the piece most likely to be over-engineered. The date-anchored `ProgressView(timerInterval:)` + `UNUserNotificationCenter` combination covers every case (active, backgrounded, notification while backgrounded, app killed and relaunched) with no background processing entitlements needed.

---

## CoreData Entity Schema (Claude's Discretion Recommendation)

### CDSessionLog

| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | Device-generated; primary key for Supabase upsert |
| userId | String | From `AppState.currentUser.id.uuidString` |
| planId | String | Supabase `workout_plans.id` for the active plan |
| workoutDayLabel | String | e.g., "Monday" — from `WorkoutDay.dayLabel` |
| startedAt | Date | Set when session begins |
| completedAt | Date? | Set when last set logged; nil if session was abandoned |
| totalExercises | Int16 | Count of exercises in the day's plan |
| totalSets | Int16 | Aggregate across all set logs (computed on complete) |
| totalReps | Int16 | Aggregate across all set logs (computed on complete) |
| syncedToSupabase | Boolean | Default `false`; `true` after successful sync |
| setLogs | to-many → CDSetLog | Ordered by completedAt ascending; cascade delete |

### CDSetLog

| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | Device-generated; primary key for Supabase upsert |
| sessionId | UUID | FK to CDSessionLog.id (redundant for Supabase sync without join) |
| exerciseName | String | Denormalized from `PlannedExercise.exerciseName` |
| setNumber | Int16 | 1-indexed (Set 1, Set 2, …) |
| targetReps | String | Copied from plan (e.g., "8-12") for Phase 6 comparison |
| repsLogged | Int16 | Actual reps tapped by user |
| completedAt | Date | Timestamp of checkmark tap |
| syncedToSupabase | Boolean | Default `false` |
| session | to-one → CDSessionLog | Inverse of CDSessionLog.setLogs; nullify on delete |

**Migration note:** These two new entities must be added to the existing `WorkoutApp.xcdatamodeld` model file. The existing lightweight migration options (`NSMigratePersistentStoresAutomaticallyOption: true`, `NSInferMappingModelAutomaticallyOption: true`) in `PersistenceController` handle adding new entities automatically — no mapping model needed.

---

## Supabase Table Schema (Claude's Discretion Recommendation)

### session_logs

```sql
CREATE TABLE public.session_logs (
    id UUID PRIMARY KEY,                  -- device-generated UUID
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.workout_plans(id) ON DELETE SET NULL,
    workout_day_label TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    total_exercises INT NOT NULL DEFAULT 0,
    total_sets INT NOT NULL DEFAULT 0,
    total_reps INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.session_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own session logs"
    ON public.session_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own session logs"
    ON public.session_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### set_logs

```sql
CREATE TABLE public.set_logs (
    id UUID PRIMARY KEY,                  -- device-generated UUID
    session_id UUID NOT NULL REFERENCES public.session_logs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    set_number INT NOT NULL,
    target_reps TEXT NOT NULL,
    reps_logged INT NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.set_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own set logs"
    ON public.set_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own set logs"
    ON public.set_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
```

**Note:** `user_id` is denormalized into `set_logs` to allow a direct RLS policy check without a join to `session_logs`. This is the standard Supabase pattern for per-user RLS on child tables. `[VERIFIED: Supabase Swift SDK docs pattern]`

---

## Common Pitfalls

### Pitfall 1: Timer Drift When App is Backgrounded
**What goes wrong:** Using `Timer.publish(every: 1)` to drive a `@State var secondsRemaining` countdown. When the app enters background, iOS suspends the timer. On foreground return, the countdown shows the wrong value and may miss the expire event entirely.
**Why it happens:** `Timer.publish` is suspended when the app is not in the foreground.
**How to avoid:** Store `timerEndDate = Date().addingTimeInterval(duration)` at timer start. Use `ProgressView(timerInterval: Date()...timerEndDate, countsDown: true)`. On foreground return, the ProgressView re-reads the current time against the stored end date and renders correctly.
**Warning signs:** Countdown UI shows stale value after returning from background.

### Pitfall 2: Rest Timer Overlay Interrupts AVPlayer
**What goes wrong:** Presenting the rest timer via `.fullScreenCover` causes `AVPlayerViewController` inside `ExerciseCardView` to tear down (its parent view leaves the hierarchy).
**Why it happens:** `fullScreenCover` covers the presenting view but can trigger deinit of embedded UIKit controllers depending on SwiftUI's internal diffing.
**How to avoid:** Implement the rest timer as a ZStack overlay within `SessionView` (above `ExerciseCardView`) rather than as a `.fullScreenCover`. The `ExerciseCardView` and its `VideoPlayerView` remain in the hierarchy; only the overlay's opacity changes.
**Warning signs:** AVPlayer logs "item ended" or video resets to beginning when rest timer dismisses.

### Pitfall 3: NWPathMonitor on Main Thread
**What goes wrong:** `monitor.start(queue: .main)` runs the `pathUpdateHandler` on the main thread. Combined with Swift 6 strict concurrency, this can generate actor isolation warnings and potentially deadlock if the handler tries to update `@Observable` state synchronously.
**Why it happens:** `NWPathMonitor` requires an explicit `DispatchQueue`; `.main` is technically valid but wrong for this use case.
**How to avoid:** Always `monitor.start(queue: DispatchQueue(label: "com.workoutapp.network-monitor"))`. Inside the handler, use `Task { @MainActor in ... }` to update any `@Observable` or UI state.

### Pitfall 4: Sync Race Condition — Multiple Reconnect Events
**What goes wrong:** `NWPathMonitor.pathUpdateHandler` can fire multiple times in rapid succession when a network transitions (e.g., WiFi handoff). Each firing triggers `syncPendingLogs()`, leading to concurrent Supabase upsert calls against the same records.
**Why it happens:** Network path changes are noisy — satisfied/unsatisfied transitions can occur multiple times in < 1 second.
**How to avoid:** Use a `Task` with `isSyncing: Bool` guard in `SessionSyncService`. If `isSyncing == true` when the handler fires, skip the sync attempt. After sync completes (success or final failure), reset `isSyncing = false`.

### Pitfall 5: CoreData Heavyweight Migration Risk
**What goes wrong:** Adding `CDSessionLog` and `CDSetLog` entities to the existing CoreData model without understanding the migration path causes a crash on launch for users with existing data (Phase 2/3 exercises and workout plans stored).
**Why it happens:** CoreData's lightweight migration can infer a mapping for adding new entities — but only if `NSInferMappingModelAutomaticallyOption` is set (it is, in the existing `PersistenceController`).
**How to avoid:** The existing `PersistenceController` already enables both `NSMigratePersistentStoresAutomaticallyOption` and `NSInferMappingModelAutomaticallyOption`. Adding new entities (with no changes to existing entities) is a safe lightweight migration. Do NOT rename or remove existing attributes. Verify by running the app in simulator after model changes before shipping.
**Warning signs:** `CoreData load error: ...` fatal crash on launch = migration inference failed; usually caused by modifying existing entities, not just adding new ones.

### Pitfall 6: Notification Permission Not Requested Before First Session
**What goes wrong:** The rest timer schedules a `UNUserNotificationCenter` local notification without first requesting authorization. The notification silently fails; user sees nothing when timer expires while backgrounded.
**Why it happens:** `UNUserNotificationCenter.add(request:)` silently drops notifications when authorization is denied or not yet granted.
**How to avoid:** Call `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])` during `SessionView.onAppear` (or `SessionViewModel.init`). Handle the `granted == false` case by logging but not blocking session start — the timer overlay still works in-app; only the backgrounded notification is unavailable.

---

## Code Examples

### Rest Timer — Complete Pattern

```swift
// Source: Context7 — Apple SwiftUI developer docs
// ProgressView with timerInterval — iOS 16+
struct RestTimerOverlay: View {
    let endDate: Date
    let onSkip: () -> Void
    let onExtend: () -> Void

    @State private var expired = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 32) {
                ProgressView(timerInterval: Date()...endDate, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    Text(endDate, style: .timer)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .progressViewStyle(.circular)
                .tint(Color("AccentColor"))
                .frame(width: 200, height: 200)

                HStack(spacing: 24) {
                    Button("+30s", action: onExtend)
                        .buttonStyle(.bordered)
                    Button("Skip Rest", action: onSkip)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .sensoryFeedback(.success, trigger: expired)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            if !expired && now >= endDate {
                expired = true
                onSkip()  // auto-dismiss when expired
            }
        }
    }
}
```

### NWPathMonitor Sync Service

```swift
// Source: [VERIFIED: Apple Network framework — NWPathMonitor documentation]
import Network
import Foundation

@Observable
@MainActor
final class SessionSyncService {
    var syncBannerVisible = false
    private(set) var isSyncing = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.workoutapp.network-monitor")

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isSyncing else { return }
                await self.syncPendingLogs()
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stopMonitoring() { monitor.cancel() }

    private func syncPendingLogs() async {
        isSyncing = true
        defer { isSyncing = false }
        var retryCount = 0
        while retryCount < 3 {
            do {
                try await performBatchSync()
                syncBannerVisible = false
                return
            } catch {
                retryCount += 1
            }
        }
        syncBannerVisible = true  // show subtle banner after 3 failures
    }
}
```

### CDSessionLog + CDSetLog CoreData Insert

```swift
// Background context write — mirrors WorkoutPlanRepository pattern
container.performBackgroundTask { ctx in
    let log = CDSetLog(context: ctx)
    log.id = UUID()
    log.sessionId = sessionLog.id
    log.exerciseName = exercise.exerciseName
    log.setNumber = Int16(setIndex + 1)
    log.targetReps = exercise.reps
    log.repsLogged = Int16(repsLogged)
    log.completedAt = Date()
    log.syncedToSupabase = false
    try? ctx.save()
}
```

### Supabase Batch Upsert

```swift
// Source: Context7 — Supabase Swift SDK docs
struct SetLogRow: Encodable {
    let id: String
    let sessionId: String
    let userId: String
    let exerciseName: String
    let setNumber: Int
    let targetReps: String
    let repsLogged: Int
    let completedAt: Date
}

try await supabase
    .from("set_logs")
    .upsert(rows, onConflict: "id")
    .execute()
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Timer.publish` countdown with manual `scenePhase` tracking | `ProgressView(timerInterval:countsDown:)` date-anchored | iOS 16 | Eliminates background timer drift; no background entitlement needed |
| `UIImpactFeedbackGenerator` (UIKit) | `SensoryFeedback` SwiftUI modifier | iOS 17 | Declarative haptic; no UIKit import; Swift 6 safe |
| `Combine` publishers for reactive state | `@Observable` + `async/await` | Swift 5.9 / iOS 17 | Cleaner ownership; compiler-checked concurrency |
| Manual `AVPlayerLooper` | Seek-to-zero on `.AVPlayerItemDidPlayToEndTime` | Phase 2 established | Already in `VideoPlayerView`; must not regress |

**Deprecated / outdated:**
- `ObservableObject` + `@Published`: Still works but `@Observable` is the Swift 6 / iOS 17 standard. Phase 1-3 already use `@Observable` — Phase 4 must continue this pattern.
- Background `URLSession` for timer delivery: Not needed for a simple countdown; overkill and requires background mode entitlement.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ProgressView(timerInterval:countsDown:)` with `.progressViewStyle(.circular)` renders as a circular ring | Standard Stack / Patterns | If the circular style renders as a linear bar instead, a custom `Circle` + `trim` Shape implementation is needed |
| A2 | `container.performBackgroundTask` is safe to call from `@MainActor` context in Swift 6 | Patterns | If compiler rejects this, use `Task.detached` or inject a private `NSManagedObjectContext` |
| A3 | Retry delay between sync attempts can be zero (immediate retry) | Patterns | If Supabase rate-limits rapid retries, exponential backoff should be added |
| A4 | `sensoryFeedback(.success, trigger:)` produces the correct "timer complete" feel | Patterns | If the feedback feels wrong, `.impact(weight: .medium)` or `.warning` may be more appropriate |

---

## Open Questions

1. **Exercise-to-plan lookup at session start**
   - What we know: `TrainView` currently shows `ExerciseLibraryView`. The session launches from the active plan displayed in the Train tab.
   - What's unclear: The TrainView doesn't yet show the active plan — that UI is in Phase 3 HomeView. Phase 4 needs a "Start Workout" entry point. The plan likely needs to be passed from a TrainView plan display or HomeView.
   - Recommendation: The first plan in Phase 4 should update `TrainView` to show the active plan with a "Start Workout" button, and pass the selected `WorkoutDay` to `SessionView` via NavigationLink.

2. **Exercise name to Exercise entity linking**
   - What we know: `PlannedExercise.exerciseName` is a string. `Exercise` CoreData entity also has a `name` string. They should match.
   - What's unclear: There is no foreign key or UUID link — they're matched by string. If an exercise name in the plan doesn't exactly match the exercises table, video playback will fail (no muxPlaybackId found).
   - Recommendation: `SessionViewModel` should attempt a lookup from the `Exercise` CoreData entity by name to get the `muxPlaybackId` and `localAssetURL`. If not found, fall back to `ExercisePlaceholderView` (already exists from Phase 2).

3. **SessionSummaryView exit — what's next?**
   - What we know: The summary shows at session end. User sees exercises, sets, reps, duration.
   - What's unclear: Where does the "Done" button take the user? Back to TrainView? Back to HomeView?
   - Recommendation: Dismiss to TrainView (parent). A "Done" button pops the session navigation stack. ADPT-01 (rate difficulty) is Phase 8 scope — do not add a difficulty rating here.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Swift 6, iOS 17 SDK, CoreData model editor | ✓ (assumed from Phase 1-3 completion) | 16.x | — |
| Supabase CLI | Migration deployment | ✓ (assumed from Phase 1-3 completion) | existing | — |
| NWPathMonitor | Network framework (system) | ✓ | iOS 12+ system | — |
| UNUserNotificationCenter | Notification framework (system) | ✓ | iOS 10+ system | Timer-only mode (no background notification) |
| AVFoundation / Mux | Video playback | ✓ (Phase 2 complete) | existing | ExercisePlaceholderView |

Step 2.6: No new external dependencies beyond system frameworks. All required packages already installed via SPM.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing in `WorkoutAppTests/`) |
| Config file | Xcode scheme `WorkoutApp` — test action targets `WorkoutAppTests` |
| Quick run command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests` |
| Full suite command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-01 | `CDSetLog` writes to CoreData on `completeSet(index:repsLogged:)` | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ Wave 0 |
| SESS-01 | `CDSessionLog` created on session start with correct userId + planId | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ Wave 0 |
| SESS-02 | `timerEndDate` is set correctly when set is completed | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionViewModelTests` | ❌ Wave 0 |
| SESS-03 | `SessionSyncService` reads unsynced logs and marks them `syncedToSupabase = true` after upsert | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionSyncServiceTests` | ❌ Wave 0 |
| SESS-04 | Summary totals (totalSets, totalReps, duration) computed correctly from `CDSessionLog` + `CDSetLog` | unit | `xcodebuild test ... -only-testing:WorkoutAppTests/SessionRepositoryTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `WorkoutAppTests/SessionRepositoryTests.swift` — covers SESS-01, SESS-04
- [ ] `WorkoutAppTests/SessionViewModelTests.swift` — covers SESS-02
- [ ] `WorkoutAppTests/SessionSyncServiceTests.swift` — covers SESS-03

*(All three test files require new source files to exist first — they are Wave 0 test scaffolds in Plan 04-01)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Session data written by authenticated user only; JWT already handled by Supabase |
| V3 Session Management | no | App session (workout session) is local state; auth session handled by Supabase |
| V4 Access Control | yes | Supabase RLS on `session_logs` and `set_logs` — `auth.uid() = user_id` policy |
| V5 Input Validation | yes | Rep counts are `Int16` (stepper or number pad) — validate range 0–999 before CoreData write |
| V6 Cryptography | no | No new secrets; JWT handling unchanged from Phase 1 |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User A reads User B's session logs | Information Disclosure | Supabase RLS `USING (auth.uid() = user_id)` on both tables |
| Client submits fabricated rep counts | Tampering | Clamped on client to 0–999; server stores what client sends (fitness app, not financial — acceptable) |
| Notification permission prompt at wrong time | Denial of Service (UX) | Request permission at session start with `.requestAuthorization(options: [.alert, .sound])` — graceful if denied |

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 4 |
|-----------|------------------|
| SwiftUI throughout (no UIKit as primary) | Session UI is pure SwiftUI; `VideoPlayerView` UIViewControllerRepresentable wrapper is acceptable and already established |
| Swift 6 + `@Observable` / async/await | `SessionViewModel` must be `@Observable @MainActor`; no `ObservableObject`; no `Combine` |
| CoreData (not SwiftData) | `CDSessionLog` and `CDSetLog` must be CoreData entities |
| Never call OpenAI directly from iOS client | Not applicable — Phase 4 has no AI calls |
| KeychainAccess for auth tokens | Not applicable — no new auth tokens in Phase 4 |
| Supabase for remote persistence | `session_logs` and `set_logs` tables in Supabase |
| NWPathMonitor or .task async for connectivity | Confirmed — `NWPathMonitor` for sync trigger |
| `.fullScreenCover` for full-screen overlays (established Phase 1) | Rest timer uses ZStack overlay WITHIN session, NOT `.fullScreenCover` (see Pitfall 2 above) — this is a deliberate exception to preserve AVPlayer state |
| MVVM (vanilla, no framework) | `SessionViewModel` owns business logic; views are thin |
| No CocoaPods / Carthage | SPM only |
| No Combine for new async code | Use `async/await` and `@Observable` |

---

## Sources

### Primary (HIGH confidence)
- `Context7 /websites/developer_apple_swiftui` — `ProgressView(timerInterval:countsDown:)` API, `sensoryFeedback` modifier, `fullScreenCover` item binding
- `Context7 /websites/developer_apple_coredata` — entity migration, background context patterns
- `Context7 /supabase/supabase-swift` — insert, upsert with `onConflict:` patterns

### Secondary (MEDIUM confidence)
- Existing codebase: `PersistenceController.swift`, `WorkoutPlanRepository.swift`, `VideoPlayerView.swift`, `CoreDataStackTests.swift` — patterns verified by reading source
- Existing Supabase migrations `00000002000000_create_workout_plans.sql`, `20260416300000_create_exercises.sql` — migration structure and RLS policy patterns

### Tertiary (LOW confidence — training knowledge only)
- `NWPathMonitor` API shape (start, cancel, pathUpdateHandler, `DispatchQueue` requirement) — `[ASSUMED]` based on training knowledge; API is stable since iOS 12 but not verified via Context7 in this session
- `UNUserNotificationCenter` local notification scheduling via `UNTimeIntervalNotificationTrigger` — `[ASSUMED]` stable API, iOS 10+; widely documented

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are established project dependencies or Apple system frameworks
- Architecture: HIGH — patterns derived from verified existing codebase and Context7 official docs
- Pitfalls: HIGH — Pitfalls 1/2/5 verified from existing Phase 2 research; Pitfalls 3/4/6 based on framework documentation
- CoreData schema: MEDIUM — Claude's discretion; schema is sound but exact column choices may be refined by planner

**Research date:** 2026-04-22
**Valid until:** 2026-07-22 (90 days — stable Apple frameworks; Supabase Swift SDK minor versions only)
