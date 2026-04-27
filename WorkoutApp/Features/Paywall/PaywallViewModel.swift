import Foundation
import Observation
import RevenueCat

// MARK: - PaywallLoadState
// Typed load state eliminates fragile string-literal equality comparisons in the view.
enum PaywallLoadState {
    case idle, loading, loaded, pricingError
}

@Observable
@MainActor
final class PaywallViewModel {
    // MARK: - Package State
    var annualPackage: Package?
    var monthlyPackage: Package?
    var selectedPackage: Package?  // D-08: annual pre-selected by default after load

    // MARK: - UI State
    var loadState: PaywallLoadState = .idle
    var isLoading = false
    var isPurchasing = false
    var purchaseCompleted = false
    var errorMessage: String?

    // MARK: - Trial Eligibility (RESEARCH Pitfall 2: NEVER hardcode trial period)
    // Read from SDK at runtime. Show trial copy ONLY when introductoryDiscount is non-nil.
    var trialEligible: Bool {
        selectedPackage?.storeProduct.introductoryDiscount != nil
    }

    var trialPeriodText: String? {
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount else { return nil }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return "\(period.value)-Day"
        case .week: return "\(period.value)-Week"
        case .month: return "\(period.value)-Month"
        case .year: return "\(period.value)-Year"
        @unknown default: return nil
        }
    }

    // MARK: - Dynamic CTA Label
    var ctaLabel: String {
        if let trialText = trialPeriodText {
            return "Start \(trialText) Free Trial"
        }
        return "Subscribe Now"
    }

    // MARK: - Dynamic Fine Print
    var finePrintText: String {
        guard let package = selectedPackage else { return "" }
        let price = package.storeProduct.localizedPriceString
        let period = package.packageType == .annual ? "year" : "month"
        if trialEligible {
            return "Cancel anytime. \(price)/\(period) after trial."
        }
        return "Cancel anytime. \(price)/\(period)."
    }

    // MARK: - Annual Monthly Equivalent (D-06: "$4.99/month, billed $59.99/year")
    var annualMonthlyEquivalent: String? {
        guard let annual = annualPackage else { return nil }
        let price = annual.storeProduct.price
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: monthly as NSDecimalNumber)
    }

    // MARK: - Dependencies
    private let revenueCatService: RevenueCatServiceProtocol

    init(revenueCatService: RevenueCatServiceProtocol) {
        self.revenueCatService = revenueCatService
    }

    // MARK: - Load Offerings
    func loadOfferings() async {
        isLoading = true
        loadState = .loading
        errorMessage = nil
        defer { isLoading = false }
        do {
            let offerings = try await revenueCatService.fetchOfferings()
            annualPackage = offerings.current?.annual
            monthlyPackage = offerings.current?.monthly
            selectedPackage = annualPackage  // D-08: annual pre-selected
            loadState = .loaded
        } catch {
            errorMessage = "Couldn't load pricing"
            loadState = .pricingError
        }
    }

    // MARK: - Select Package
    func selectPackage(_ package: Package) {
        selectedPackage = package
    }

    // MARK: - Purchase
    func purchase() async {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let (_, customerInfo, userCancelled) = try await revenueCatService.purchase(package: package)
            if userCancelled { return }
            if customerInfo.entitlements["pro"]?.isActive == true {
                purchaseCompleted = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let subscribed = await revenueCatService.refreshEntitlements()
        if subscribed {
            purchaseCompleted = true
        } else {
            errorMessage = "No active subscription found."
        }
    }
}
