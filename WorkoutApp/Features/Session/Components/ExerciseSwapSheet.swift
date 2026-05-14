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
    @State private var currentEquipment: String = ""
    @State private var searchText = ""
    @State private var isLoading = true

    private var filtered: [ExerciseModel] {
        if searchText.isEmpty { return alternatives }
        return alternatives.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Top 5 suggestions: prioritize same equipment (closest substitute), then same difficulty.
    private var suggested: [ExerciseModel] {
        let pool = filtered
        let ranked = pool.sorted { a, b in
            let aEquip = a.equipmentTag == currentEquipment
            let bEquip = b.equipmentTag == currentEquipment
            if aEquip != bEquip { return aEquip }
            return a.name < b.name
        }
        return Array(ranked.prefix(5))
    }

    /// Everything after the top 5.
    private var moreOptions: [ExerciseModel] {
        let suggestedIds = Set(suggested.map(\.id))
        return filtered.filter { !suggestedIds.contains($0.id) }
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
                    List {
                        if !suggested.isEmpty {
                            Section {
                                ForEach(suggested) { exercise in
                                    swapRow(exercise: exercise)
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Theme.accent)
                                    Text("Suggested")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .textCase(nil)
                            }
                        }

                        if !moreOptions.isEmpty {
                            Section {
                                ForEach(moreOptions) { exercise in
                                    swapRow(exercise: exercise)
                                }
                            } header: {
                                Text("More Options")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
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

    private func swapRow(exercise: ExerciseModel) -> some View {
        SwapRowView(
            exercise: exercise,
            currentExercise: currentExercise,
            onSwap: onSwap,
            dismiss: dismiss
        )
    }

    private func loadAlternatives() async {
        // Look up muscle group of current exercise — try CoreData first, then Supabase
        let repo = ExerciseRepository.shared
        var muscleGroup: String?
        if let entity = try? repo.fetchByName(currentExercise.exerciseName) ?? repo.fetchByNameContains(currentExercise.exerciseName) {
            muscleGroup = entity.value(forKey: "primaryMuscle") as? String
            currentEquipment = (entity.value(forKey: "equipmentTag") as? String) ?? ""
        }

        // Supabase fallback for muscle group + equipment lookup when CoreData name doesn't match
        if muscleGroup == nil {
            struct LookupRow: Decodable {
                let primaryMuscle: String
                let equipmentTag: String
                enum CodingKeys: String, CodingKey {
                    case primaryMuscle = "primary_muscle"
                    case equipmentTag = "equipment_tag"
                }
            }
            if let rows: [LookupRow] = try? await supabase
                .from("exercises")
                .select("primary_muscle, equipment_tag")
                .ilike("name", pattern: "%\(currentExercise.exerciseName)%")
                .limit(1)
                .execute()
                .value,
               let first = rows.first {
                muscleGroup = first.primaryMuscle
                currentEquipment = first.equipmentTag
            }
        }

        // Query Supabase for exercises in same muscle group with videos
        struct ExRow: Decodable {
            let name: String
            let primaryMuscle: String
            let equipmentTag: String
            let difficulty: String
            let thumbnailUrl: String?
            let videoUrl: String?
            let muxPlaybackId: String?
            enum CodingKeys: String, CodingKey {
                case name
                case primaryMuscle = "primary_muscle"
                case equipmentTag = "equipment_tag"
                case difficulty
                case thumbnailUrl = "thumbnail_url"
                case videoUrl = "video_url"
                case muxPlaybackId = "mux_playback_id"
            }
        }

        do {
            // Always filter by muscle group — don't show unrelated exercises
            guard let mg = muscleGroup else {
                isLoading = false
                return
            }

            let rows: [ExRow] = try await supabase
                .from("exercises")
                .select("name, primary_muscle, equipment_tag, difficulty, thumbnail_url, video_url, mux_playback_id")
                .not("video_url", operator: .is, value: "null")
                .ilike("primary_muscle", pattern: mg)
                .order("name")
                .limit(50)
                .execute()
                .value

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
                        muxPlaybackId: $0.muxPlaybackId,
                        thumbnailURL: $0.thumbnailUrl,
                        videoUrl: $0.videoUrl,
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

// MARK: - SwapRowView
// Extracted to own struct so each row can hold @State for video presentation.

private struct SwapRowView: View {
    let exercise: ExerciseModel
    let currentExercise: PlannedExercise
    let onSwap: (PlannedExercise) -> Void
    let dismiss: DismissAction

    @State private var showVideo = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail — tap to preview video
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
            .overlay(alignment: .center) {
                if exercise.hasVideo {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .onTapGesture {
                guard exercise.hasVideo else { return }
                showVideo = true
            }

            // Exercise info + swap button — tap to swap
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
                HStack {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .fullScreenCover(isPresented: $showVideo) {
            VideoOverlayView(
                muxPlaybackId: exercise.muxPlaybackId ?? "",
                exerciseName: exercise.name,
                videoUrl: exercise.videoUrl
            )
        }
    }
}
