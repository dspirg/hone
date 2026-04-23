---
phase: 05-ai-coach-chat
plan: 03
subsystem: coach-viewmodel
tags: [viewmodel, coredata, supabase, streaming, nwpathmonitor, unit-tests]
dependency_graph:
  requires: [05-01, 05-02]
  provides: [CoachViewModel, CoachViewModelTests, CoachSSEClientTests]
  affects: [05-04]
tech_stack:
  added: []
  patterns:
    - "@Observable @MainActor ViewModel (same as PlanGenerationService)"
    - "NWPathMonitor on background queue with MainActor bridge"
    - "isSyncing Bool guard for concurrent Supabase upsert protection"
    - "CoreData write-ahead persistence before SSE stream starts"
    - "cachedUserId from AppState.currentUser (avoids async auth.session in sync predicates)"
    - "Testing helpers (setChatStateForTesting, setIsOnlineForTesting, setCachedProfileForTesting)"
key_files:
  created:
    - WorkoutApp/Features/Coach/CoachViewModel.swift
    - WorkoutAppTests/CoachViewModelTests.swift
    - WorkoutAppTests/CoachSSEClientTests.swift
  modified:
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - "cachedUserId stored from AppState.currentUser on onAppear — avoids async supabase.auth.session in synchronous CoreData NSPredicate contexts"
  - "applyPlanUpdate uses new UUID as supabaseId for AI-modified plans (Supabase sync is out of scope for plan 03; plan will be wired to full sync in a future plan)"
  - "Testing helpers exposed as public methods on CoachViewModel to enable state machine unit testing without subclassing or protocol injection"
  - "[MODIFICATION] stripping uses NSRegularExpression instead of Swift regex literal — avoids iOS 16 deployment target issue with /pattern/ syntax"
metrics:
  duration: ~30m
  completed: "2026-04-23"
  tasks: 2
  files: 4
---

# Phase 05 Plan 03: CoachViewModel Summary

**One-liner:** CoachViewModel chat state machine with SSE streaming, CoreData write-ahead, Supabase sync, NWPathMonitor offline detection, plan modification confirm/dismiss, and real user profile payload assembly from Supabase profiles table.

## What Was Built

### Task 1: CoachViewModel (WorkoutApp/Features/Coach/CoachViewModel.swift)

Full chat state machine following the `@Observable @MainActor final class` pattern from `PlanGenerationService`. Key behaviors implemented:

**State machine:**
- `ChatState` enum: `.idle`, `.streaming`, `.error(String)` — Equatable
- `canSend` computed property: `!isStreaming && isOnline` — both guards required
- `currentStreamTask` cancelled on new send to prevent overlapping streams

**Streaming (D-01 to D-04):**
- `sendMessage(_:appState:)` writes user message to CoreData first (write-ahead, D-20), then starts SSE stream via `CoachSSEClient.streamChat(payload:)`
- Token events accumulate into `streamingText` for live UI update
- Action envelope captured as `pendingEnvelope` when `[ACTION]` arrives
- `completed` event triggers `handleStreamCompleted` to finalize coach message

**Persistence (D-20):**
- `saveMessageToCoreData` creates `CDChatMessage` with `syncedToSupabase = false` before stream starts
- After stream completion, both user and coach messages are upserted to Supabase `coach_messages` table
- `isSyncing` Bool guard prevents concurrent upserts (T-05-11)

**Offline detection (D-32):**
- `NWPathMonitor` started on `com.workoutapp.coach-network-monitor` background queue
- `pathUpdateHandler` bridges to `@MainActor` via `Task { @MainActor [weak self] in ... }`
- `isOnline` state drives `canSend`; offline banner shown in Plan 04 UI

**Plan modification (D-08 to D-12):**
- `confirmModification(messageId:appState:)` immediately sets state to `.confirmed`, then calls Edge Function with `action: "execute_modify"`
- On HTTP error or any thrown error, reverts to `.pending`
- `dismissModification(messageId:)` immediately sets to `.dismissed`, persists to CoreData
- Both states written to `CDChatMessage.planModificationState` for restart persistence

**Retry (D-33):**
- `retry()` resets error state, removes last user message from CoreData and display array, re-sends

**Profile assembly (CHAT-03):**
- `fetchUserProfile(appState:)` queries Supabase `profiles` table on `onAppear`
- Fetches: `goal`, `fitness_level`, `days_per_week`, `equipment`, `injuries`, `display_name`
- `buildPayload` uses `cachedUserProfile?.goal ?? ""` — never hardcoded empty strings
- Message history capped at `suffix(20)` before building payload (T-05-10)

