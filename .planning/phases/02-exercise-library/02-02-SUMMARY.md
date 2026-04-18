---
phase: 02
plan: 02
subsystem: exercise-library-ui
tags: [swiftui, exercise-browse, filter-chips, search, mvvm, observable]
dependency_graph:
  requires: ["02-01"]
  provides: ["ExerciseLibraryView", "ExerciseLibraryViewModel", "FilterChipRow", "ExerciseLibraryRowView"]
  affects: ["TrainView", "WorkoutAppTests"]
tech_stack:
  added: []
  patterns:
    - "@Observable @MainActor ViewModel with in-memory filter + sectioned computed properties"
    - "FilterChip: AccentColor/CardBackground toggle with .contentShape(Rectangle()) 44pt touch target"
    - "ExerciseLibraryView: .searchable on NavigationStack (not inner List), filter chips hidden during search"
key_files:
  created:
    - WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift
    - WorkoutApp/Features/Train/FilterChipRow.swift
    - WorkoutApp/Features/Train/ExerciseLibraryRowView.swift
    - WorkoutApp/Features/Train/ExerciseLibraryView.swift
    - WorkoutAppTests/ExerciseSearchFilterTests.swift
  modified:
    - WorkoutApp/Features/Main/Tabs/TrainView.swift
    - WorkoutApp.xcodeproj/project.pbxproj
    - WorkoutApp/Features/Onboarding/OnboardingViewModel.swift
    - WorkoutApp/Features/PlanPreview/PlanPreviewView.swift
    - WorkoutAppTests/CoreDataStackTests.swift
    - WorkoutAppTests/ExerciseRepositoryTests.swift
decisions:
  - "Named Train-feature row view ExerciseLibraryRowView (not ExerciseRowView) to avoid duplicate filename with PlanPreview/Components/ExerciseRowView.swift in same module"
  - "FilterChipRow collapses (hidden) when searchText is non-empty, matching UI-SPEC search behavior"
  - ".searchable placed on NavigationStack content body (not inner List) per Pitfall 6 from RESEARCH.md"
  - "NavigationLink destination is Text(exercise.name) placeholder until Plan 03 adds ExerciseDetailView"
metrics:
  duration_seconds: 849
  completed_date: "2026-04-18"
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 6
requirements:
  - EXRC-02
---

# Phase 2 Plan 2: Exercise Library Browse UI Summary

Exercise browse and search UI built with SwiftUI @Observable MVVM — sectioned list by muscle group, horizontal filter chips (muscle group + equipment with AND logic), live search, loading/empty/error states, wired into TrainView.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | ExerciseLibraryViewModel + FilterChipRow + ExerciseLibraryRowView | a45485d | ExerciseLibraryViewModel.swift, FilterChipRow.swift, ExerciseLibraryRowView.swift, ExerciseSearchFilterTests.swift |
| 2 | ExerciseLibraryView + TrainView integration | 10f1460 | ExerciseLibraryView.swift, TrainView.swift |

## What Was Built

**ExerciseLibraryViewModel** (`@Observable @MainActor`): fetches exercises from Supabase via `ExerciseRepository.fetchAndSync()` with CoreData offline fallback. Exposes `filteredExercises` (AND logic: muscle group + equipment + search text), `exerciseSections` (grouped by primaryMuscle, sorted alphabetically), and `isEmptySearch`. Error mapping follows the UI-SPEC copywriting contract.

**FilterChipRow**: horizontal `ScrollView` with "All" chip (clears both filters), 8 muscle group chips, 1pt vertical divider, 4 equipment chips. AccentColor fill when selected, CardBackground with tertiaryLabel stroke when unselected. 44pt touch targets via `.contentShape(Rectangle())`. Full accessibility: label, traits, and selected/not selected value.

**ExerciseLibraryRowView**: 52x52 `AsyncImage` thumbnail with dumbbell SF Symbol placeholder (CardBackground + tertiaryLabel), exercise name (`.subheadline semibold`), primaryMuscle label (`.subheadline secondary`), combined `.accessibilityLabel`.

**ExerciseLibraryView**: `NavigationStack` root with `FilterChipRow` (hidden when searching) + `List` sectioned by primaryMuscle with `NavigationLink` rows. `.searchable` on NavigationStack body per Pitfall 6. Pull-to-refresh via `.refreshable`. Three overlay states: loading (ProgressView), empty search ("No results for..."), load error (wifi.slash + copy).

**TrainView**: replaced empty state with `ExerciseLibraryView()` — one line, no extra NavigationStack.

