import SwiftUI
import CoreData

// MARK: - ExerciseCardView
// Full-screen exercise card: fixed video player (top) + scrollable metadata + set rows.
//
// Layout (top to bottom):
//   1. VideoPlayerView (fixed, 16:9) — or ExercisePlaceholderView if no muxPlaybackId
//   2. ScrollView:
//      a. Exercise metadata (name, sets × reps)
//      b. SetLogRow rows with Dividers between them
//
// Video metadata is resolved asynchronously via ExerciseRepository.fetchByName(_:).
// Rep counts are local @State initialized from PlannedExercise.reps target.
//
// Requirements: SESS-01, SESS-02
// UI-SPEC: Phase 4 "ExerciseCardView — Full-Screen Exercise Card"

struct ExerciseCardView: View {
    let exercise: PlannedExercise
    let exerciseIndex: Int
    @Bindable var viewModel: SessionViewModel

    // Video metadata resolved by name lookup against CoreData exercise cache
    @State private var muxPlaybackId: String? = nil
    @State private var localAssetURL: URL? = nil

    @Environment(\.managedObjectContext) private var context

    // Per-set rep counts — initialized from exercise.reps target (e.g., "8-12" → 8, "10" → 10)
    @State private var repCounts: [Int]

    init(exercise: PlannedExercise, exerciseIndex: Int, viewModel: SessionViewModel) {
        self.exercise = exercise
        self.exerciseIndex = exerciseIndex
        self.viewModel = viewModel
        // Parse lower bound of rep range as the starting stepper value
        let defaultReps = Int(
            exercise.reps
                .split(separator: "-")
                .first
                .flatMap { Int(String($0)) }
                ?? Int(exercise.reps)
                ?? 8
        ) ?? 8
        _repCounts = State(initialValue: Array(repeating: defaultReps, count: exercise.sets))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Video area (fixed top, NOT in scroll view — prevents video scrolling out of sight)
            Group {
                if let pid = muxPlaybackId, !pid.isEmpty {
                    VideoPlayerView(muxPlaybackId: pid, localAssetURL: localAssetURL)
                        .aspectRatio(16 / 9, contentMode: .fit)
                } else {
                    ExercisePlaceholderView(exerciseName: exercise.exerciseName)
                        .aspectRatio(16 / 9, contentMode: .fit)
                }
            }

            // Scrollable area: metadata + set rows
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Exercise metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(.title2.weight(.semibold))
                        Text("\(exercise.sets) sets × \(exercise.reps) reps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    // Set log rows with dividers between (not after last)
                    ForEach(0..<exercise.sets, id: \.self) { setIndex in
                        let isCompleted = viewModel.completedSets[exerciseIndex]?[setIndex] != nil

                        SetLogRow(
                            setNumber: setIndex + 1,
                            targetReps: exercise.reps,
                            isCompleted: isCompleted,
                            repsLogged: $repCounts[setIndex],
                            onComplete: {
                                viewModel.completeSet(
                                    setIndex: setIndex,
                                    repsLogged: repCounts[setIndex]
                                )
                            }
                        )

                        if setIndex < exercise.sets - 1 {
                            Divider()
                        }
                    }

                    Spacer(minLength: 24)
                }
            }
        }
        // Async video lookup — runs when card appears; no spinner shown (placeholder handles empty state)
        .task { await lookupVideo() }
    }

    // MARK: - Video Lookup

    /// Resolves muxPlaybackId and localAssetURL from the CoreData Exercise cache by exercise name.
    /// Uses ExerciseRepository.fetchByName(_:) — case/diacritic insensitive match.
    /// Silently no-ops on miss (ExercisePlaceholderView is the fallback).
    private func lookupVideo() async {
        let repo = ExerciseRepository.shared
        guard let entity = try? repo.fetchByName(exercise.exerciseName) else { return }
        muxPlaybackId = entity.value(forKey: "muxPlaybackId") as? String
        if let urlStr = entity.value(forKey: "localAssetURL") as? String {
            localAssetURL = URL(string: urlStr)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let exercise = PlannedExercise(
        exerciseName: "Bench Press",
        sets: 3,
        reps: "8-12",
        restSeconds: 90,
        rationale: "Compound push movement"
    )
    let day = WorkoutDay(
        dayLabel: "Monday",
        sessionName: "Push Day",
        exercises: [exercise]
    )
    let vm = SessionViewModel(
        workoutDay: day,
        planId: "preview-plan",
        userId: "preview-user"
    )
    ExerciseCardView(exercise: exercise, exerciseIndex: 0, viewModel: vm)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
#endif
