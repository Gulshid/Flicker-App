import FirebaseFirestore

/// Mirrors a chats/{chatId} Firestore document. New in Phase 7 (Real-Time
/// Chat). `id` is deterministic — see `FirestoreService.chatId(for:and:)` —
/// so two users always land on the same thread no matter which one starts
/// the conversation, instead of risking duplicate chat docs between the
/// same pair of people.
struct Chat: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var participantIds: [String]

    // Denormalized, same reasoning as Post.authorUsername — lets
    // ChatListView render every row from the chat doc alone, with no
    // extra per-row user fetch.
    var participantUsernames: [String: String]
    var participantAvatarURLs: [String: String]

    var lastMessageText: String?
    var lastMessageSenderId: String?
    var lastMessageAt: Date
    var createdAt: Date

    /// Per-participant "I've seen up to this point" marker, updated when
    /// a user opens the thread (see FirestoreService.markChatRead).
    /// Drives the unread dot in ChatListView without a separate
    /// unread-count field that could drift out of sync.
    var readAt: [String: Date]

    /// uid of whoever is currently typing, if anyone — set by
    /// FirestoreService.setTyping and cleared a few seconds after the
    /// last keystroke by ChatViewModel, or automatically the moment a
    /// message actually sends. A single field is enough for a 1:1
    /// thread; a group chat would need a set instead.
    var typingUserId: String?

    var chatId: String { id ?? "" }

    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }

    func otherParticipantUsername(currentUserId: String) -> String {
        guard let otherId = otherParticipantId(currentUserId: currentUserId) else { return "" }
        return participantUsernames[otherId] ?? ""
    }

    func otherParticipantAvatarURL(currentUserId: String) -> String? {
        guard let otherId = otherParticipantId(currentUserId: currentUserId) else { return nil }
        return participantAvatarURLs[otherId]
    }

    /// True when the other participant's most recent message hasn't been
    /// read yet. Never true for a thread the current user sent the last
    /// message in.
    func isUnread(for userId: String) -> Bool {
        guard let lastMessageSenderId, lastMessageSenderId != userId else { return false }
        guard let lastRead = readAt[userId] else { return true }
        return lastMessageAt > lastRead
    }
}
