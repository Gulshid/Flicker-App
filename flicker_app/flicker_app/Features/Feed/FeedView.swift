import SwiftUI

/// The Home tab as of Phase 5/6 — replaces the "signed in" placeholder
/// that lived in MainTabView. Segmented "Following" / "Discover" control
/// at the top backs the two feed query modes in FirestoreService.
struct FeedView: View {
    /// All sheet presentations for this screen are routed through this
    /// single piece of state (rather than 2-3 separate optionals/bools,
    /// each with its own `.sheet` modifier). Multiple independent `.sheet`
    /// modifiers in the same NavigationStack branch can get their
    /// presentation contexts crossed by SwiftUI — e.g. tapping a post's
    /// author would sometimes present the post-detail sheet instead of
    /// the profile sheet. One enum + one `.sheet(item:)` removes that
    /// ambiguity entirely.
    private enum FeedSheet: Identifiable {
        case createPost
        case author(String)
        case postDetail(String)

        var id: String {
            switch self {
            case .createPost: return "createPost"
            case .author(let id): return "author-\(id)"
            case .postDetail(let id): return "postDetail-\(id)"
            }
        }
    }

    @State private var viewModel = FeedViewModel()
    @State private var activeSheet: FeedSheet?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StoryTrayView()
                Divider()

                Group {
                    if viewModel.posts.isEmpty && viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Feed", selection: $viewModel.tab) {
                        ForEach(FeedTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .createPost
                    } label: {
                        Image(systemName: "plus.square")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .createPost:
                    CreatePostView { newPost in
                        viewModel.prependNewPost(newPost)
                    }
                case .author(let userId):
                    UserProfileView(userId: userId)
                case .postDetail(let postId):
                    PostDetailView(postId: postId)
                }
            }
            .task { await viewModel.loadInitialIfNeeded() }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCardView(
                        post: post,
                        isLiked: viewModel.likedPostIds.contains(post.postId),
                        onToggleLike: { Task { await viewModel.toggleLike(on: post) } },
                        onOpenDetail: { activeSheet = .postDetail(post.postId) },
                        onOpenAuthor: { activeSheet = .author(post.authorId) }
                    )
                    .task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                    Divider()
                }

                if viewModel.isLoading && !viewModel.posts.isEmpty {
                    ProgressView().padding()
                }
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.tab == .following ? "person.2" : "photo.on.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(viewModel.tab == .following ? "No posts from people you follow yet" : "No posts yet")
                .font(.headline)
            if viewModel.tab == .following {
                Text("Switch to Discover to find people to follow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
