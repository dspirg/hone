import SwiftUI

struct CoachHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            HoneAvatarView(diameter: 28)
            Text("Hone")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
