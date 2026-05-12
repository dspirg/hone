# Collapsible Exercise Library Sections

**Date:** 2026-05-12
**Status:** Approved

## Problem

The exercise library shows all sections expanded. With 8 muscle groups and 50+ exercises, users must scroll past every exercise in earlier groups to reach later ones (e.g. Arms → Legs).

## Approach

Make section headers tappable to expand/collapse. All sections start collapsed, showing the group name and exercise count. Tap to expand. Multiple sections can be open at once.

## Behavior

### Default State
- All sections **collapsed** on load
- Each collapsed section shows: chevron + section name + exercise count badge

### Expand/Collapse
- Tap section header to toggle with `spring` animation
- `chevron.right` rotates to `chevron.down` when expanded
- Expanded section header tinted `Theme.accent`; collapsed uses primary/secondary
- Multiple sections can be open simultaneously

### Auto-Expand Rules
- **Single section after filter:** When a muscle group filter chip narrows results to one section, auto-expand it
- **Search active:** When `searchText` is non-empty, expand all sections so matches are visible
- **Filter cleared:** When returning to "All", collapse all sections back to default

### Section Header Layout

**Collapsed:**
```
[chevron.right (secondary)]  ARMS                              [4]
```

**Expanded:**
```
[chevron.down (accent)]      CHEST                             [4]
  ┌─────────────────────────────────────────┐
  │ [thumb] Bench Press          Chest      │
  │ [thumb] Cable Flye           Chest      │
  │ [thumb] Incline DB Press     Chest      │
  │ [thumb] Push-Up              Chest      │
  └─────────────────────────────────────────┘
```

**Header spec:**
- Chevron: `Image(systemName: "chevron.right")`, 12pt, rotates 90 degrees on expand
- Section name: `.subheadline.weight(.semibold)`, uppercased
- Count badge: `.caption2`, secondary color, pill-shaped `Theme.surfaceElevated` background
- Row padding: 14pt vertical, 16pt horizontal
- Tap target: full row width, minimum 44pt height

## Files Changed

### `ExerciseLibraryViewModel.swift`
- Add `expandedSections: Set<String>` state property (starts empty = all collapsed)
- Add `toggleSection(_ section: String)` method — inserts or removes from set
- Add `shouldAutoExpand` computed logic:
  - If `exerciseSections.count == 1`, return that section name
  - If `!searchText.isEmpty`, return all section names
  - Otherwise return empty set
- Expose `isSectionExpanded(_ section: String) -> Bool` that checks both `expandedSections` and `shouldAutoExpand`

### `ExerciseLibraryView.swift`
- Replace `Section(header: Text(section).textCase(.uppercase))` with a custom tappable header row + conditional `ForEach` for exercises
- Section header is a `Button` that calls `viewModel.toggleSection(section)`
- Exercise rows wrapped in `if viewModel.isSectionExpanded(section)`
- Chevron rotation: `.rotationEffect(.degrees(expanded ? 90 : 0))` with `.animation(.spring(...))`

## Out of Scope
- Persisting expanded/collapsed state across app launches
- Changing the grouping logic (stays grouped by `primaryMuscle`)
- Changing the sort order within sections (stays alphabetical by name)
- Any changes to `FilterChipRow`, `ExerciseLibraryRowView`, or `ExerciseDetailView`
