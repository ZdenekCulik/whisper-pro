import SwiftUI

/// The Insights panel. The hero above already shows the headline counters (sessions,
/// words, wpm, time saved), so this panel skips those and focuses on the visual
/// stories: a 2/3 activity heatmap beside a 1/3 lightning streak card, then when you
/// dictate + which apps. Explanatory text lives on hover, not on the face.
struct InsightsV1Refined: View {
    let data: InsightsData
    let stats: DashboardStats
    var animate: Bool = true

    @EnvironmentObject var theme: ThemeManager

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    /// Fixed height for the activity/streak row — tall enough for the streak card's
    /// sticker + labels (~240pt) so neither column overflows into the row below.
    /// The heatmap sizes by cell count, not width, so this is stable across widths.
    private let topRowHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let gap: CGFloat = 12
                let available = geo.size.width - gap
                HStack(spacing: gap) {
                    activityCard.frame(width: available * 2 / 3)
                    streakCard.frame(width: available / 3)
                }
            }
            .frame(height: topRowHeight)

            HStack(alignment: .top, spacing: 12) {
                whenPanel
                appsPanel
            }
        }
    }

    // MARK: Activity (2/3)

    private var activityCard: some View {
        card(fillHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Activity")
                ContributionGraphView(days: data.days, accent: accent, animate: animate, showMonths: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help("Most active on \(mostActiveWeekday)s · \(activeDayCount) active days")
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Day streak (1/3) — the lightning sticker lives here, once

    private var streakCard: some View {
        card(fillHeight: true, contentAlignment: .center) {
            VStack(spacing: 10) {
                StickerAchievementBadge()
                    .frame(width: 97, height: 122)
                VStack(spacing: 1) {
                    CountingNumberText("\(data.currentStreak)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(theme.resolvedPrimaryText)
                    cardLabel("DAY STREAK")
                }
                cardLabel("LONGEST · \(data.longestStreak) DAYS")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Bottom row — two charts

    private var whenPanel: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("When you dictate")
                InsightTimeOfDay(hours: data.hourBuckets, accent: accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var appsPanel: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    sectionTitle("Top apps")
                    Spacer()
                    cardLabel("DICTATED INTO · \(data.topApps.count)")
                }
                if data.topApps.isEmpty {
                    Text("App names start filling in as you dictate.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                } else {
                    TopAppsList(apps: data.topApps, accent: accent, animate: animate)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Derived

    private var activeDayCount: Int {
        data.days.filter { $0.count > 0 }.count
    }

    private var mostActiveWeekday: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        var totals: [Int: Int] = [:]
        for day in data.days {
            let weekday = calendar.component(.weekday, from: day.date)
            totals[weekday, default: 0] += day.count
        }
        let best = totals.max { $0.value < $1.value }?.key ?? 3
        return calendar.weekdaySymbols[(best - 1) % 7]
    }

    // MARK: Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(theme.resolvedPrimaryText)
    }

    private func cardLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.4)
            .foregroundColor(theme.resolvedSecondaryText)
    }

    private func card<Content: View>(
        fillHeight: Bool = false,
        contentAlignment: Alignment = .topLeading,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: contentAlignment)
            .background(AppCardBackground(cornerRadius: 16))
    }
}

#if DEBUG
#Preview("Insights panel") {
    InsightsV1Refined(data: .sample, stats: .sample, animate: false)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 980)
}
#endif
