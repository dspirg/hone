import SwiftUI

struct DiscountOfferView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel: DiscountOfferViewModel?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
                    .task {
                        let vm = DiscountOfferViewModel(revenueCatService: appState.revenueCatService)
                        await vm.loadManagementURL()
                        viewModel = vm
                    }
            }
        }
        .navigationTitle("Special Offer")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(vm: DiscountOfferViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Heading
                Text("Stay for half price")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                // Body
                Text("Get 50% off for the next 3 months — then your regular price.")
                    .font(.body)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // Offer card
                VStack(spacing: 4) {
                    Text("50% off")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Color("AccentColor"))
                    Text("3 months, then full price")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color("CardBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
                .padding(.top, 24)

                if vm.offerUnavailable {
                    // Error/unavailable state
                    VStack(spacing: 12) {
                        Text(vm.errorMessage ?? "This offer isn't available right now.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Manage in Settings") {
                            if let url = vm.managementURL {
                                Task { await UIApplication.shared.open(url) }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 48)
                } else {
                    // Accept Offer CTA
                    Button {
                        Task {
                            await vm.acceptOffer()
                            if vm.offerAccepted { dismiss() }
                        }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Accept Offer")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("AccentColor"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(vm.isLoading)
                    .padding(.horizontal, 32)
                    .padding(.top, 48)
                }

                // Cancel anyway — destructive
                Button("Cancel anyway") {
                    if let url = vm.managementURL {
                        Task { await UIApplication.shared.open(url) }
                    }
                }
                .font(.body)
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .accessibilityLabel("Cancel subscription")

                Spacer(minLength: 32)
            }
        }
    }
}
