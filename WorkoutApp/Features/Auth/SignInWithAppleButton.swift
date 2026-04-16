import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - SignInWithAppleButton
// UIViewRepresentable wrapper for ASAuthorizationAppleIDButton
// Preserves Apple's required button styling (cannot be replicated in SwiftUI)
// T-03-01: Cryptographic nonce via SecRandomCopyBytes (NOT arc4random) prevents replay attacks
struct SignInWithAppleButton: UIViewRepresentable {
    var style: ASAuthorizationAppleIDButton.ButtonType  // .signIn or .signUp (matches auth mode)
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    @Binding var rawNonce: String

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        // .black style enforced per Apple's Sign In with Apple HIG (system-required dark appearance)
        let button = ASAuthorizationAppleIDButton(type: style, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButton

        init(parent: SignInWithAppleButton) {
            self.parent = parent
        }

        @objc func handleTap() {
            // Generate cryptographic nonce — SecRandomCopyBytes only (Security Domain; never arc4random)
            let nonce = randomNonceString()
            parent.rawNonce = nonce

            // Hash sent to Apple; raw nonce retained for Supabase (T-03-01: prevents replay attacks)
            let hashedNonce = SHA256.hash(data: Data(nonce.utf8))
                .compactMap { String(format: "%02x", $0) }.joined()

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Nonce Generation
// Cryptographically secure nonce — Security Domain: NEVER use arc4random
// SecRandomCopyBytes uses the system's cryptographically secure RNG (T-03-01)
private func randomNonceString(length: Int = 32) -> String {
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    precondition(errorCode == errSecSuccess, "Nonce generation failed: \(errorCode)")
    return randomBytes.map { String(format: "%02x", $0) }.joined()
}
