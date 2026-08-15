import SwiftUI

struct CommentRowView: View {
    let comment: Comment
    let canDelete: Bool
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                (Text("@\(comment.authorUsername) ").font(.footnote.weight(.semibold)) + Text(comment.text).font(.footnote))
                Text(comment.createdAt.relativeTimeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .swipeActions(edge: .trailing) {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = comment.authorAvatarURL,
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 60)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            placeholder.frame(width: 28, height: 28)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").font(.caption2).foregroundStyle(.secondary))
    }
}
