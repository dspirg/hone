import SwiftUI

// MARK: - FilterChip
// Reusable filter chip button used in FilterChipRow.
// Selected state: AccentColor fill, white text.
// Unselected state: CardBackground fill, primary text, 1pt tertiaryLabel border.
// Touch target: minimum 44pt via .contentShape(Rectangle()) — HIG requirement.
// Accessibility: label = "[title] filter", value = "selected" / "not selected".

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.accent : Theme.surface)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color(UIColor.tertiaryLabel),
                            lineWidth: 1
                        )
                )
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

// MARK: - FilterChipRow
// Horizontal scrolling row of filter chips for muscle group and equipment.
// Chip order: "All", then 8 muscle groups, then vertical divider, then 4 equipment types.
// "All" chip is selected when BOTH activeMuscleGroup and activeEquipment are nil.
// Muscle group and equipment filters are independent (AND logic).
// Tapping "All" clears both filters. Tapping a selected chip deselects it (sets to nil).

struct FilterChipRow: View {
    @Binding var activeMuscleGroup: String?
    @Binding var activeEquipment: String?

    // From CONTEXT.md / UI-SPEC: 8 muscle groups + 4 equipment types
    private let muscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Core", "Legs", "Glutes", "Full Body"]
    private let equipmentTypes = ["Bodyweight", "Dumbbells", "Barbell", "Machine"]

    private var isAllSelected: Bool {
        activeMuscleGroup == nil && activeEquipment == nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip — clears all filters when tapped
                FilterChip(title: "All", isSelected: isAllSelected) {
                    activeMuscleGroup = nil
                    activeEquipment = nil
                }

                // Muscle group chips
                ForEach(muscleGroups, id: \.self) { muscle in
                    FilterChip(title: muscle, isSelected: activeMuscleGroup == muscle) {
                        if activeMuscleGroup == muscle {
                            activeMuscleGroup = nil  // Deselect current chip
                        } else {
                            activeMuscleGroup = muscle
                        }
                    }
                }

                // Visual divider between muscle group and equipment chips
                Rectangle()
                    .fill(Color(UIColor.tertiaryLabel))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 4)

                // Equipment chips
                ForEach(equipmentTypes, id: \.self) { equipment in
                    FilterChip(title: equipment, isSelected: activeEquipment == equipment) {
                        if activeEquipment == equipment {
                            activeEquipment = nil  // Deselect current chip
                        } else {
                            activeEquipment = equipment
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var muscle: String? = "Chest"
    @Previewable @State var equipment: String? = nil
    FilterChipRow(activeMuscleGroup: $muscle, activeEquipment: $equipment)
        .background(Theme.background)
}
#endif
