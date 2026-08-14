import SwiftUI

/// First step of onboarding after sign-up.
/// The users/{uid} Firestore document itself is created in Phase 3 —
/// this view just validates and reserves a display username.
struct UsernameSelectionView: View {
    @State private var username = ""
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var isAvailable: Bool?

    private let checker = UsernameCheckService()

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
        }
        .padding()
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
}
