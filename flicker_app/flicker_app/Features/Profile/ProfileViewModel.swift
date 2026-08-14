import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var user: AppUser?
    private(set) var isLoading = false
    var errorMessage: String?

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.firestoreService = firestoreService
        self.authService = authService
    }

    func loadCurrentUser() async {
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await firestoreService.fetchUser(uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called after EditProfileView saves — updates local state immediately
    /// rather than re-fetching, so the profile screen reflects the edit
    /// without an extra Firestore read.
    func applyLocalEdit(bio: String?, avatarURL: String?) {
        guard var user else { return }
        if let bio { user.bio = bio }
        if let avatarURL { user.avatarURL = avatarURL }
        self.user = user
    }
}
