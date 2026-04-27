import SwiftUI

struct ChatInputBar: View {
    @Binding var messageText: String
    let isStreaming: Bool
    let isOnline: Bool
    let onSend: () -> Void

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isStreaming
        && isOnline
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // D-34: Multi-line auto-expanding input, 1-4 lines
            TextField("Ask your coach...", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(isStreaming)

            // Send button — arrow icon (D-03: disabled during streaming)
            Button(action: {
                guard canSend else { return }
                onSend()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Theme.accent : Theme.borderSubtle)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
