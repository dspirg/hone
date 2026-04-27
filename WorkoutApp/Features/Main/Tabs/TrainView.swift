import SwiftUI
import CoreData

// MARK: - TrainView
// Train tab root — shows the user's active workout plan as per-day cards with "Start Workout" entry points.
// Replaced Phase 2 ExerciseLibraryView-only host with plan-first layout.
//
// Layout:
//   - Active plan: one WorkoutDayCard per day with "Start Workout" NavigationLink to SessionView
//   - Browse Exercises: NavigationLink to ExerciseLibraryView (Phase 2, preserved)
//   - Empty state: shown when no active plan found (unexpected post-Phase-3 state)
//
// Plan loading: mirrors HomeView.swift pattern — WorkoutPlanRepository.fetchActivePlan in .task
// supabaseId: fetched from CDWorkoutPlan via NSPredicate for use as planId in SessionView
//
// UI-SPEC: Phase 4 "TrainView entry point" and "Empty state — no active plan"
// Requirements: SESS-01

struct TrainView: View {
    @Environment(AppState.self) var appState
    @Environment(AdaptationService.self) var adaptationService
    @State private var activePlan: WorkoutPlan?
    @State private var activePlanSupabaseId: String = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // D-05: Show adjustment summary when plan was recently adapted.
                    // Fades in after adaptation — builds trust by explaining changes.
                    if let summary = adaptationService.lastAdjustmentSummary {
                        AdaptationSummaryBanner(summary: summary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity)
                    }

                    if isLoading {
                        ProgressView()
                            .padding(.top, 48)
                    } else if let plan = activePlan {
                        // Active plan day cards — one per WorkoutDay
                        ForEach(plan.weeklyDays) { day in
                            WorkoutDayCard(day: day, planId: activePlanSupabaseId)
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        // Browse Exercises (Phase 2 preserved)
                        NavigationLink(destination: ExerciseLibraryView()) {
                            HStack {
                                Label("Browse Exercises", systemImage: "list.bullet")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)

                    } else {
                        // Empty state — unexpected post-Phase-3 state
                        // UI-SPEC Copywriting Contract: exact copy below
                        VStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No workout planned for today.")
                                .font(.body)
                            Text("Your AI plan appears here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 48)

                        // Still offer exercise browsing in empty state
                        NavigationLink(destination: ExerciseLibraryView()) {
                            HStack {
                                Label("Browse Exercises", systemImage: "list.bullet")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("Train")
            .task {
                await loadActivePlan()
            }
        }
    }

    // MARK: - Data Loading

    private func loadActivePlan() async {
        guard let userId = appState.currentUser?.id.uuidString else {
            isLoading = false
            return
        }
        do {
            let repo = WorkoutPlanRepository()
            activePlan = try repo.fetchActivePlan(userId: userId)

            // Fetch supabaseId from CDWorkoutPlan — needed as planId when launching SessionView
            let viewContext = PersistenceController.shared.container.viewContext
            let cdReq = CDWorkoutPlan.fetchRequest()
            cdReq.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
            cdReq.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            cdReq.fetchLimit = 1
            if let cdPlan = try? viewContext.fetch(cdReq).first {
                activePlanSupabaseId = cdPlan.supabaseId ?? ""
            }
        } catch {
            // Silently fail — show empty state
        }
        isLoading = false
    }
}

// MARK: - WorkoutDayCard

/// Card showing one WorkoutDay with a "Start Workout" NavigationLink to SessionView.
/// UI-SPEC: dayLabel (.title2 semibold), sessionName + exercise count (.subheadline .secondary),
/// "Start Workout" button (.borderedProminent, full width within card).
private struct WorkoutDayCard: View {
    let day: WorkoutDay
    let planId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.dayLabel)
                    .font(.title2.weight(.semibold))
                Text(day.sessionName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(day.exercises.count) exercises")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                SessionView(workoutDay: day, planId: planId)
            } label: {
                Text("Start Workout")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

// MARK: - AdaptationSummaryBanner

/// Brief AI rationale shown in TrainView after plan adaptation (D-05).
/// "Increased weight — you rated last 3 sessions as too easy." — builds trust without clutter.
private struct AdaptationSummaryBanner: View {
    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HoneAvatarView(diameter: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hone")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
