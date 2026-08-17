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

    /// Optional so every post written before Phase 10 decodes fine with
    /// no migration — missing key just means "not a reel". Set on
    /// creation by `CreateReelViewModel` (never toggled after the fact),
    /// and used both to filter the Reels feed query and to pick the
    /// video vs. photo renderer in PostCardView/PostDetailView.
    var hasVideo: Bool?

    /// Feed/detail views only ever see documents that came back from
    /// Firestore (so `id` is always populated); this keeps call sites
    /// from having to unwrap an optional that's never actually nil.
    var postId: String { id ?? "" }

    var isVideo: Bool { hasVideo ?? false }
}
