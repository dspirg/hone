import SwiftUI

/// Pre-session time picker shown before starting a workout.
/// User selects how much time they have — this adjusts the workout volume.
struct SessionTimePicker: View {
    let onSelect: (Int) -> Void

    private let options = [
        (minutes: 30, label: "30 min", description: "Quick & focused"),
        (minutes: 45, label: "45 min", description: "Balanced session"),
        (minutes: 60, label: "60 min", description: "Full workout"),
        (minutes: 90, label: "90 min", description: "Extended training"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("How much time do you have?")
                    .font(.title3.weight(.semibold))
                Text("We'll adjust your workout to fit")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            VStack(spacing: 10) {
                ForEach(options, id: \.minutes) { option in
                    Button {
                        onSelect(option.minutes)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.borderSubtle, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Theme.background)
    }
}
