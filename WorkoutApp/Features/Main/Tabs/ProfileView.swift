import SwiftUI
import RevenueCatUI

// MARK: - ProfileView
// Functional profile screen with Manage Subscription retention flow entry point (D-09).
//
// Sections:
//   1. Account — email display
//   2. Subscription — "Manage Subscription" NavigationLink to CancellationRetentionView,
//      subscription status badge ("Active" / "Free"), Restore Purchases via RC CustomerCenterView
//   3. Account actions — Sign Out (destructive)
//
// NavigationStack here enables the push navigation into CancellationRetentionView.
// The retention flow's internal NavigationStack is nested within.
//
// Requirements: SUBS-04 (cancellation retention flow accessible from Profile tab)
struct ProfileView: View {
    @Environment(AppState.self) var appState
    @State private var showCustomerCenter = false

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Account info
                Section("Account") {
                    if let email = appState.currentUser?.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Section 2: Subscription (D-09)
                Section("Subscription") {
                    // "Manage Subscription" navigates to retention flow (D-09)
                    // NavigationLink push — not modal — so system back button is available
                    NavigationLink {
                        CancellationRetentionView()
                    } label: {
                        HStack {
                            Text("Manage Subscription")
                            Spacer()
                            Text(appState.isSubscribed ? "Active" : "Free")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Restore Purchases via RevenueCat CustomerCenterView (Pattern 6 from RESEARCH.md)
                    // Supplements the custom retention flow — handles standard restore scenarios
                    Button("Restore Purchases") {
                        showCustomerCenter = true
                    }
                    .foregroundStyle(.secondary)
                }

                // Section 3: Account actions
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            try? await supabase.auth.signOut()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCustomerCenter) {
                // RevenueCat CustomerCenterView handles standard restore flow
                // This supplements the custom retention flow (D-09 through D-12)
                CustomerCenterView()
            }
        }
    }
}
