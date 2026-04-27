import SwiftUI

struct HoneAvatarView: View {
    let diameter: CGFloat

    var body: some View {
        LinearGradient(
            colors: [Theme.accent, Color(red: 0.976, green: 0.451, blue: 0.086)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(Circle())
        .frame(width: diameter, height: diameter)
    }
}
