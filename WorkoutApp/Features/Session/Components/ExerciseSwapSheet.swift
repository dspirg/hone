import SwiftUI
import CoreData
import Supabase

/// Sheet for substituting an exercise with an alternative from the same muscle group.
/// Shows exercises that have videos, grouped by relevance.
struct ExerciseSwapSheet: View {
    let currentExercise: PlannedExercise
    let onSwap: (PlannedExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var alternatives: [ExerciseModel] = []
    @State private var searchText = ""
    @State private var isLoading = true

    var filtered: [ExerciseModel] {
        if searchText.isEmpty { return alternatives }
        return alternatives.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No alternatives found")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(filtered) { exercise in
                        Button {
                            let replacement = PlannedExercise(
                                exerciseName: exercise.name,
                                sets: currentExercise.sets,
                                reps: currentExercise.reps,
                                restSeconds: currentExercise.restSeconds,
                                rationale: "Substituted for \(currentExercise.exerciseName)"
                            )
                            onSwap(replacement)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                // Thumbnail
                                AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    default:
                                        Theme.surface
                                            .overlay {
                                                Text(String(exercise.name.prefix(1)).uppercased())
                                                    .font(.body.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        Text(exercise.primaryMuscle)
                                            .font(.caption)
                                            .foregroundStyle(Theme.accent)
                                        Text(exercise.equipmentTag)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundStyle(Theme.accent)
                                    .font(.caption)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadAlternatives()
        }
    }

    private func loadAlternatives() async {
        // Look up muscle group of current exercise
        let repo = ExerciseRepository.shared
        var muscleGroup: String?
        if let entity = try? repo.fetchByName(currentExercise.exerciseName) ?? repo.fetchByNameContains(currentExercise.exerciseName) {
            muscleGroup = entity.value(forKey: "primaryMuscle") as? String
        }

        // Query Supabase for exercises in same muscle group with videos
        struct ExRow: Decodable {
            let name: String
            let primaryMuscle: String
            let equipmentTag: String
            let difficulty: String
            let thumbnailUrl: String?
            enum CodingKeys: String, CodingKey {
                case name
                case primaryMuscle = "primary_muscle"
                case equipmentTag = "equipment_tag"
                case difficulty
                case thumbnailUrl = "thumbnail_url"
            }
        }

        do {
            let rows: [ExRow]
            if let mg = muscleGroup {
                rows = try await supabase
                    .from("exercises")
                    .select("name, primary_muscle, equipment_tag, difficulty, thumbnail_url")
                    .not("video_url", operator: .is, value: "null")
                    .ilike("primary_muscle", pattern: mg)
                    .order("name")
                    .limit(50)
                    .execute()
                    .value
            } else {
                rows = try await supabase
                    .from("exercises")
                    .select("name, primary_muscle, equipment_tag, difficulty, thumbnail_url")
                    .not("video_url", operator: .is, value: "null")
                    .order("name")
                    .limit(50)
                    .execute()
                    .value
            }

            alternatives = rows
                .filter { $0.name != currentExercise.exerciseName }
                .map {
                    ExerciseModel(
                        id: UUID(),
                        name: $0.name,
                        primaryMuscle: $0.primaryMuscle,
                        equipmentTag: $0.equipmentTag,
                        difficulty: $0.difficulty,
                        howToSteps: [],
                        formTips: nil,
                        muxPlaybackId: nil,
                        thumbnailURL: $0.thumbnailUrl,
                        localAssetURL: nil,
                        lastViewedAt: nil
                    )
                }
        } catch {
            // Silent failure
        }

        isLoading = false
    }
}
