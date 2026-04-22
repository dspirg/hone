import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
final class DiscountOfferViewModel {
    var isLoading = false
    var offerAccepted = false
    var errorMessage: String?
    var offerUnavailable = false
    var managementURL: URL?

    private let revenueCatService: RevenueCatServiceProtocol

    init(revenueCatService: RevenueCatServiceProtocol) {
        self.revenueCatService = revenueCatService
    }

    /// Applies the promotional offer "monthly_50pct_3months" (D-12).
    /// Only shown to active monthly subscribers (non-trial) per CancellationRetentionView eligibility guard.
    func acceptOffer() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let offerings = try await revenueCatService.fetchOfferings()
            guard let monthlyPackage = offerings.current?.monthly else {
                offerUnavailable = true
                errorMessage = "This offer isn't available right now."
                return
            }

            let hasPromo = monthlyPackage.storeProduct.discounts.contains {
                $0.offerIdentifier == "monthly_50pct_3months"
            }

            guard hasPromo else {
                offerUnavailable = true
                errorMessage = "This offer isn't available right now."
                return
            }

            let (_, customerInfo, _) = try await revenueCatService.purchaseWithPromo(
                package: monthlyPackage,
                promoOfferID: "monthly_50pct_3months"
            )

            if customerInfo.entitlements["pro"]?.isActive == true {
                offerAccepted = true
            }
        } catch {
            errorMessage = "This offer isn't available right now."
            offerUnavailable = true
        }
    }

    func loadManagementURL() async {
        let info = try? await Purchases.shared.customerInfo()
        managementURL = info?.managementURL
            ?? URL(string: "https://apps.apple.com/account/subscriptions")
    }
}
