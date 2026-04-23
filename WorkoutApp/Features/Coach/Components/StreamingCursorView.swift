import SwiftUI

struct StreamingCursorView: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        Text("|")
            .fontWeight(.thin)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    opacity = 0.1
                }
            }
    }
}
