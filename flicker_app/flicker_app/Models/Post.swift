import FirebaseFirestore

/// Mirrors the posts/{postId} Firestore document. Fully wired up as of
/// Phase 5 (Core Feed).
///
/// `id` uses `@DocumentID` so `FirestoreService` can decode a query
/// snapshot straight into `[Post]` without manually stitching the doc ID
/// back on afterwards — see `fetchFeed`.
struct Post: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var authorId: String
    var authorUsername: String       // denormalized to avoid an extra read per feed row
    var authorAvatarURL: String?     // denormalized for the same reason
    var mediaURLs: [String]
    var caption: String?
    var likeCount: Int
    var commentCount: Int
    var createdAt: Date

    /// Feed/detail views only ever see documents that came back from
    /// Firestore (so `id` is always populated); this keeps call sites
    /// from having to unwrap an optional that's never actually nil.
    var postId: String { id ?? "" }
}
