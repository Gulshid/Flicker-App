import SwiftUI

// Feed tab is fully wired up as of Phase 5/6 (posts, likes, comments,
// follow graph). Profile tab has been live since Phase 3/4.
struct MainTabView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .task {
            // Populate SessionStore's cached AppUser if it isn't already
            // (e.g. a hot-reload path that skipped refreshProfileStatus).
            if session.currentUser == nil {
                await session.refreshCurrentUser()
            }
        }
    }
}
