import SwiftUI

/// A single 1:1 thread — live message list, typing indicator, and a
/// composer. Reached from ChatListView, or from a profile's Message
/// button (UserProfileView → ChatView directly).
struct ChatView: View {
    @State private var viewModel: ChatViewModel

    init(chat: Chat) {
        _viewModel = State(initialValue: ChatViewModel(chat: chat))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if viewModel.otherUserIsTyping {
                typingIndicator
            }
            composer
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty {
                        Text("Say hi 👋")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == viewModel.currentUserId
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            .onChange(of: viewModel.messages.count) {
                guard let lastId = viewModel.messages.last?.id else { return }
                withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
            }
        }
    }

    private var typingIndicator: some View {
        HStack {
            Text("Typing…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $viewModel.draftText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onChange(of: viewModel.draftText) { viewModel.draftTextChanged() }
            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(12)
        .background(.bar)
    }
}
