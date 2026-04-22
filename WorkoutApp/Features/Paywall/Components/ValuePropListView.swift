import SwiftUI

// MARK: - ValuePropListView
// Renders 4 value proposition bullet rows per D-05 and UI-SPEC section.
// Each row: checkmark SF Symbol in accent color + body text.
// Horizontal padding: xl (32pt) per UI-SPEC spacing scale.
struct ValuePropListView: View {
    private let valueProps: [String] = [
        "AI plan built for you",
        "500+ exercises with video",
        "Coach chat anytime",
        "Adapts as you improve"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(valueProps, id: \.self) { prop in
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .foregroundStyle(Color("AccentColor"))
                    Text(prop)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    ValuePropListView()
}
