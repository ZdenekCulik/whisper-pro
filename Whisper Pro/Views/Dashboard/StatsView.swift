import SwiftUI
import SwiftData
import Charts
import os

private struct StatsSummary: Equatable, Sendable {
    var totalCount: Int = 0
    var totalWords: Int = 0
    var totalDuration: TimeInterval = 0
}

private enum StatsSummaryLoader {
    static func load(from modelContainer: ModelContainer) async throws -> StatsSummary {
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let backgroundContext = ModelContext(modelContainer)
            let count = try backgroundContext.fetchCount(FetchDescriptor<SessionMetric>())

            try Task.checkCancellation()

            var words = 0
            var duration: TimeInterval = 0
            let batchSize = 500
            var offset = 0

            while offset < count {
                try Task.checkCancellation()

                var descriptor = FetchDescriptor<SessionMetric>()
                descriptor.fetchLimit = batchSize
                descriptor.fetchOffset = offset

                let records = try backgroundContext.fetch(descriptor)
                if records.isEmpty { break }

                for metric in records {
                    words += metric.wordCount
                    duration += metric.audioDuration
                }

                offset += records.count
            }

            try Task.checkCancellation()

            return StatsSummary(
                totalCount: count,
                totalWords: words,
                totalDuration: duration
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

struct StatsView: View {
    private let logger = Logger(subsystem: "com.prakashjoshipax.whisperpro", category: "StatsView")

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeManager

    @State private var totalCount: Int = 0
    @State private var totalWords: Int = 0
    @State private var totalDuration: TimeInterval = 0
    @State private var hasLoadedStatsSnapshot = false
    @State private var insightsData: InsightsData?
    @State private var summaryTask: Task<Void, Never>?
    @State private var insightsTask: Task<Void, Never>?

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    StatsProductivityGainCard(stats: dashboardStats)

                    StatsMetricGrid(
                        stats: dashboardStats,
                        insightsData: insightsData
                    )

                    if let insightsData {
                        analyticsGrid(data: insightsData)
                    } else if hasLoadedStatsSnapshot {
                        emptyAnalyticsCard
                    }

                    Text("All times in your local time zone")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 1)
                }
                .frame(minHeight: geometry.size.height - 42, alignment: .top)
                .padding(.top, 40)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .task {
            await loadStats()
            await loadInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionMetricsDidChange)) { _ in
            summaryTask?.cancel()
            summaryTask = Task { await loadStats() }

            insightsTask?.cancel()
            insightsTask = Task { await loadInsights() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .typedMetricsDidChange)) { _ in
            // Typed-words aggregates changed — refresh only the insights (the
            // gray line). Dictation summary is unaffected.
            insightsTask?.cancel()
            insightsTask = Task { await loadInsights() }
        }
        .onDisappear {
            summaryTask?.cancel()
            insightsTask?.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stats")
                    .font(.system(size: 25, weight: .bold))
                    .tracking(-0.35)
                    .foregroundColor(theme.resolvedPrimaryText)

                Text("Detailed insights from your dictation history.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
            }

            Spacer()

            Text("All time")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.08)))
        }
    }

    private func analyticsGrid(data: InsightsData) -> some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    StatsActivityCard(data: data, accent: accent)
                        .frame(maxWidth: .infinity)

                    StatsTimeOfDayCard(data: data, accent: accent)
                        .frame(width: 224)
                }

                VStack(spacing: 10) {
                    StatsActivityCard(data: data, accent: accent)
                    StatsTimeOfDayCard(data: data, accent: accent)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                StatsTopAppsCard(data: data, accent: accent)
                    .frame(maxWidth: .infinity)

                StatsWordsTrendCard(data: data, accent: accent)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                StatsMiniTrendCard(
                    title: "Enhanced sessions",
                    subtitle: "AI improvement applied",
                    value: "\(data.enhancedSessions)",
                    points: data.enhancedTrend,
                    accent: accent
                )

                StatsMiniTrendCard(
                    title: "Dictionary entries",
                    subtitle: "Custom words and rules",
                    value: "\(data.dictionaryWords + data.dictionaryReplacements)",
                    points: data.wordsTrend,
                    accent: accent
                )
            }
        }
    }

    private var emptyAnalyticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analytics will appear after your first dictation.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)
            Text("Record a few sessions to unlock activity, app, and trend charts.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StatsCardBackground(cornerRadius: 12))
    }

    private var dashboardStats: DashboardStats {
        DashboardStats(
            timeSaved: hasLoadedStatsSnapshot
                ? StatsFormatters.formattedDuration(timeSaved, style: .abbreviated, fallback: "0m")
                : "Whisper Pro Insights",
            timeSavedSeconds: timeSaved,
            sessions: hasLoadedStatsSnapshot ? StatsFormatters.formattedNumber(totalCount) : "-",
            words: hasLoadedStatsSnapshot ? StatsFormatters.formattedNumber(totalWords) : "-",
            wordsPerMinute: hasLoadedStatsSnapshot && averageWordsPerMinute > 0
                ? String(format: "%.0f", averageWordsPerMinute) : "-",
            keystrokes: hasLoadedStatsSnapshot ? StatsFormatters.formattedNumber(totalKeystrokesSaved) : "-",
            wordsToday: "–",
            hasLoaded: hasLoadedStatsSnapshot
        )
    }

    private func loadStats() async {
        do {
            let summary = try await StatsSummaryLoader.load(from: modelContext.container)

            guard !Task.isCancelled else { return }

            let shouldAcceptSummary = summary.totalCount > 0 || !SessionMetricMigrationService.shared.isRunning

            await MainActor.run {
                guard shouldAcceptSummary else { return }
                totalCount = summary.totalCount
                totalWords = summary.totalWords
                totalDuration = summary.totalDuration
                hasLoadedStatsSnapshot = true
            }
        } catch is CancellationError {
        } catch {
            logger.error("Error loading stats summary: \(error, privacy: .public)")
        }
    }

    private func loadInsights() async {
        do {
            let data = try await InsightsLoader.load(from: modelContext.container)
            guard !Task.isCancelled else { return }
            await MainActor.run { insightsData = data }
        } catch is CancellationError {
        } catch {
            logger.error("Error loading stats insights: \(error, privacy: .public)")
        }
    }

    private var estimatedTypingTime: TimeInterval {
        Double(totalWords) / 35.0 * 60.0
    }

    private var timeSaved: TimeInterval {
        max(estimatedTypingTime - totalDuration, 0)
    }

    private var averageWordsPerMinute: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalWords) / (totalDuration / 60.0)
    }

    private var totalKeystrokesSaved: Int {
        Int(Double(totalWords) * 5.0)
    }
}

