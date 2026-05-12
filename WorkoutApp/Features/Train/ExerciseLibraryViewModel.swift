import Foundation
import Observation

// MARK: - ExerciseLibraryViewModel
// @Observable ViewModel for the exercise browse and search experience (EXRC-02).
// Fetches all exercises from Supabase via ExerciseRepository, caches to CoreData,
// and exposes filtered/sectioned computed properties for ExerciseLibraryView.
//
// Filter logic is entirely in-memory — 50–100 exercises is negligible; no debounce needed.
// activeMuscleGroup and activeEquipment are independent (AND logic).
// nil value = "All" (no active filter for that dimension).
//
// Pattern: follows AuthViewModel exactly — isLoading flag, defer { isLoading = false },
//          do/catch with offline fallback, error mapping to UI-SPEC copy.

@Observable
@MainActor
final class ExerciseLibraryViewModel {

    // MARK: - State

    var allExercises: [ExerciseModel] = []
    var isLoading: Bool = false
    var loadError: String? = nil
    var searchText: String = ""
    var activeMuscleGroup: String? = nil   // nil = "All"
    var activeEquipment: String? = nil     // nil = "All"
    var expandedSections: Set<String> = []

    // MARK: - Computed: Filtered Exercises

    /// Applies muscle group, equipment, and search text filters with AND logic.
    /// Search covers exercise name and primaryMuscle (case-insensitive contains — fuzzy match).
    var filteredExercises: [ExerciseModel] {
        allExercises.filter { exercise in
            // Muscle group filter (nil = any)
            if let muscle = activeMuscleGroup, exercise.primaryMuscle != muscle {
                return false
            }
            // Equipment filter (nil = any)
            if let equipment = activeEquipment, exercise.equipmentTag != equipment {
                return false
            }
            // Search text filter (empty = no filter)
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesName = exercise.name.lowercased().contains(query)
                let matchesMuscle = exercise.primaryMuscle.lowercased().contains(query)
                if !matchesName && !matchesMuscle {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Computed: Sectioned Exercises

    /// Groups filteredExercises by primaryMuscle.
    /// Section keys sorted alphabetically; exercises sorted by name within each section.
    var exerciseSections: [(String, [ExerciseModel])] {
        let grouped = Dictionary(grouping: filteredExercises, by: \.primaryMuscle)
        return grouped.keys
            .sorted()
            .compactMap { key in
                guard let exercises = grouped[key] else { return nil }
                return (key, exercises.sorted { $0.name < $1.name })
            }
    }

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

    // MARK: - Computed: Empty Search State

    /// True when search is active but produces no results.
    var isEmptySearch: Bool {
        !searchText.isEmpty && filteredExercises.isEmpty
    }

    /// Collapses all sections when filters are cleared back to "All".
    func collapseAll() {
        expandedSections.removeAll()
    }

    // MARK: - Load

    /// Fetches exercises from Supabase, upserts to CoreData.
    /// Falls back to CoreData on network failure; shows error only if both fail.
    func loadExercises() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            allExercises = try await ExerciseRepository.shared.fetchAndSync()
        } catch {
            // Offline fallback — try CoreData cache
            let cached = ExerciseRepository.shared.loadFromCoreData()
            if cached.isEmpty {
                loadError = mapError(error)
            } else {
                allExercises = cached
            }
        }
    }

    // MARK: - Error Mapping

    /// Maps raw errors to UI-SPEC Copywriting Contract strings.
    /// Never exposes raw error descriptions to the UI.
    private func mapError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            return "Couldn't load exercises. Check your connection."
        } else {
            return "Couldn't load exercises. Please try again."
        }
    }
}
