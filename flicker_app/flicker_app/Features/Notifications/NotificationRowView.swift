import SwiftUI

struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                (Text("@\(notification.actorUsername) ").font(.footnote.weight(.semibold))
                    + Text(notification.message).font(.footnote))
                Text(notification.createdAt.relativeTimeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !notification.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = notification.actorAvatarURL,
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 80)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            placeholder.frame(width: 36, height: 36)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: iconName).font(.caption).foregroundStyle(.secondary))
    }

    private var iconName: String {
        switch notification.type {
        case .like: return "heart.fill"
        case .comment: return "bubble.right.fill"
        case .follow: return "person.fill"
        }
    }
}
