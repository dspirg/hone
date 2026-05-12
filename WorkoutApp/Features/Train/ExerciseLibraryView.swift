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
// Navigation: NavigationLink pushes to ExerciseDetailView (wired in Plan 03).

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
                .listStyle(.plain)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .refreshable {
                await viewModel.loadExercises()
            }
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
