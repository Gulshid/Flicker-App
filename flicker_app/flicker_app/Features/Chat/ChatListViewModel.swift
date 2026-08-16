import Foundation
import Observation

/// Drives ChatListView: a live list of the signed-in user's threads,
/// most-recent activity first. Firestore does that ordering for us (see
/// `FirestoreService.observeUserChats`), so this mostly just holds the
/// stream open for as long as the tab is around and hands the array to
/// the view.
@MainActor
@Observable
final class ChatListViewModel {
    private(set) var chats: [Chat] = []
    private(set) var isLoading = true
    var errorMessage: String?

    private var chatsTask: Task<Void, Never>?
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.firestoreService = firestoreService
        self.authService = authService
    }

    var currentUserId: String? { authService.currentUserId }

    /// Threads with an unread incoming message — surfaced as a tab badge
    /// in MainTabView.
    var unreadCount: Int {
        guard let uid = currentUserId else { return 0 }
        return chats.filter { $0.isUnread(for: uid) }.count
    }

    /// Idempotent — MainTabView/ChatListView can call this from `.task`
    /// every time the tab appears without restarting the listener.
    func startObserving() {
        guard chatsTask == nil, let uid = currentUserId else { return }
        chatsTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.firestoreService.observeUserChats(userId: uid) {
                if Task.isCancelled { return }
                self.chats = updated
                self.isLoading = false
            }
        }
    }

    func stopObserving() {
        chatsTask?.cancel()
        chatsTask = nil
    }
}
