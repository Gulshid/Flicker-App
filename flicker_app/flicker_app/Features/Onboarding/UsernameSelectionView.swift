import SwiftUI

/// First step of onboarding after sign-up. Checks availability, then
/// (Phase 3) creates the users/{uid} Firestore document itself before
/// handing off to profile setup.
struct UsernameSelectionView: View {
    var onCreated: (String) -> Void

    @State private var username = ""
    @State private var isChecking = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isAvailable: Bool?

    private let checker: UsernameCheckService
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    init(
        checker: UsernameCheckService = UsernameCheckService(),
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService,
        onCreated: @escaping (String) -> Void
    ) {
        self.checker = checker
        self.firestoreService = firestoreService
        self.authService = authService
        self.onCreated = onCreated
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose a Username")
                .font(.title2.bold())

            TextField("username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .onChange(of: username) { _, _ in
                    isAvailable = nil
                    errorMessage = nil
                }

            if isChecking {
                ProgressView()
            } else if let isAvailable {
                Text(isAvailable ? "✅ Available" : "❌ Already taken")
                    .font(.footnote)
                    .foregroundStyle(isAvailable ? .green : .red)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("Check Availability") {
                Task { await checkAvailability() }
            }
            .buttonStyle(.bordered)
            .disabledWhileLoading(isChecking || username.isEmpty)

            Button("Continue") {
                Task { await createProfile() }
            }
            .buttonStyle(.borderedProminent)
            .disabledWhileLoading(isSubmitting || isAvailable != true)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    private func checkAvailability() async {
        isChecking = true
        defer { isChecking = false }
        do {
            isAvailable = try await checker.isUsernameAvailable(username)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createProfile() async {
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await firestoreService.createUserProfile(uid: uid, username: username)
            onCreated(username)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
