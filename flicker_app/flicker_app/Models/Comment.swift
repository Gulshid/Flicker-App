import FirebaseFirestore

/// Mirrors a posts/{postId}/comments/{commentId} Firestore document.
/// New in Phase 6 (Social Graph & Engagement).
struct Comment: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var authorId: String
    var authorUsername: String     // denormalized, same reasoning as Post
    var authorAvatarURL: String?
    var text: String
    var createdAt: Date
}
