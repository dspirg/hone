import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .coach {
                    // Coach label with icon (D-27)
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Coach")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(message.content)
                    .padding(12)
                    .background(message.role == .user
                        ? Color("AccentColor")
                        : Color(.systemGray6))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .coach { Spacer(minLength: 60) }
        }
    }
}
