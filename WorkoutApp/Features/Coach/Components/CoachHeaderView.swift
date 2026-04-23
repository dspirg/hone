import SwiftUI

struct CoachHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
            Text("Coach")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
