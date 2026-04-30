import SwiftUI

// MARK: - InjuriesCardView
// Card 4 (optional) — "Any areas to avoid?"
// Has a "Skip" link (top-right, accent color) and a "Save & Continue" button.
// Both "Skip" and "Save & Continue" call completeOnboarding() to trigger profile building.
struct InjuriesCardView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // "Skip" link — top-right aligned within card area
            HStack {
                Spacer()
                Button(action: {
                    viewModel.injuriesText = ""
                    viewModel.completeOnboarding()
                }) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Skip — no injuries to add")
            }
            .padding(.trailing, 16)

            OnboardingHeroIcon(symbol: "🩹")

            Spacer().frame(height: 20)

            Text("Any areas to avoid?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Text("We'll work around them")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 8) // sm gap

            Text("Optional — helps the AI protect you from aggravating existing injuries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer().frame(height: 24) // lg gap

            // Injuries text field — multi-line, md internal padding
            TextField(
                "e.g. lower back, left knee",
                text: $viewModel.injuriesText,
                axis: .vertical
            )
            .lineLimit(3, reservesSpace: true)
            .font(.body)
            .padding(16) // md internal padding
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.tertiaryLabel), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            Spacer().frame(height: 24) // lg gap

            // "Save & Continue" — always enabled (empty injuries is valid)
            Button(action: { viewModel.completeOnboarding() }) {
                Text("Save & Continue")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .accessibilityHint("Proceeds to the next step.")

            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    InjuriesCardView(viewModel: vm)
}
