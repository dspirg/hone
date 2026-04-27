import SwiftUI

// MARK: - WeeklyRingView
// Circle.trim progress ring showing weekly session completion.
// Ring diameter: 120pt fixed. Stroke width: 10pt.
// Background ring: .secondary at 20% opacity.
// Fill ring: AccentColor, rotated -90° so fill starts at top.
// Center text: fraction (e.g. "3/4") in .title2.weight(.semibold).
// Zero state: shows "0/{N} this week" with ring at 0% fill.
// UI-SPEC: WeeklyRingView component — D-04
// Requirements: PROG-02

struct WeeklyRingView: View {
    let completed: Int
    let planned: Int

    private var progress: CGFloat {
        guard planned > 0 else { return 0 }
        return min(CGFloat(completed) / CGFloat(planned), 1.0)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 120, height: 120)

            // Progress fill ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Center text
            VStack(spacing: 2) {
                Text("\(completed)/\(planned)")
                    .font(.title2.weight(.semibold))

                Text("this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly completion: \(completed) of \(planned) sessions done")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack(spacing: 32) {
        WeeklyRingView(completed: 3, planned: 4)
        WeeklyRingView(completed: 0, planned: 4)
        WeeklyRingView(completed: 4, planned: 4)
    }
    .padding()
}
#endif
