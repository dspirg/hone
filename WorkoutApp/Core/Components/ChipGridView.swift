import SwiftUI

// MARK: - ChipGridView
// Grid layout container for chip options. Supports 1 or 2 columns.
// UI-SPEC: 12pt spacing between chips, 16pt (md) horizontal padding.
struct ChipGridView: View {
    let options: [String]
    let selectedOptions: Set<String>
    let columns: Int // 1 or 2
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: columns),
            spacing: 12
        ) {
            ForEach(options, id: \.self) { option in
                ChipView(
                    label: option,
                    isSelected: selectedOptions.contains(option),
                    action: { onSelect(option) }
                )
            }
        }
        .padding(.horizontal, 16) // md
    }
}

#Preview {
    ChipGridView(
        options: ["Build Muscle", "Lose Fat", "Get Fitter", "Athletic Performance"],
        selectedOptions: ["Build Muscle"],
        columns: 2,
        onSelect: { _ in }
    )
    .padding()
}
