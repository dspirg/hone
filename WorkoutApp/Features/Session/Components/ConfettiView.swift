import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var opacity: Double = 1.0

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.x * size.width,
                    y: particle.y * size.height,
                    width: particle.size,
                    height: particle.size * 1.5
                )
                context.fill(
                    Path(rect),
                    with: .color(particle.color)
                )
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<40).map { _ in ConfettiParticle() }
            withAnimation(.easeOut(duration: 2.0)) {
                opacity = 0
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: Double = .random(in: 0...1)
    let y: Double = .random(in: -0.1...0.6)
    let size: Double = .random(in: 4...10)
    let color: Color = [
        Color(red: 245/255, green: 158/255, blue: 11/255),
        Color(red: 0.486, green: 0.227, blue: 0.929),
        Color(red: 52/255, green: 211/255, blue: 153/255),
        Color(red: 96/255, green: 165/255, blue: 250/255),
    ].randomElement()!
}
