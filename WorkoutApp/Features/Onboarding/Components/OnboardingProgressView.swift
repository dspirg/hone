import SwiftUI

// MARK: - OnboardingProgressView
// "N of 5" pill + 3pt animated progress bar per UI-SPEC D-04.
// Pill: subheadline text in CardBackground capsule.
// Bar: 3pt AccentColor fill with spring animation on step change.
struct OnboardingProgressView: View {
    let currentStep: Int   // 0-indexed
    let totalSteps: Int
    let progress: Double   // 0.0 to 1.0

    var body: some View {
        VStack(spacing: 8) { // sm gap between pill and bar
            // "2 of 5" pill
            Text("\(currentStep + 1) of \(totalSteps)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4) // xs
                .background(Color("CardBackground"))
                .clipShape(Capsule())

            // 3pt animated progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color(UIColor.tertiaryLabel).opacity(0.2))
                        .frame(height: 3)
                    // Fill
                    Capsule()
                        .fill(Color("AccentColor"))
                        .frame(width: geometry.size.width * progress, height: 3)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16) // md
            .accessibilityHidden(true) // progress pill label covers accessibility
        }
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}

#Preview {
    OnboardingProgressView(currentStep: 1, totalSteps: 5, progress: 0.4)
        .padding()
}
