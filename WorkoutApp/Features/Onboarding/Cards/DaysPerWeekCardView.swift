import SwiftUI

// MARK: - DaysPerWeekCardView
// Card 2 — "How many days per week can you train?"
// Single-select, 2-column chip grid. Parses integer from label. Auto-advances after 120ms.
struct DaysPerWeekCardView: View {
    var viewModel: OnboardingViewModel

    private let options = ["2 days", "3 days", "4 days", "5 days"]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeroIcon(
                iconName: "calendar",
                gradient: [Color(red: 0.506, green: 0.549, blue: 0.973), Color(red: 0.310, green: 0.275, blue: 0.898)]
            )

            Spacer().frame(height: 20)

            Text("How many days per week can you train?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Text("Pick what fits your schedule")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 24) // lg gap

            ChipGridView(
                options: options,
                selectedOptions: viewModel.selectedDaysPerWeek.map { days in
                    Set(["\(days) days"])
                } ?? [],
                columns: 2,
                onSelect: { option in
                    // Parse integer from "N days" label (e.g. "4 days" -> 4)
                    if let dayCount = Int(option.prefix(1)) {
                        viewModel.selectDaysPerWeek(dayCount)
                    }
                }
            )
            .accessibilityHint("Selects this option and advances to the next question.")

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    DaysPerWeekCardView(viewModel: vm)
}
