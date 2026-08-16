import Foundation
import Observation

/// Drives NotificationsView: a live feed of likes/comments/follows,
/// written client-side by `FirestoreService.writeNotification` and
/// observed here via `observeNotifications` — the Spark-plan stand-in
/// for a Cloud-Function-driven notification system.
@MainActor
@Observable
final class NotificationsViewModel {
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = true
    var errorMessage: String?

    private var notificationsTask: Task<Void, Never>?
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.firestoreService = firestoreService
        self.authService = authService
    }

    /// Read by MainTabView to badge the Activity tab.
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    /// Idempotent, same as ChatListViewModel.startObserving — safe to
    /// call once from MainTabView and again (no-op) from NotificationsView
    /// itself.
    func startObserving() {
        guard notificationsTask == nil, let uid = authService.currentUserId else { return }
        notificationsTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.firestoreService.observeNotifications(userId: uid) {
                if Task.isCancelled { return }
                self.notifications = updated
                self.isLoading = false
            }
        }
    }

    func stopObserving() {
        notificationsTask?.cancel()
        notificationsTask = nil
    }

    func markAllRead() async {
        guard let uid = authService.currentUserId else { return }
        let unreadIds = notifications.filter { !$0.isRead }.compactMap(\.id)
        guard !unreadIds.isEmpty else { return }
        do {
            try await firestoreService.markAllNotificationsRead(userId: uid, among: unreadIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ notification: AppNotification) async {
        guard let uid = authService.currentUserId, let id = notification.id, !notification.isRead else { return }
        do {
            try await firestoreService.markNotificationRead(userId: uid, notificationId: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
