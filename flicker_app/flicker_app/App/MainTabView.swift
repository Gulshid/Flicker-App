import SwiftUI

// Placeholder tab shell.
// Feed, Profile, Chat, Notifications tabs get built out in later phases.
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

                    Button("Sign Out", role: .destructive) {
                        try? DIContainer.shared.authService.signOut()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 24)
                }
                .navigationTitle("Home")
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            Text("Profile — Phase 3")
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}
