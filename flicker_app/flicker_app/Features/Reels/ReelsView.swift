import SwiftUI

/// The Reels tab, new in Phase 10. A vertically paged, full-screen video
/// feed built on iOS 17's native paging scroll (`.scrollTargetBehavior`
/// + `.scrollPosition`) — the project already targets iOS 16/17 and uses
/// `@Observable` elsewhere, so this needs no extra minimum-version bump
/// and no `UIPageViewController` bridging.
struct ReelsView: View {
    /// Single source of truth for this screen's sheet, instead of two
    /// separate optionals each with their own `.sheet` modifier — see
    /// FeedView's FeedSheet for why: multiple `.sheet` modifiers in the
    /// same NavigationStack can get their presentation contexts crossed,
    /// so tapping a reel's author could end up opening the comments
    /// sheet instead of the profile sheet.
    private enum ReelsSheet: Identifiable {
        case createReel
        case author(String)
        case postDetail(String)

        var id: String {
            switch self {
            case .createReel: return "createReel"
            case .author(let id): return "author-\(id)"
            case .postDetail(let id): return "postDetail-\(id)"
            }
        }
    }

    @State private var viewModel = ReelsViewModel()
    @State private var selectedPostId: String?
    @State private var activeSheet: ReelsSheet?

    var body: some View {
        NavigationStack {
            mainContent
                .toolbar { toolbarContent }
                .toolbarBackground(.hidden, for: .navigationBar)
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .createReel:
                        createReelSheet
                    case .author(let userId):
                        UserProfileView(userId: userId)
                    case .postDetail(let postId):
                        PostDetailView(postId: postId)
                    }
                }
                .task { await loadInitialIfNeeded() }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var mainContent: some View {
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeSheet = .createReel
            } label: {
                Image(systemName: "video.badge.plus")
                    .foregroundStyle(.white)
            }
        }
    }

    private var createReelSheet: some View {
        CreateReelView { newPost in
            viewModel.prepend(newPost)
        }
    }

    private func loadInitialIfNeeded() async {
        await viewModel.loadInitialIfNeeded()
        if selectedPostId == nil {
            selectedPostId = viewModel.posts.first?.id
        }
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
                            onOpenComments: { activeSheet = .postDetail(post.postId) },
                            onOpenAuthor: { activeSheet = .author(post.authorId) }
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
