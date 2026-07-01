import SwiftUI

/// V3 — calm, premium, editorial: an oversized "time saved" hero with an animated
/// accent underline, the activity heatmap as the centrepiece, mode bars demoted
/// to a quiet supporting strip. Generous whitespace.
struct InsightsVariantEditorialHero: View {
    let data: InsightsData
    let stats: DashboardStats
    var animate: Bool = true

    @EnvironmentObject var theme: ThemeManager
    @State private var underline: Double = 0

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            hero
            heatmap
            footerStrip
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 24))
        .onAppear {
            guard animate else { underline = 1; return }
            withAnimation(.easeOut(duration: 0.7)) { underline = 1 }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME SAVED WITH WHISPER PRO")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(theme.resolvedSecondaryText)

            Text(stats.timeSaved)
                .font(.system(size: 52, weight: .bold))
                .tracking(-1)
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .overlay(alignment: .bottomLeading) {
                    Capsule()
                        .fill(accent)
                        .frame(height: 5)
                        .scaleEffect(x: underline, anchor: .leading)
                        .offset(y: 10)
                }

            HStack(spacing: 28) {
                heroStat(stats.words, "words dictated")
                heroStat(stats.wordsPerMinute, "words / min")
                heroStat(stats.sessions, "sessions")
                heroStat("\(data.currentStreak) days", "current streak")
            }
            .padding(.top, 14)
        }
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CountingNumberText(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your year in voice")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.resolvedPrimaryText)
                Spacer()
                ContributionLegend(accent: accent)
            }
            ContributionGraphView(days: data.days, accent: accent, animate: animate)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var footerStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(theme.resolvedBorder.opacity(0.6))
            HStack(alignment: .firstTextBaseline) {
                Text("How you dictate")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.resolvedSecondaryText)
                Spacer()
            }
            InsightModeBars(modes: data.modes, accent: accent, animate: animate)
        }
    }
}

#if DEBUG
#Preview("V3 Editorial hero") {
    InsightsVariantEditorialHero(data: .sample, stats: .sample, animate: false)
        .environmentObject(ThemeManager())
        .padding(28)
        .frame(width: 1040)
}
#endif
