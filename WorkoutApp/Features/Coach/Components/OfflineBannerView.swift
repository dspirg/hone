import SwiftUI

struct OfflineBannerView: View {
    var body: some View {
        Text("No connection — coach unavailable")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
