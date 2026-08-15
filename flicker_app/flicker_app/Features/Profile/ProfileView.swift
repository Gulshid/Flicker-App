import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.user == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = viewModel.user {
                    content(for: user)
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Couldn't load profile",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    // Covers the brief gap before .task sets isLoading = true,
                    // and any state where loadCurrentUser() returned without
                    // setting user or errorMessage (e.g. currentUserId was
                    // nil for a moment). Without this branch the screen was
                    // rendering nothing at all.
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditProfile = true }
                        .disabled(viewModel.user == nil)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out", role: .destructive) {
                        try? DIContainer.shared.authService.signOut()
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let user = viewModel.user {
                    EditProfileView(user: user) { bio, avatarURL in
                        viewModel.applyLocalEdit(bio: bio, avatarURL: avatarURL)
                        session.applyLocalProfileEdit(bio: bio, avatarURL: avatarURL)
                    }
                }
            }
            .task {
                await viewModel.loadCurrentUser()
            }
        }
    }

    @ViewBuilder
    private func content(for user: AppUser) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                avatar(for: user)

                Text("@\(user.username)")
                    .font(.title3.bold())

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: 32) {
                    statColumn(count: user.postCount, label: "Posts")
                    statColumn(count: user.followerCount, label: "Followers")
                    statColumn(count: user.followingCount, label: "Following")
                }
                .padding(.top, 8)

                // Phase 5: the grid of the signed-in user's own posts.
                PostGridView(authorId: user.id)
                    .padding(.top, 20)
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func avatar(for user: AppUser) -> some View {
        if let avatarURL = user.avatarURL,
           let url = URL(string: CloudinaryTransformation.avatar(avatarURL)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
                .frame(width: 96, height: 96)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
    }

    private func statColumn(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
