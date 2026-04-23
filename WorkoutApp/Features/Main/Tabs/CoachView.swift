import SwiftUI

struct CoachView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CoachViewModel()
    @State private var messageText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Coach header (D-27)
            CoachHeaderView()

            // Offline banner (D-32) — above chat, below header
            if !viewModel.isOnline {
                OfflineBannerView()
            }

            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Date-grouped messages (D-18)
                        ForEach(groupedMessages, id: \.date) { group in
                            ChatDateHeader(date: group.date)

                            ForEach(group.messages) { message in
                                VStack(alignment: .leading, spacing: 8) {
                                    ChatBubbleView(message: message)

                                    // Plan modification card below coach message (D-05, D-06)
                                    if message.role == .coach,
                                       message.planModificationJSON != nil {
                                        PlanModificationCard(
                                            message: message,
                                            onConfirm: {
                                                viewModel.confirmModification(
                                                    messageId: message.id,
                                                    appState: appState
                                                )
                                            },
                                            onDismiss: {
                                                viewModel.dismissModification(messageId: message.id)
                                            }
                                        )
                                        .padding(.leading, 8)
                                    }
                                }
                                .id(message.id)
                            }
                        }

                        // Streaming bubble — OUTSIDE ForEach to avoid LazyVStack recycling (Pitfall 7)
                        if viewModel.isStreaming {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "figure.run")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("Coach")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack(spacing: 0) {
                                        Text(viewModel.streamingText)
                                        // D-04: Pulsing cursor at end of streaming text
                                        StreamingCursorView()
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                Spacer(minLength: 60)
                            }
                            .id("streaming")
                        }

                        // Error bubble — tap to retry (D-33)
                        if case .error(let errorMsg) = viewModel.chatState {
                            Button(action: { viewModel.retry() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.secondary)
                                    Text(errorMsg)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Scroll anchor
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                // D-02: Auto-scroll to bottom as tokens arrive
                .onChange(of: viewModel.streamingText) { _, _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input bar at bottom (D-34)
            ChatInputBar(
                messageText: $messageText,
                isStreaming: viewModel.isStreaming,
                isOnline: viewModel.isOnline,
                onSend: {
                    let text = messageText
                    messageText = ""
                    viewModel.sendMessage(text, appState: appState)
                }
            )
        }
        .onAppear { viewModel.onAppear(appState: appState) }
        .onDisappear { viewModel.onDisappear() }
        .animation(.easeInOut, value: viewModel.isOnline)
    }

    // MARK: - Date Grouping (D-18)

    struct MessageGroup: Identifiable {
        let date: Date
        let messages: [ChatMessage]
        var id: Date { date }
    }

    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.messages) { msg in
            calendar.startOfDay(for: msg.createdAt)
        }
        return grouped.sorted { $0.key < $1.key }
            .map { MessageGroup(date: $0.key, messages: $0.value) }
    }
}
