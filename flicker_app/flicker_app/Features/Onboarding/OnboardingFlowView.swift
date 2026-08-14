import SwiftUI

/// Coordinates the two onboarding steps that depend on Phase 3's schema:
/// reserve + create a username, then (optionally) fill in bio/avatar.
/// RootView shows this whenever a signed-in user has no users/{uid}
/// document yet.
struct OnboardingFlowView: View {
    var onFinished: () -> Void

    @State private var createdUsername: String?

    var body: some View {
        NavigationStack {
            if let createdUsername {
                ProfileSetupView(username: createdUsername, onFinished: onFinished)
            } else {
                UsernameSelectionView { username in
                    createdUsername = username
                }
            }
        }
    }
}
