import Foundation
import Observation

enum FeedTab: String, CaseIterable, Identifiable, Equatable {
    case following = "Following"
    case discover = "Discover"
    var id: String { rawValue }
}

/// Drives FeedView: tab switching between "Following"/"Discover",
/// cursor-based pagination, pull-to-refresh, and the optimistic
/// like-toggle state shared across every row in the feed.
@MainActor
@Observable
final class FeedViewModel {
    private(set) var posts: [Post] = []
    /// Post IDs the current user has liked, among the posts currently
    /// loaded — checked in one batched query per page via the
    /// `likedPosts` reverse index rather than a read per post.
    private(set) var likedPostIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    var errorMessage: String?

    var tab: FeedTab = .following {
        didSet {
            guard oldValue != tab else { return }
            Task { await refresh() }
        }
    }

    private var cursor: FeedCursor?
    private var hasMorePages = true

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.firestoreService = firestoreService
        self.authService = authService
    }

    func loadInitialIfNeeded() async {
        guard posts.isEmpty, !isLoading else { return }
        await refresh()
    }

    /// Pull-to-refresh: reloads page one from scratch.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        cursor = nil
        hasMorePages = true
        posts = []
        likedPostIds = []
        await loadPage()
    }

    /// Called from a row's `.task` as it appears near the end of the list.
    func loadMoreIfNeeded(currentPost post: Post) async {
        guard post.id == posts.last?.id else { return }
        await loadPage()
    }

    private func loadPage() async {
        guard !isLoading, hasMorePages else { return }
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let feedType: FeedType
            switch tab {
            case .discover:
                feedType = .discover
            case .following:
                let followingIds = try await firestoreService.fetchFollowingIds(userId: uid, limit: 30)
                feedType = .following(authorIds: followingIds)
            }

            let page = try await firestoreService.fetchFeed(type: feedType, cursor: cursor, pageSize: 10)
            posts.append(contentsOf: page.posts)
            cursor = page.nextCursor
            hasMorePages = page.nextCursor != nil
            errorMessage = nil

            let newIds = try await firestoreService.fetchLikedPostIds(userId: uid, among: page.posts.map(\.postId))
            likedPostIds.formUnion(newIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Optimistically flips the like state and count for one post
    /// immediately, then reconciles with the server's transaction
    /// result — flipping back if it turns out to disagree (e.g. a
    /// stale local state after being offline).
    func toggleLike(on post: Post) async {
        guard let uid = authService.currentUserId, let postId = post.id else { return }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        let wasLiked = likedPostIds.contains(postId)
        applyLikeState(liked: !wasLiked, postId: postId, index: index)

        do {
            let liked = try await firestoreService.toggleLike(postId: postId, userId: uid, postAuthorId: post.authorId)
            if liked != !wasLiked {
                applyLikeState(liked: liked, postId: postId, index: index)
            }
        } catch {
            // Roll back the optimistic update on failure.
            applyLikeState(liked: wasLiked, postId: postId, index: index)
            errorMessage = error.localizedDescription
        }
    }

    private func applyLikeState(liked: Bool, postId: String, index: Int) {
        guard posts.indices.contains(index) else { return }
        let currentlyLiked = likedPostIds.contains(postId)
        guard currentlyLiked != liked else { return }
        if liked {
            likedPostIds.insert(postId)
            posts[index].likeCount += 1
        } else {
            likedPostIds.remove(postId)
            posts[index].likeCount = max(0, posts[index].likeCount - 1)
        }
    }

    /// Called from CreatePostView after a successful post so the feed
    /// shows it immediately without a full refresh (and possible
    /// duplicate first page).
    func prependNewPost(_ post: Post) {
        posts.insert(post, at: 0)
    }

    func removePost(_ postId: String) {
        posts.removeAll { $0.id == postId }
        likedPostIds.remove(postId)
    }
}
