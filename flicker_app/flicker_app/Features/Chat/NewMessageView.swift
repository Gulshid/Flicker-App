import SwiftUI

/// Sheet reached from the compose button in ChatListView. Username
/// lookup is exact-match for now — Phase 9 adds real prefix search;
/// good enough to start a first conversation with someone whose handle
/// you already know.
struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var onChatCreated: (Chat) -> Void

    private let firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService
    private let authService: AuthServiceProtocol = DIContainer.shared.authService

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Start a new conversation")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chat") { Task { await startChat() } }
                        .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }
            }
            .disabledWhileLoading(isSearching)
        }
    }

    private func startChat() async {
        guard let uid = authService.currentUserId else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            guard let target = try await firestoreService.findUser(byUsername: username) else {
                errorMessage = "No user found with that username."
                return
            }
            guard target.id != uid else {
                errorMessage = "You can't message yourself."
                return
            }
            let me = try await firestoreService.fetchUser(uid)
            let chat = try await firestoreService.createOrGetChat(
                currentUserId: uid,
                currentUsername: me.username,
                currentAvatarURL: me.avatarURL,
                otherUserId: target.id,
                otherUsername: target.username,
                otherAvatarURL: target.avatarURL
            )
            dismiss()
            onChatCreated(chat)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
