import SwiftUI
import RevenueCat

// MARK: - PaywallView
// Full paywall modal with feature showcase, dynamic pricing cards, free trial CTA, and post-purchase success.
// Presented as fullScreenCover from ContentView when isAuthenticated && !isSubscribed (D-13 hard paywall).
// All prices and trial periods read from RevenueCat SDK at runtime — never hardcoded (RESEARCH anti-patterns).
// D-08: Annual plan pre-selected by default with "Most Popular" badge.
// D-13: .interactiveDismissDisabled(true) — no drag dismiss.
// Post-purchase: calls appState.refreshEntitlements() which sets isSubscribed = true, dismissing cover.
struct PaywallView: View {
    @Environment(AppState.self) var appState
    // ViewModel is lazily initialized in .task using appState.revenueCatService.
    // Initial placeholder uses the live service; the .task modifier calls loadOfferings()
    // once the environment is available.
    @State private var viewModel = PaywallViewModel(revenueCatService: RevenueCatService())

    var body: some View {
        if viewModel.purchaseCompleted {
            successView
                .transition(.opacity)
        } else {
            paywallContent
        }
    }

    // MARK: - Main Paywall Content

    private var paywallContent: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                // Restore row (trailing aligned)
                HStack {
                    Spacer()
                    Button("Restore Purchases") {
                        Task { await viewModel.restorePurchases() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                }
                .padding(.top, 16)
                .padding(.trailing, 32)

                // Headline (UI-SPEC: .title semibold, centered)
                Text("Your personalized plan is ready")
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 48)

                // Value propositions (D-05)
                ValuePropListView()
                    .padding(.top, 24)

                // Social proof (D-07: seeded "1,200 members" — future: from Supabase app_config table)
                Text("Join 1,200 members")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                // Pricing cards or skeleton/error state
                pricingSection
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                // CTA button (only shown when not in error state)
                if viewModel.errorMessage != "Couldn't load pricing" {
                    ctaButton
                        .padding(.horizontal, 32)
                        .padding(.top, 24)

                    // Fine print (updates reactively on card selection)
                    Text(viewModel.finePrintText)
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .accessibilityHidden(false)

                    // Billing transparency notice (App Store review guideline requirement)
                    Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
            }
        }
        .task {
            // Reinitialize ViewModel with AppState's service (available after environment injection)
            viewModel = PaywallViewModel(revenueCatService: appState.revenueCatService)
            await viewModel.loadOfferings()
        }
        .interactiveDismissDisabled(true)
        .onChange(of: viewModel.purchaseCompleted) { _, newValue in
            if newValue {
                Task { await appState.refreshEntitlements() }
            }
        }
    }

    // MARK: - Pricing Section

    @ViewBuilder
    private var pricingSection: some View {
        if viewModel.isLoading && viewModel.annualPackage == nil {
            // Loading skeleton (UI-SPEC: redacted placeholders)
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("CardBackground"))
                    .frame(height: 88)
                    .redacted(reason: .placeholder)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("CardBackground"))
                    .frame(height: 88)
                    .redacted(reason: .placeholder)
            }
        } else if viewModel.errorMessage == "Couldn't load pricing" {
            // Error state with retry
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(Color.secondary)
                Text("Couldn't load pricing")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                Button("Try Again") {
                    Task { await viewModel.loadOfferings() }
                }
                .font(.subheadline)
                .foregroundStyle(Color("AccentColor"))
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        } else if let annualPackage = viewModel.annualPackage,
                  let monthlyPackage = viewModel.monthlyPackage {
            // Pricing cards (both packages available)
            VStack(spacing: 8) {
                // Annual card first — pre-selected with "Most Popular" badge (D-08)
                PricingCardView(
                    package: annualPackage,
                    isSelected: viewModel.selectedPackage?.identifier == annualPackage.identifier,
                    showBadge: true,
                    monthlyEquivalent: viewModel.annualMonthlyEquivalent,
                    onSelect: { viewModel.selectPackage(annualPackage) }
                )
                // Monthly card below
                PricingCardView(
                    package: monthlyPackage,
                    isSelected: viewModel.selectedPackage?.identifier == monthlyPackage.identifier,
                    showBadge: false,
                    monthlyEquivalent: nil,
                    onSelect: { viewModel.selectPackage(monthlyPackage) }
                )
            }
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            Task { await viewModel.purchase() }
        } label: {
            if viewModel.isPurchasing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            } else {
                Text(viewModel.ctaLabel)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    viewModel.isLoading || viewModel.isPurchasing || viewModel.selectedPackage == nil
                    ? Color("AccentColor").opacity(0.5)
                    : Color("AccentColor")
                )
        )
        .disabled(viewModel.isLoading || viewModel.isPurchasing || viewModel.selectedPackage == nil)
        .accessibilityLabel(viewModel.ctaLabel)
    }

    // MARK: - Post-Purchase Success State

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color("AccentColor"))

            Text("You're all set")
                .font(.title)
                .fontWeight(.semibold)

            Group {
                if let trialText = viewModel.trialPeriodText {
                    Text("Your \(trialText.lowercased()) free trial has started. Enjoy the full app.")
                } else {
                    Text("Your subscription is active. Enjoy the full app.")
                }
            }
            .font(.body)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            Button {
                Task { await appState.refreshEntitlements() }
                // refreshEntitlements sets isSubscribed = true, which flips
                // the fullScreenCover binding to false, auto-dismissing the cover (D-13)
            } label: {
                Text("Start Training")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("AccentColor"))
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("AppBackground").ignoresSafeArea())
    }
}

#Preview {
    PaywallView()
        .environment(AppState())
}
