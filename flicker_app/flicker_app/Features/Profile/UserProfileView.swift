import SwiftUI

/// Read-only profile for someone other than the signed-in user — reached
/// by tapping a post author in the feed or a post detail view. Reuses
/// PostGridView (Phase 5) and adds a FollowButton (Phase 6). If the
/// author happens to be the signed-in user themself, FollowButton hides
/// itself automatically (see FollowViewModel.isOwnProfile).
struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel
    @State private var activeChat: Chat?

    init(userId: String) {
        _viewModel = State(initialValue: UserProfileViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let user = viewModel.user {
                    content(for: user)
                } else if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Couldn't load profile",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .sheet(item: $activeChat) { chat in
                NavigationStack {
                    ChatView(chat: chat)
                }
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

                HStack(spacing: 10) {
                    FollowButton(targetUserId: user.id)
                    if !viewModel.isOwnProfile {
                        Button {
                            Task {
                                if let chat = await viewModel.startChat() {
                                    activeChat = chat
                                }
                            }
                        } label: {
                            Text("Message")
                                .font(.footnote.weight(.semibold))
                                .frame(minWidth: 90)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(Color.primary)
                                .clipShape(Capsule())
                        }
                        .disabledWhileLoading(viewModel.isStartingChat)
                    }
                }

                HStack(spacing: 32) {
                    statColumn(count: user.postCount, label: "Posts")
                    statColumn(count: user.followerCount, label: "Followers")
                    statColumn(count: user.followingCount, label: "Following")
                }
                .padding(.top, 4)

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
            avatarPlaceholder.frame(width: 96, height: 96)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
    }

    private func statColumn(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
