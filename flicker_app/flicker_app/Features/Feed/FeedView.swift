import SwiftUI

/// The Home tab as of Phase 5/6 — replaces the "signed in" placeholder
/// that lived in MainTabView. Segmented "Following" / "Discover" control
/// at the top backs the two feed query modes in FirestoreService.
struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showCreatePost = false
    @State private var authorToView: String?
    @State private var detailPostId: IdentifiableString?

    var body: some View {
        NavigationStack {
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
                        showCreatePost = true
                    } label: {
                        Image(systemName: "plus.square")
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView { newPost in
                    viewModel.prependNewPost(newPost)
                }
            }
            .sheet(item: Binding(
                get: { authorToView.map { IdentifiableString(value: $0) } },
                set: { authorToView = $0?.value }
            )) { wrapped in
                UserProfileView(userId: wrapped.value)
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
                        onOpenDetail: { openDetail(post) },
                        onOpenAuthor: { authorToView = post.authorId }
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
        .sheet(item: $detailPostId) { wrapped in
            PostDetailView(postId: wrapped.value)
        }
    }

    // Wrapping in an Identifiable box since PostDetailView is presented
    // by post ID (it refetches on appear), not by a whole Post value.
    private func openDetail(_ post: Post) {
        detailPostId = IdentifiableString(value: post.postId)
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

/// Small helper so `String` post/author IDs can be used with `.sheet(item:)`.
struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}
