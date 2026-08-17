import SwiftUI
import AVKit

/// A chromeless, auto-looping `AVPlayer`-backed video view. Used by both
/// the story viewer and the Reels feed (Phase 10) — video posts autoplay
/// and loop silently in the background, with none of stock `VideoPlayer`'s
/// playback-controls chrome.
struct LoopingVideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    var isMuted: Bool = true
    var isPlaying: Bool = true

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        // AVPlayerViewController's own view has an opaque black
        // background by default; without this a brief flash of black
        // shows through rounded corners / safe-area insets before the
        // first frame decodes.
        controller.view.backgroundColor = .clear

        context.coordinator.observe(player: player)
        if isPlaying { player.play() }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player?.isMuted = isMuted
        guard let player = controller.player else { return }
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause()
        coordinator.stopObserving()
    }

    /// Owns the loop-on-finish notification observer so it's torn down
    /// deterministically in `dismantleUIViewController` rather than
    /// relying on NotificationCenter's block-based observer being
    /// released at some unspecified later point.
    final class Coordinator {
        private var token: NSObjectProtocol?
        private weak var player: AVPlayer?

        func observe(player: AVPlayer) {
            self.player = player
            token = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        func stopObserving() {
            if let token {
                NotificationCenter.default.removeObserver(token)
            }
            token = nil
        }
    }
}
