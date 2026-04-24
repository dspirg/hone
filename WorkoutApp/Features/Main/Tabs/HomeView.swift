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
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let plan = activePlan {
                        if appState.isSubscribed {
                            planCard(plan: plan)
                        } else {
                            // D-14: Blurred plan preview for expired/lapsed users
                            // D-15: Tap triggers paywall
                            BlurredPlanGateView(showPaywall: $showPaywall) {
                                planCard(plan: plan)
                            }
                        }
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
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Plan Card

    @ViewBuilder
    private func planCard(plan: WorkoutPlan) -> some View {
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
