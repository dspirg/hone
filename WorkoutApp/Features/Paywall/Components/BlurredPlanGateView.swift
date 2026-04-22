import SwiftUI

// MARK: - BlurredPlanGateView
// Overlays expired/lapsed plan content with blur + scrim + "Your plan is waiting" copy.
// D-14: Shown when user has completed onboarding but isSubscribed == false.
// D-15: Tapping anywhere on the overlay triggers the paywall.
// UI-SPEC: blur(radius: 8), Color.black.opacity(0.40) scrim, .white title2 semibold copy.
struct BlurredPlanGateView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Binding var showPaywall: Bool

    var body: some View {
        ZStack {
            // Bottom layer: plan content rendered at full fidelity, then blurred (UI-SPEC)
            content()
                .blur(radius: 8)

            // Middle layer: semi-transparent scrim (UI-SPEC: 40% black)
            Color.black.opacity(0.40)

            // Top layer: centered call-to-action copy
            Text("Your plan is waiting")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .multilineTextAlignment(.center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showPaywall = true
        }
        .accessibilityLabel("Your plan is waiting. Tap to subscribe.")
    }
}

#Preview {
    BlurredPlanGateView(showPaywall: .constant(false)) {
        Color.gray
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(Text("Plan content").foregroundStyle(.white))
    }
}
