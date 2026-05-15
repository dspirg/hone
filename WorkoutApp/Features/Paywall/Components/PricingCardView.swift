import SwiftUI
import RevenueCat

// MARK: - PricingCardView
// Renders a single subscription option card with selected/unselected states and Most Popular badge.
// All pricing strings read from SDK at runtime — never hardcoded (RESEARCH anti-pattern).
// D-08: Annual card shown first and pre-selected by default.
// D-06: Annual card shows monthly equivalent price + billed-annually sub-label.
struct PricingCardView: View {
    let package: Package
    let isSelected: Bool
    let showBadge: Bool
    /// Monthly equivalent string for annual card only (e.g. "$4.99") — derived in PaywallViewModel.
    /// Nil for monthly card.
    let monthlyEquivalent: String?
    let onSelect: () -> Void

    private var planName: String {
        switch package.packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        default: return package.identifier
        }
    }

    /// Primary price label — always the billed amount (Guideline 3.1.2(c): billed amount must be most prominent)
    private var priceLabel: String {
        if package.packageType == .annual {
            return "\(package.storeProduct.localizedPriceString)/year"
        }
        return "\(package.storeProduct.localizedPriceString)/month"
    }

    /// Subordinate label — monthly equivalent for annual card only
    private var annualSubLabel: String? {
        guard package.packageType == .annual, let monthly = monthlyEquivalent else { return nil }
        return "just \(monthly)/month · ~50% off"
    }

    var body: some View {
        Button(action: onSelect) {
            cardContent
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if showBadge {
                mostPopularBadge
                    .offset(x: 0, y: -12)
            }
        }
        .accessibilityLabel("\(planName) plan, \(priceLabel)")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(planName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)

            Text(priceLabel)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)

            if let subLabel = annualSubLabel {
                Text(subLabel)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 88)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Theme.accent.opacity(0.10) : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? Theme.accent : Color(UIColor.tertiaryLabel),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }

    private var mostPopularBadge: some View {
        Text("Most Popular")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(Theme.accent)
            )
            .accessibilityLabel("Most Popular")
    }
}
