import FirebaseFirestore

/// Which query powers a feed page. `.following` needs the caller's list of
/// followed author IDs up front — see `FeedViewModel`, which fetches that
/// via `fetchFollowingIds` before requesting the first page.
enum FeedType {
    case discover
    case following(authorIds: [String])
}

/// Opaque pagination cursor returned by `fetchFeed`/`fetchUserPosts`. Wraps
/// the underlying `DocumentSnapshot` so pagination stays cursor-based
/// (`.start(afterDocument:)`) without leaking Firestore's query API into
/// ViewModels — they just pass the cursor they were handed back in for the
/// next page.
struct FeedCursor {
    fileprivate let snapshot: DocumentSnapshot
}

protocol FirestoreServiceProtocol {
    // Username / onboarding
    func isUsernameAvailable(_ username: String) async throws -> Bool
    func userExists(_ uid: String) async throws -> Bool

    // Profile (Phase 3)
    func createUserProfile(uid: String, username: String) async throws
    func fetchUser(_ uid: String) async throws -> AppUser
    func updateUserProfile(uid: String, bio: String?, avatarURL: String?) async throws

    // Posts (Phase 5)
    func createPost(authorId: String, authorUsername: String, authorAvatarURL: String?, mediaURLs: [String], caption: String?) async throws -> Post
    func fetchFeed(type: FeedType, cursor: FeedCursor?, pageSize: Int) async throws -> (posts: [Post], nextCursor: FeedCursor?)
    func fetchUserPosts(authorId: String, cursor: FeedCursor?, pageSize: Int) async throws -> (posts: [Post], nextCursor: FeedCursor?)
    func fetchPost(_ postId: String) async throws -> Post
    func updatePostCaption(postId: String, caption: String?) async throws
    func deletePost(postId: String, authorId: String) async throws

    // Likes (Phase 6)
    func toggleLike(postId: String, userId: String) async throws -> Bool
    func fetchLikedPostIds(userId: String, among postIds: [String]) async throws -> Set<String>

    // Comments (Phase 6)
    func addComment(postId: String, authorId: String, authorUsername: String, authorAvatarURL: String?, text: String) async throws
    func deleteComment(postId: String, commentId: String) async throws
    func observeComments(postId: String) -> AsyncStream<[Comment]>

    // Follow graph (Phase 6)
    func follow(currentUserId: String, targetUserId: String) async throws
    func unfollow(currentUserId: String, targetUserId: String) async throws
    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool
    func fetchFollowingIds(userId: String, limit: Int) async throws -> [String]
}

/// Thin wrapper around Firestore. Collection layout mirrors the schema in
/// Phase 3 of the roadmap — only the `users` collection is fully wired up
/// here; the rest are declared as constants now so every later phase
/// (posts, follows, likes, comments, chats) writes to the same paths
/// instead of each feature inventing its own naming.
final class FirestoreService: FirestoreServiceProtocol {
    private let db = Firestore.firestore()

    // MARK: - Collection paths (schema reference, Phase 3)
    // users/{uid}
    // users/{uid}/followers/{followerId}
    // users/{uid}/following/{followingId}
    // posts/{postId}
    // posts/{postId}/likes/{userId}
    // posts/{postId}/comments/{commentId}
    // chats/{chatId}/messages/{messageId}
    private enum Collection {
        static let users = "users"
        static let followers = "followers"
        static let following = "following"
        static let posts = "posts"
        static let likes = "likes"
        static let comments = "comments"
        static let chats = "chats"
        static let messages = "messages"
        // users/{uid}/likedPosts/{postId} — reverse index of the source-of-truth
        // posts/{postId}/likes/{uid} doc, added in Phase 6. Lets the feed answer
        // "which of these posts did I like" with one batched query instead of
        // one read per post — see fetchLikedPostIds.
        static let likedPosts = "likedPosts"
    }

    private func userDoc(_ uid: String) -> DocumentReference {
        db.collection(Collection.users).document(uid)
    }

    private func postDoc(_ postId: String) -> DocumentReference {
        db.collection(Collection.posts).document(postId)
    }

    // MARK: - Username

