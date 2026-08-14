import SwiftUI

// Feed tab is still a placeholder (built out in Phase 5).
// Profile tab is fully wired up as of Phase 3/4.
struct MainTabView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 12) {
                    Text("You're signed in 🎉")
                        .font(.title2.bold())
                    Text("User ID: \(session.userId ?? "unknown")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Feed — Phase 5")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Home")
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}
