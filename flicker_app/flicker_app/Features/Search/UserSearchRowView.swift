import SwiftUI

struct UserSearchRowView: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username)")
                    .font(.subheadline.weight(.semibold))
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = user.avatarURL,
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 100)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            placeholder.frame(width: 44, height: 44)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
    }
}
