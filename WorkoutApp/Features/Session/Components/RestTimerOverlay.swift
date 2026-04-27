import SwiftUI
import AudioToolbox

// MARK: - RestTimerOverlay
// Date-anchored circular countdown overlay displayed as a ZStack layer above ExerciseCardView.
//
// CRITICAL: This is NOT a .fullScreenCover — it is a ZStack overlay within SessionView.
// Using fullScreenCover would pause AVPlayer in the card beneath (RESEARCH.md Pitfall 2).
//
// Implementation follows RESEARCH.md Pattern 1:
//   - ProgressView(timerInterval:countsDown:) for the circular ring — driven by Date range, not a timer
//   - Timer.publish at 0.5Hz solely to detect expiry (not for countdown display)
//   - sensoryFeedback(.success) + AudioServicesPlaySystemSound(1016) on expire
//
// Requirements: SESS-02 (rest timer), T-04-10 (DoS — timer fires only while overlay in hierarchy)

struct RestTimerOverlay: View {
    let endDate: Date
    let nextContextLabel: String
    let onSkip: () -> Void
    let onExtend: () -> Void
    let onExpired: () -> Void

    @State private var expired = false

    var body: some View {
        ZStack {
            // Backdrop: opaque enough to focus user on timer; ExerciseCardView + AVPlayer remain
            // in the hierarchy beneath (preserving playback state — RESEARCH.md Pitfall 2)
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 32) {
                // "REST" heading — minimal chrome per CONTEXT.md
                Text("REST")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                // Date-anchored circular countdown ring — RESEARCH.md Pattern 1
                // ProgressView(timerInterval:) owns the countdown display; no manual date math
                ProgressView(timerInterval: Date()...endDate, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    Text(endDate, style: .timer)
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .progressViewStyle(.circular)
                .tint(Theme.accent)
                .frame(width: 200, height: 200)
                .accessibilityLabel("Rest timer")

                // "Up next: ..." context label from SessionViewModel.nextContextLabel
                Text(nextContextLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Action buttons
                HStack(spacing: 24) {
                    Button("+30s", action: onExtend)
                        .buttonStyle(.bordered)
                        .contentShape(Rectangle())
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Add 30 seconds to rest")

                    Button("Skip Rest") {
                        expired = false
                        onSkip()
                    }
                    .buttonStyle(.borderedProminent)
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Skip rest, go to next set")
                }
            }
        }
        // Haptic feedback on timer expiry — .sensoryFeedback(.success) per UI-SPEC
        .sensoryFeedback(.success, trigger: expired)
        // 0.5Hz polling timer — only to detect expiry; countdown display is driven by ProgressView
        // T-04-10: cancelled automatically when overlay leaves the ZStack hierarchy
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            guard !expired else { return }
            if now >= endDate {
                expired = true
                // Soft system sound on expire — tweet sound (1016) per CONTEXT.md "soft sound on expire"
                AudioServicesPlaySystemSound(1016)
                // Auto-dismiss via SessionViewModel.handleTimerExpired()
                onExpired()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    RestTimerOverlay(
        endDate: Date().addingTimeInterval(60),
        nextContextLabel: "Up next: Set 2 — Bench Press",
        onSkip: {},
        onExtend: {},
        onExpired: {}
    )
}
#endif
