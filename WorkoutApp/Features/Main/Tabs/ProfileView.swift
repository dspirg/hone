import SwiftUI
import Supabase
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
    @State private var currentProfile = UserProfile(goal: "", fitnessLevel: "", daysPerWeek: 3, sessionMinutes: 45, equipment: [], injuries: "")
    @State private var showRegenConfirm = false

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

                // Section: Fitness Profile
                Section("Fitness Profile") {
                    NavigationLink {
                        EditProfileView(profile: currentProfile)
                    } label: {
                        HStack {
                            Text("Edit Profile")
                            Spacer()
                            Text(currentProfile.goal.isEmpty ? "Not set" : currentProfile.goal)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showRegenConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Theme.accent)
                            Text("Regenerate Plan")
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
            .task {
                if let profile = try? await loadProfile() {
                    currentProfile = profile
                }
            }
            .alert("Regenerate your workout plan?", isPresented: $showRegenConfirm) {
                Button("Regenerate") {
                    let service = PlanGenerationService()
                    service.generatePlan(profile: currentProfile)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Hone will create a new plan based on your current profile.")
            }
        }
    }

    private func loadProfile() async throws -> UserProfile {
        let userId = try await supabase.auth.session.user.id
        struct ProfileRow: Decodable {
            let goal: String?
            let fitnessLevel: String?
            let daysPerWeek: Int?
            let sessionMinutes: Int?
            let equipment: [String]?
            let injuries: String?
            enum CodingKeys: String, CodingKey {
                case goal
                case fitnessLevel = "fitness_level"
                case daysPerWeek = "days_per_week"
                case sessionMinutes = "session_minutes"
                case equipment, injuries
            }
        }
        let rows: [ProfileRow] = try await supabase
            .from("profiles")
            .select("goal, fitness_level, days_per_week, session_minutes, equipment, injuries")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        let row = rows.first
        return UserProfile(
            goal: row?.goal ?? "",
            fitnessLevel: row?.fitnessLevel ?? "",
            daysPerWeek: row?.daysPerWeek ?? 3,
            sessionMinutes: row?.sessionMinutes ?? 45,
            equipment: row?.equipment ?? [],
            injuries: row?.injuries ?? ""
        )
    }
}
