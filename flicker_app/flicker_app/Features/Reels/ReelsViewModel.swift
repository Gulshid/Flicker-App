import Foundation
import Observation

/// Drives ReelsView: a paginated, video-only feed (`fetchVideoPosts`),
/// plus like state reusing the same `likedPosts` reverse index the Home
/// feed uses. New in Phase 10.
@MainActor
@Observable
final class ReelsViewModel {
    private(set) var posts: [Post] = []
    private(set) var likedPostIds: Set<String> = []
    private(set) var isLoading = false
    var errorMessage: String?

    private var cursor: FeedCursor?
    private var hasMorePages = true
    private var hasLoadedOnce = false

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
        guard !hasLoadedOnce else { return }
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }
        do {
            let page = try await firestoreService.fetchVideoPosts(cursor: cursor, pageSize: 5)
            posts.append(contentsOf: page.posts)
            cursor = page.nextCursor
            hasMorePages = page.nextCursor != nil
            await refreshLikedState(for: page.posts)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called as each reel scrolls into view — same "load the next page
    /// a couple items early" pattern as `FeedViewModel.loadMoreIfNeeded`.
    func loadMoreIfNeeded(currentPost: Post) async {
        guard let index = posts.firstIndex(where: { $0.id == currentPost.id }) else { return }
        if index >= posts.count - 2 {
            await loadMore()
        }
    }

    func toggleLike(on post: Post) async {
        guard let uid = authService.currentUserId, let postId = post.id else { return }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        do {
            let liked = try await firestoreService.toggleLike(postId: postId, userId: uid, postAuthorId: post.authorId)
            posts[index].likeCount += liked ? 1 : -1
            if liked {
                likedPostIds.insert(postId)
            } else {
                likedPostIds.remove(postId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshLikedState(for newPosts: [Post]) async {
        guard let uid = authService.currentUserId else { return }
        let ids = newPosts.compactMap(\.id)
        guard !ids.isEmpty else { return }
        do {
            let liked = try await firestoreService.fetchLikedPostIds(userId: uid, among: ids)
            likedPostIds.formUnion(liked)
        } catch {
            // Non-fatal — reel just renders as not-liked until the next refresh.
        }
    }
}
