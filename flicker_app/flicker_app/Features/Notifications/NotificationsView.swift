import SwiftUI

/// The Activity tab, new in Phase 8. Real-time feed of likes, comments,
/// and follows written by `FirestoreService.writeNotification` —
/// client-side triggers standing in for Cloud Functions on the Spark
/// plan, per the roadmap's Phase 8 compensation strategy.
struct NotificationsView: View {
    @State var viewModel: NotificationsViewModel
    @State private var authorToView: String?

    // No default value here on purpose — a default argument expression
    // that calls `NotificationsViewModel()` (a @MainActor initializer)
    // is evaluated in this init's own nonisolated context and fails to
    // build under Swift 6 strict concurrency. The one call site
    // (MainTabView) always passes its shared instance explicitly anyway,
    // so a required parameter costs nothing.
    init(viewModel: NotificationsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty && viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "bell",
                        description: Text("Likes, comments, and new followers will show up here.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                if viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark all read") { Task { await viewModel.markAllRead() } }
                            .font(.footnote)
                    }
                }
            }
            .sheet(item: Binding(
                get: { authorToView.map { IdentifiableString(value: $0) } },
                set: { authorToView = $0?.value }
            )) { wrapped in
                UserProfileView(userId: wrapped.value)
            }
            .task { viewModel.startObserving() }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                Button {
                    authorToView = notification.actorId
                    Task { await viewModel.markRead(notification) }
                } label: {
                    NotificationRowView(notification: notification)
                }
                .buttonStyle(.plain)
                .listRowBackground(notification.isRead ? Color.clear : Color.accentColor.opacity(0.06))
            }
        }
        .listStyle(.plain)
    }
}