**ExerciseSearchFilterTests**: 5 tests covering muscle group filter, partial name search, All chip clear, equipment filter, and AND logic intersection. All pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Renamed ExerciseRowView.swift to ExerciseLibraryRowView.swift**
- **Found during:** Task 1 (first build attempt)
- **Issue:** `PlanPreview/Components/ExerciseRowView.swift` already defines `struct ExerciseRowView` in the same module. Two files named `ExerciseRowView.swift` cause a "Multiple commands produce .stringsdata" build error.
- **Fix:** Named the Train-feature file `ExerciseLibraryRowView.swift` with struct `ExerciseLibraryRowView`. Plan's `ExerciseRowView.swift` filename preserved as intent; struct name disambiguates. References in ExerciseLibraryView updated accordingly.
- **Files modified:** WorkoutApp/Features/Train/ExerciseLibraryRowView.swift, WorkoutApp.xcodeproj/project.pbxproj

**2. [Rule 3 - Blocker] Fixed Components group path in pbxproj**
- **Found during:** Task 1 build
- **Issue:** The `Components` PBX group (ChipView, ChipGridView, OnboardingProgressView) was nested under the `Core` group in the project file, resolving to `WorkoutApp/Core/Components/`. The actual files live at `WorkoutApp/Features/Onboarding/Components/`. Build error: "Build input files cannot be found."
- **Fix:** Removed `Components` from `Core` group, added it as a child of the `Onboarding` group.
- **Files modified:** WorkoutApp.xcodeproj/project.pbxproj

**3. [Rule 1 - Bug] Removed duplicate UserProfile stub from OnboardingViewModel**
- **Found during:** Task 1 build after fixing Components path
- **Issue:** `OnboardingViewModel.swift` contained a local `struct UserProfile` stub marked "will be replaced once Plan 01 merges." With `Features/Models/UserProfile.swift` now present (from parallel wave), both compiled causing `invalid redeclaration of 'UserProfile'`.
- **Fix:** Removed the local stub from OnboardingViewModel.swift.
- **Files modified:** WorkoutApp/Features/Onboarding/OnboardingViewModel.swift

**4. [Rule 1 - Bug] Fixed Color.tertiary type mismatch in PlanPreviewView**
- **Found during:** Task 1 build
- **Issue:** Two lines in PlanPreviewView used `.tertiary` in a ternary with a `Color` value. In Swift 6 / Xcode 26, `Color.tertiary` returns `some ShapeStyle`, not `Color`, causing type mismatch errors in the ternary.
- **Fix:** Replaced `.tertiary` with `Color(UIColor.tertiaryLabel)` in both ternary expressions.
- **Files modified:** WorkoutApp/Features/PlanPreview/PlanPreviewView.swift

**5. [Rule 1 - Bug] Added @MainActor to CoreDataStackTests and ExerciseRepositoryTests**
- **Found during:** Test run (Task 1 verification)
- **Issue:** Both test classes access `PersistenceController.preview` (a `@MainActor`-isolated property) from non-isolated test methods, causing Swift 6 concurrency errors.
- **Fix:** Added `@MainActor` annotation to both test class declarations.
- **Files modified:** WorkoutAppTests/CoreDataStackTests.swift, WorkoutAppTests/ExerciseRepositoryTests.swift

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `NavigationLink { Text(exercise.name) }` | ExerciseLibraryView.swift | ~46 | Placeholder for ExerciseDetailView — Plan 03 will replace with full detail screen. Intentional per plan spec. |

## Threat Flags

None. This plan renders read-only exercise data fetched by ExerciseRepository (covered in plan 02-01 threat model). No new network endpoints, auth paths, or trust boundaries introduced.

## Self-Check

**Created files:**
- [x] WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift — FOUND
- [x] WorkoutApp/Features/Train/FilterChipRow.swift — FOUND
- [x] WorkoutApp/Features/Train/ExerciseLibraryRowView.swift — FOUND
- [x] WorkoutApp/Features/Train/ExerciseLibraryView.swift — FOUND
- [x] WorkoutAppTests/ExerciseSearchFilterTests.swift — FOUND

**Commits:**
- [x] a45485d — feat(02-02): ExerciseLibraryViewModel, FilterChipRow, ExerciseLibraryRowView + search/filter tests
- [x] 10f1460 — feat(02-02): ExerciseLibraryView + TrainView integration

**Tests:** 5/5 ExerciseSearchFilterTests passed.
**Build:** PROJECT BUILD SUCCEEDED.

## Self-Check: PASSED
