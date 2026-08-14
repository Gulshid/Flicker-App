import Foundation

/// Mirrors the posts/{postId} Firestore document.
/// Built out fully in Phase 5 (Core Feed) — placeholder for now.
struct Post: Codable, Identifiable {
    var id: String
    var authorId: String
    var authorUsername: String   // denormalized to avoid extra reads
    var mediaURLs: [String]
    var caption: String?
    var likeCount: Int
    var commentCount: Int
    var createdAt: Date
}
