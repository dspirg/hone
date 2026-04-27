import SwiftUI
import AVKit

struct VideoOverlayView: View {
    let muxPlaybackId: String
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if !muxPlaybackId.isEmpty {
                VideoPlayerView(muxPlaybackId: muxPlaybackId, localAssetURL: nil)
            }
            // Dismiss button so user can close the overlay from within the view
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .accessibilityLabel("Close video")
        }
        .ignoresSafeArea()
    }
}
