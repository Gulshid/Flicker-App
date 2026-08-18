import SwiftUI

/// The Chats tab, new in Phase 7. Lists every thread the signed-in user
/// is part of, most-recent first, with an unread dot for threads whose
/// last message hasn't been read yet. New conversations start either
/// here (compose button → username search) or from a profile's Message
/// button (see UserProfileView).
struct ChatListView: View {
    /// Single source of truth for this screen's sheet, instead of two
    /// separate optionals (`openChat` / `showNewMessage`) each with their
    /// own `.sheet` modifier — see FeedView's FeedSheet for why: multiple
    /// `.sheet` modifiers in the same NavigationStack can get their
    /// presentation contexts crossed, so tapping an existing chat row
    /// could end up presenting the "new message" composer instead (or
    /// vice versa).
    private enum ChatListSheet: Identifiable {
        case newMessage
        case chat(Chat)

        var id: String {
            switch self {
            case .newMessage: return "newMessage"
            case .chat(let chat): return "chat-\(chat.id ?? chat.chatId)"
            }
        }
    }

    @State private var viewModel = ChatListViewModel()
    @State private var activeSheet: ChatListSheet?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.chats.isEmpty && viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.chats.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .newMessage
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newMessage:
                    NewMessageView { chat in
                        activeSheet = .chat(chat)
                    }
                case .chat(let chat):
                    NavigationStack {
                        ChatView(chat: chat)
                    }
                }
            }
            .task { viewModel.startObserving() }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.chats) { chat in
                Button {
                    activeSheet = .chat(chat)
                } label: {
                    ChatRowView(chat: chat, currentUserId: viewModel.currentUserId ?? "")
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No messages yet",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Start a conversation from someone's profile, or tap the compose button.")
        )
    }
}
