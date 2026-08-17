import SwiftUI

struct StoryRingView: View {
    let group: StoryGroup
    let isViewed: Bool

    var body: some View {
        VStack(spacing: 4) {
            avatar
                .padding(3)
                .overlay(
                    Circle()
                        .strokeBorder(ringStyle, lineWidth: 2.5)
                )
            Text("@\(group.authorUsername)")
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 64)
        }
    }

    private var ringStyle: AnyShapeStyle {
        isViewed
            ? AnyShapeStyle(Color.secondary.opacity(0.4))
            : AnyShapeStyle(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL = group.authorAvatarURL,
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 120)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
        } else {
            placeholder.frame(width: 60, height: 60)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
    }
}
