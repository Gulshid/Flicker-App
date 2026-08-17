import SwiftUI

/// The Reels tab, new in Phase 10. A vertically paged, full-screen video
/// feed built on iOS 17's native paging scroll (`.scrollTargetBehavior`
/// + `.scrollPosition`) — the project already targets iOS 16/17 and uses
/// `@Observable` elsewhere, so this needs no extra minimum-version bump
/// and no `UIPageViewController` bridging.
struct ReelsView: View {
    @State private var viewModel = ReelsViewModel()
    @State private var selectedPostId: String?
    @State private var authorToView: String?
    @State private var detailPostId: IdentifiableString?
    @State private var showCreateReel = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.posts.isEmpty && viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    pager
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateReel = true
                    } label: {
                        Image(systemName: "video.badge.plus")
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateReel) {
                CreateReelView { newPost in
                    viewModel.posts.insert(newPost, at: 0)
                }
            }
            .sheet(item: Binding(
                get: { authorToView.map { IdentifiableString(value: $0) } },
                set: { authorToView = $0?.value }
            )) { wrapped in
                UserProfileView(userId: wrapped.value)
            }
            .sheet(item: $detailPostId) { wrapped in
                PostDetailView(postId: wrapped.value)
            }
            .task {
                await viewModel.loadInitialIfNeeded()
                if selectedPostId == nil {
                    selectedPostId = viewModel.posts.first?.id
                }
            }
        }
        .background(Color.black)
    }

    private var pager: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        ReelPlayerView(
                            post: post,
                            isActive: post.id == selectedPostId,
                            isLiked: viewModel.likedPostIds.contains(post.postId),
                            onToggleLike: { Task { await viewModel.toggleLike(on: post) } },
                            onOpenComments: { detailPostId = IdentifiableString(value: post.postId) },
                            onOpenAuthor: { authorToView = post.authorId }
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .id(post.id)
                        .task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedPostId)
            .scrollIndicators(.hidden)
        }
        .ignoresSafeArea()
        .background(Color.black)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.6))
            Text("No reels yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tap the camera icon to post the first one.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
