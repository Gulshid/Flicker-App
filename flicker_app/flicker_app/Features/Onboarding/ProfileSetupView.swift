import SwiftUI

/// Second onboarding step: bio + avatar, both optional. Reuses
/// AvatarUploadView from Phase 4 for the upload UI, and writes straight
/// to the users/{uid} doc that UsernameSelectionView already created.
struct ProfileSetupView: View {
    let username: String
    var onFinished: () -> Void

    @State private var bio = ""
    @State private var avatarURL: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        username: String,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService,
        onFinished: @escaping () -> Void
    ) {
        self.username = username
        self.firestoreService = firestoreService
        self.authService = authService
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome, @\(username) 👋")
                .font(.title2.bold())

            Text("Add a photo and a short bio — or skip this for now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            AvatarUploadView(currentAvatarURL: avatarURL) { url in
                avatarURL = url
            }

            TextField("Bio (optional)", text: $bio, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            Spacer()

            Button("Finish") {
                Task { await save() }
            }
            .buttonStyle(.borderedProminent)
            .disabledWhileLoading(isSaving)

            Button("Skip for now") {
                onFinished()
            }
            .font(.footnote)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    private func save() async {
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            try await firestoreService.updateUserProfile(
                uid: uid,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                avatarURL: avatarURL
            )
            onFinished()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
