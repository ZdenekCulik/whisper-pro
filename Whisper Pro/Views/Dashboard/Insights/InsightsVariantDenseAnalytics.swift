import SwiftUI
import Charts

/// V2 — analytics-tool feel: a tight grid of metric tiles each carrying a sparkline,
/// then a wide full-width activity heatmap. Denser, more data-forward than V1.
struct InsightsVariantDenseAnalytics: View {
    let data: InsightsData
    let stats: DashboardStats
    var animate: Bool = true

    @EnvironmentObject var theme: ThemeManager

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 14) {
                tile(stats.words, "Total words", data.wordsTrend, delta: data.wordsDeltaPercent)
                tile(stats.wordsPerMinute, "Words / min", data.wpmTrend, delta: 8)
                tile(stats.sessions, "Sessions", data.wordsTrend, delta: 12)
                tile(stats.timeSaved, "Time saved", data.wpmTrend, delta: nil, valueSize: 18)
            }

            heatmapPanel
            modePanel
        }
    }

    private func tile(
        _ value: String,
        _ label: String,
        _ trend: [InsightsData.TrendPoint],
        delta: Int?,
        valueSize: CGFloat = 24
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(theme.resolvedSecondaryText)
            CountingNumberText(value)
                .font(.system(size: valueSize, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let delta {
                DeltaBadge(percent: delta)
            }
            Spacer(minLength: 6)
            Sparkline(points: trend, accent: accent, height: 30)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.resolvedSecondaryText.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.resolvedBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private var heatmapPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.resolvedPrimaryText)
                Spacer()
                Text("\(data.currentStreak)-day streak · best \(data.longestStreak)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                ContributionLegend(accent: accent)
            }
            ContributionGraphView(days: data.days, accent: accent, animate: animate)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 16))
    }

    private var modePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mode breakdown")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)
            InsightModeBars(modes: data.modes, accent: accent, animate: animate)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 16))
    }
}

#if DEBUG
#Preview("V2 Dense analytics") {
    InsightsVariantDenseAnalytics(data: .sample, stats: .sample, animate: false)
        .environmentObject(ThemeManager())
        .padding(28)
        .frame(width: 1040)
}
#endif
