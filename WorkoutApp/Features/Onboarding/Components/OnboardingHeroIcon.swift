import SwiftUI

struct OnboardingHeroIcon: View {
    let iconName: String
    let gradient: [Color]
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 12)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
    }
}
