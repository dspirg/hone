import SwiftUI

// MARK: - PasswordResetView
// Password reset form with two states: form state and success state
// AUTH-03: sends reset link to workout://auth-callback?type=recovery deep link
// Navigation: push via NavigationLink from AuthView (not modal) — UI-SPEC Interaction Contract
struct PasswordResetView: View {
    @State private var viewModel = AuthViewModel()
    @State private var emailSent = false

    var body: some View {
        if emailSent {
            // Success state — form replaced by confirmation message
            // UI-SPEC: no CTA on success; user exits via system back button
            VStack(spacing: 16) {
                Spacer()

                Text("Check your email")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("A reset link has been sent to \(viewModel.email). It may take a minute to arrive.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Spacer()
            }
            .padding(16)
        } else {
            // Form state
            VStack(spacing: 16) {
                Spacer()

                Text("Reset Your Password")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Email field — CardBackground fill, 12pt corner radius, 16pt internal padding (UI-SPEC)
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(16)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                // Inline error display — subheadline, red, left-aligned (UI-SPEC Error Display Pattern)
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                // Primary CTA — matches Primary CTA Button Style pattern (UI-SPEC)
                Button(action: {
                    Task {
                        await viewModel.sendPasswordReset()
                        if viewModel.errorMessage == nil {
                            emailSent = true
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .cornerRadius(12)
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 16)
        }
    }
}
