import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .coach {
                    HStack(spacing: 6) {
                        HoneAvatarView(diameter: 20)
                        Text("Hone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                formattedContent
                    .padding(12)
                    .background(message.role == .user
                        ? Theme.accent.opacity(0.15)
                        : Theme.surface)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .coach { Spacer(minLength: 60) }
        }
    }

    // MARK: - Formatted Content

    @ViewBuilder
    private var formattedContent: some View {
        if message.role == .coach {
            Text(parseBasicMarkdown(message.content))
        } else {
            Text(message.content)
        }
    }

    // MARK: - Basic Markdown Parser

    /// Parses **bold** and numbered/bulleted lists into AttributedString.
    private func parseBasicMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            if i > 0 { result += AttributedString("\n") }

            // Numbered list: "1. ", "2. ", etc.
            let listPattern = /^(\d+)\.\s+(.+)$/
            if let match = line.firstMatch(of: listPattern) {
                var number = AttributedString("\(match.1). ")
                number.foregroundColor = UIColor(Theme.accent)
                number.font = .body.bold()
                result += number
                result += parseBold(String(match.2))
            } else if line.hasPrefix("- ") {
                // Bullet list
                var bullet = AttributedString("  \u{2022} ")
                bullet.foregroundColor = UIColor(Theme.accent)
                result += bullet
                result += parseBold(String(line.dropFirst(2)))
            } else {
                result += parseBold(line)
            }
        }

        return result
    }

    /// Parses **bold** spans within a line.
    private func parseBold(_ text: String) -> AttributedString {
        var result = AttributedString()
        let parts = text.components(separatedBy: "**")

        for (i, part) in parts.enumerated() {
            var attr = AttributedString(part)
            if i % 2 == 1 {
                attr.font = .body.bold()
                attr.foregroundColor = .white
            }
            result += attr
        }

        return result
    }
}
