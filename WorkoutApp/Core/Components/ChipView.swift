import SwiftUI

// MARK: - ChipView
// Reusable single-tap chip with selected/unselected accent color states.
// UI-SPEC: 52pt height, 12pt corner radius, AccentColor fill when selected,
// CardBackground + tertiaryLabel border when unselected.
struct ChipView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52) // UI-SPEC: 52pt chip height
                .background(isSelected ? Color("AccentColor") : Color("CardBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color(UIColor.tertiaryLabel),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle()) // full 52pt hit area
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

#Preview {
    VStack(spacing: 12) {
        ChipView(label: "Build Muscle", isSelected: true, action: {})
        ChipView(label: "Lose Fat", isSelected: false, action: {})
    }
    .padding()
}
