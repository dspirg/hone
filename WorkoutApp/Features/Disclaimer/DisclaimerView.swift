import SwiftUI

// MARK: - DisclaimerView
// First-launch physician-consult disclaimer modal (SAFE-01, D-06, D-07)
// Stateless component — parent owns @AppStorage write via onAcknowledge callback
// .interactiveDismissDisabled(true) enforces hard block — no swipe-to-dismiss (D-07)
struct DisclaimerView: View {
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // SF Symbol illustration — system(size: 64) per plan spec; .secondary color (UI-SPEC)
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // Heading — .title2, semibold (UI-SPEC Typography)
            Text("Before You Train")
                .font(.title2)
                .fontWeight(.semibold)

            // Body — UI-SPEC Copywriting Contract / App Store Guideline 1.4.1 language
            Text("This app provides general fitness guidance and is not a substitute for professional medical advice. Consult a physician before starting any new exercise program, especially if you have a medical condition or injury.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()

            // Primary CTA — single tap acknowledgment, no checkbox required (D-06)
            // Full-width, 52pt height, accent fill, 12pt corner radius (UI-SPEC Primary CTA Style)
            Button(action: onAcknowledge) {
                Text("I Understand")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        // D-07: Hard block — user cannot swipe to dismiss; must tap "I Understand"
        .interactiveDismissDisabled(true)
    }
}
