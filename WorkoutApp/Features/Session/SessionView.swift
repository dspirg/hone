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
    /// When provided, resumes an existing session instead of creating a new one
    var existingViewModel: SessionViewModel? = nil
    /// Called when user explicitly ends the session (not minimize)
    var onEndSession: (() -> Void)? = nil
    /// Called when a new session VM is created, so parent can hold a reference for resume
    var onSessionCreated: ((SessionViewModel) -> Void)? = nil

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
                Theme.background.ignoresSafeArea()
                ProgressView()
                    .task { await setupSession() }
            }
        }
        .alert("What would you like to do?", isPresented: $showAbandonAlert) {
            Button("Minimize") { dismiss() }
            Button("End Session", role: .destructive) {
                onEndSession?()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Minimize keeps your progress. End Session discards it.")
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
                    Task {
                        await adaptationService.requestPostSessionAdaptation(rating: rating)
                    }
                    onEndSession?()  // Clear activeSessionVM — session is fully complete
                    appState.selectedTab = 0
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
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Exercise navigation bar: prev | progress | next | X
                    HStack(spacing: 8) {
                        Button {
                            vm.goToExercise(vm.currentExerciseIndex - 1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(vm.currentExerciseIndex > 0 ? .primary : .quaternary)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(vm.currentExerciseIndex == 0)

                        SessionProgressBar(
                            current: vm.currentExerciseIndex + 1,
                            total: vm.exercises.count
                        )

                        Button {
                            vm.goToExercise(vm.currentExerciseIndex + 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(vm.currentExerciseIndex < vm.exercises.count - 1 ? .primary : .quaternary)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(vm.currentExerciseIndex >= vm.exercises.count - 1)

                        Button {
                            showAbandonAlert = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Theme.surfaceElevated)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Session options")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // Exercise cards ZStack with horizontal offset slide navigation.
                    // WR-05: Use GeometryReader instead of deprecated UIScreen.main.bounds.width
                    // which returns incorrect values on Stage Manager and future window layouts.
                    GeometryReader { geometry in
                        ZStack {
                            ForEach(Array(vm.exercises.enumerated()), id: \.offset) { index, exercise in
                                ExerciseCardView(
                                    exercise: exercise,
                                    exerciseIndex: index,
                                    viewModel: vm
                                )
                                .offset(x: CGFloat(index - vm.currentExerciseIndex) * geometry.size.width)
                            }
                        }
                        .animation(animation, value: vm.currentExerciseIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Context-aware CTA (D-09): three states based on set completion progress
                    let ctaLabel = computeCtaLabel(vm: vm)
                    let isCompleteSetAction = ctaLabel == "Complete Set"

                    Button(ctaLabel) {
                        if isCompleteSetAction {
                            vm.completeCurrentSet()
                        } else {
                            vm.advanceExercise()
                        }
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(isCompleteSetAction ? .black : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        isCompleteSetAction || ctaLabel == "Finish Session"
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Theme.accent, Color(red: 249/255, green: 115/255, blue: 22/255)],
                                startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Theme.surface)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        if !isCompleteSetAction && ctaLabel != "Finish Session" {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.accent, lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                    .accessibilityLabel(ctaLabel)
                    .animation(.default, value: ctaLabel)
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

    // MARK: - CTA Logic (D-09)

    /// Returns the context-aware CTA label based on current set completion state.
    /// - "Complete Set": sets remain for the current exercise
    /// - "Next Exercise": all sets done, more exercises remain
    /// - "Finish Session": all sets done on the last exercise
    private func computeCtaLabel(vm: SessionViewModel) -> String {
        guard let currentExercise = vm.currentExercise else { return "Next Exercise" }
        let completedCount = vm.completedSets[vm.currentExerciseIndex]?.count ?? 0
        let allSetsComplete = completedCount >= currentExercise.sets
        let isLastExercise = vm.currentExerciseIndex == vm.exercises.count - 1

        if !allSetsComplete { return "Complete Set" }
        else if isLastExercise { return "Finish Session" }
        else { return "Next Exercise" }
    }

    // MARK: - Session Setup

    /// Initializes SessionViewModel and SessionSyncService on first appearance.
    /// Non-blocking: ProgressView shown until this completes.
    private func setupSession() async {
        // Resume existing session if provided (minimize/resume flow)
        if let existing = existingViewModel {
            viewModel = existing
            let repo = SessionRepository(
                context: context,
                container: PersistenceController.shared.container
            )
            syncService = SessionSyncService(repository: repo)
            return
        }

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
        await vm.startSession()   // CR-02: await ensures sessionLog is set before view is shown
        viewModel = vm
        onSessionCreated?(vm)

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
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
}
