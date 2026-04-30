import SwiftUI

struct OnboardingHeroIcon: View {
    let symbol: String
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Text(symbol)
            .font(.system(size: 36))
            .frame(width: 72, height: 72)
            .background(
                LinearGradient(
                    colors: [Theme.accent.opacity(0.15), Theme.accent.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .shadow(color: Theme.accent.opacity(0.1), radius: 12)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
    }
}
