import SwiftUI

// MARK: - SessionView
// Root in-session container pushed from TrainView via NavigationStack.
//
// Layout:
//   - SessionProgressBar (top)
//   - ZStack of ExerciseCardViews offset by index × screen width (card slide nav)
//   - "Next Exercise" / "Finish Session" CTA button (bottom)
//   - RestTimerOverlay (ZStack layer — NOT fullScreenCover; preserves AVPlayer state)
//   - SyncFailureBanner (bottom, above rest area, when syncBannerVisible)
//
// Card transition: .spring(response: 0.4, dampingFraction: 0.85)
//   Reduced motion: .easeInOut(duration: 0.15) — detected via @Environment(\.accessibilityReduceMotion)
//
// Abandonment: confirmation alert required before dismiss (T-04-11).
// Session setup is async in .task — ProgressView shown until viewModel is ready.
//
// Requirements: SESS-01, SESS-02, SESS-03
// UI-SPEC: Phase 4 "SessionView — Root Session Container"

struct SessionView: View {
    let workoutDay: WorkoutDay
    let planId: String

    @Environment(AppState.self) var appState
    @Environment(AdaptationService.self) var adaptationService
    @Environment(\.managedObjectContext) var context
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: SessionViewModel?
    @State private var syncService: SessionSyncService?
    @State private var showAbandonAlert = false

    var body: some View {
        Group {
            if let vm = viewModel {
                sessionContent(vm: vm)
            } else {
                ProgressView()
                    .task { await setupSession() }
            }
        }
        // Back button hidden — abandonment requires confirmation alert (T-04-11)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showAbandonAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel("End session")
                }
            }
        }
        // T-04-11: confirmation required before dismiss — prevents accidental session loss
        .alert("End this session?", isPresented: $showAbandonAlert) {
            Button("End Session", role: .destructive) { dismiss() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: - Session Content

    @ViewBuilder
    private func sessionContent(vm: SessionViewModel) -> some View {
        // Session complete — replace card area with summary screen
        if vm.isSessionComplete {
            SessionSummaryView(
                workoutDayLabel: vm.workoutDay.dayLabel,
                totalExercises: vm.exercises.count,
                totalSets: vm.completedSets.values.reduce(0) { $0 + $1.count },
                totalReps: vm.completedSets.values.flatMap { $0.values }.reduce(0, +),
                duration: vm.sessionDuration,
                prs: vm.detectedPRs,
                onDone: { rating in
                    vm.saveDifficultyRating(rating)
                    // Phase 8 ADPT-01: trigger post-session adaptation with the captured rating.
                    // Fire-and-forget — dismiss is not blocked on the network call.
                    Task {
                        await adaptationService.requestPostSessionAdaptation(rating: rating)
                    }
                    dismiss()
                }
            )
        } else {
            // Card transition: spring for normal, easeInOut(0.15) for reduce motion
            let animation: Animation = reduceMotion
                ? .easeInOut(duration: 0.15)
                : .spring(response: 0.4, dampingFraction: 0.85)

            ZStack(alignment: .bottom) {
                // App background
                Color("AppBackground").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar — "Exercise N of M" + segmented capsules
                    SessionProgressBar(
                        current: vm.currentExerciseIndex + 1,
                        total: vm.exercises.count
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // Exercise cards ZStack with horizontal offset slide navigation
                    // UIScreen.main.bounds.width offset per RESEARCH.md Pattern 7 and UI-SPEC
                    ZStack {
                        ForEach(Array(vm.exercises.enumerated()), id: \.offset) { index, exercise in
                            ExerciseCardView(
                                exercise: exercise,
                                exerciseIndex: index,
                                viewModel: vm
                            )
                            .offset(x: CGFloat(index - vm.currentExerciseIndex) * UIScreen.main.bounds.width)
                        }
                    }
                    .animation(animation, value: vm.currentExerciseIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // "Next Exercise" / "Finish Session" CTA button
                    let isLast = vm.currentExerciseIndex == vm.exercises.count - 1
                    Button(isLast ? "Finish Session" : "Next Exercise") {
                        vm.advanceExercise()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .accessibilityLabel(isLast ? "Finish Session" : "Next Exercise")
                }

                // Rest timer overlay — ZStack layer (NOT fullScreenCover) so AVPlayer stays alive beneath
                // RESEARCH.md Pitfall 2: fullScreenCover pauses AVPlayer; ZStack overlay does not
                if vm.isRestTimerActive, let endDate = vm.timerEndDate {
                    RestTimerOverlay(
                        endDate: endDate,
                        nextContextLabel: vm.nextContextLabel,
                        onSkip: { vm.skipRest() },
                        onExtend: { vm.extendRest() },
                        onExpired: { vm.handleTimerExpired() }
                    )
                    .transition(.opacity)
                }

                // Sync failure banner — bottom, shown after 3 failed sync retries
                if let sync = syncService, sync.syncBannerVisible {
                    SyncFailureBanner()
                        .padding(.bottom, 8)
                }
            }
            .task {
                syncService?.startMonitoring()
            }
            .onDisappear {
                syncService?.stopMonitoring()
            }
        }
    }

    // MARK: - Session Setup

    /// Initializes SessionViewModel and SessionSyncService on first appearance.
    /// Non-blocking: ProgressView shown until this completes.
    private func setupSession() async {
        let userId = appState.currentUser?.id.uuidString ?? ""
        let repo = SessionRepository(
            context: context,
            container: PersistenceController.shared.container
        )
        let vm = SessionViewModel(
            workoutDay: workoutDay,
            planId: planId,
            userId: userId,
            repository: repo
        )
        vm.startSession()
        viewModel = vm

        let sync = SessionSyncService(repository: repo)
        syncService = sync
    }
}

// MARK: - Sync Failure Banner

/// Compact inline banner shown when SessionSyncService.syncBannerVisible is true.
/// Auto-hides on successful reconnect sync. Not user-dismissable.
/// UI-SPEC: Phase 4 "Sync Failure Banner"
private struct SyncFailureBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.subheadline)
            Text("Couldn't sync your session. Will retry.")
                .font(.subheadline)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
}
