---
phase: 05-ai-coach-chat
plan: "01"
subsystem: coach-data-foundation
tags: [coredata, supabase, swift, sse, ai-coach]
dependency_graph:
  requires: []
  provides:
    - CDChatMessage CoreData entity
    - coach_messages Supabase table with RLS
    - ChatPayload Swift model
    - CoachResponseEnvelope Swift model
    - ChatMessage display model
    - CoachSSEClient streaming client
  affects:
    - WorkoutApp/Features/Coach (downstream plans 05-02, 05-03)
    - Supabase coach_messages table (backend)
tech_stack:
  added: []
  patterns:
    - SSE streaming via manual URLRequest (mirrors PlanSSEClient pattern)
    - CoreData lightweight migration (new entity, no changes to existing)
    - AnyCodable passthrough for raw JSON Data blobs
key_files:
  created:
    - WorkoutApp/Features/Coach/Models/ChatModels.swift
    - WorkoutApp/Features/Coach/SSE/CoachSSEClient.swift
    - supabase/migrations/20260423000000_create_coach_messages.sql
  modified:
    - WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld/WorkoutApp.xcdatamodel/contents
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - "[ACTION] prefix check placed before [DONE] check in SSE line parser — both are terminal events and action arrives first"
  - "AnyCodableValue private helper added to support nested JSON object/array encoding (not in plan spec but required for correctness)"
  - "invokeWithStreamedResponse avoided per SDK bug #634 — manual URLRequest used instead (same as PlanSSEClient)"
metrics:
  duration: "5 minutes"
  completed: "2026-04-23"
  tasks_completed: 2
  files_created: 3
  files_modified: 2
---

# Phase 05 Plan 01: Coach Data Foundation Summary

**One-liner:** CoreData CDChatMessage entity, Supabase coach_messages RLS migration, Swift ChatPayload/CoachResponseEnvelope models, and CoachSSEClient streaming client with [ACTION] envelope parsing — all data contracts ready for Plans 02 and 03.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | CoreData CDChatMessage + Supabase migration + ChatModels | f1480eb | contents, 20260423000000_create_coach_messages.sql, ChatModels.swift |
| 2 | CoachSSEClient with [ACTION] envelope parsing | db12a75 | CoachSSEClient.swift, project.pbxproj |

## What Was Built

### Task 1: Data Foundation

**CDChatMessage CoreData entity** — 8 attributes added to `WorkoutApp.xcdatamodel/contents`:
- `id` (UUID), `userId` (String), `role` (String), `content` (String), `createdAt` (Date), `syncedToSupabase` (Boolean)
- `planModificationJSON` (String, optional), `planModificationState` (String, optional)
- Uses `codeGenerationType="class"` and `syncable="YES"` matching existing entity conventions (CDSessionLog pattern)
- Lightweight migration applies automatically — new entity, no changes to existing entities

**coach_messages Supabase migration** — `supabase/migrations/20260423000000_create_coach_messages.sql`:
- Table with `user_id`, `role`, `content`, `created_at`, `plan_modification_json`, `plan_modification_state`
- RLS enabled with `user_owns_messages` policy (`auth.uid() = user_id`) — satisfies T-05-01
- Index `idx_coach_messages_user_created` on `(user_id, created_at desc)` for paginated history fetch (D-19)

**ChatModels.swift** — `WorkoutApp/Features/Coach/Models/`:
- `ChatMessage` — Identifiable, Equatable, Sendable display model with ChatRole and PlanModificationState enums
- `ChatPayload` — Encodable, Sendable with snake_case CodingKeys (message_history, current_plan, session_summaries, message_count)
- `ChatProfile`, `HistoryMessage`, `SessionSummary` nested types with correct snake_case CodingKeys
- `AnyCodable` / `AnyCodableValue` — passthrough encoding for CDWorkoutPlan.rawJSON Data blob
- `CoachResponseEnvelope` — Decodable, Sendable with action + plan_delta fields

### Task 2: SSE Streaming Client

**CoachSSEClient.swift** — `WorkoutApp/Features/Coach/SSE/`:
- Mirrors PlanSSEClient verbatim with three changes: endpoint (`coach-chat`), payload type (`ChatPayload`), event enum (`CoachSSEEvent`)
- `CoachSSEEvent` adds `.action(CoachResponseEnvelope)` case between `.token` and `.completed`
- `[ACTION]` prefix detection before `[DONE]` check — critical ordering per plan spec
- Manual URLRequest with Bearer + apikey dual auth headers — avoids Supabase SDK bug #634 (T-05-02)
- `CoachSSEError` enum — identical cases to PlanSSEError

**Xcode project registration** — both new Swift files registered in `project.pbxproj` with B005 IDs, Coach group (Models + SSE sub-groups) added to Features group.

## Deviations from Plan

### Auto-added functionality

**1. [Rule 2 - Missing Critical Functionality] AnyCodableValue private helper**
- **Found during:** Task 1
- **Issue:** `AnyCodable` as specified in plan only handled `Data`, `String`, and nil — nested `[String: Any]` dictionaries from `JSONSerialization.jsonObject` would fail to encode, making `currentPlan` always encode as nil
- **Fix:** Added private `AnyCodableValue` struct with full type switching (String, Int, Double, Bool, [String: Any], [Any]) to support nested JSON object encoding
- **Files modified:** WorkoutApp/Features/Coach/Models/ChatModels.swift
- **Commit:** f1480eb

No other deviations — plan executed with one correctness auto-fix.

## Verification

- `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 17'` → **BUILD SUCCEEDED**
- CDChatMessage entity confirmed in CoreData schema (2 occurrences of `CDChatMessage` in contents XML)
- Migration SQL contains `create table coach_messages`, `enable row level security`, `user_owns_messages`, `idx_coach_messages_user_created`
- ChatModels.swift contains `ChatMessage`, `ChatPayload`, `CoachResponseEnvelope` with correct snake_case CodingKeys
- CoachSSEClient.swift contains `streamChat(payload:)`, `functions/v1/coach-chat`, `data.hasPrefix("[ACTION]")`, dual auth headers
- `invokeWithStreamedResponse` appears only in comments (not called) — confirmed via grep

## Known Stubs

None — all types are complete data contracts with no placeholder values.

## Threat Flags

No new threat surface beyond what is documented in the plan's threat model (T-05-01 through T-05-03 all addressed).

## Self-Check: PASSED

- [x] WorkoutApp/Features/Coach/Models/ChatModels.swift — FOUND
- [x] WorkoutApp/Features/Coach/SSE/CoachSSEClient.swift — FOUND
- [x] supabase/migrations/20260423000000_create_coach_messages.sql — FOUND
- [x] CDChatMessage in WorkoutApp.xcdatamodel/contents — FOUND
- [x] Commit f1480eb — verified via git log
- [x] Commit db12a75 — verified via git log
- [x] Build SUCCESS confirmed
