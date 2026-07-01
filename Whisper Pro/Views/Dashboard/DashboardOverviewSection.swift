import SwiftUI

struct DashboardOverviewSection: View {
    let stats: DashboardStats
    let insightsData: InsightsData?

    var body: some View {
        // Redesigned hero (2026-07): three switchable designs in
        // DashboardHeroRedesign.swift. The old WordsOverTimeCard +
        // OverviewStreakCard pair stays in the tree but is no longer mounted.
        DashboardHeroSection(stats: stats, insightsData: insightsData)
    }
}

/// Right-hand streak card: a big holographic lightning sticker over a single-row
/// "N Day Streak" label, with the longest streak beneath.
private struct OverviewStreakCard: View {
    let streak: Int
    let longest: Int
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            StickerAchievementBadge()
                .frame(width: 138, height: 177)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CountingNumberText("\(streak)", tracking: -0.4)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.resolvedPrimaryText)

                Text("Day Streak")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.resolvedPrimaryText)
            }

            Text("Longest \(longest) days")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .background(AppCardBackground(cornerRadius: 18))
    }
}

#if DEBUG
#Preview("Dashboard Overview Section") {
    DashboardOverviewSection(stats: .sample, insightsData: .sample)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 760)
}
#endif
