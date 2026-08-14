import FirebaseFirestore

protocol FirestoreServiceProtocol {
    // Username / onboarding
    func isUsernameAvailable(_ username: String) async throws -> Bool
    func userExists(_ uid: String) async throws -> Bool

    // Profile (Phase 3)
    func createUserProfile(uid: String, username: String) async throws
    func fetchUser(_ uid: String) async throws -> AppUser
    func updateUserProfile(uid: String, bio: String?, avatarURL: String?) async throws
}

/// Thin wrapper around Firestore. Collection layout mirrors the schema in
/// Phase 3 of the roadmap — only the `users` collection is fully wired up
/// here; the rest are declared as constants now so every later phase
/// (posts, follows, likes, comments, chats) writes to the same paths
/// instead of each feature inventing its own naming.
final class FirestoreService: FirestoreServiceProtocol {
    private let db = Firestore.firestore()

    // MARK: - Collection paths (schema reference, Phase 3)
    // users/{uid}
    // users/{uid}/followers/{followerId}
    // users/{uid}/following/{followingId}
    // posts/{postId}
    // posts/{postId}/likes/{userId}
    // posts/{postId}/comments/{commentId}
    // chats/{chatId}/messages/{messageId}
    private enum Collection {
        static let users = "users"
        static let followers = "followers"
        static let following = "following"
        static let posts = "posts"
        static let likes = "likes"
        static let comments = "comments"
        static let chats = "chats"
        static let messages = "messages"
    }

    private func userDoc(_ uid: String) -> DocumentReference {
        db.collection(Collection.users).document(uid)
    }

    // MARK: - Username

    /// Checks the `usernameLowercase` field so lookups are case-insensitive.
    /// Storing this field alongside the display username from day one is
    /// what makes prefix-based search possible later (Phase 9).
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let lowered = username.lowercased()
        let snapshot = try await db.collection(Collection.users)
            .whereField("usernameLowercase", isEqualTo: lowered)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.isEmpty
    }

    func userExists(_ uid: String) async throws -> Bool {
        let snapshot = try await userDoc(uid).getDocument()
        return snapshot.exists
    }

    // MARK: - Profile (Phase 3)

    /// Creates the users/{uid} document right after a username is reserved.
    /// Uses a single denormalized document so a profile screen or a feed
    /// row only ever needs one read.
    func createUserProfile(uid: String, username: String) async throws {
        let user = AppUser(
            id: uid,
            username: username,
            usernameLowercase: username.lowercased(),
            bio: nil,
            avatarURL: nil,
            followerCount: 0,
            followingCount: 0,
            postCount: 0,
            createdAt: Date()
        )
        do {
            // The async/throws overload is used deliberately (not the
            // fire-and-forget sync one) so this only returns once the
            // write has actually landed — callers immediately check for
            // the document's existence (see SessionStore.refreshProfileStatus),
            // so a fire-and-forget write would race against that read.
            try await userDoc(uid).setData(from: user, merge: false)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func fetchUser(_ uid: String) async throws -> AppUser {
        let snapshot = try await userDoc(uid).getDocument()
        guard snapshot.exists else {
            throw AppError.notFound("Profile not found.")
        }
        do {
            return try snapshot.data(as: AppUser.self)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Partial update — only writes the fields that changed so an edit
    /// that only touches the avatar doesn't also rewrite the bio, and
    /// vice versa. Keeps writes cheap against the free-tier quota.
    func updateUserProfile(uid: String, bio: String?, avatarURL: String?) async throws {
        var fields: [String: Any] = [:]
        if let bio { fields["bio"] = bio }
        if let avatarURL { fields["avatarURL"] = avatarURL }
        guard !fields.isEmpty else { return }
        do {
            try await userDoc(uid).updateData(fields)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }
}
