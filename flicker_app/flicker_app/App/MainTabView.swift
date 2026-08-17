import SwiftUI

// Feed and Profile tabs have been live since Phase 3–6 (posts, likes,
// comments, follow graph). Chats (Phase 7) and Activity (Phase 8) round
// out the tab bar. NotificationsViewModel is created once here (rather
// than inside NotificationsView) so its listener — and the unread count
// that drives the tab badge — stay alive even while the Activity tab
// itself isn't the one on screen. Search (Phase 9) and Reels (Phase 10)
// are the last two additions — six tabs total now means iOS's stock
// "More" overflow can kick in on narrower devices, which is expected,
// standard UITabBarController behavior rather than a bug here.
struct MainTabView: View {
    @Environment(SessionStore.self) private var session
    @State private var notificationsViewModel = NotificationsViewModel()

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            ReelsView()
                .tabItem { Label("Reels", systemImage: "play.rectangle.fill") }

            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }

            NotificationsView(viewModel: notificationsViewModel)
                .tabItem { Label("Activity", systemImage: "bell.fill") }
                .badge(notificationsViewModel.unreadCount)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .task {
            // Populate SessionStore's cached AppUser if it isn't already
            // (e.g. a hot-reload path that skipped refreshProfileStatus).
            if session.currentUser == nil {
                await session.refreshCurrentUser()
            }
            notificationsViewModel.startObserving()
        }
    }
}
