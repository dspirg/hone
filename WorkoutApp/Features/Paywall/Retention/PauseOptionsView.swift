import SwiftUI

struct PauseOptionsView: View {
    let isEligibleForDiscount: Bool
    let managementURL: URL?

    @Environment(AppState.self) var appState
    @State private var viewModel: PauseOptionsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
                    .onAppear {
                        let userId = appState.currentUser?.id.uuidString ?? ""
                        viewModel = PauseOptionsViewModel(userId: userId)
                    }
            }
        }
        .navigationTitle("Manage Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(vm: PauseOptionsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Heading
                Text("Life gets busy — take a break")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                // Body
                Text("Pause your plan for a month or two and pick up right where you left off.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // Pause chip selector
                HStack(spacing: 8) {
                    ForEach(PauseDuration.allCases) { duration in
                        let isSelected = vm.selectedDuration == duration
                        Button {
                            vm.selectedDuration = duration
                        } label: {
                            Text(duration.label)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : Color.primary)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(isSelected ? Color("AccentColor") : Color("CardBackground"))
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("\(duration.label) pause")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityValue(isSelected ? "selected" : "not selected")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // Mandatory billing transparency notice (RESEARCH Pitfall 5)
                Text("Pausing hides your plan in the app. Your billing continues — manage your subscription in Settings > Apple ID > Subscriptions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .accessibilityHidden(false)

                // Pause CTA
                Button {
                    Task {
                        await vm.pause()
                        if vm.pauseCompleted, let url = vm.managementURL {
                            await UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    Group {
                        if vm.isPausing {
                            ProgressView().tint(.white)
                        } else {
                            Text(vm.selectedDuration?.ctaLabel ?? "Pause Membership")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("AccentColor").opacity(vm.selectedDuration == nil ? 0.5 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(vm.selectedDuration == nil || vm.isPausing)
                .padding(.horizontal, 32)
                .padding(.top, 48)

                // "I still want to cancel"
                Group {
                    if isEligibleForDiscount {
                        NavigationLink("I still want to cancel") {
                            DiscountOfferView()
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    } else {
                        Button("I still want to cancel") {
                            if let url = managementURL {
                                Task { await UIApplication.shared.open(url) }
                            }
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 32)
        }
    }
}
