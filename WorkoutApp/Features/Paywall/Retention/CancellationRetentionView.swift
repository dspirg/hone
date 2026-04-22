import SwiftUI
import RevenueCat

/// Coordinates the retention flow: pause first (D-10), then discount (D-12).
///
/// ELIGIBILITY GUARD (RESEARCH Assumption A4):
/// The discount screen (DiscountOfferView) must ONLY be shown to users with
/// an active MONTHLY subscription. For annual subscribers or trial users,
/// "I still want to cancel" opens Apple managementURL directly.
struct CancellationRetentionView: View {
    @Environment(AppState.self) var appState
    @State private var isEligibleForDiscount = false
    @State private var managementURL: URL?
    @State private var isCheckingEligibility = true

    var body: some View {
        NavigationStack {
            Group {
                if isCheckingEligibility {
                    ProgressView("Loading...")
                } else {
                    PauseOptionsView(
                        isEligibleForDiscount: isEligibleForDiscount,
                        managementURL: managementURL
                    )
                }
            }
        }
        .task {
            await checkDiscountEligibility()
        }
    }

    private func checkDiscountEligibility() async {
        defer { isCheckingEligibility = false }
        do {
            let info = try await Purchases.shared.customerInfo()
            managementURL = info.managementURL
                ?? URL(string: "https://apps.apple.com/account/subscriptions")

            let activeSubscriptions = info.activeSubscriptions
            let hasMonthly = activeSubscriptions.contains { $0.contains("monthly") }

            let entitlement = info.entitlements["pro"]
            let isInTrial = entitlement?.periodType == .trial

            isEligibleForDiscount = hasMonthly && !isInTrial
        } catch {
            isEligibleForDiscount = false
            managementURL = URL(string: "https://apps.apple.com/account/subscriptions")
        }
    }
}
