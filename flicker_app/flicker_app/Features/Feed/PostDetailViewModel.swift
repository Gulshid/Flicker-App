import Foundation
import Observation

@MainActor
@Observable
final class PostDetailViewModel {
    private(set) var post: Post?
    private(set) var comments: [Comment] = []
    private(set) var isLiked = false
    private(set) var isLoading = false
    var newCommentText: String = ""
    private(set) var isPostingComment = false
    var errorMessage: String?

    let postId: String
    private var commentsTask: Task<Void, Never>?

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        postId: String,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.postId = postId
        self.firestoreService = firestoreService
        self.authService = authService
    }

    var isOwnPost: Bool {
        guard let post, let uid = authService.currentUserId else { return false }
        return post.authorId == uid
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            post = try await firestoreService.fetchPost(postId)
            if let uid = authService.currentUserId {
                let liked = try await firestoreService.fetchLikedPostIds(userId: uid, among: [postId])
                isLiked = liked.contains(postId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        startObservingComments()
    }

    /// Real-time comment listener, live for as long as the detail screen
    /// is on screen. Cancelling the Task tears down the underlying
    /// Firestore listener via observeComments' onTermination.
    private func startObservingComments() {
        commentsTask?.cancel()
        commentsTask = Task { [weak self] in
            guard let self else { return }
            for await updated in self.firestoreService.observeComments(postId: self.postId) {
                if Task.isCancelled { return }
                self.comments = updated
            }
        }
    }

    func stopObservingComments() {
        commentsTask?.cancel()
    }

    func toggleLike() async {
        guard var post, let uid = authService.currentUserId, let postId = post.id else { return }
        let wasLiked = isLiked
        isLiked.toggle()
        post.likeCount += isLiked ? 1 : -1
        post.likeCount = max(0, post.likeCount)
        self.post = post

        do {
            let liked = try await firestoreService.toggleLike(postId: postId, userId: uid, postAuthorId: post.authorId)
            if liked != isLiked {
                isLiked = liked
                await load()
            }
        } catch {
            isLiked = wasLiked
            self.post?.likeCount += wasLiked ? 1 : -1
            errorMessage = error.localizedDescription
        }
    }

    func postComment() async {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let uid = authService.currentUserId, let postAuthorId = post?.authorId else { return }
        isPostingComment = true
        defer { isPostingComment = false }
        do {
            let author = try await firestoreService.fetchUser(uid)
            try await firestoreService.addComment(
                postId: postId,
                postAuthorId: postAuthorId,
                authorId: uid,
                authorUsername: author.username,
                authorAvatarURL: author.avatarURL,
                text: text
            )
            newCommentText = ""
            post?.commentCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(_ comment: Comment) async {
        guard let commentId = comment.id else { return }
        do {
            try await firestoreService.deleteComment(postId: postId, commentId: commentId)
            post?.commentCount = max(0, (post?.commentCount ?? 1) - 1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canDelete(_ comment: Comment) -> Bool {
        guard let uid = authService.currentUserId else { return false }
        return comment.authorId == uid || isOwnPost
    }

    func updateCaption(_ caption: String?) async -> Bool {
        do {
            try await firestoreService.updatePostCaption(postId: postId, caption: caption)
            post?.caption = caption
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true on success so the view can dismiss.
    func deletePost() async -> Bool {
        guard let uid = authService.currentUserId else { return false }
        do {
            try await firestoreService.deletePost(postId: postId, authorId: uid)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
