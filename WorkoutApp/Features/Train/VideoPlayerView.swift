import SwiftUI
import AVKit
import MuxPlayerSwift

// MARK: - VideoPlayerView
// UIViewControllerRepresentable wrapping AVPlayerViewController with Mux HLS playback.
//
// Online path: Uses MuxPlayerSwift to init AVPlayerViewController with a playback ID.
//              Smart Cache at 720p single rendition handles progressive caching automatically.
// Offline path: Uses local asset URL from CoreData (set after AVAssetDownloadTask completes).
//
// Looping: seek-to-zero via AVPlayerItemDidPlayToEndTime notification.
// CRITICAL ANTI-PATTERN: Do NOT use AVPlayerLooper — broken for HLS streams (duplicate downloads).
//
// Requirements: EXRC-01, EXRC-03
// Research: 02-RESEARCH.md Patterns 5 and 6

struct VideoPlayerView: UIViewControllerRepresentable {
    let muxPlaybackId: String
    let localAssetURL: URL?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc: AVPlayerViewController

        if let localURL = localAssetURL {
            // Offline path: use local cached HLS asset directly
            let player = AVPlayer(url: localURL)
            player.actionAtItemEnd = .none
            vc = AVPlayerViewController()
            vc.player = player
            context.coordinator.setupLooping(player: player)
        } else {
            // Online path: Mux Smart Cache at 720p single rendition
            let options = PlaybackOptions(
                enableSmartCache: true,
                singleRenditionResolutionTier: .only720p
            )
            vc = AVPlayerViewController(
                playbackID: muxPlaybackId,
                playbackOptions: options
            )
            context.coordinator.setupLooping(player: vc.player)
        }

        vc.player?.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator
    // Manages the AVPlayerItemDidPlayToEndTime observer lifetime.
    // Uses addObserver(forName:object:queue:) block form so [weak player] capture avoids retain cycles.
    class Coordinator: NSObject {
        private var observer: NSObjectProtocol?

        func setupLooping(player: AVPlayer?) {
            guard let player else { return }
            player.actionAtItemEnd = .none
            // Pattern 6 from 02-RESEARCH.md: seek-to-zero loop (NOT AVPlayerLooper — HLS incompatible)
            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero) { _ in
                    player?.play()
                }
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
