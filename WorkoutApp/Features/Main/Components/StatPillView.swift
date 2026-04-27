import SwiftUI

// MARK: - StatPillView
// Shared stat pill component used on Home and Summary screens (D-15, UI-SPEC).
// Renders a value + label in a surfaceElevated background pill.
//
// Usage:
//   StatPillView(label: "Sessions", value: "12")
//   StatPillView(label: "PRs", value: "3", valueColor: Theme.accent)

struct StatPillView: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack(spacing: 8) {
        StatPillView(label: "Sessions", value: "12")
        StatPillView(label: "PRs", value: "3", valueColor: Theme.accent)
        StatPillView(label: "Sets", value: "84")
    }
    .padding()
    .background(Theme.background)
}
#endif
