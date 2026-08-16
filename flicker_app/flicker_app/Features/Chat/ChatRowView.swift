import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    let currentUserId: String

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(chat.otherParticipantUsername(currentUserId: currentUserId))")
                    .font(.subheadline.weight(chat.isUnread(for: currentUserId) ? .bold : .semibold))
                Text(chat.lastMessageText ?? "Say hi 👋")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(chat.lastMessageAt.relativeTimeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if chat.isUnread(for: currentUserId) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = chat.otherParticipantAvatarURL(currentUserId: currentUserId),
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 100)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            avatarPlaceholder.frame(width: 44, height: 44)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
    }
}
