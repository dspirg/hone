import SwiftUI

// MARK: - OnboardingView
// Root container for the 5-card onboarding flow.
// Presented as .fullScreenCover from ContentView (wiring done in Plan 05).
// ZStack card switching with asymmetric slide transitions per UI-SPEC.
struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var onComplete: ((UserProfile) -> Void)?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: back chevron + progress indicator + trailing balance spacer
                HStack {
                    if viewModel.currentStep > 0 {
                        Button(action: { viewModel.goBack() }) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Go back")
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }

                    Spacer()

                    OnboardingProgressView(
                        currentStep: viewModel.currentStep,
                        totalSteps: viewModel.totalSteps,
                        progress: viewModel.progressFraction
                    )

                    Spacer()
                    Button(action: { viewModel.requestQuitConfirmation() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Sign out")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Card area — ZStack with asymmetric transition
                ZStack {
                    cardForCurrentStep
                        .id(viewModel.currentStep)
                        .transition(cardTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Quit setup?",
            isPresented: $viewModel.showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { try? await supabase.auth.signOut() }
            }
            Button("Continue Setup", role: .cancel) { }
        } message: {
            Text("You'll lose your progress and won't get your personalized plan.")
        }
        .interactiveDismissDisabled() // prevent accidental swipe dismiss; force quit confirmation
        .onAppear {
            viewModel.onComplete = onComplete
        }
    }

    // MARK: - Card Transition

    private var cardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return viewModel.isGoingForward
            ? .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
              )
            : .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
              )
    }

    // MARK: - Card Routing

    @ViewBuilder
    private var cardForCurrentStep: some View {
        switch viewModel.currentStep {
        case 0: GoalCardView(viewModel: viewModel)
        case 1: FitnessLevelCardView(viewModel: viewModel)
        case 2: DaysPerWeekCardView(viewModel: viewModel)
        case 3: SessionLengthCardView(viewModel: viewModel)
        case 4: EquipmentCardView(viewModel: viewModel)
        case 5: InjuriesCardView(viewModel: viewModel)
        default: EmptyView()
        }
    }
}

#Preview {
    OnboardingView()
}
