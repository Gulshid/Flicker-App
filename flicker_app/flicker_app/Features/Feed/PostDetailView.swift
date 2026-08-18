import SwiftUI

/// Full post view: media, caption, like/comment counts, a live comment
/// list (real-time via observeComments), and a comment composer. Owner
/// gets edit-caption/delete actions in the toolbar.
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PostDetailViewModel
    @State private var showEditCaption = false
    @State private var showDeleteConfirm = false
    @FocusState private var commentFieldFocused: Bool

    init(postId: String) {
        _viewModel = State(initialValue: PostDetailViewModel(postId: postId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let post = viewModel.post {
                    content(for: post)
                } else if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Couldn't load post",
                        systemImage: "exclamationmark.triangle",
                        description: Text(viewModel.errorMessage ?? "")
                    )
                }
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if viewModel.isOwnPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit Caption") { showEditCaption = true }
                            Button("Delete Post", role: .destructive) { showDeleteConfirm = true }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditCaption) {
                if let post = viewModel.post {
                    EditPostView(caption: post.caption) { newCaption in
                        Task { _ = await viewModel.updateCaption(newCaption) }
                    }
                }
            }
            .confirmationDialog(
                "Delete this post?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.deletePost() { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .task { await viewModel.load() }
        .onDisappear { viewModel.stopObservingComments() }
    }

    @ViewBuilder
    private func content(for post: Post) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    postMedia(post)

                    HStack(spacing: 18) {
                        Button {
                            Task { await viewModel.toggleLike() }
                        } label: {
                            Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(viewModel.isLiked ? .red : .primary)
                        }
                        Image(systemName: "bubble.right")
                        Spacer()
                    }
                    .font(.title3)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    if post.likeCount > 0 {
                        Text("\(post.likeCount) \(post.likeCount == 1 ? "like" : "likes")")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                    }

                    if let caption = post.caption, !caption.isEmpty {
                        (Text("@\(post.authorUsername) ").font(.footnote.weight(.semibold)) + Text(caption).font(.footnote))
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                    }

                    Text(post.createdAt.relativeTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)

                    Divider().padding(.top, 12)

                    comments
                }
            }

            Divider()
            commentComposer
        }
    }

    @ViewBuilder
    private func postMedia(_ post: Post) -> some View {
        // No wrapping Group here — this function is already @ViewBuilder,
        // and stacking Group's own generic inference on top of that for
        // two very differently-modified branches (a single image vs. a
        // heavily-modified TabView) is what was tripping up the type
        // checker ("Generic parameter 'V' could not be inferred").
        if post.mediaURLs.count == 1 {
            mediaImage(post.mediaURLs[0])
        } else {
            TabView {
                ForEach(post.mediaURLs, id: \.self) { mediaImage($0) }
            }
            .tabViewStyle(.page)
            .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
        }
    }

    private func mediaImage(_ urlString: String) -> some View {
        Group {
            if let url = URL(string: CloudinaryTransformation.fullResolution(urlString)) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.secondary.opacity(0.1).overlay(ProgressView())
                    }
                }
            } else {
                Color.secondary.opacity(0.1)
            }
        }
        // maxWidth: .infinity is required here — without it, scaledToFit
        // sizes the image to its native aspect ratio at the fixed height
        // instead of stretching to the screen width, leaving a gap on
        // the trailing edge.
        .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
        .clipped()
    }

    private var comments: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            if viewModel.comments.isEmpty {
                Text("No comments yet — be the first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            ForEach(viewModel.comments) { comment in
                CommentRowView(
                    comment: comment,
                    canDelete: viewModel.canDelete(comment),
                    onDelete: { Task { await viewModel.deleteComment(comment) } }
                )
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
    }

    private var commentComposer: some View {
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $viewModel.newCommentText, axis: .vertical)
                .lineLimit(1...4)
                .focused($commentFieldFocused)
            Button("Post") {
                Task { await viewModel.postComment() }
            }
            .font(.footnote.weight(.semibold))
            .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPostingComment)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
