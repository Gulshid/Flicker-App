import SwiftUI

struct RootView: View {
    @State private var session = SessionStore()
    @State private var showSplash = true

    var body: some View {
        ZStack {
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

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            // Keep the splash up for a minimum, pleasant duration regardless
            // of how quickly Firebase's auth listener resolves, so it never
            // just flashes on screen for returning users with a fast network.
            try? await Task.sleep(for: SplashView.minimumDuration)
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}
