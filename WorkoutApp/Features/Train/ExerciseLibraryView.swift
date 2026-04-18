import SwiftUI

// MARK: - ExerciseLibraryView
// Root view for the Train tab — exercise browse experience (EXRC-02).
// Renders a sectioned list of exercises grouped by primary muscle group,
// with a horizontal filter chip row and system search bar.
//
// Layout (top to bottom):
//   1. System search bar (via .searchable on NavigationStack — Pitfall 6 from RESEARCH.md)
//   2. FilterChipRow — hidden while search is active (collapsed for vertical space)
//   3. Sectioned List grouped by primaryMuscle (section headers uppercased)
//
// States:
//   - Loading (initial, no data yet): ProgressView centered
//   - Empty search result: "No results for [query]" message + suggestion copy
//   - Load error: wifi.slash icon + error message
//   - Success: sectioned list of ExerciseLibraryRowView rows
//
// Navigation: NavigationLink pushes to placeholder Text(exercise.name) until Plan 03
// adds ExerciseDetailView (intentional placeholder — avoids file ownership conflict).

struct ExerciseLibraryView: View {
    @State private var viewModel = ExerciseLibraryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chip row — hidden when search is active (UI-SPEC: search collapses chips)
                if viewModel.searchText.isEmpty {
                    FilterChipRow(
                        activeMuscleGroup: $viewModel.activeMuscleGroup,
                        activeEquipment: $viewModel.activeEquipment
                    )
                }

                List {
                    ForEach(viewModel.exerciseSections, id: \.0) { section, exercises in
                        Section(header: Text(section).textCase(.uppercase)) {
                            ForEach(exercises) { exercise in
                                NavigationLink {
                                    // Placeholder — ExerciseDetailView added in Plan 03
                                    Text(exercise.name)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                } label: {
                                    ExerciseLibraryRowView(exercise: exercise)
                                }
                                .accessibilityLabel("\(exercise.name), \(exercise.primaryMuscle)")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .refreshable {
                await viewModel.loadExercises()
            }
            .overlay {
                if viewModel.isLoading && viewModel.allExercises.isEmpty {
                    // Initial load state — ProgressView only (no heading per UI-SPEC)
                    ProgressView()
                } else if viewModel.isEmptySearch {
                    // Empty search result state — UI-SPEC Copywriting Contract
                    VStack(spacing: 8) {
                        Text("No results for \"\(viewModel.searchText)\"")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        Text("Try a different name or muscle group.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                } else if viewModel.loadError != nil {
                    // Load error state — UI-SPEC Copywriting Contract
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("Couldn't load exercises")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Check your connection and pull to refresh.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
        .task {
            await viewModel.loadExercises()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ExerciseLibraryView()
}
#endif
