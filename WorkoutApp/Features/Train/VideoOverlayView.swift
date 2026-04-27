import SwiftUI
import AVKit

struct VideoOverlayView: View {
    let muxPlaybackId: String
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoPlayerView(muxPlaybackId: muxPlaybackId, localAssetURL: nil)
        }
        .ignoresSafeArea()
    }
}
