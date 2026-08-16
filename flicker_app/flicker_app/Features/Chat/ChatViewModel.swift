import Foundation
import Observation

/// Drives ChatView: the live message list, the composer's draft text, a
/// debounced typing indicator, and read receipts. Everything here works
/// on the Spark plan with zero server code — real-time listeners and
/// plain field updates only, exactly the phase 7 "works perfectly on the
/// Spark plan" feature the roadmap calls out.
@MainActor
@Observable
final class ChatViewModel {
    let chat: Chat
    private(set) var messages: [ChatMessage] = []
    var draftText: String = ""
    private(set) var isSending = false
    var errorMessage: String?

    /// Driven by a live listener on this one chat doc — true whenever
    /// `typingUserId` is set to someone other than the current user.
    private(set) var otherUserIsTyping = false

    private var messagesTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var typingResetTask: Task<Void, Never>?

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        chat: Chat,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.chat = chat
        self.firestoreService = firestoreService
        self.authService = authService
    }

    var currentUserId: String? { authService.currentUserId }

    var navigationTitle: String {
        "@\(chat.otherParticipantUsername(currentUserId: currentUserId ?? ""))"
    }

    func startObserving() {
        guard let chatId = chat.id else { return }

        messagesTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.firestoreService.observeMessages(chatId: chatId) {
                if Task.isCancelled { return }
                self.messages = updated
            }
        }

        chatTask = Task { [weak self] in
            guard let self, let uid = self.currentUserId else { return }
            for await updated in self.firestoreService.observeChat(chatId: chatId) {
                if Task.isCancelled { return }
                guard let updated else { continue }
                self.otherUserIsTyping = updated.typingUserId != nil && updated.typingUserId != uid
            }
        }

        Task { [weak self] in
            guard let self, let uid = self.currentUserId else { return }
            try? await self.firestoreService.markChatRead(chatId: chatId, userId: uid)
        }
    }

    /// Tears down both listeners and clears this user's own typing flag
    /// so leaving mid-sentence doesn't leave the other side staring at a
    /// stuck "Typing…" indicator.
    func stopObserving() {
        messagesTask?.cancel()
        chatTask?.cancel()
        typingResetTask?.cancel()
        if let chatId = chat.id, let uid = currentUserId {
            Task { try? await firestoreService.setTyping(chatId: chatId, userId: uid, isTyping: false) }
        }
    }

    /// Called on every keystroke in the composer. Flips `typingUserId` on
    /// immediately, then clears it after a few seconds of no further
    /// input — a self-resetting timer rather than anything server-driven,
    /// since there's no Cloud Function to schedule that cleanup on the
    /// Spark plan.
    func draftTextChanged() {
        guard let chatId = chat.id, let uid = currentUserId else { return }
        typingResetTask?.cancel()
        let isTyping = !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        Task { try? await firestoreService.setTyping(chatId: chatId, userId: uid, isTyping: isTyping) }
        guard isTyping else { return }
        typingResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            try? await self.firestoreService.setTyping(chatId: chatId, userId: uid, isTyping: false)
        }
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let chatId = chat.id, let uid = currentUserId, !isSending else { return }
        isSending = true
        defer { isSending = false }
        draftText = ""
        typingResetTask?.cancel()
        do {
            try await firestoreService.sendMessage(chatId: chatId, senderId: uid, text: text)
        } catch {
            errorMessage = error.localizedDescription
            draftText = text
        }
    }
}
