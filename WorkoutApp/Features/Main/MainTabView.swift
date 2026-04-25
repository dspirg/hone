import SwiftUI
import CoreData

// MARK: - MainTabView
// D-04: 5-tab shell — Home, Train, Coach, Progress, Profile
// Active tab accent tint via .tint(Color("AccentColor")) (UI-SPEC)
//
// Phase 8: AdaptationService injected here (same pattern as SessionSyncService in SessionView).
// scenePhase observer triggers checkOnForeground on every app foreground:
//   - Weekly plan regeneration on Monday mornings (ADPT-02, D-04)
//   - Missed session detection + adaptation (ADPT-03, D-07)
// AdaptationService is passed down via @Environment so SessionView can trigger
// post-session adaptation without needing a separate init path.

struct MainTabView: View {
    @Environment(AppState.self) var appState
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.managedObjectContext) var context

    @State private var adaptationService = AdaptationService()

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            TrainView()
                .tabItem {
                    Label("Train", systemImage: "figure.strengthtraining.traditional")
                }

            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "message")
                }

            WorkoutProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        // Active tab icon + label tint (UI-SPEC Color Token: Accent)
        .tint(Color("AccentColor"))
        // Inject AdaptationService for SessionView post-session trigger (ADPT-01)
        .environment(adaptationService)
        // Foreground check: weekly regen + missed session detection (ADPT-02, ADPT-03)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard appState.isAuthenticated else { return }
            Task {
                await runForegroundCheck()
            }
        }
    }

    // MARK: - Foreground Check

    /// Loads active plan day labels and completed sessions from CoreData,
    /// then delegates to AdaptationService.checkOnForeground for AI trigger logic.
    private func runForegroundCheck() async {
        guard let userId = appState.currentUser?.id.uuidString else { return }

        // Fetch active plan day labels — needed by MissedSessionDetector
        let planDayLabels: [String]
        do {
            let repo = WorkoutPlanRepository(context: context)
            let plan = try repo.fetchActivePlan(userId: userId)
            planDayLabels = plan?.weeklyDays.map { $0.dayLabel } ?? []
        } catch {
            planDayLabels = []
        }

        // Fetch completed sessions this week from CoreData
        let completedSessions: [CDSessionLog]
        do {
            let request = CDSessionLog.fetchRequest()
            request.predicate = NSPredicate(
                format: "completedAt != nil AND userId == %@",
                userId
            )
            completedSessions = try context.fetch(request)
        } catch {
            completedSessions = []
        }

        await adaptationService.checkOnForeground(
            activePlanDayLabels: planDayLabels,
            completedSessions: completedSessions
        )
    }
}
