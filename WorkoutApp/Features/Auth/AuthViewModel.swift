import Observation
import Supabase
import AuthenticationServices
import CryptoKit

// MARK: - AuthViewModel
// @Observable ViewModel (Swift 6 / iOS 17+ idiom — not @ObservableObject)
// Handles all 4 auth flows: email sign-up, email sign-in, password reset, Apple Sign-In
// Error messages mapped to UI-SPEC Copywriting Contract strings (T-03-02: no raw error leakage)
@Observable
@MainActor
final class AuthViewModel {

    // MARK: - State
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // MARK: - Email Sign-Up
    func signUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Email Sign-In
    func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Password Reset
    // AUTH-03: sends deep link to workout://auth-callback?type=recovery
    func sendPasswordReset() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "workout://auth-callback?type=recovery")
            )
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Apple Sign-In
    // T-03-06 / Pitfall 1: fullName captured immediately on first sign-in — Apple only provides it once
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                errorMessage = "Apple Sign-In failed. Please try again."
                return
            }
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce  // raw nonce sent to Supabase; hash was sent to Apple (T-03-01)
                )
            )
            // Capture full name immediately — Apple only sends it on the first authentication (Pitfall 1)
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            if !fullName.isEmpty {
                try await supabase.from("profiles")
                    .update(["display_name": fullName])
                    .eq("id", value: session.user.id.uuidString)
                    .execute()
            }
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Error Mapping
    // T-03-02: Maps raw Supabase/GoTrue errors to generic user-facing copy from UI-SPEC
    // Never expose internal error details to the UI
    private func mapAuthError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login credentials") || msg.contains("invalid password") {
            return "Incorrect password. Try again or reset your password."
        } else if msg.contains("user not found") || msg.contains("email not found") {
            return "No account found with that email."
        } else if msg.contains("already registered") || msg.contains("already exists") {
            return "An account with this email already exists. Try logging in."
        } else if msg.contains("network") || msg.contains("connection") {
            return "Connection failed. Check your internet and try again."
        } else {
            return "Something went wrong. Please try again."
        }
    }
}
