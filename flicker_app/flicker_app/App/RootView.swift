import SwiftUI

struct RootView: View {
    @State private var session = SessionStore()

    var body: some View {
        Group {
            if !session.isAuthenticated {
                AuthFlowView()
            } else if session.hasProfile == nil {
                // Checking Firestore for users/{uid} — brief, avoids a
                // flash of the onboarding screen for returning users.
                ProgressView()
            } else if session.hasProfile == false {
                OnboardingFlowView {
                    Task { await session.refreshProfileStatus() }
                }
            } else {
                MainTabView()
            }
        }
        .environment(session)
    }
}
