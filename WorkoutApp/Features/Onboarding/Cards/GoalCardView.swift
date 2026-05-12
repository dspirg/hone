import SwiftUI

// MARK: - GoalCardView
// Card 0 — "What's your main goal?"
// Single-select, 2-column chip grid. Auto-advances after 120ms visual delay.
struct GoalCardView: View {
    var viewModel: OnboardingViewModel

    private let options = ["Build Muscle", "Lose Fat", "Get Fitter", "Athletic Performance"]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeroIcon(
                iconName: "scope",
                gradient: [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.92, green: 0.35, blue: 0.05)]
            )

            Spacer().frame(height: 20)

            Text("What's your goal?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Text("This shapes your entire program")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 24)

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