private struct StatsProductivityGainCard: View {
    let stats: DashboardStats

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Estimated productivity gain")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.resolvedPrimaryText)

                Spacer()

                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
            }

            HStack(spacing: 14) {
                gainColumn(value: stats.timeSaved, label: "Time saved")

                Divider().overlay(theme.resolvedBorder.opacity(0.6))

                gainColumn(value: "~\(stats.keystrokes)", label: "Keystrokes saved")

                Divider().overlay(theme.resolvedBorder.opacity(0.6))

                Text("Based on 35 WPM typing and ~5 keystrokes per word.")
                    .font(.system(size: 11.5, weight: .medium))
                    .lineSpacing(3)
                    .foregroundColor(theme.resolvedSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 50)
        }
        .padding(14)
        .background(StatsCardBackground(cornerRadius: 10))
    }

    private func gainColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CountingNumberText(value, tracking: -0.55)
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(stats.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatsMetricGrid: View {
    let stats: DashboardStats
    let insightsData: InsightsData?

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
            spacing: 8
        ) {
            metric("text.bubble.fill", stats.words, "Words dictated", "All time", AppTheme.Sidebar.modes)
            metric("speedometer", stats.wordsPerMinute, "Avg. speed", "Based on audio time", AppTheme.Status.infoStrong)
            metric("mic.fill", stats.sessions, "Dictations", "Completed", AppTheme.Status.positive)
            metric("sparkles", "\(insightsData?.enhancedSessions ?? 0)", "Enhanced sessions", "AI improved", AppTheme.Sidebar.modes)
            metric("text.book.closed.fill", "\(dictionaryEntries)", "Dictionary entries", "Words + rules", AppTheme.Sidebar.dictionary)
        }
    }

    private var dictionaryEntries: Int {
        guard let insightsData else { return 0 }
        return insightsData.dictionaryWords + insightsData.dictionaryReplacements
    }

    private func metric(
        _ icon: String,
        _ value: String,
        _ label: String,
        _ detail: String,
        _ color: Color
    ) -> some View {
        StatsMetricCard(icon: icon, value: value, label: label, detail: detail, color: color, hasLoaded: stats.hasLoaded)
    }
}

private struct StatsMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let detail: String
    let color: Color
    let hasLoaded: Bool

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            DashboardIconGlyph(systemName: icon, color: color, size: 16, frameSize: 20)

            CountingNumberText(value, tracking: -0.35)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 8.8, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(detail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(StatsCardBackground(cornerRadius: 10))
    }
}

private struct StatsActivityCard: View {
    let data: InsightsData
    let accent: Color

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        StatsAnalyticsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    StatsSectionTitle(title: "Activity", subtitle: "Last 17 weeks")
                    Spacer()
                    ContributionLegend(accent: accent)
                }

                HStack(alignment: .center, spacing: 10) {
                    ContributionGraphView(days: data.days, accent: accent, animate: true, showMonths: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    StatsDayStreakSticker(
                        current: data.currentStreak,
                        longest: data.longestStreak
                    )
                    .frame(width: 74)
                }
            }
        }
        .frame(minHeight: 176)
    }
}

