import SwiftUI

// MARK: - WorkoutProgressView
// Root view for the Progress tab (5th tab in MainTabView).
// Named WorkoutProgressView to avoid conflict with SwiftUI.ProgressView spinner.
// Shows streak card + weekly ring, session history with navigation to detail,
// and two Swift Charts (sessions/week bar chart, volume line chart).
// Empty state shown when no completed sessions exist.
// UI-SPEC: ProgressView — D-01 through D-11
// Requirements: PROG-01, PROG-02, PROG-04

struct WorkoutProgressView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                if viewModel.isLoading {
                    SwiftUI.ProgressView()
                        .scaleEffect(1.5)
                } else if let errorMessage = viewModel.loadError {
                    errorState(message: errorMessage)
                } else if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.onAppear(appState: appState)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Streak + Weekly Ring section
                streakRingSection
                    .padding(.horizontal, 16)

                // Recent Sessions section
                sessionHistorySection

                // Activity Charts section
                chartsSection
                    .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Streak + Ring Section

    private var streakRingSection: some View {
        HStack(spacing: 24) {
            StreakCard(
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak
            )
            .frame(maxWidth: .infinity)

            WeeklyRingView(
                completed: viewModel.weeklyCompleted,
                planned: viewModel.weeklyPlanned
            )
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Session History Section

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Sessions")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // Limit to last 20 sessions for performance
            let recentSessions = Array(viewModel.sessions.prefix(20))

            ForEach(Array(recentSessions.enumerated()), id: \.element.objectID) { index, session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    SessionHistoryRow(session: session)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if index < recentSessions.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)

            ChartSectionView(title: "Sessions / Week") {
                SessionsBarChart(weekBuckets: viewModel.weekBuckets)
            }
            .padding(.horizontal, 16)

            ChartSectionView(title: "Volume") {
                VolumeTrendChart(weekBuckets: viewModel.weekBuckets)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No sessions yet")
                .font(.title2.weight(.semibold))

            Text("Complete your first workout to start tracking progress.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Go to Train") {
                // Visual cue only — tab switching handled by MainTabView
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
