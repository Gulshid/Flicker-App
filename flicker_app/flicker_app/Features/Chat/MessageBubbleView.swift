import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 40) }
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? Color.accentColor : Color.secondary.opacity(0.15))
                    .foregroundStyle(isFromCurrentUser ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message.createdAt.relativeTimeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isFromCurrentUser { Spacer(minLength: 40) }
        }
    }
}
