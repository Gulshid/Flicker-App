import SwiftUI

/// The Chats tab, new in Phase 7. Lists every thread the signed-in user
/// is part of, most-recent first, with an unread dot for threads whose
/// last message hasn't been read yet. New conversations start either
/// here (compose button → username search) or from a profile's Message
/// button (see UserProfileView).
struct ChatListView: View {
    @State private var viewModel: ChatListViewModel
    @State private var openChat: Chat?
    @State private var showNewMessage = false

    init(viewModel: ChatListViewModel = ChatListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

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
                        showNewMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView { chat in
                    openChat = chat
                }
            }
            .sheet(item: $openChat) { chat in
                NavigationStack {
                    ChatView(chat: chat)
                }
            }
            .task { viewModel.startObserving() }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.chats) { chat in
                Button {
                    openChat = chat
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
