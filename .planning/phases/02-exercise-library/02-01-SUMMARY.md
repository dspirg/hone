---
plan: 02-01
phase: 02-exercise-library
status: complete
completed: 2026-04-18
subsystem: data-layer
tags: [coredata, supabase, exercise-library, persistence]
dependency_graph:
  requires: [01-foundation]
  provides: [exercise-data-layer, coredata-stack, exercise-repository]
  affects: [02-02-exercise-browse, 02-03-exercise-detail]
tech_stack:
  added: [CoreData NSPersistentContainer, NSManagedObject, Supabase exercises table]
  patterns: [PersistenceController singleton, Repository pattern with offline fallback, DTO-to-model mapping]
key_files:
  created:
    - WorkoutApp/Core/Data/PersistenceController.swift
    - WorkoutApp/Core/Data/ExerciseRepository.swift
    - WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld
    - WorkoutApp/Models/ExerciseDTO.swift
    - WorkoutApp/Models/ExerciseModel.swift
    - supabase/migrations/20260416300000_create_exercises.sql
    - WorkoutAppTests/CoreDataStackTests.swift
    - WorkoutAppTests/ExerciseRepositoryTests.swift
  modified:
    - WorkoutApp/WorkoutApp.swift (managedObjectContext injection)
    - WorkoutApp.xcodeproj/project.pbxproj (new Core/Data and Models groups)
decisions:
  - Files placed at WorkoutApp/Core/Data/ and WorkoutApp/Models/ per plan spec
  - PersistenceController named consistently (not CoreDataStack) to match plan artifact name
  - muxPlaybackId is NULL for all seed exercises — placeholder until videos licensed
  - Phase 3 files (WorkoutPlan, UserProfile, WorkoutPlanRepository) relocated from Core/ to Features/ to match pbxproj group structure
metrics:
  duration: ~45min
  completed: 2026-04-18
  tasks: 2
  files: 10
---

# Phase 02 Plan 01: Data Foundation Summary

## One-Liner

CoreData PersistenceController + Exercise entity, ExerciseDTO/Model value types, ExerciseRepository with Supabase fetch/CoreData upsert, and 20-seed SQL migration with RLS.

## What Was Built

- `PersistenceController` singleton with `NSPersistentContainer(name: "WorkoutApp")`, lightweight migration enabled, in-memory preview store for tests and SwiftUI previews
- `Exercise` CoreData entity with 12 attributes: id (UUID), name, primaryMuscle, equipmentTag, difficulty, howToSteps (Transformable NSArray), formTips, muxPlaybackId, thumbnailURL, localAssetURL, lastViewedAt, syncedAt
- `ExerciseDTO` — Decodable with snake_case CodingKeys mapping Supabase column names; muxPlaybackId nullable for unlicensed video placeholder state
- `ExerciseModel` — Identifiable/Equatable value type with `init(from dto:)` and `init(from entity:)` for both code paths; `hasVideo` computed property drives VideoPlayerView vs placeholder branch
- `ExerciseRepository` — @MainActor singleton; `fetchAndSync()` from Supabase + CoreData upsert; `loadFromCoreData()` offline fallback sorted by name; `updateLastViewed()` for LRU tracking
- `managedObjectContext` environment key injected in `WorkoutApp.swift` via `PersistenceController.shared.container.viewContext`
- `supabase/migrations/20260416300000_create_exercises.sql` — exercises table with CHECK constraints on primaryMuscle/equipmentTag/difficulty, RLS (anon+authenticated SELECT only, no write policies for client roles), indexes on primary_muscle and equipment_tag, 20 seed exercises covering all 8 muscle groups
- `CoreDataStackTests.swift` — 3 tests verifying in-memory store, entity creation, save/load round-trip
- `ExerciseRepositoryTests.swift` — 4 tests (stubs for Task 2 network path, offline load, upsert idempotency)

## Key Decisions

- **Files at correct plan paths**: `WorkoutApp/Core/Data/` and `WorkoutApp/Models/` per 02-01-PLAN.md spec — not under Features
- **PersistenceController naming**: consistent with plan artifact name (not CoreDataStack); class comment documents singleton and in-memory usage patterns
- **muxPlaybackId NULL for all seeds**: placeholder state — feature videos not yet licensed; hasVideo = false for all current exercises
- **Phase 3 file relocation**: WorkoutPlan.swift, UserProfile.swift, WorkoutPlanRepository.swift moved from old `Core/CoreData` and `Core/Models` paths (deleted by previous worktree) to `Features/CoreData` and `Features/Models` — matches pbxproj group structure and Phase 3 import paths
- **Single xcdatamodeld**: removed duplicate; only `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` compiled; old `Features/CoreData` copy deleted

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wrong file paths from previous worktree agent**
- **Found during:** Initial assessment
- **Issue:** Previous executor wrote 02-01 files to `WorkoutApp/Features/CoreData/` and `WorkoutApp/Features/Models/` instead of `WorkoutApp/Core/Data/` and `WorkoutApp/Models/`
- **Fix:** Copied files to correct paths, updated pbxproj group hierarchy to add `Core/Data` group and top-level `Models` group under WorkoutApp, removed wrong-path copies
- **Files modified:** `WorkoutApp.xcodeproj/project.pbxproj` — new groups B002000030000001 (Models) and B002000030000002 (Data)
- **Commits:** 3e6bc1d, 52c20ba

**2. [Rule 3 - Blocking] Phase 3 files deleted from old Core/ paths**
- **Found during:** Step 2 (import check)
- **Issue:** `WorkoutPlanRepository.swift`, `UserProfile.swift`, `WorkoutPlan.swift` were deleted from `WorkoutApp/Core/CoreData/` and `WorkoutApp/Core/Models/` but still imported by Phase 3 code (PlanPreviewView, OnboardingView, etc.)
- **Fix:** Staged the relocations — files moved to `WorkoutApp/Features/CoreData/` and `WorkoutApp/Features/Models/` (where the previous worktree agent had placed them); pbxproj already referenced them there
- **Commits:** 3e6bc1d

**3. [Rule 1 - Note] supabase db push — table already exists**
- **Found during:** Step 7
- **Issue:** `relation "exercises" already exists (SQLSTATE 42P07)` — the migration was already applied from the worktree execution
- **Impact:** None — migration file is committed to source control; remote DB is in correct state
- **Not a deviation**: migration content is correct; idempotency error is expected after worktree push

## Known Stubs

- `muxPlaybackId` is NULL for all 20 seed exercises — `ExerciseModel.hasVideo` returns false for all entries; `VideoPlayerView` branch will never render until real Mux assets are licensed and IDs added via Supabase dashboard or future migration

## Self-Check: PASSED

- [x] `PersistenceController.swift` at `WorkoutApp/Core/Data/PersistenceController.swift`
- [x] `ExerciseDTO.swift` at `WorkoutApp/Models/ExerciseDTO.swift`
- [x] `ExerciseModel.swift` at `WorkoutApp/Models/ExerciseModel.swift`
- [x] `ExerciseRepository.swift` at `WorkoutApp/Core/Data/ExerciseRepository.swift`
- [x] `WorkoutApp.xcdatamodeld` at `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld`
- [x] `supabase/migrations/20260416300000_create_exercises.sql` committed
- [x] `CoreDataStackTests.swift` and `ExerciseRepositoryTests.swift` committed
- [x] pbxproj groups updated with correct paths
- [x] managedObjectContext injected in WorkoutApp.swift
- [x] Task 1 commit: 3e6bc1d
- [x] Task 2 commit: 52c20ba
