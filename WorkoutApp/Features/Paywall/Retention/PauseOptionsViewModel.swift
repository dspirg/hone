import Foundation
import Observation
import RevenueCat

// D-11: Pause options are 1, 2, or 3 months
enum PauseDuration: Int, CaseIterable, Identifiable {
    case oneMonth = 1
    case twoMonths = 2
    case threeMonths = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneMonth: return "1 month"
        case .twoMonths: return "2 months"
        case .threeMonths: return "3 months"
        }
    }

    var ctaLabel: String {
        switch self {
        case .oneMonth: return "Pause for 1 month"
        case .twoMonths: return "Pause for 2 months"
        case .threeMonths: return "Pause for 3 months"
        }
    }
}

@Observable
@MainActor
final class PauseOptionsViewModel {
    var selectedDuration: PauseDuration? = nil
    var isPausing = false
    var pauseCompleted = false
    var errorMessage: String?
    var managementURL: URL?

    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    /// Records subscription_pause_until in Supabase profiles, then fetches
    /// the Apple management URL for redirect.
    ///
    /// IMPORTANT (RESEARCH Pitfall 5): Apple has NO native subscription pause API.
    /// This is purely an in-app UX convention. The app records a pause-until date
    /// and hides workout content during that period. Apple billing continues
    /// regardless.
    func pause() async {
        guard let duration = selectedDuration else { return }
        isPausing = true
        errorMessage = nil
        defer { isPausing = false }

        let calendar = Calendar.current
        guard let pauseUntil = calendar.date(
            byAdding: .month,
            value: duration.rawValue,
            to: Date()
        ) else { return }

        do {
            try await supabase
                .from("profiles")
                .update(["subscription_pause_until": pauseUntil.ISO8601Format()])
                .eq("id", value: userId)
                .execute()

            pauseCompleted = true

            let info = try? await Purchases.shared.customerInfo()
            managementURL = info?.managementURL
                ?? URL(string: "https://apps.apple.com/account/subscriptions")
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    func loadManagementURL() async {
        let info = try? await Purchases.shared.customerInfo()
        managementURL = info?.managementURL
            ?? URL(string: "https://apps.apple.com/account/subscriptions")
    }
}
