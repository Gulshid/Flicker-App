import FirebaseFirestore

/// Mirrors a top-level stories/{storyId} Firestore document. New in
/// Phase 10. Deliberately NOT a subcollection under users/{uid} — a
/// single collection-wide `expiresAt` range query is what lets
/// `observeActiveStories` fetch every non-expired story from every
/// author in one listener, per the roadmap's "expiresAt field with
/// client-side filtering (no scheduled Cloud Functions needed)".
struct Story: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var authorId: String
    var authorUsername: String        // denormalized, same reasoning as Post
    var authorAvatarURL: String?
    var mediaURL: String
    var isVideo: Bool
    var createdAt: Date
    var expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }
}

/// One author's story tray entry — their still-active stories grouped
/// together in chronological order, plus whether the signed-in user has
/// already opened this ring this session. Built client-side in
/// `StoriesViewModel` from the flat `observeActiveStories` stream;
/// nothing about grouping lives in Firestore.
struct StoryGroup: Identifiable, Equatable {
    let authorId: String
    let authorUsername: String
    let authorAvatarURL: String?
    var stories: [Story]

    var id: String { authorId }
    var latestCreatedAt: Date { stories.map(\.createdAt).max() ?? .distantPast }
}
