import Foundation
import Observation

/// Backs `FollowButton`. Kept tiny and reusable since the button shows up
/// in more than one place (post author header today; a followers/
/// following list would reuse it later).
@MainActor
@Observable
final class FollowViewModel {
    let targetUserId: String
    private(set) var isFollowing = false
    private(set) var isLoading = false
    var errorMessage: String?

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        targetUserId: String,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.targetUserId = targetUserId
        self.firestoreService = firestoreService
        self.authService = authService
    }

    var isOwnProfile: Bool {
        authService.currentUserId == targetUserId
    }

    func loadStatus() async {
        guard !isOwnProfile, let uid = authService.currentUserId else { return }
        do {
            isFollowing = try await firestoreService.isFollowing(currentUserId: uid, targetUserId: targetUserId)
        } catch {
            // A failed status check just leaves the button in its
            // default "Follow" state — not worth surfacing as an error
            // banner for something this minor.
        }
    }

    func toggle() async {
        guard let uid = authService.currentUserId, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let wasFollowing = isFollowing
        isFollowing.toggle()
        do {
            if wasFollowing {
                try await firestoreService.unfollow(currentUserId: uid, targetUserId: targetUserId)
            } else {
                try await firestoreService.follow(currentUserId: uid, targetUserId: targetUserId)
            }
        } catch {
            isFollowing = wasFollowing
            errorMessage = error.localizedDescription
        }
    }
}
