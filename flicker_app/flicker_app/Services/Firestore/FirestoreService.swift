import FirebaseFirestore

protocol FirestoreServiceProtocol {
    func isUsernameAvailable(_ username: String) async throws -> Bool
}

/// Thin wrapper around Firestore. Grows significantly in Phase 3+
/// (users, posts, follows, likes, comments, chats collections).
final class FirestoreService: FirestoreServiceProtocol {
    private let db = Firestore.firestore()

    /// Checks the `usernameLowercase` field so lookups are case-insensitive.
    /// Storing this field alongside the display username from day one is
    /// what makes prefix-based search possible later (Phase 9).
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let lowered = username.lowercased()
        let snapshot = try await db.collection("users")
            .whereField("usernameLowercase", isEqualTo: lowered)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.isEmpty
    }
}
