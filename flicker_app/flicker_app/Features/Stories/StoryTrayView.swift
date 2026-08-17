import SwiftUI

/// The horizontal story tray, embedded at the top of FeedView. Owns its
/// own `StoriesViewModel` (and its listener) so it can be dropped in
/// without FeedView needing to know anything about stories.
struct StoryTrayView: View {
    @State private var viewModel = StoriesViewModel()
    @State private var showCreateStory = false
    @State private var openGroupIndex: IndexBox?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                addStoryRing
                ForEach(Array(viewModel.groups.enumerated()), id: \.element.id) { index, group in
                    StoryRingView(
                        group: group,
                        isViewed: viewModel.viewedAuthorIds.contains(group.authorId)
                    )
                    .onTapGesture { openGroupIndex = IndexBox(value: index) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .task { viewModel.startObserving() }
        .sheet(isPresented: $showCreateStory) {
            CreateStoryView()
        }
        .fullScreenCover(item: $openGroupIndex) { box in
            StoryViewerView(groups: viewModel.groups, startIndex: box.value) { authorId in
                viewModel.markViewed(authorId)
            }
        }
    }

    private var addStoryRing: some View {
        Button {
            showCreateStory = true
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(.secondary.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                }
                Text("Your story")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Small Identifiable wrapper so an Int can be used with `.fullScreenCover(item:)`.
private struct IndexBox: Identifiable {
    let value: Int
    var id: Int { value }
}
