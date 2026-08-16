import FirebaseFirestore

/// Mirrors a chats/{chatId}/messages/{messageId} Firestore document.
/// New in Phase 7 (Real-Time Chat).
struct ChatMessage: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var createdAt: Date
}
