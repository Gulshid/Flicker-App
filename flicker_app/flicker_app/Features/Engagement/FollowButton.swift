import SwiftUI

/// Self-contained follow/unfollow button. Loads its own initial state and
/// hides itself entirely on the signed-in user's own profile, so callers
/// can drop it into a header without any conditional logic.
struct FollowButton: View {
    let targetUserId: String
    @State private var viewModel: FollowViewModel

    init(targetUserId: String) {
        self.targetUserId = targetUserId
        _viewModel = State(initialValue: FollowViewModel(targetUserId: targetUserId))
    }

    var body: some View {
        if !viewModel.isOwnProfile {
            Button {
                Task { await viewModel.toggle() }
            } label: {
                Text(viewModel.isFollowing ? "Following" : "Follow")
                    .font(.footnote.weight(.semibold))
                    .frame(minWidth: 90)
                    .padding(.vertical, 6)
                    .background(viewModel.isFollowing ? Color.secondary.opacity(0.15) : Color.accentColor)
                    .foregroundStyle(viewModel.isFollowing ? Color.primary : Color.white)
                    .clipShape(Capsule())
            }
            .disabledWhileLoading(viewModel.isLoading)
            .task { await viewModel.loadStatus() }
        }
    }
}