    /// Checks the `usernameLowercase` field so lookups are case-insensitive.
    /// Storing this field alongside the display username from day one is
    /// what makes prefix-based search possible later (Phase 9).
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let lowered = username.lowercased()
        let snapshot = try await db.collection(Collection.users)
            .whereField("usernameLowercase", isEqualTo: lowered)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.isEmpty
    }

    func userExists(_ uid: String) async throws -> Bool {
        let snapshot = try await userDoc(uid).getDocument()
        return snapshot.exists
    }

    // MARK: - Profile (Phase 3)

    /// Creates the users/{uid} document right after a username is reserved.
    /// Uses a single denormalized document so a profile screen or a feed
    /// row only ever needs one read.
    func createUserProfile(uid: String, username: String) async throws {
        let user = AppUser(
            id: uid,
            username: username,
            usernameLowercase: username.lowercased(),
            bio: nil,
            avatarURL: nil,
            followerCount: 0,
            followingCount: 0,
            postCount: 0,
            createdAt: Date()
        )
        do {
            // The async/throws overload is used deliberately (not the
            // fire-and-forget sync one) so this only returns once the
            // write has actually landed — callers immediately check for
            // the document's existence (see SessionStore.refreshProfileStatus),
            // so a fire-and-forget write would race against that read.
            try await userDoc(uid).setData(from: user, merge: false)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func fetchUser(_ uid: String) async throws -> AppUser {
        let snapshot = try await userDoc(uid).getDocument()
        guard snapshot.exists else {
            throw AppError.notFound("Profile not found.")
        }
        do {
            return try snapshot.data(as: AppUser.self)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Partial update — only writes the fields that changed so an edit
    /// that only touches the avatar doesn't also rewrite the bio, and
    /// vice versa. Keeps writes cheap against the free-tier quota.
    func updateUserProfile(uid: String, bio: String?, avatarURL: String?) async throws {
        var fields: [String: Any] = [:]
        if let bio { fields["bio"] = bio }
        if let avatarURL { fields["avatarURL"] = avatarURL }
        guard !fields.isEmpty else { return }
        do {
            try await userDoc(uid).updateData(fields)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    // MARK: - Posts (Phase 5)

    /// Writes the post doc and bumps the author's `postCount` in one
    /// batch so the two never drift out of sync. Firestore assigns the
    /// ID up front via `.document()` so it can be embedded in the post
    /// itself (denormalized, same reasoning as `authorUsername`) and
    /// handed straight back to the caller.
    func createPost(
        authorId: String,
        authorUsername: String,
        authorAvatarURL: String?,
        mediaURLs: [String],
        caption: String?
    ) async throws -> Post {
        guard !mediaURLs.isEmpty else {
            throw AppError.invalidInput("A post needs at least one photo or video.")
        }
        let ref = db.collection(Collection.posts).document()
        let post = Post(
            id: ref.documentID,
            authorId: authorId,
            authorUsername: authorUsername,
            authorAvatarURL: authorAvatarURL,
            mediaURLs: mediaURLs,
            caption: caption,
            likeCount: 0,
            commentCount: 0,
            createdAt: Date()
        )
        do {
            let batch = db.batch()
            try batch.setData(from: post, forDocument: ref)
            batch.updateData(["postCount": FieldValue.increment(Int64(1))], forDocument: userDoc(authorId))
            try await batch.commit()
            return post
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Powers both the "Discover" and "Following" tabs in FeedView.
    /// `.following` needs the caller's followed-author IDs up front
    /// (see `fetchFollowingIds`) since Firestore has no server-side join —
    /// and since `whereField(_:in:)` caps out at 30 values, only the 30
    /// most-recently-followed authors show up in that feed. Fine at
    /// hobby-app scale; a fan-out-on-write timeline is the real fix later.
    ///
    /// Note: the `.following` case's `whereField(authorId, in:)` combined
    /// with `.order(by: createdAt)` needs a composite index — Firestore
    /// will log a console error with a one-click link to create it the
    /// first time this runs against a real project.
    func fetchFeed(
        type: FeedType,
        cursor: FeedCursor?,
        pageSize: Int = 10
    ) async throws -> (posts: [Post], nextCursor: FeedCursor?) {
        var query: Query
        switch type {
        case .discover:
            query = db.collection(Collection.posts).order(by: "createdAt", descending: true)
        case .following(let authorIds):
            guard !authorIds.isEmpty else { return ([], nil) }
            query = db.collection(Collection.posts)
                .whereField("authorId", in: Array(authorIds.prefix(30)))
                .order(by: "createdAt", descending: true)
        }
        return try await runPagedPostQuery(query, cursor: cursor, pageSize: pageSize)
    }

    /// Same shape as `fetchFeed`, scoped to one author — backs the posts
    /// grid on a profile screen (own or someone else's).
    func fetchUserPosts(
        authorId: String,
        cursor: FeedCursor?,
        pageSize: Int = 21
    ) async throws -> (posts: [Post], nextCursor: FeedCursor?) {
        let query = db.collection(Collection.posts)
            .whereField("authorId", isEqualTo: authorId)
            .order(by: "createdAt", descending: true)
        return try await runPagedPostQuery(query, cursor: cursor, pageSize: pageSize)
    }

    private func runPagedPostQuery(
        _ baseQuery: Query,
        cursor: FeedCursor?,
        pageSize: Int
    ) async throws -> (posts: [Post], nextCursor: FeedCursor?) {
        var query = baseQuery
        if let cursor {
            query = query.start(afterDocument: cursor.snapshot)
        }
        query = query.limit(to: pageSize)
        do {
            let snapshot = try await query.getDocuments()
            let posts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
            // Only hand back a cursor if the page was full — a short page
            // means we've hit the end, so the caller can stop paginating.
            let nextCursor = (snapshot.documents.count == pageSize)
                ? snapshot.documents.last.map { FeedCursor(snapshot: $0) }
                : nil
            return (posts, nextCursor)
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func fetchPost(_ postId: String) async throws -> Post {
        do {
            let snapshot = try await postDoc(postId).getDocument()
            guard snapshot.exists else { throw AppError.notFound("This post is no longer available.") }
            return try snapshot.data(as: Post.self)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func updatePostCaption(postId: String, caption: String?) async throws {
        // `nil` clears the caption entirely — FieldValue.delete() removes
        // the field rather than writing an Optional.none through as a
        // raw Any, which Firestore's Codable bridge doesn't handle.
        let value: Any = caption ?? FieldValue.delete()
        do {
            try await postDoc(postId).updateData(["caption": value])
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Deletes the post document and decrements the author's `postCount`.
    /// Note: this does NOT cascade-delete the `likes`/`comments`
    /// subcollections — Firestore never does that automatically, and
    /// bulk-deleting a subcollection from the client is expensive against
    /// the free-tier quota. Cleaning those up is a good fit for a
    /// scheduled Cloud Function once the project moves off Spark
    /// (Phase 11+); the orphaned docs are harmless until then since
    /// nothing can query into a deleted post's subcollections.
    func deletePost(postId: String, authorId: String) async throws {
        do {
            let batch = db.batch()
            batch.deleteDocument(postDoc(postId))
            batch.updateData(["postCount": FieldValue.increment(Int64(-1))], forDocument: userDoc(authorId))
            try await batch.commit()
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    // MARK: - Likes (Phase 6)

    /// Toggles posts/{postId}/likes/{userId} (source of truth) and the
    /// mirrored users/{userId}/likedPosts/{postId} (reverse index, see
    /// `fetchLikedPostIds`) together, and bumps `likeCount` via
    /// `FieldValue.increment` rather than reading-then-writing the count —
    /// this is exactly the counter pattern the roadmap calls for to avoid
    /// needing a Cloud Function on the Spark plan. Wrapped in a
    /// transaction so two rapid taps (or a retry) can't double-count.
    /// Returns the resulting liked state; the caller already knows the
    /// old count locally and can adjust it by ±1 without an extra read.
    func toggleLike(postId: String, userId: String) async throws -> Bool {
        let likeRef = postDoc(postId).collection(Collection.likes).document(userId)
        let reverseRef = userDoc(userId).collection(Collection.likedPosts).document(postId)
        let postRef = postDoc(postId)

        do {
            let result = try await db.runTransaction { transaction, errorPointer -> Any? in
                let likeSnapshot: DocumentSnapshot
                do {
                    likeSnapshot = try transaction.getDocument(likeRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                if likeSnapshot.exists {
                    transaction.deleteDocument(likeRef)
                    transaction.deleteDocument(reverseRef)
                    transaction.updateData(["likeCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
                    return false
                } else {
                    transaction.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: likeRef)
                    transaction.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: reverseRef)
                    transaction.updateData(["likeCount": FieldValue.increment(Int64(1))], forDocument: postRef)
                    return true
                }
            }
            return (result as? Bool) ?? false
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Batched "did I like any of these posts" lookup for a feed page —
    /// one query per 30 posts via the `likedPosts` reverse index instead
    /// of one read per post.
    func fetchLikedPostIds(userId: String, among postIds: [String]) async throws -> Set<String> {
        guard !postIds.isEmpty else { return [] }
        var result = Set<String>()
        do {
            for chunk in postIds.chunked(into: 30) {
                let snapshot = try await userDoc(userId).collection(Collection.likedPosts)
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                result.formUnion(snapshot.documents.map { $0.documentID })
            }
            return result
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    // MARK: - Comments (Phase 6)

    func addComment(
        postId: String,
        authorId: String,
        authorUsername: String,
        authorAvatarURL: String?,
        text: String
    ) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.invalidInput("Comment can't be empty.")
        }
        let ref = postDoc(postId).collection(Collection.comments).document()
        let comment = Comment(
            id: ref.documentID,
            authorId: authorId,
            authorUsername: authorUsername,
            authorAvatarURL: authorAvatarURL,
            text: trimmed,
            createdAt: Date()
        )
        do {
            try await ref.setData(from: comment)
            try await postDoc(postId).updateData(["commentCount": FieldValue.increment(Int64(1))])
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func deleteComment(postId: String, commentId: String) async throws {
        do {
            try await postDoc(postId).collection(Collection.comments).document(commentId).delete()
            try await postDoc(postId).updateData(["commentCount": FieldValue.increment(Int64(-1))])
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Real-time comment stream for a post's detail view — matches the
    /// architecture doc's "AsyncStream for Firestore listeners" pattern.
    /// The listener is torn down automatically when the consuming
    /// `for await` loop's Task is cancelled (e.g. the view disappears),
    /// via `onTermination`.
    func observeComments(postId: String) -> AsyncStream<[Comment]> {
        AsyncStream { continuation in
            let listener = postDoc(postId).collection(Collection.comments)
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot else {
                        continuation.yield([])
                        return
                    }
                    let comments = snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
                    continuation.yield(comments)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // MARK: - Follow graph (Phase 6)

    /// Writes both sides of the edge (users/{me}/following/{them} and
    /// users/{them}/followers/{me}) plus both denormalized counters in
    /// one batch, so the graph and the counts on each profile can never
    /// disagree with each other.
    func follow(currentUserId: String, targetUserId: String) async throws {
        guard currentUserId != targetUserId else {
            throw AppError.invalidInput("You can't follow yourself.")
        }
        let followingRef = userDoc(currentUserId).collection(Collection.following).document(targetUserId)
        let followerRef = userDoc(targetUserId).collection(Collection.followers).document(currentUserId)
        do {
            let batch = db.batch()
            batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: followingRef)
            batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: followerRef)
            batch.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: userDoc(currentUserId))
            batch.updateData(["followerCount": FieldValue.increment(Int64(1))], forDocument: userDoc(targetUserId))
            try await batch.commit()
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func unfollow(currentUserId: String, targetUserId: String) async throws {
        let followingRef = userDoc(currentUserId).collection(Collection.following).document(targetUserId)
        let followerRef = userDoc(targetUserId).collection(Collection.followers).document(currentUserId)
        do {
            let batch = db.batch()
            batch.deleteDocument(followingRef)
            batch.deleteDocument(followerRef)
            batch.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: userDoc(currentUserId))
            batch.updateData(["followerCount": FieldValue.increment(Int64(-1))], forDocument: userDoc(targetUserId))
            try await batch.commit()
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool {
        do {
            let snapshot = try await userDoc(currentUserId).collection(Collection.following).document(targetUserId).getDocument()
            return snapshot.exists
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }

    /// Most-recently-followed first, capped at `limit` (default 30) since
    /// that's the max Firestore's `in` operator accepts — see the note on
    /// `fetchFeed`'s `.following` case.
    func fetchFollowingIds(userId: String, limit: Int = 30) async throws -> [String] {
        do {
            let snapshot = try await userDoc(userId).collection(Collection.following)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.map { $0.documentID }
        } catch {
            throw AppError.firestoreError(error.localizedDescription)
        }
    }
}
