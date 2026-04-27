import SwiftUI
import Charts

// MARK: - ChartSectionView
// Card container wrapping a chart with a title header and "Last 8 weeks" trailing label.
// Used twice in ProgressView: once for sessions/week bar chart, once for volume line chart.
// UI-SPEC: ChartSectionView — D-08, D-09, D-10, D-11
// Requirements: PROG-04

struct ChartSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("Last 8 weeks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - SessionsBarChart
// Bar chart: sessions per week over the last 8 weeks.
// Bar foreground: .secondary (system adaptive gray — informational, not decorative).
// Chart height: 160pt fixed.
// UI-SPEC: Sessions/Week Bar Chart — D-08

struct SessionsBarChart: View {
    let weekBuckets: [WeekBucket]

    var body: some View {
        if weekBuckets.isEmpty {
            Text("No data yet")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("No sessions data available")
        } else {
            Chart(weekBuckets) { bucket in
                BarMark(
                    x: .value("Week", bucket.weekLabel),
                    y: .value("Sessions", bucket.sessionCount)
                )
                .foregroundStyle(Color.secondary)
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .accessibilityLabel("Sessions per week chart, last 8 weeks")
        }
    }
}

// MARK: - VolumeTrendChart
// Line + area chart: total volume (sets × reps) per week over the last 8 weeks.
// Line foreground: AccentColor at 70% opacity.
// Area fill: LinearGradient from AccentColor 20% to AccentColor 2% opacity.
// Interpolation: .catmullRom for smooth curves.
// Chart height: 160pt fixed.
// UI-SPEC: Volume Line Chart — D-09

struct VolumeTrendChart: View {
    let weekBuckets: [WeekBucket]

    var body: some View {
        if weekBuckets.isEmpty {
            Text("No data yet")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("No volume data available")
        } else {
            Chart(weekBuckets) { bucket in
                LineMark(
                    x: .value("Week", bucket.weekLabel),
                    y: .value("Volume", bucket.volume)
                )
                .foregroundStyle(Theme.accent.opacity(0.7))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Week", bucket.weekLabel),
                    y: .value("Volume", bucket.volume)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.2),
                            Theme.accent.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .accessibilityLabel("Volume trend chart, last 8 weeks")
        }
    }
}
