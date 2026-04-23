import SwiftUI

// MARK: - MainTabView
// D-04: 5-tab shell — Home, Train, Coach, Progress, Profile
// Active tab accent tint via .tint(Color("AccentColor")) (UI-SPEC)
struct MainTabView: View {
    @Environment(AppState.self) var appState

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
    }
}
