import SwiftUI

// MARK: - HomeView
// Displays the user's active workout plan summary after onboarding completes.
// Loads the active plan from CoreData via WorkoutPlanRepository on appear.
// D-05: Plan summary card — plan name, goal summary, training day count.
// Empty state shown if no active plan found (unexpected post-onboarding state).
struct HomeView: View {
    @Environment(AppState.self) var appState
    @State private var activePlan: WorkoutPlan?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let plan = activePlan {
                        // Plan summary card — D-05: plan name (.title2 semibold) + goal summary (.body secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(plan.planName)
                                .font(.title2.weight(.semibold))

                            Text(plan.goalSummary)
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Text("\(plan.weeklyDays.count) training days this week")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    } else if isLoading {
                        ProgressView()
                            .padding(.top, 48)
                    } else {
                        // No plan state (unexpected post-onboarding)
                        VStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No active plan")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 48)
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("Home")
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
        } catch {
            // Silently fail — show empty state
        }
        isLoading = false
    }
}
