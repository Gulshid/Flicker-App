import Foundation
import Observation

@MainActor
@Observable
final class UserProfileViewModel {
    private(set) var user: AppUser?
    private(set) var isLoading = false
    private(set) var isStartingChat = false
    var errorMessage: String?

    let userId: String
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        userId: String,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.userId = userId
        self.firestoreService = firestoreService
        self.authService = authService
    }

    var isOwnProfile: Bool {
        authService.currentUserId == userId
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

    /// Finds or creates the 1:1 thread with this profile's user — backs
    /// the Message button (Phase 7). Returns nil (and sets errorMessage)
    /// on failure so the view can decide whether to show a sheet.
    func startChat() async -> Chat? {
        guard !isOwnProfile, let currentUserId = authService.currentUserId, let user else { return nil }
        isStartingChat = true
        defer { isStartingChat = false }
        do {
            let me = try await firestoreService.fetchUser(currentUserId)
            return try await firestoreService.createOrGetChat(
                currentUserId: currentUserId,
                currentUsername: me.username,
                currentAvatarURL: me.avatarURL,
                otherUserId: user.id,
                otherUsername: user.username,
                otherAvatarURL: user.avatarURL
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
