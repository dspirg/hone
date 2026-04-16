import SwiftUI
import AuthenticationServices

// MARK: - AuthMode
// D-01: Login/signup toggle on a single auth screen
enum AuthMode { case login, signUp }

// MARK: - AuthView
// D-01: Segmented control toggles between login and sign-up states
// D-02: Apple Sign-In is PRIMARY CTA — rendered above the "or" divider
// D-03: "Forgot password?" NavigationLink visible in login state only
struct AuthView: View {
    @State private var viewModel = AuthViewModel()
    @State private var authMode: AuthMode = .login
    @State private var rawNonce: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Heading — .title2, semibold (UI-SPEC Typography)
                Text(authMode == .login ? "Welcome back." : "Let's get started.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 48)
                    .padding(.bottom, 32)

                // Login / Sign Up toggle — equal-width segmented control (D-01)
                Picker("", selection: $authMode) {
                    Text("Log In").tag(AuthMode.login)
                    Text("Sign Up").tag(AuthMode.signUp)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)

                // Apple Sign-In — PRIMARY CTA, above "or" divider (D-02)
                // Style matches current auth mode: .signIn for login, .signUp for sign-up
                SignInWithAppleButton(
                    style: authMode == .login ? .signIn : .signUp,
                    onCompletion: handleAppleSignIn,
                    rawNonce: $rawNonce
                )
                .frame(height: 52)
                .padding(.horizontal, 16)

                // "or" divider (UI-SPEC)
                Text("or")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 24)

                // Display Name field — sign-up state only
                if authMode == .signUp {
                    TextField("Display Name", text: $viewModel.displayName)
                        .padding(16)
                        .background(Color("CardBackground"))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                // Email field — .emailAddress keyboard, no autocap (UI-SPEC)
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(16)
                    .background(Color("CardBackground"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // Password field — masked (T-03-03: SecureField prevents shoulder surfing)
                SecureField("Password", text: $viewModel.password)
                    .padding(16)
                    .background(Color("CardBackground"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                // Inline error display — subheadline, red, below fields (UI-SPEC Error Display Pattern)
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                // "Forgot password?" — login state only, right-aligned (D-03)
                if authMode == .login {
                    NavigationLink(destination: PasswordResetView()) {
                        Text("Forgot password?")
                            .font(.subheadline)
                            .foregroundStyle(Color("AccentColor"))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Primary CTA — "Sign In" or "Create Account", full-width, 52pt, accent (UI-SPEC)
                // T-03-04: disabled during isLoading prevents double-submission
                Button(action: { Task { await primaryAction() } }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(authMode == .login ? "Sign In" : "Create Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
                .cornerRadius(12)
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Actions

    private func primaryAction() async {
        if authMode == .login {
            await viewModel.signIn()
        } else {
            await viewModel.signUp()
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            Task {
                await viewModel.signInWithApple(credential: credential, rawNonce: rawNonce)
            }
        case .failure:
            // User cancelled or error — no action needed; Apple shows its own error UI
            break
        }
    }
}
