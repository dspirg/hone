import SwiftUI

// MARK: - MainTabView
// D-04: 4-tab shell — Home, Train, Coach, Profile
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

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        // Active tab icon + label tint (UI-SPEC Color Token: Accent)
        .tint(Color("AccentColor"))
    }
}
