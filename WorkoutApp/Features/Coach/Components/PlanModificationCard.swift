import SwiftUI

struct PlanModificationCard: View {
    let message: ChatMessage
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if message.planModificationState == .confirmed {
                // D-11: Compact confirmed state
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Plan updated")
                        .font(.subheadline.weight(.medium))
                }
                .transition(.opacity)
            } else if message.planModificationState == .dismissed {
                // Dismissed — compact state
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                    Text("Change dismissed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                // D-06: Pending — show diff and buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proposed Plan Change")
                        .font(.subheadline.weight(.semibold))

                    // Display modification description from JSON
                    if let modJSON = message.planModificationJSON,
                       let data = modJSON.data(using: .utf8),
                       let mod = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let description = mod["description"] as? String {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // D-08: Confirm and Dismiss buttons
                    HStack(spacing: 12) {
                        Button("Dismiss") { onDismiss() }
                            .buttonStyle(.bordered)

                        Button("Confirm") { onConfirm() }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .animation(.easeInOut, value: message.planModificationState)
    }
}
