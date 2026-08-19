import SwiftUI

/// The Search tab, new in Phase 9. A search field drives username
/// results (`AppUser.usernameLowercase` prefix query); with the field
/// empty it falls back to an Explore grid of the most-liked posts
/// app-wide, same visual shape as `PostGridView`.
struct SearchView: View {
    /// Single source of truth for this screen's sheet, instead of two
    /// separate optionals each with their own `.sheet` modifier — see
    /// FeedView's FeedSheet for why: multiple `.sheet` modifiers in the
    /// same NavigationStack can get their presentation contexts crossed,
    /// so tapping a user could end up opening the post-detail sheet.
    private enum SearchSheet: Identifiable {
        case author(String)
        case postDetail(String)

        var id: String {
            switch self {
            case .author(let id): return "author-\(id)"
            case .postDetail(let id): return "postDetail-\(id)"
            }
        }
    }

    @State private var viewModel = SearchViewModel()
    @State private var activeSheet: SearchSheet?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearchActive {
                    searchResults
                } else {
                    exploreGrid
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.queryText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search people")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .author(let userId):
                    UserProfileView(userId: userId)
                case .postDetail(let postId):
                    PostDetailView(postId: postId)
                }
            }
            .task { await viewModel.loadExploreIfNeeded() }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isSearching && viewModel.userResults.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.userResults.isEmpty {
            ContentUnavailableView.search
        } else {
            List(viewModel.userResults) { user in
                Button {
                    activeSheet = .author(user.id)
                } label: {
                    UserSearchRowView(user: user)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private var exploreGrid: some View {
        ScrollView {
            if viewModel.explorePosts.isEmpty && viewModel.isLoadingExplore {
                ProgressView().padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(viewModel.explorePosts) { post in
                        Button {
                            activeSheet = .postDetail(post.postId)
                        } label: {
                            exploreThumbnail(for: post)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if post.id == viewModel.explorePosts.last?.id {
                                Task { await viewModel.loadMoreExplore() }
                            }
                        }
                    }
                }

                if viewModel.isLoadingExplore && !viewModel.explorePosts.isEmpty {
                    ProgressView().padding(.vertical, 16)
                }
            }
        }
        .refreshable { await viewModel.refreshExplore() }
    }

    @ViewBuilder
    private func exploreThumbnail(for post: Post) -> some View {
        // Same issue as PostGridView: `thumbnail(...)` assumes an image
        // delivery path and can't decode an mp4, which is why video
        // cells were rendering blank even though the video badge showed
        // correctly. `videoThumbnail` extracts a real JPEG frame instead.
        let rawURL = post.isVideo
            ? post.mediaURLs.first.map { CloudinaryTransformation.videoThumbnail($0, size: 300) }
            : post.mediaURLs.first.map { CloudinaryTransformation.thumbnail($0, size: 300) }

        ZStack(alignment: .topTrailing) {
            if let urlString = rawURL, let url = URL(string: urlString) {
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

            if post.isVideo {
                Image(systemName: "video.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(4)
                    .shadow(radius: 2)
            }
        }
    }
}