private struct StatsDayStreakSticker: View {
    let current: Int
    let longest: Int

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 4) {
            StickerAchievementBadge()
                .frame(width: 40, height: 50)

            Text("\(current)")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)

            Text("Day streak".uppercased())
                .font(.system(size: 8.8, weight: .semibold))
                .tracking(0.55)
                .foregroundColor(theme.resolvedSecondaryText)
                .lineLimit(1)

            Text("Best \(longest)")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private struct StatsTimeOfDayCard: View {
    let data: InsightsData
    let accent: Color

    @EnvironmentObject private var theme: ThemeManager

    private var peakHour: Int {
        data.hourBuckets.max { $0.value < $1.value }?.index ?? 12
    }

    var body: some View {
        StatsAnalyticsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    StatsSectionTitle(title: "When you dictate", subtitle: "By time of day")
                    Spacer()
                    Text("Most around \(clockLabel(peakHour))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                InsightTimeOfDay(hours: data.hourBuckets, accent: accent)
            }
        }
        .frame(minHeight: 176)
    }

    private func clockLabel(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12) \(hour < 12 ? "AM" : "PM")"
    }
}

private struct StatsTopAppsCard: View {
    let data: InsightsData
    let accent: Color

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        StatsAnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    StatsSectionTitle(title: "Top apps", subtitle: "Tracked from recent sessions")
                    Spacer()
                    Text("View all")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.08)))
                }

                if data.topApps.isEmpty {
                    Text("App names start filling in as you dictate.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText)
                        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
                } else {
                    TopAppsList(apps: data.topApps.prefix(3).map { $0 }, accent: accent)
                }
            }
        }
        .frame(minHeight: 176)
    }
}

private struct StatsWordsTrendCard: View {
    let data: InsightsData
    let accent: Color

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        StatsAnalyticsCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    StatsSectionTitle(title: "Words trend", subtitle: "Last 12 weeks")
                    Spacer()
                    Text(deltaText)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.Status.positive)
                    Text("vs last month")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText)
                }

                Chart(data.wordsTrend) { point in
                    AreaMark(
                        x: .value("Week", point.index),
                        y: .value("Words", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.28), accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Week", point.index),
                        y: .value("Words", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent)
                    .lineStyle(.init(lineWidth: 2.4))
                }
                .chartXAxis {
                    AxisMarks(values: [0, 4, 8, 11]) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self) {
                                Text(axisLabel(for: index))
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(theme.resolvedSecondaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(theme.resolvedBorder.opacity(0.35))
                        AxisValueLabel {
                            if let words = value.as(Double.self) {
                                Text(shortNumber(words))
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(theme.resolvedSecondaryText)
                            }
                        }
                    }
                }
                .frame(height: 104)
            }
        }
        .frame(minHeight: 176)
    }

    private var deltaText: String {
        let sign = data.wordsDeltaPercent >= 0 ? "+" : "-"
        return "\(sign)\(abs(data.wordsDeltaPercent))%"
    }

    private func axisLabel(for index: Int) -> String {
        // index 11 == current week and each step back is one week earlier (matches
        // InsightsLoader bucketing), so the labels track the real calendar month.
        let date = Calendar.current.date(byAdding: .weekOfYear, value: index - 11, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func shortNumber(_ value: Double) -> String {
        if value >= 1_000 {
            return "\(Int(value / 1_000))K"
        }
        return "\(Int(value))"
    }
}

private struct StatsMiniTrendCard: View {
    let title: String
    let subtitle: String
    let value: String
    let points: [InsightsData.TrendPoint]
    let accent: Color

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.resolvedPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.2)
                    .foregroundColor(theme.resolvedPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(subtitle)
                    .font(.system(size: 10.8, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                Sparkline(points: points, accent: accent, height: 26)
                    .frame(width: 80)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(StatsCardBackground(cornerRadius: 10))
    }
}

private struct StatsAnalyticsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(StatsCardBackground(cornerRadius: 10))
    }
}

private struct StatsSectionTitle: View {
    let title: String
    let subtitle: String

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.15)
                .foregroundColor(theme.resolvedPrimaryText)

            Text(subtitle)
                .font(.system(size: 10.8, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }
}

private struct StatsCardBackground: View {
    var cornerRadius: CGFloat

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.resolvedSecondaryText.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(theme.resolvedBorder.opacity(0.32), lineWidth: 0.8)
            )
    }
}

private enum StatsFormatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()

    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        return formatter
    }()

    static func formattedNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formattedDuration(
        _ interval: TimeInterval,
        style: DateComponentsFormatter.UnitsStyle,
        fallback: String = "-"
    ) -> String {
        guard interval > 0 else { return fallback }
        durationFormatter.unitsStyle = style
        durationFormatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        return durationFormatter.string(from: interval) ?? fallback
    }
}

#if DEBUG
#Preview("Stats") {
    StatsProductivityGainCard(stats: .sample)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 760)
}
#endif
