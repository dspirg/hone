import SwiftUI

// MARK: - GoalCardView
// Card 0 — "What's your main goal?"
// Single-select, 2-column chip grid. Auto-advances after 120ms visual delay.
struct GoalCardView: View {
    var viewModel: OnboardingViewModel

    private let options = ["Build Muscle", "Lose Fat", "Get Fitter", "Athletic Performance"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("What's your main goal?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Spacer().frame(height: 24) // lg gap

            ChipGridView(
                options: options,
                selectedOptions: viewModel.selectedGoal.map { Set([$0]) } ?? [],
                columns: 2,
                onSelect: { option in
                    viewModel.selectGoal(option)
                }
            )
            // Accessibility hint for auto-advance behavior
            .accessibilityHint("Selects this option and advances to the next question.")

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    GoalCardView(viewModel: vm)
}
