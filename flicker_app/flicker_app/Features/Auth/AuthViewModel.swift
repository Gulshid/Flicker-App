import Observation

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var errorMessage: String?
    var isLoading = false

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = DIContainer.shared.authService) {
        self.authService = authService
    }

    func signUp() async {
        guard validate() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await authService.signUp(email: email, password: password)
            try await authService.sendEmailVerification()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn() async {
        guard validate() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }
        do {
            try await authService.sendPasswordReset(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validate() -> Bool {
        errorMessage = nil
        guard email.contains("@"), !password.isEmpty else {
            errorMessage = "Enter a valid email and password."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        return true
    }
}