**Pagination (D-19):**
- `loadMessages(limit:offset:)` with default limit 50
- `loadOlderMessages()` calls `loadMessages(limit:50, offset: messages.count)` to prepend older messages
- Session summaries fetched from `CDSessionLog` with `fetchLimit: 3` (D-30)

### Task 2: Unit Tests

**CoachViewModelTests.swift** — 15 tests covering:
- Initial state assertions (idle, empty messages, canSend true)
- Streaming state: `canSend` false when `.streaming`
- Offline state: `canSend` false when `isOnline = false`
- `dismissModification` changes `planModificationState` to `.dismissed` via CoreData in-memory
- `planModificationState: "pending"` CDChatMessage maps to `.pending` display enum
- Message history cap at 20 entries verified via `buildPayloadForTesting` with 30-message CoreData context
- Profile population: goal/fitnessLevel/equipment/name all non-empty when `setCachedProfileForTesting` called
- Session summaries limited to 3 entries (D-30)
- `loadMessages` offset correctly prepends older messages

**CoachSSEClientTests.swift** — 19 tests covering:
- All 3 `CoachSSEEvent` cases: `.token`, `.completed`, `.action`
- `CoachResponseEnvelope` decoding: `modify_plan`, `chat`, `execute_modify` actions
- `plan_delta` snake_case CodingKey maps to `planDelta` camelCase property
- Missing `plan_delta` field decodes gracefully (optional)
- All 5 `CoachSSEError` cases have non-nil, non-empty `errorDescription`
- `streamFailed(statusCode:)` includes status code in description
- `CoachSSEClient()` instantiates without crash
- `ChatMessage.PlanModificationState` raw value roundtrip encoding

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced Swift regex literal with NSRegularExpression**
- **Found during:** Task 1 implementation
- **Issue:** The plan's action used Swift regex literal `/\[MODIFICATION\]\{.*\}\s*$/` which requires iOS 16+ but can cause issues in older toolchains. `NSRegularExpression` is more compatible.
- **Fix:** Used `NSRegularExpression(pattern:)` for `[MODIFICATION]` tag stripping in `handleStreamCompleted`
- **Files modified:** WorkoutApp/Features/Coach/CoachViewModel.swift

**2. [Rule 2 - Missing critical functionality] Added cachedUserId from AppState**
- **Found during:** Task 1 implementation
- **Issue:** The plan's `getCurrentUserId()` used `supabase.auth.currentSession?.user.id.uuidString` which is a synchronous property that may not exist in Supabase Swift SDK v2 (async is the standard pattern). Using it in sync CoreData predicate contexts is fragile.
- **Fix:** Added `cachedUserId: String?` property, set from `AppState.currentUser?.id.uuidString` in `onAppear`. `getCurrentUserId()` returns this cached value.
- **Files modified:** WorkoutApp/Features/Coach/CoachViewModel.swift

## Known Stubs

**applyPlanUpdate supabaseId:** When a plan modification is confirmed and `applyPlanUpdate` saves the updated plan to CoreData, it uses `UUID().uuidString` as the `supabaseId`. This is intentional — the AI-modified plan is not yet synced back to Supabase (that wiring is out of scope for Plan 03). Plan 04 or a future sync plan should wire the updated plan's Supabase row insertion. The plan is correctly stored in CoreData with the new content.

## Threat Surface Scan

No new network endpoints beyond what is documented in the plan's threat model. The `coach_messages` Supabase upsert and `coach-chat` Edge Function call are both within the T-05-10 through T-05-13 threat register scope.

## Self-Check

- FOUND: `/Users/Fish/Desktop/workout/.claude/worktrees/agent-adb97abc/WorkoutApp/Features/Coach/CoachViewModel.swift`
- FOUND: `/Users/Fish/Desktop/workout/.claude/worktrees/agent-adb97abc/WorkoutAppTests/CoachViewModelTests.swift`
- FOUND: `/Users/Fish/Desktop/workout/.claude/worktrees/agent-adb97abc/WorkoutAppTests/CoachSSEClientTests.swift`
- FOUND: commit `395000e` (feat 05-03 CoachViewModel)
- FOUND: commit `866c8bd` (test 05-03 unit tests)

## Self-Check: PASSED
