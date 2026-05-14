import SwiftUI
import CoreData

// MARK: - HomeView
// Full rebuild matching Sketch 001-A card-stack layout.
//
// Sections (top-to-bottom):
//   1. Greeting (D-01, D-02) — time-of-day prefix + user name in accent
//   2. Adaptation banner (D-03) — conditional on AdaptationService within 24h
//   3. Today's Workout card (D-01, D-04) — exercise rows + Start Workout CTA
//   4. This Week streak bar (D-01) — 7 locale-safe day tiles
//   5. Quick Stats row (D-05) — Sessions / Sets / PRs stat pills
//
// Session launch: fullScreenCover (D-13, D-16)
// Post-session refresh: onChange(of: viewModel.showSession) (D-14)
// Subscription gate: BlurredPlanGateView preserved for non-subscribed users
// Error/empty states: pull-to-refresh via .refreshable
//
// Requirements: UI-04
// Threat mitigations:
//   T-11-03: data scoped to current user via HomeViewModel.load
//   T-11-04: session launch reuses existing AppState auth guard

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(AdaptationService.self) var adaptationService
    @Environment(\.managedObjectContext) var context
    @State private var viewModel = HomeViewModel()
    @State private var showPaywall = false
    @State private var showTimePicker = false
    @State private var pendingSessionDay: WorkoutDay? = nil
    @State private var swapTarget: SwapTarget? = nil

    struct SwapTarget: Identifiable {
        let dayLabel: String
        let exerciseIndex: Int
        let exercise: PlannedExercise
        var id: String { "\(dayLabel)-\(exerciseIndex)" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // GREETING SECTION (D-01, D-02)
                    greetingSection
                        .padding(.top, Theme.Spacing.md)  // 16pt
                        .padding(.horizontal, 20)

                    // ADAPTATION BANNER (D-03, conditional)
                    if let banner = viewModel.adaptationBanner {
                        AdaptationBannerView(rationale: banner)
                            .padding(.top, Theme.Spacing.md)
                    }

                    // RESUME WORKOUT banner (visible when session was minimized)
                    if appState.activeSessionVM != nil && !appState.showSession {
                        Button {
                            appState.showSession = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Workout in progress")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Tap to resume")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.15), Theme.accent.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, Theme.Spacing.md)
                    }

                    // TODAY'S WORKOUT section (D-01, D-04)
                    if let plan = viewModel.activePlan, let day = viewModel.todayWorkoutDay {
                        sectionLabel("TODAY'S WORKOUT")
                            .padding(.top, Theme.Spacing.lg)  // 24pt

                        if appState.isSubscribed {
                            workoutCard(plan: plan, day: day)
                        } else {
                            // CRITICAL: preserve subscription gate (BlurredPlanGateView)
                            BlurredPlanGateView(showPaywall: $showPaywall) {
                                workoutCard(plan: plan, day: day)
                            }
                        }
                    }

                    // THIS WEEK section
                    sectionLabel("THIS WEEK")
                        .padding(.top, Theme.Spacing.lg)
                    streakCard

                    // QUICK STATS section (D-05)
                    sectionLabel("QUICK STATS")
                        .padding(.top, Theme.Spacing.lg)
                    quickStatsRow

                    // BROWSE EXERCISES shortcut
                    NavigationLink(destination: ExerciseLibraryView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.title3)
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Browse Exercises")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("Explore the full exercise library")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [Theme.accent, Color(red: 0.486, green: 0.227, blue: 0.929)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, Theme.Spacing.lg)

                    Spacer().frame(height: Theme.Spacing.xl)  // 32pt bottom padding
                }
            }
            .refreshable {
                await viewModel.load(appState: appState, adaptationService: adaptationService, context: context)
            }
            .overlay {
                // Loading and error/empty states
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 48)
                } else if viewModel.loadError != nil && viewModel.activePlan == nil {
                    errorState
                } else if !viewModel.isLoading && viewModel.activePlan == nil {
                    emptyState
                }
            }
            .task {
                await viewModel.load(appState: appState, adaptationService: adaptationService, context: context)
            }
            // D-14: Reload stats after session dismiss
            .onChange(of: appState.showSession) { _, isShowing in
                if !isShowing {
                    Task {
                        await viewModel.load(appState: appState, adaptationService: adaptationService, context: context)
                    }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
            // Session launch via fullScreenCover (shared via AppState)
            .fullScreenCover(isPresented: Bindable(appState).showSession) {
                if let day = appState.activeSessionDay {
                    SessionView(
                        workoutDay: day,
                        planId: appState.activeSessionPlanId,
                        existingViewModel: appState.activeSessionVM,
                        onEndSession: {
                            appState.activeSessionVM = nil
                            appState.activeSessionDay = nil
                        },
                        onSessionCreated: { vm in
                            appState.activeSessionVM = vm
                        }
                    )
                    .environment(\.managedObjectContext, context)
                    .environment(adaptationService)
                    .environment(appState)
                }
            }
            .sheet(isPresented: $showTimePicker) {
                SessionTimePicker { minutes in
                    showTimePicker = false
                    if let day = pendingSessionDay {
                        appState.activeSessionDay = day
                        appState.activeSessionPlanId = viewModel.activePlanId
                        appState.sessionMinutesOverride = minutes
                        appState.showSession = true
                    }
                }
                .presentationDetents([.height(320)])
            }
        }
    }

    // MARK: - Greeting (D-01, D-02)

    @ViewBuilder
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.timeOfDayGreeting)
                .font(.body)
                .foregroundStyle(.secondary)
            if let name = appState.currentUser?.userMetadata["display_name"]?.stringValue
                ?? appState.currentUser?.email?.components(separatedBy: "@").first,
               !name.isEmpty {
                (Text("Hey ") + Text(name.capitalized).foregroundColor(Theme.accent))
                    .font(.largeTitle.bold())
            } else {
                Text("Hey there")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.08 * 11)  // 0.08em at 11pt
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    // MARK: - Workout Card (D-01, D-04)

    @ViewBuilder
    private func workoutCard(plan: WorkoutPlan, day: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Session name + day label
            HStack {
                Text(day.sessionName)
                    .font(.title2.weight(.bold))
                Spacer()
                Text(day.dayLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }

            // Exercise count
            Text("\(day.exercises.count) exercises")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Tap swap to replace with a similar movement")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()

            // Exercise rows with dividers (D-04: 40x40 thumbnails via HomeExerciseRowView)
            ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, exercise in
                HomeExerciseRowView(exercise: exercise) {
                    swapTarget = SwapTarget(dayLabel: day.dayLabel, exerciseIndex: index, exercise: exercise)
                }
                if index < day.exercises.count - 1 {
                    Divider()
                }
            }

            // Start Workout CTA (D-13)
            Button {
                pendingSessionDay = day
                showTimePicker = true
            } label: {
                Text("Start Workout")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Color(red: 0.486, green: 0.227, blue: 0.929)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 4)
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(20)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, Theme.Spacing.sm)
        // Swap sheet attached to workout card — avoids conflict with time picker and session sheets
        .sheet(item: $swapTarget) { target in
            ExerciseSwapSheet(currentExercise: target.exercise) { replacement in
                Task {
                    await viewModel.swapExercise(
                        dayLabel: target.dayLabel,
                        exerciseIndex: target.exerciseIndex,
                        replacement: replacement,
                        appState: appState,
                        adaptationService: adaptationService,
                        context: context
                    )
                }
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            WeekStreakBar(
                completedDates: viewModel.completedDatesThisWeek,
                currentStreak: viewModel.currentStreak
            )
        }
        .padding(20)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.borderSubtle, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Quick Stats (D-05)

    private var quickStatsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            StatPillView(label: "Sessions", value: "\(viewModel.totalSessions)", valueColor: Theme.accent)
            StatPillView(label: "Sets", value: "\(viewModel.totalSets)")
            StatPillView(label: "PRs", value: "\(viewModel.totalPRs)", valueColor: Theme.successGreen)
        }
        .padding(.horizontal, 20)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No workout scheduled")
                .font(.title2.weight(.semibold))
            Text("Your plan will appear here after onboarding.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Couldn't load your workout")
                .font(.title2.weight(.semibold))
            Text("Check your connection and pull down to retry.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
