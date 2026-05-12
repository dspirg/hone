import SwiftUI

// MARK: - SessionSummaryView
// Session completion screen shown after the last set of the last exercise is confirmed.
// Displays total exercises, sets, reps, session duration, and PR badges.
// Done button dismisses SessionView (pops back to TrainView via NavigationStack).
//
// Difficulty rating captured via emoji picker (D-01, D-02) — required before dismissal.
// No weight logging — deferred per CONTEXT.md.
//
// UI-SPEC: Phase 11 Screen 3 "SessionSummaryView — Completion Screen"
// Requirements: SESS-04, PROG-03, UI-07
//
// D-10: Checkmark 36pt, stats merged into 4-item row using StatPillView
// D-11: Emoji difficulty picker always visible without scrolling
// D-12: PR badges section capped at 80pt with internal ScrollView; outer ScrollView removed

struct SessionSummaryView: View {
    let workoutDayLabel: String    // e.g., "Monday"
    let totalExercises: Int
    let totalSets: Int
    let totalReps: Int
    let duration: TimeInterval     // sessionDuration from SessionViewModel
    let prs: [PRResult]            // Personal records detected this session (D-14)
    let onDone: (DifficultyRating) -> Void  // Dismisses SessionView with rating

    @State private var selectedRating: DifficultyRating? = nil
    @State private var animatedExercises: Int = 0
    @State private var animatedSets: Int = 0
    @State private var animatedReps: Int = 0
    @State private var appeared = false

    private var celebrationHeading: String {
        ["Crushed it!", "Beast mode!", "Nailed it!", "Strong session!", "Great work!"].randomElement()!
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Glowing checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent, Color(red: 249/255, green: 115/255, blue: 22/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.accent.opacity(0.4), radius: 15)
                    .accessibilityLabel("Session complete")

                VStack(spacing: 4) {
                    Text(celebrationHeading)
                        .font(.title2.weight(.bold))

                    Text("\(workoutDayLabel) complete")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                Spacer().frame(height: 20)

                // Animated stat cards
                HStack(spacing: 8) {
                    statCard(label: "Exercises", value: "\(animatedExercises)")
                    statCard(label: "Sets", value: "\(animatedSets)")
                    statCard(label: "Reps", value: "\(animatedReps)")
                    statCard(label: "Duration", value: formattedDuration)
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // PR section with trophy styling
                if !prs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                            Text("New Records")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(.horizontal, 16)

                        ScrollView {
                            PRBadgeView(prs: prs)
                                .padding(.horizontal, 16)
                        }
                        .frame(maxHeight: 80)
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.1), Theme.accent.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 12)

                // Difficulty rating — unchanged logic
                VStack(spacing: 12) {
                    Text("How was that?")
                        .font(.headline)

                    HStack(spacing: 24) {
                        ForEach(DifficultyRating.allCases, id: \.self) { rating in
                            Button {
                                selectedRating = rating
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: rating.iconName)
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundStyle(rating.strokeColor)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            LinearGradient(
                                                colors: rating.gradientColors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: rating.gradientColors.last?.opacity(0.3) ?? .clear, radius: 8)
                                        .opacity(selectedRating == nil || selectedRating == rating ? 1.0 : 0.3)
                                        .scaleEffect(selectedRating == rating ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                                    Text(rating.label)
                                        .font(.caption2)
                                        .foregroundStyle(selectedRating == rating ? rating.gradientColors.last ?? Theme.accent : .secondary)
                                }
                            }
                            .accessibilityLabel(rating.label)
                        }
                    }
                }

                Spacer(minLength: 16)

                // Done button with gradient
                Button {
                    if let rating = selectedRating {
                        onDone(rating)
                    }
                } label: {
                    Text("Done")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Theme.accent, Color(red: 249/255, green: 115/255, blue: 22/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 4)
                }
                .disabled(selectedRating == nil)
                .opacity(selectedRating == nil ? 0.5 : 1.0)
                .padding(.horizontal, 16)

                Spacer().frame(height: 32)
            }

            // Confetti overlay (PRs only)
            if !prs.isEmpty && appeared {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            appeared = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.8)) {
                animatedExercises = totalExercises
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animatedSets = totalSets
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedReps = totalReps
            }
        }
    }

    // MARK: - Duration Formatting

    /// Formats duration as "42m 07s". Under 1 minute: "0m 45s".
    private var formattedDuration: String {
        let total = Int(max(duration, 0))
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(label == "Exercises" ? Theme.accent : .primary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SessionSummaryView(
            workoutDayLabel: "Monday",
            totalExercises: 5,
            totalSets: 15,
            totalReps: 120,
            duration: 2527,
            prs: [],
            onDone: { _ in }
        )
    }
}
#endif
