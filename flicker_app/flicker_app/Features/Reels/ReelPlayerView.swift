import SwiftUI

/// One page of the Reels feed — full-bleed looping video with a
/// TikTok/Reels-style overlay: author + caption bottom-left, like/comment
/// actions bottom-right, tap-to-mute anywhere else.
struct ReelPlayerView: View {
    let post: Post
    let isActive: Bool
    let isLiked: Bool
    let onToggleLike: () -> Void
    let onOpenComments: () -> Void
    let onOpenAuthor: () -> Void

    @State private var isMuted = true

    var body: some View {
        ZStack {
            Color.black

            if let urlString = post.mediaURLs.first, let url = URL(string: urlString) {
                LoopingVideoPlayerView(url: url, isMuted: isMuted, isPlaying: isActive)
            }

            gradientOverlay

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    captionBlock
                    Spacer()
                    actionRail
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isMuted.toggle() }
        .overlay(alignment: .topTrailing) {
            if isMuted {
                Image(systemName: "speaker.slash.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(.top, 12)
                    .padding(.trailing, 16)
            }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .clear, .black.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onOpenAuthor) {
                Text("@\(post.authorUsername)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 240, alignment: .leading)
    }

    private var actionRail: some View {
        VStack(spacing: 20) {
            Button(action: onToggleLike) {
                VStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(isLiked ? .red : .white)
                    Text("\(post.likeCount)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
            }
            Button(action: onOpenComments) {
                VStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("\(post.commentCount)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
