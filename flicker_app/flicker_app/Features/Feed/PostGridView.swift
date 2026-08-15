import SwiftUI

/// The 3-column thumbnail grid of one author's posts, used at the bottom
/// of both `ProfileView` (own profile) and `UserProfileView` (someone
/// else's). Owns its own pagination via `fetchUserPosts` so it can be
/// dropped into either screen without the parent view needing to know
/// anything about post loading.
struct PostGridView: View {
    let authorId: String

    @State private var posts: [Post] = []
    @State private var cursor: FeedCursor?
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var hasMorePages = true
    @State private var selectedPost: Post?

    private let firestoreService: FirestoreServiceProtocol

    init(authorId: String, firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService) {
        self.authorId = authorId
        self.firestoreService = firestoreService
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        Group {
            if hasLoadedOnce && posts.isEmpty {
                Text("No posts yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(posts) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            thumbnail(for: post)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if post.id == posts.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
        }
        .task(id: authorId) {
            // Reset and reload whenever we're pointed at a different
            // author (e.g. UserProfileView navigating between profiles).
            posts = []
            cursor = nil
            hasLoadedOnce = false
            hasMorePages = true
            await loadMore()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(postId: post.postId)
        }
    }

    @ViewBuilder
    private func thumbnail(for post: Post) -> some View {
        if let urlString = post.mediaURLs.first.map({ CloudinaryTransformation.thumbnail($0, size: 300) }),
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
        } else {
            Color.secondary.opacity(0.1)
                .aspectRatio(1, contentMode: .fill)
        }
    }

    private func loadMore() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }
        do {
            let page = try await firestoreService.fetchUserPosts(authorId: authorId, cursor: cursor, pageSize: 21)
            posts.append(contentsOf: page.posts)
            cursor = page.nextCursor
            hasMorePages = page.nextCursor != nil
        } catch {
            // Grid fails silently into an empty state — the parent
            // profile screen already surfaces load errors for the
            // profile doc itself, and a broken grid shouldn't block that.
        }
    }
}
