import Foundation
import Observation

/// Drives StoryTrayView: groups the flat, real-time `observeActiveStories`
/// stream into per-author `StoryGroup`s, most-recently-active first, and
/// tracks which rings the signed-in user has already opened this session.
/// New in Phase 10.
@MainActor
@Observable
final class StoriesViewModel {
    private(set) var groups: [StoryGroup] = []

    /// Session-only "seen" set — resets on relaunch rather than being
    /// persisted to Firestore. Persisting per-user view state would mean
    /// a write for every story every viewer opens; a greyed-out ring
    /// that resets on next launch is a reasonable trade against the
    /// free-tier write quota for a feature this minor.
    private(set) var viewedAuthorIds: Set<String> = []

    private var storiesTask: Task<Void, Never>?
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

    func startObserving() {
        guard storiesTask == nil else { return }
        storiesTask = Task { [weak self] in
            guard let self else { return }
            for await stories in self.firestoreService.observeActiveStories() {
                if Task.isCancelled { return }
                self.groups = Self.group(stories)
            }
        }
    }

    func stopObserving() {
        storiesTask?.cancel()
        storiesTask = nil
    }

    func markViewed(_ authorId: String) {
        viewedAuthorIds.insert(authorId)
    }

    private static func group(_ stories: [Story]) -> [StoryGroup] {
        let byAuthor = Dictionary(grouping: stories, by: \.authorId)
        return byAuthor.values.map { items -> StoryGroup in
            let sorted = items.sorted { $0.createdAt < $1.createdAt }
            let first = sorted[0]
            return StoryGroup(
                authorId: first.authorId,
                authorUsername: first.authorUsername,
                authorAvatarURL: first.authorAvatarURL,
                stories: sorted
            )
        }
        .sorted { $0.latestCreatedAt > $1.latestCreatedAt }
    }
}
