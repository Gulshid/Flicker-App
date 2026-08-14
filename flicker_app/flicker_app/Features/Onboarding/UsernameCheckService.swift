import Foundation

/// Thin wrapper over FirestoreService's username lookup,
/// kept in the Onboarding feature folder since that's the only
/// place it's currently used.
final class UsernameCheckService {
    private let firestoreService: FirestoreServiceProtocol

    init(firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService) {
        self.firestoreService = firestoreService
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        guard username.count >= 3 else {
            throw AppError.invalidInput("Username must be at least 3 characters.")
        }
        return try await firestoreService.isUsernameAvailable(username)
    }
}
