import SwiftUI
import CoreData

// MARK: - ExerciseCardView
// Full-screen exercise card: compact 2:1 video player (top) + scrollable metadata + set rows.
//
// Layout (top to bottom):
//   1. VideoPlayerView (fixed, 2:1) — or ExercisePlaceholderView if no muxPlaybackId
//      - Tap-to-expand opens VideoOverlayView via fullScreenCover (D-06)
//   2. ScrollView:
//      a. Exercise metadata (name, muscle group, equipment, set counter)
//      b. SetLogRow rows with Dividers between them
//      c. ContextCardView pair: Previous/Best reps (D-07)
//
// Video metadata is resolved asynchronously via ExerciseRepository.fetchByName(_:).
// Rep counts are local @State initialized from PlannedExercise.reps target.
// Context cards reload per exercise via .task(id: exerciseIndex) (RESEARCH Pitfall 1).
//
// Requirements: SESS-01, SESS-02
// UI-SPEC: Phase 11 "ExerciseCardView — Compact 2:1 Video Layout" (D-06, D-07)

struct ExerciseCardView: View {
    let exercise: PlannedExercise
    let exerciseIndex: Int
    @Bindable var viewModel: SessionViewModel

    // Video metadata resolved by name lookup against CoreData exercise cache
    @State private var muxPlaybackId: String? = nil
    @State private var localAssetURL: URL? = nil
    @State private var videoUrl: String? = nil

    // D-06: Tap-to-expand video overlay
    @State private var showVideoOverlay = false

    // D-07: Previous/Best context cards
    @State private var previousReps: Int? = nil
    @State private var bestReps: Int? = nil

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
            // D-06: 2:1 aspect ratio, tap-to-expand via fullScreenCover
            Group {
                if let pid = muxPlaybackId, !pid.isEmpty {
                    VideoPlayerView(muxPlaybackId: pid, localAssetURL: localAssetURL)
                        .aspectRatio(2 / 1, contentMode: .fit)
                } else if let urlStr = videoUrl,
                          let url = URL(string: urlStr.replacingOccurrences(of: " ", with: "%20")) {
                    VideoPlayerView(muxPlaybackId: "", localAssetURL: url)
                        .aspectRatio(2 / 1, contentMode: .fit)
                } else {
                    ExercisePlaceholderView(exerciseName: exercise.exerciseName)
                        .aspectRatio(2 / 1, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(12)
            }
            .padding(.horizontal, 20)
            .onTapGesture { showVideoOverlay = true }
            .fullScreenCover(isPresented: $showVideoOverlay) {
                VideoOverlayView(
                    muxPlaybackId: muxPlaybackId ?? "",
                    exerciseName: exercise.exerciseName
                )
            }

            // Scrollable area: metadata + set rows + context cards
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Exercise info row (D-06 updated layout)
                    // Note: PlannedExercise has no muscleGroup/equipment fields — show sets×reps as subtitle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.exerciseName)
                                .font(.title2.weight(.semibold))
                            Text("\(exercise.sets) sets × \(exercise.reps) reps")
                                .font(.body)
                                .foregroundStyle(Theme.accent)
                        }
                        Spacer()
                        Text("Set \(completedSetCount + 1) of \(exercise.sets)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

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

                    // Context cards (D-07) — Previous and Best reps
                    HStack(spacing: Theme.Spacing.sm) {
                        ContextCardView(
                            label: "Previous",
                            value: previousReps.map { "\($0) reps" } ?? "---"
                        )
                        ContextCardView(
                            label: "Best",
                            value: bestReps.map { "\($0) reps" } ?? "---",
                            valueColor: Theme.accent
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, Theme.Spacing.sm)

                    Spacer(minLength: 24)
                }
            }
        }
        // RESEARCH Pitfall 1: .task(id:) reruns when exerciseIndex changes (not just on appear)
        // This ensures context data reloads when sliding to a different exercise card
        .task(id: exerciseIndex) {
            await lookupVideo()
            await loadContextData()
        }
    }

    // MARK: - Computed

    private var completedSetCount: Int {
        viewModel.completedSets[exerciseIndex]?.count ?? 0
    }

    // MARK: - Video Lookup

    /// Resolves muxPlaybackId and localAssetURL from the CoreData Exercise cache by exercise name.
    /// Uses ExerciseRepository.fetchByName(_:) — case/diacritic insensitive match.
    /// Silently no-ops on miss (ExercisePlaceholderView is the fallback).
    private func lookupVideo() async {
        let repo = ExerciseRepository.shared
        guard let entity = try? repo.fetchByName(exercise.exerciseName) else { return }
        muxPlaybackId = entity.value(forKey: "muxPlaybackId") as? String
        videoUrl = entity.value(forKey: "videoUrl") as? String
        if let urlStr = entity.value(forKey: "localAssetURL") as? String {
            localAssetURL = URL(string: urlStr)
        }
    }

    // MARK: - Context Data (D-07)

    /// Loads previous and best reps from CoreData for the context cards.
    /// Silently fails — context cards show "---" on any error (T-11-05).
    private func loadContextData() async {
        let repo = SessionRepository()
        let userId = viewModel.userId
        guard !userId.isEmpty else { return }
        let sessionId = viewModel.sessionLogId
        do {
            previousReps = try repo.fetchPreviousReps(
                exerciseName: exercise.exerciseName,
                excludingSessionId: sessionId,
                userId: userId
            )
            bestReps = try repo.fetchBestReps(
                exerciseName: exercise.exerciseName,
                userId: userId
            )
        } catch {
            // Silently fail — show "---" in context cards (T-11-05)
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
