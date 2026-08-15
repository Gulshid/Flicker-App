import SwiftUI

/// One post in the feed: author header, media carousel, like/comment
/// actions, and caption. Used by both FeedView and (read-only variants
/// aside) PostDetailView reuses the same media/header building blocks.
struct PostCardView: View {
    let post: Post
    let isLiked: Bool
    var onToggleLike: () -> Void
    var onOpenDetail: () -> Void
    var onOpenAuthor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            media
                .onTapGesture(count: 2) { onToggleLike() }
            actions
            captionAndMeta
        }
        .padding(.vertical, 10)
    }

    private var header: some View {
        Button(action: onOpenAuthor) {
            HStack(spacing: 10) {
                avatar
                Text("@\(post.authorUsername)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(post.createdAt.relativeTimeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = post.authorAvatarURL,
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 80)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            avatarPlaceholder.frame(width: 32, height: 32)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").font(.caption).foregroundStyle(.secondary))
    }

    @ViewBuilder
    private var media: some View {
        Button(action: onOpenDetail) {
            if post.mediaURLs.count == 1 {
                mediaImage(post.mediaURLs[0])
            } else {
                TabView {
                    ForEach(post.mediaURLs, id: \.self) { url in
                        mediaImage(url)
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 360)
            }
        }
        .buttonStyle(.plain)
    }

    private func mediaImage(_ urlString: String) -> some View {
        Group {
            if let url = URL(string: CloudinaryTransformation.fullResolution(urlString)) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Color.secondary.opacity(0.1)
                            .overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary))
                    } else {
                        Color.secondary.opacity(0.1)
                            .overlay(ProgressView())
                    }
                }
            } else {
                Color.secondary.opacity(0.1)
            }
        }
        .frame(height: 360)
        .clipped()
    }

    private var actions: some View {
        HStack(spacing: 18) {
            Button(action: onToggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? .red : .primary)
            }
            Button(action: onOpenDetail) {
                Image(systemName: "bubble.right")
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .font(.title3)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var captionAndMeta: some View {
        VStack(alignment: .leading, spacing: 4) {
            if post.likeCount > 0 {
                Text("\(post.likeCount) \(post.likeCount == 1 ? "like" : "likes")")
                    .font(.footnote.weight(.semibold))
            }
            if let caption = post.caption, !caption.isEmpty {
                (Text("@\(post.authorUsername) ").font(.footnote.weight(.semibold)) + Text(caption).font(.footnote))
            }
            if post.commentCount > 0 {
                Button(action: onOpenDetail) {
                    Text("View all \(post.commentCount) comments")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
