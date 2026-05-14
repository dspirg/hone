import SwiftUI

// MARK: - FitnessLevelCardView
// Card 1 — "What's your fitness level?"
// Single-select, single-column VStack of 3 full-width chips. Auto-advances after 120ms.
struct FitnessLevelCardView: View {
    var viewModel: OnboardingViewModel

    private let options = ["Beginner", "Intermediate", "Advanced"]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeroIcon(
                iconName: "chart.xyaxis.line",
                gradient: [Color(red: 0.957, green: 0.447, blue: 0.714), Color(red: 0.859, green: 0.153, blue: 0.467)]
            )

            Spacer().frame(height: 20)

            Text("What's your fitness level?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Text("We'll match your starting point")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 24) // lg gap

            // Single column — VStack of full-width chips per UI-SPEC FitnessLevelCardView
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    ChipView(
                        label: option,
                        isSelected: viewModel.selectedFitnessLevel == option,
                        action: { viewModel.selectFitnessLevel(option) }
                    )
                    .accessibilityHint("Selects this option and advances to the next question.")
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    FitnessLevelCardView(viewModel: vm)
}
