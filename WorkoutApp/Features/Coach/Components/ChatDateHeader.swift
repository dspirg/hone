import SwiftUI

struct ChatDateHeader: View {
    let date: Date

    var body: some View {
        Text(sectionTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private var sectionTitle: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
