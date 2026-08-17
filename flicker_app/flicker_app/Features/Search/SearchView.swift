import SwiftUI

/// The Search tab, new in Phase 9. A search field drives username
/// results (`AppUser.usernameLowercase` prefix query); with the field
/// empty it falls back to an Explore grid of the most-liked posts
/// app-wide, same visual shape as `PostGridView`.
struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var authorToView: String?
    @State private var detailPostId: IdentifiableString?

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
            .sheet(item: Binding(
                get: { authorToView.map { IdentifiableString(value: $0) } },
                set: { authorToView = $0?.value }
            )) { wrapped in
                UserProfileView(userId: wrapped.value)
            }
            .sheet(item: $detailPostId) { wrapped in
                PostDetailView(postId: wrapped.value)
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
                    authorToView = user.id
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
                            detailPostId = IdentifiableString(value: post.postId)
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
        ZStack(alignment: .topTrailing) {
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
