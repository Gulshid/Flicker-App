import SwiftUI

/// Full-screen story playback: a segmented progress bar per author,
/// auto-advancing through their stories, then rolling into the next
/// author's ring. Tap the right two-thirds of the screen to skip ahead,
/// the left third to go back; the X button (or running out of stories)
/// dismisses.
struct StoryViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let groups: [StoryGroup]
    var onViewed: (String) -> Void = { _ in }

    @State private var groupIndex: Int
    @State private var storyIndex = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?

    private let storyDuration: Double = 5
    private let tickInterval: Double = 0.05

    init(groups: [StoryGroup], startIndex: Int, onViewed: @escaping (String) -> Void = { _ in }) {
        self.groups = groups
        self.onViewed = onViewed
        _groupIndex = State(initialValue: startIndex)
    }

    private var currentGroup: StoryGroup? {
        groups.indices.contains(groupIndex) ? groups[groupIndex] : nil
    }

    private var currentStory: Story? {
        guard let currentGroup, currentGroup.stories.indices.contains(storyIndex) else { return nil }
        return currentGroup.stories[storyIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let story = currentStory {
                storyContent(story)
                    .id(story.id)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    progressBars
                    header(for: story)
                    Spacer()
                }
                .padding(.top, 8)

                tapZones
            }
        }
        .statusBarHidden()
        .onAppear { restart() }
        .onDisappear { stopTimer() }
        .onChange(of: storyIndex) { restart() }
        .onChange(of: groupIndex) { restart() }
    }

    @ViewBuilder
    private func storyContent(_ story: Story) -> some View {
        if story.isVideo, let url = URL(string: story.mediaURL) {
            LoopingVideoPlayerView(url: url, isMuted: false)
        } else if let url = URL(string: CloudinaryTransformation.fullResolution(story.mediaURL)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color.black
                }
            }
        }
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            if let currentGroup {
                ForEach(Array(currentGroup.stories.enumerated()), id: \.offset) { index, _ in
                    GeometryReader { geo in
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(.white)
                                    .frame(width: geo.size.width * segmentProgress(for: index))
                            }
                    }
                    .frame(height: 2.5)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func segmentProgress(for index: Int) -> Double {
        if index < storyIndex { return 1 }
        if index == storyIndex { return progress }
        return 0
    }

    private func header(for story: Story) -> some View {
        HStack(spacing: 8) {
            if let avatarURL = story.authorAvatarURL,
               let url = URL(string: CloudinaryTransformation.avatar(avatarURL, size: 80)) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.2)
                    }
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            }
            Text("@\(story.authorUsername)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Text(story.createdAt.relativeTimeString)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.2), in: Circle())
            }
        }
        .padding(.horizontal, 12)
    }

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .onTapGesture { goBack() }
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .onTapGesture { advance() }
        }
    }

    private func restart() {
        guard let story = currentStory else {
            dismiss()
            return
        }
        onViewed(story.authorId)
        progress = 0
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            Task { @MainActor in
                progress += tickInterval / storyDuration
                if progress >= 1 {
                    advance()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        guard let currentGroup else { return }
        if storyIndex + 1 < currentGroup.stories.count {
            storyIndex += 1
        } else if groupIndex + 1 < groups.count {
            groupIndex += 1
            storyIndex = 0
        } else {
            dismiss()
        }
    }

    private func goBack() {
        if storyIndex > 0 {
            storyIndex -= 1
        } else if groupIndex > 0 {
            groupIndex -= 1
            storyIndex = max(0, groups[groupIndex].stories.count - 1)
        }
    }
}
