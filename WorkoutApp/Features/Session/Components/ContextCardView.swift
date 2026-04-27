import SwiftUI

// MARK: - ContextCardView
// Previous/Best context card for the Session screen (D-07, UI-SPEC).
// Displays a label ("Previous" or "Best") with a formatted value ("10 reps" or "---").
//
// Usage (pair side-by-side):
//   HStack(spacing: 8) {
//     ContextCardView(label: "Previous", value: previousRepsText)
//     ContextCardView(label: "Best", value: bestRepsText, valueColor: Theme.accent)
//   }

struct ContextCardView: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack(spacing: 8) {
        ContextCardView(label: "Previous", value: "10 reps")
        ContextCardView(label: "Best", value: "12 reps", valueColor: Theme.accent)
    }
    .padding()
    .background(Theme.background)
}
#endif
