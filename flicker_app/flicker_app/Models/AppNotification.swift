import FirebaseFirestore

/// The three activity types that generate a notification, matching the
/// features that exist as of Phase 6 (likes, comments, follows).
enum NotificationType: String, Codable {
    case like
    case comment
    case follow
}

/// Mirrors a users/{uid}/notifications/{notificationId} Firestore
/// document. New in Phase 8. Written client-side by whoever performs the
/// action — see `FirestoreService.writeNotification` — rather than a
/// Cloud Function, which is exactly the Spark-plan compensation the
/// roadmap calls for ("client-side Firestore writes, observed via a
/// real-time listener").
struct AppNotification: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var type: NotificationType
    var actorId: String
    var actorUsername: String       // denormalized, same reasoning as Post/Comment
    var actorAvatarURL: String?
    /// The post the like/comment happened on. nil for `.follow`.
    var postId: String?
    /// First ~80 characters of the comment, so the row can show a
    /// preview without a second read back to the comment itself.
    var commentPreview: String?
    var createdAt: Date
    var isRead: Bool

    /// Trailing half of the notification row's sentence — the leading
    /// "@username " half is rendered separately so it can be bolded.
    var message: String {
        switch type {
        case .like:
            return "liked your post"
        case .comment:
            return "commented: \(commentPreview ?? "")"
        case .follow:
            return "started following you"
        }
    }
}
