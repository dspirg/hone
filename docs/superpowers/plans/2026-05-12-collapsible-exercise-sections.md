# Collapsible Exercise Library Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make exercise library sections collapsible so users can jump between muscle groups without scrolling through every exercise.

**Architecture:** Add `expandedSections: Set<String>` state to the ViewModel with toggle/auto-expand logic. Replace the List's `Section(header:)` with custom tappable header rows that conditionally show exercises based on expanded state.

**Tech Stack:** SwiftUI, @Observable

**Spec:** `docs/superpowers/specs/2026-05-12-collapsible-exercise-sections-design.md`

---

### Task 1: Add expand/collapse state and logic to ViewModel

**Files:**
- Modify: `WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift`

- [ ] **Step 1: Add expandedSections state and methods**

Add the following after the existing state properties (after line 27):

```swift
var expandedSections: Set<String> = []
```

Add the following methods after the `exerciseSections` computed property (after line 68):

```swift
// MARK: - Section Expand/Collapse

/// Toggles a section's expanded state.
func toggleSection(_ section: String) {
    if expandedSections.contains(section) {
        expandedSections.remove(section)
    } else {
        expandedSections.insert(section)
    }
}

/// Returns true if a section should display its exercises.
/// Auto-expands when: search is active (all sections), or filter yields single section.
func isSectionExpanded(_ section: String) -> Bool {
    // Search active — show all matches
    if !searchText.isEmpty {
        return true
    }
    // Single section after filtering — auto-expand it
    if exerciseSections.count == 1 {
        return true
    }
    // Manual toggle state
    return expandedSections.contains(section)
}
```

- [ ] **Step 2: Clear expanded sections when filters change**

Add the following computed property to reset state when returning to "All". Add after `isEmptySearch` (after line 75):

```swift
/// Collapses all sections when filters are cleared back to "All".
/// Called by the view when activeMuscleGroup/activeEquipment change.
func collapseAll() {
    expandedSections.removeAll()
}
```

- [ ] **Step 3: Commit**

```bash
git add WorkoutApp/Features/Train/ExerciseLibraryViewModel.swift
git commit -m "feat: add expand/collapse state to ExerciseLibraryViewModel"
```

---

### Task 2: Replace List sections with collapsible headers in ExerciseLibraryView

**Files:**
- Modify: `WorkoutApp/Features/Train/ExerciseLibraryView.swift`

- [ ] **Step 1: Replace the List section rendering**

Replace the entire `List { ... }` block (lines 35-48) with:

```swift
List {
    ForEach(viewModel.exerciseSections, id: \.0) { section, exercises in
        // Tappable section header
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.toggleSection(section)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.isSectionExpanded(section) ? Theme.accent : .secondary)
                    .rotationEffect(.degrees(viewModel.isSectionExpanded(section) ? 90 : 0))

                Text(section.uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.isSectionExpanded(section) ? Theme.accent : .primary)

                Spacer()

                Text("\(exercises.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceElevated)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section), \(exercises.count) exercises")
        .accessibilityHint(viewModel.isSectionExpanded(section) ? "Collapse" : "Expand")

        // Exercise rows — only when expanded
        if viewModel.isSectionExpanded(section) {
            ForEach(exercises) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    ExerciseLibraryRowView(exercise: exercise)
                }
                .accessibilityLabel("\(exercise.name), \(exercise.primaryMuscle)")
            }
        }
    }
}
```

- [ ] **Step 2: Add onChange to collapse sections when filter returns to "All"**

Add the following modifier after `.refreshable { ... }` (after line 55):

```swift
.onChange(of: viewModel.activeMuscleGroup) { _, newValue in
    if newValue == nil && viewModel.activeEquipment == nil {
        viewModel.collapseAll()
    }
}
.onChange(of: viewModel.activeEquipment) { _, newValue in
    if newValue == nil && viewModel.activeMuscleGroup == nil {
        viewModel.collapseAll()
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | grep -E "BUILD|error:" | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WorkoutApp/Features/Train/ExerciseLibraryView.swift
git commit -m "feat: collapsible exercise library sections with auto-expand"
```
