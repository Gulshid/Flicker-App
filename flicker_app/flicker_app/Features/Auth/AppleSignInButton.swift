import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit

/// Requires the "Sign in with Apple" capability enabled in
/// Signing & Capabilities, and is required by the App Store
/// review guidelines any time another third-party login is offered.
struct AppleSignInButton: View {
    @State private var currentNonce: String?
    var onComplete: (Result<Void, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                onComplete(.failure(AppError.invalidInput("Apple credential was invalid.")))
                return
            }

            let firebaseCredential = OAuthProvider.credential(
                providerID: .apple,
                idToken: tokenString,
                rawNonce: nonce
            )
            Auth.auth().signIn(with: firebaseCredential) { _, error in
                if let error {
                    onComplete(.failure(error))
                } else {
                    onComplete(.success(()))
                }
            }
        case .failure(let error):
            onComplete(.failure(error))
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
