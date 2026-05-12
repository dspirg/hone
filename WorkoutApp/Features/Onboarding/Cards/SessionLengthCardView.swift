import SwiftUI

// MARK: - SessionLengthCardView
// Card 3 — "How long do you want to train?"
// Single-select chip grid. Auto-advances after 120ms.
struct SessionLengthCardView: View {
    var viewModel: OnboardingViewModel

    private let options = [
        (label: "30 min", minutes: 30),
        (label: "45 min", minutes: 45),
        (label: "60 min", minutes: 60),
        (label: "90 min", minutes: 90),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingHeroIcon(
                iconName: "timer",
                gradient: [Color(red: 0.02, green: 0.71, blue: 0.83), Color(red: 0.05, green: 0.46, blue: 0.56)]
            )

            Spacer().frame(height: 20)

            Text("How long per session?")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Text("You can change this before each workout")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                ForEach(options, id: \.minutes) { option in
                    Button {
                        viewModel.selectSessionMinutes(option.minutes)
                    } label: {
                        HStack {
                            Text(option.label)
                                .font(.body.weight(.medium))
                            Spacer()
                            if viewModel.selectedSessionMinutes == option.minutes {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(16)
                        .background(
                            viewModel.selectedSessionMinutes == option.minutes
                                ? Theme.accent.opacity(0.1)
                                : Theme.surface
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.selectedSessionMinutes == option.minutes
                                        ? Theme.accent.opacity(0.3)
                                        : Theme.borderSubtle,
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundStyle(.primary)
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
    SessionLengthCardView(viewModel: vm)
}
