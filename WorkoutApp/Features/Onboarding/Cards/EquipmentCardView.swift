import SwiftUI

// MARK: - EquipmentCardView
// Card 3 — "What equipment do you have access to?"
// Multi-select with "No equipment" mutual exclusivity.
// "No equipment" spans full width; other 4 in a 2-column grid.
// Continue button enabled only when at least 1 chip is selected.
struct EquipmentCardView: View {
    var viewModel: OnboardingViewModel

    private let exclusiveOption = "No equipment"
    private let gearOptions = ["Dumbbells", "Barbell", "Pull-up bar", "Full gym"]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeroIcon(symbol: "🏋️")

            Spacer().frame(height: 20)

            Text("What equipment do you have access to?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Text("Select all that apply")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 24) // lg gap

            // "No equipment" — full-width standalone chip
            ChipView(
                label: exclusiveOption,
                isSelected: viewModel.selectedEquipment.contains(exclusiveOption),
                action: { viewModel.toggleEquipment(exclusiveOption) }
            )
            .padding(.horizontal, 16)

            Spacer().frame(height: 12)

            // Other 4 gear options in a 2-column grid
            ChipGridView(
                options: gearOptions,
                selectedOptions: viewModel.selectedEquipment,
                columns: 2,
                onSelect: { option in
                    viewModel.toggleEquipment(option)
                }
            )

            Spacer().frame(height: 24) // lg gap

            // Continue button — enabled when canAdvanceEquipment
            Button(action: { viewModel.advance() }) {
                Text("Continue")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        viewModel.canAdvanceEquipment
                            ? Theme.accent
                            : Color(.quaternaryLabel)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canAdvanceEquipment)
            .padding(.horizontal, 16)
            .accessibilityHint("Proceeds to the next step.")

            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    EquipmentCardView(viewModel: vm)
}
