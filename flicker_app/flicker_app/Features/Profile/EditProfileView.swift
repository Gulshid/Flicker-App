import SwiftUI

/// Edit-profile screen from Phase 3: bio text + avatar upload, backed by
/// AvatarUploadView (Phase 4) for the actual picker/compress/upload flow.
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let user: AppUser
    var onSaved: (String?, String?) -> Void

    @State private var bio: String
    @State private var pendingAvatarURL: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        user: AppUser,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService,
        onSaved: @escaping (String?, String?) -> Void
    ) {
        self.user = user
        self.firestoreService = firestoreService
        self.authService = authService
        self.onSaved = onSaved
        _bio = State(initialValue: user.bio ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarUploadView(currentAvatarURL: pendingAvatarURL ?? user.avatarURL) { url in
                            pendingAvatarURL = url
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Bio") {
                    TextField("Tell people about yourself", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabledWhileLoading(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await firestoreService.updateUserProfile(uid: uid, bio: bio, avatarURL: pendingAvatarURL)
            onSaved(bio, pendingAvatarURL)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
