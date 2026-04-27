import SwiftUI

// MARK: - SessionProgressBar
// "Exercise N of M" label + segmented capsule progress bar for SessionView.
//
// Layout (top to bottom):
//   - Text: "Exercise [N] of [M]" — .subheadline regular, .secondary color
//   - HStack of M capsule segments (4pt tall, xs=4pt gaps)
//     - Completed segments (index < current): AccentColor fill
//     - Incomplete/current segments: CardBackground fill + tertiaryLabel border
//
// Adapted from OnboardingProgressView (deleted — recovered from git history).
// Key differences: uses individual segment capsules (not a single fill bar) and
// 1-indexed display ("Exercise 1 of 5") vs 0-indexed OnboardingProgressView.
//
// Requirements: SESS-01 (session view)
// UI-SPEC: Phase 4 "Progress indicator (top of screen)"

struct SessionProgressBar: View {
    let current: Int    // 1-indexed (e.g., 1 for first exercise, 2 when on second)
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            // "Exercise N of M" label — subheadline, secondary color, per UI-SPEC copywriting contract
            Text("Exercise \(current) of \(total)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Exercise \(current) of \(total)")

            // Segmented capsule bar — GeometryReader for equal-width dynamic segments
            GeometryReader { proxy in
                let gapCount = max(total - 1, 0)
                let totalGap = CGFloat(gapCount) * 4   // xs (4pt) gap between segments
                let segmentWidth = (proxy.size.width - totalGap) / CGFloat(max(total, 1))

                HStack(spacing: 4) {
                    ForEach(0..<max(total, 1), id: \.self) { index in
                        Capsule()
                            .fill(index < current
                                  ? Theme.accent     // Completed segments: AccentColor fill
                                  : Theme.surface) // Incomplete: CardBackground
                            .overlay(
                                Capsule()
                                    .stroke(
                                        index < current
                                            ? Color.clear
                                            : Color.primary.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                            .frame(width: segmentWidth, height: 4)
                    }
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        // Combine text + bar into a single accessibility element
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exercise \(current) of \(total)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 32) {
        SessionProgressBar(current: 1, total: 5)
        SessionProgressBar(current: 3, total: 5)
        SessionProgressBar(current: 5, total: 5)
    }
    .padding()
    .background(Theme.background)
}
#endif
