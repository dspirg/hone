import SwiftUI
import CoreData
import UIKit

// MARK: - MainTabView
// D-04: 5-tab shell — Home, Train, Coach, Progress, Profile
// Active tab accent tint via .tint(Theme.accent) (UI-SPEC)
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

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.086, alpha: 0.85)

        let activeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = activeAttributes

        let inactiveAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(white: 0.4, alpha: 1.0)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.4, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = inactiveAttributes

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        // D-14: selectedTab binding enables programmatic tab switching
        // (e.g., post-session routing to Home tab via AppState.selectedTab = 0)
        TabView(selection: Bindable(appState).selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            TrainView()
                .tabItem {
                    Label("Train", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(1)

            CoachView()
                .tabItem {
                    Label("Hone", systemImage: "message")
                }
                .tag(2)

            WorkoutProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(4)
        }
        // Active tab icon + label tint (UI-SPEC Color Token: Accent)
        .tint(Theme.accent)
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

        // Fetch completed sessions this week from CoreData.
        // WR-04: Add date bound so we only load current-week sessions — MissedSessionDetector
        // only cares about the current week, and an unbounded fetch grows with usage history.
        let completedSessions: [CDSessionLog]
        do {
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let request = CDSessionLog.fetchRequest()
            request.predicate = NSPredicate(
                format: "completedAt != nil AND userId == %@ AND completedAt >= %@",
                userId,
                weekStart as CVarArg
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
