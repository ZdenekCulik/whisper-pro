import SwiftUI

/// V1 — faithful to the Flow "Insights" reference: a row of three stat cards on top,
/// then two large panels below (mode bars left, activity heatmap right).
struct InsightsVariantFlowClone: View {
    let data: InsightsData
    let stats: DashboardStats
    /// Pass false for stable screenshots.
    var animate: Bool = true

    @EnvironmentObject var theme: ThemeManager

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                wpmCard
                fixesCard
                totalWordsCard
            }
            HStack(alignment: .top, spacing: 18) {
                modePanel
                streakPanel
            }
        }
    }

    // MARK: Top cards

    private var wpmCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                CountingNumberText(stats.wordsPerMinute)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(theme.resolvedPrimaryText)
                Text("WORDS PER MINUTE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(theme.resolvedSecondaryText)
                Spacer(minLength: 4)
                MiniGauge(value: 0.82, accent: accent, caption: "Top 4%")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var fixesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                CountingNumberText("7 029")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(theme.resolvedPrimaryText)
                Text("FIXES MADE BY WHISPER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(theme.resolvedSecondaryText)
                Spacer(minLength: 8)
                miniRow("6 631", "words corrected")
                miniRow("398", "dictionary fixes")
            }
        }
    }

    private var totalWordsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    CountingNumberText(stats.words)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(theme.resolvedPrimaryText)
                    Spacer()
                    DeltaBadge(percent: data.wordsDeltaPercent)
                }
                Text("TOTAL WORDS DICTATED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(theme.resolvedSecondaryText)
                Spacer(minLength: 8)
                Sparkline(points: data.wordsTrend, accent: accent, height: 56)
            }
        }
    }

    private func miniRow(_ value: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            CountingNumberText(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }

    // MARK: Bottom panels

    private var modePanel: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                panelHeader("Mode usage", trailing: "TOTAL MODES | \(data.modes.count)")
                InsightModeBars(modes: data.modes, accent: accent, animate: animate)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var streakPanel: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                panelHeader("\(data.currentStreak) day streak", trailing: "LONGEST | \(data.longestStreak) DAYS")
                ContributionGraphView(days: data.days, accent: accent, animate: animate)
                ContributionLegend(accent: accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func panelHeader(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)
            Spacer()
            Text(trailing)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppCardBackground(cornerRadius: 18))
    }
}

#if DEBUG
#Preview("V1 Flow clone") {
    InsightsVariantFlowClone(data: .sample, stats: .sample, animate: false)
        .environmentObject(ThemeManager())
        .padding(28)
        .frame(width: 1040)
}
#endif
