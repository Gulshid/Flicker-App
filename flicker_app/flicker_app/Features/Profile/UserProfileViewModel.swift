import Foundation
import Observation

@MainActor
@Observable
final class UserProfileViewModel {
    private(set) var user: AppUser?
    private(set) var isLoading = false
    var errorMessage: String?

    let userId: String
    private let firestoreService: FirestoreServiceProtocol

    init(userId: String, firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService) {
        self.userId = userId
        self.firestoreService = firestoreService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await firestoreService.fetchUser(userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
