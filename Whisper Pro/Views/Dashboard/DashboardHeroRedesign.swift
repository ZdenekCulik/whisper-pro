import SwiftUI
import Charts

// MARK: - Dashboard hero
// One wide card: time-saved hero number, switchable activity charts and
// the holographic streak sticker on the right.

/// Top section of the dashboard.
struct DashboardHeroSection: View {
    let stats: DashboardStats
    let insightsData: InsightsData?
    var animate: Bool = true

    var body: some View {
        HeroCalmCard(stats: stats, insightsData: insightsData, animate: animate)
    }
}

// MARK: - Shared model helpers

enum DashboardChartStyle: String, CaseIterable, Identifiable {
    case activity = "calendar"
    case bars
    case growth

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .activity: return "V1"
        case .bars: return "V3"
        case .growth: return "Line"
        }
    }

    var displayName: String {
        switch self {
        case .activity: return "V1 — Activity Grid"
        case .bars: return "V3 — Daily Bars"
        case .growth: return "Line — Growing Curve"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .activity: return "Calendar activity chart"
        case .bars: return "Words bar chart"
        case .growth: return "Cumulative words curve"
        }
    }
}

/// Data slice + formatting for the hero card.
private struct HeroModel {
    let stats: DashboardStats
    let insightsData: InsightsData?
    let range: WordsRange

    var points: [WordsSeriesPoint] { insightsData?.wordsByRange[range] ?? [] }
    var hasLoaded: Bool { insightsData != nil }

    var spokenWords: Int { Int(points.reduce(0) { $0 + $1.value }) }

    private var baselineWords: Int {
        Int((insightsData?.wordsByRange[.total] ?? []).reduce(0) { $0 + $1.value })
    }

    /// All-time time saved scaled by the share of words in the selected range.
    var rangeTimeSavedSeconds: TimeInterval? {
        guard hasLoaded else { return nil }
        let ratio = baselineWords > 0 ? min(1, max(0, Double(spokenWords) / Double(baselineWords))) : 0
        return stats.timeSavedSeconds * ratio
    }

    var timeSavedText: String {
        guard let s = rangeTimeSavedSeconds else { return "–" }
        return HeroModel.durationText(s)
    }

    var currentStreak: Int { insightsData?.currentStreak ?? 0 }
    var longestStreak: Int { insightsData?.longestStreak ?? 0 }

    var activityDays: [InsightsData.DayActivity] {
        guard let days = insightsData?.days else { return [] }
        let count: Int
        switch range {
        case .today: count = 1
        case .week: count = 7
        case .month: count = 30
        case .sixMonths: count = 26 * 7
        case .year, .total: count = 52 * 7
        }
        return Array(days.suffix(count))
    }

    static func durationText(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0m" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        return formatter.string(from: interval) ?? "0m"
    }

    /// Compact figure for direct labels, e.g. 627,578 -> "628k".
    static func compact(_ value: Int) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
        case 10_000...:    return "\(Int((Double(value) / 1_000).rounded()))k"
        case 1_000...:     return String(format: "%.1fk", Double(value) / 1_000)
        default:           return "\(value)"
        }
    }

    var xAxisFormat: Date.FormatStyle {
        switch range {
        case .today: return .dateTime.hour()
        // Weekday + date ("Mon 29") so the axis shows WHICH day you spent what.
        case .week, .month: return .dateTime.weekday(.abbreviated).day()
        case .sixMonths, .year: return .dateTime.month(.abbreviated)
        case .total: return .dateTime.month(.abbreviated).day()
        }
    }

    var xAxisValues: AxisMarkValues {
        switch range {
        case .today:     return .stride(by: .hour, count: 3)
        case .week:      return .stride(by: .day)
        case .month:     return .stride(by: .day, count: 5)
        case .sixMonths: return .stride(by: .month)
        case .year:      return .stride(by: .month, count: 2)
        case .total:     return .stride(by: .month)
        }
    }

    func tooltipDateText(_ date: Date) -> String {
        switch range {
        case .today: return date.formatted(.dateTime.hour())
        case .week, .month: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .sixMonths: return "Week of " + date.formatted(.dateTime.month(.abbreviated).day())
        case .year: return date.formatted(.dateTime.month(.wide).year())
        case .total: return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }
    }

    var barWidth: MarkDimension {
        switch range {
        case .today: return .inset(4)
        case .week: return .inset(10)
        case .month, .sixMonths: return .inset(2)
        case .year: return .inset(4)
        case .total: return .inset(0.5)
        }
    }

    func cumulative(_ series: [WordsSeriesPoint]) -> [WordsSeriesPoint] {
        var total = 0.0
        return series.map { point in
            total += point.value
            return WordsSeriesPoint(date: point.date, value: total, duration: point.duration)
        }
    }

}

// MARK: - Range picker

private struct HeroRangePicker: View {
    @Binding var selectedRange: WordsRange
    @EnvironmentObject private var theme: ThemeManager

    private let inlineRanges: [WordsRange] = [.week, .month, .total]
    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(inlineRanges) { range in
                pill(range)
            }
        }
        .padding(3)
        .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.07)))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func pill(_ range: WordsRange) -> some View {
        let isSelected = range == selectedRange
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedRange = range }
        } label: {
            Text(range.label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(isSelected ? accent : theme.resolvedSecondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? accent.opacity(0.16) : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hover tooltip

// Chart .annotation closures don't inherit environment objects, so the tooltip
// takes its colors as plain values; an @EnvironmentObject here crashes at hover.
private struct HeroTooltip: View {
    let title: String
    let rows: [(color: Color, label: String, value: String)]
    let primaryText: Color
    let secondaryText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(secondaryText)
            ForEach(rows.indices, id: \.self) { i in
                let row = rows[i]
                HStack(spacing: 7) {
                    Circle().fill(row.color).frame(width: 6, height: 6)
                    Text(row.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(secondaryText)
                    Spacer(minLength: 4)
                    Text(row.value)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.92))
                        .monospacedDigit()
                }
            }
        }
        .frame(minWidth: 132, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(secondaryText.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

/// Transparent layer that tracks the cursor and resolves the nearest data point.
private struct HeroHoverCapture: View {
    let proxy: ChartProxy
    let points: [WordsSeriesPoint]
    @Binding var hovered: WordsSeriesPoint?

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hovered = nearestPoint(to: location, geo: geo)
                    case .ended:
                        hovered = nil
                    }
                }
        }
    }

    private func nearestPoint(to location: CGPoint, geo: GeometryProxy) -> WordsSeriesPoint? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let plotRect = geo[plotFrame]
        guard plotRect.contains(location) else { return nil }
        guard let date: Date = proxy.value(atX: location.x - plotRect.origin.x) else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}

// MARK: - Chart variants

/// V1 — calendar heatmap inspired by year-at-a-glance activity charts.
private struct HeroCalendarHeatmap: View {
    let days: [InsightsData.DayActivity]
    let range: WordsRange
    let accent: Color
    let inactive: Color

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekCount: Int {
        switch range {
        case .today, .week: return 1
        case .month: return 5
        case .sixMonths: return 26
        case .year, .total: return 52
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let gap = min(3, max(1, geometry.size.width / CGFloat(weekCount * 6)))
            let availableWidth = max(1, geometry.size.width - CGFloat(weekCount - 1) * gap)
            let cell = max(1, min(15, availableWidth / CGFloat(weekCount)))
            let columns = calendarColumns()

            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topLeading) {
                    ForEach(columns.indices, id: \.self) { index in
                        if let label = monthLabel(for: columns[index].first?.date, at: index, columns: columns) {
                            Text(label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(inactive.opacity(0.9))
                                .offset(x: CGFloat(index) * (cell + gap))
                        }
                    }
                }
                .frame(height: 11)

                HStack(alignment: .top, spacing: gap) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: gap) {
                            ForEach(week) { day in
                                RoundedRectangle(cornerRadius: max(1, min(3, cell * 0.22)), style: .continuous)
                                    .fill(color(for: day.count))
                                    .frame(width: cell, height: cell)
                                    .help(dayHelp(day))
                                    .accessibilityLabel(dayHelp(day))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 148)
        .clipped()
    }

    private func calendarColumns() -> [[InsightsData.DayActivity]] {
        let endDate = days.last?.date ?? Date()
        let weekday = calendar.component(.weekday, from: endDate)
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        let endWeekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: endDate)) ?? endDate
        let startDate = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: endWeekStart) ?? endWeekStart
        let values = Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0.count) })

        return (0..<weekCount).map { week in
            (0..<7).compactMap { weekday in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + weekday, to: startDate) else { return nil }
                return InsightsData.DayActivity(date: date, count: values[date] ?? 0)
            }
        }
    }

    private func monthLabel(
        for date: Date?,
        at index: Int,
        columns: [[InsightsData.DayActivity]]
    ) -> String? {
        guard let date else { return nil }
        let month = calendar.component(.month, from: date)
        if index > 0,
           let previous = columns[index - 1].first?.date,
           calendar.component(.month, from: previous) == month {
            return nil
        }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func color(for count: Int) -> Color {
        guard count > 0 else { return inactive.opacity(0.11) }
        let peak = max(days.map(\.count).max() ?? 1, 1)
        let ratio = Double(count) / Double(peak)
        switch ratio {
        case ..<0.18: return accent.opacity(0.30)
        case ..<0.42: return accent.opacity(0.50)
        case ..<0.72: return accent.opacity(0.74)
        default: return accent
        }
    }

    private func dayHelp(_ day: InsightsData.DayActivity) -> String {
        "\(day.date.formatted(.dateTime.month(.abbreviated).day())) · \(day.count) sessions"
    }
}

// MARK: - The hero card

private struct HeroCalmCard: View {
    let stats: DashboardStats
    let insightsData: InsightsData?
    let animate: Bool

    @AppStorage("dashboardWordsRange") private var selectedRange: WordsRange = .total
    // Only the growth-curve chart is offered anymore (Settings' Overview Chart
    // picker was removed) — hardcoded so a leftover persisted pick can't resurrect
    // a dead chart style.
    private let chartVariant: DashboardChartStyle = .growth
    @EnvironmentObject private var theme: ThemeManager
    @State private var hovered: WordsSeriesPoint?

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    /// `selectedRange` can still hold a legacy value (today/6M/year) from before
    /// the picker was trimmed to Week/Month/All — fall back to `.total` so the
    /// UI never lands on a range with no matching pill.
    private var displayRange: WordsRange {
        switch selectedRange {
        case .today, .sixMonths, .year: return .total
        case .week, .month, .total: return selectedRange
        }
    }

    private var rangeBinding: Binding<WordsRange> {
        Binding(get: { displayRange }, set: { selectedRange = $0 })
    }

    private var model: HeroModel { HeroModel(stats: stats, insightsData: insightsData, range: displayRange) }

    var body: some View {
        let m = model
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header(m)
                chart(m)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()
                .overlay(theme.resolvedSecondaryText.opacity(0.08))
                .padding(.vertical, 16)

            streakColumn(m)
                .frame(width: 172)
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 18))
    }

    private func header(_ m: HeroModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text("TIME SAVED")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(theme.resolvedSecondaryText)
                Spacer(minLength: 12)
                HeroRangePicker(selectedRange: rangeBinding)
            }

            Text(m.timeSavedText)
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.8)
                .foregroundColor(m.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.28), value: m.timeSavedText)

            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text("Dictated")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(m.hasLoaded ? m.spokenWords.formatted() : "–")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.resolvedPrimaryText.opacity(0.85))
                        .monospacedDigit()
                    Text("words")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText.opacity(0.8))
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func chart(_ m: HeroModel) -> some View {
        if chartVariant == .activity, !m.activityDays.isEmpty {
            HeroCalendarHeatmap(
                days: m.activityDays,
                range: displayRange,
                accent: accent,
                inactive: theme.resolvedSecondaryText
            )
            .id(chartVariant)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else if chartVariant == .bars, m.points.count >= 2 {
            let bars = Chart {
                ForEach(m.points) { point in
                    BarMark(
                        x: .value("Time", point.date),
                        y: .value("Words", point.value),
                        width: m.barWidth
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.78), accent],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(1.25)
                    .opacity(hovered == nil || hovered?.date == point.date ? 1 : 0.38)
                }
                if let hovered {
                    RuleMark(x: .value("Time", hovered.date))
                        .foregroundStyle(theme.resolvedSecondaryText.opacity(0.25))
                        .lineStyle(.init(lineWidth: 1))
                        .annotation(position: .top, spacing: 6,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            barTooltip(m, at: hovered)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(theme.resolvedSecondaryText.opacity(0.07))
                    AxisValueLabel {
                        if let words = value.as(Double.self) {
                            Text(HeroModel.compact(Int(words)))
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(theme.resolvedSecondaryText)
                }
            }
            .chartXAxis {
                AxisMarks(values: m.xAxisValues) { _ in
                    AxisValueLabel(format: m.xAxisFormat)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.resolvedSecondaryText)
                }
            }
            .chartOverlay { proxy in
                HeroHoverCapture(proxy: proxy, points: m.points, hovered: $hovered)
            }
            .animation(.easeOut(duration: 0.12), value: hovered)

            bars
            .frame(height: 148)
            .id(chartVariant)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else if chartVariant == .growth, m.points.count >= 2 {
            let cumulative = m.cumulative(m.points)
            Chart {
                ForEach(cumulative) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Words", point.value),
                        series: .value("Series", "dictated")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.22), accent.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                ForEach(cumulative) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Words", point.value),
                        series: .value("Series", "dictated")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(accent)
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                if let hovered {
                    RuleMark(x: .value("Time", hovered.date))
                        .foregroundStyle(theme.resolvedSecondaryText.opacity(0.25))
                        .lineStyle(.init(lineWidth: 1))
                        .annotation(position: .top, spacing: 6,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            growthTooltip(m, at: hovered)
                        }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: m.xAxisValues) { _ in
                    AxisValueLabel(format: m.xAxisFormat)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.resolvedSecondaryText)
                }
            }
            .chartOverlay { proxy in
                HeroHoverCapture(proxy: proxy, points: m.points, hovered: $hovered)
            }
            .animation(.easeOut(duration: 0.12), value: hovered)
            .frame(height: 148)
            .id(chartVariant)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else if !m.hasLoaded {
            // No insights loaded yet and nothing cached from a previous view — the
            // first load is still in flight. Blank rather than "not enough data":
            // that message is only true once a load has actually completed.
            loadingChart
        } else {
            emptyChart
        }
    }

    private var loadingChart: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 148)
    }

    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(theme.resolvedSecondaryText.opacity(0.5))
            Text("Not enough data for this range yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
    }

    private func barTooltip(_ m: HeroModel, at point: WordsSeriesPoint) -> some View {
        var rows: [(color: Color, label: String, value: String)] = [
            (accent, "Dictated", "\(Int(point.value).formatted()) words")
        ]
        if point.duration > 0 {
            rows.append((theme.resolvedSecondaryText, "Duration", HeroModel.durationText(point.duration)))
        }
        return HeroTooltip(
            title: m.tooltipDateText(point.date),
            rows: rows,
            primaryText: theme.resolvedPrimaryText,
            secondaryText: theme.resolvedSecondaryText
        )
    }

    private func growthTooltip(_ m: HeroModel, at point: WordsSeriesPoint) -> some View {
        let total = Int(
            m.points
                .filter { $0.date <= point.date }
                .reduce(0.0) { $0 + $1.value }
        )
        return HeroTooltip(
            title: m.tooltipDateText(point.date) + " · total so far",
            rows: [(accent, "Dictated", "\(total.formatted()) words")],
            primaryText: theme.resolvedPrimaryText,
            secondaryText: theme.resolvedSecondaryText
        )
    }

    private func streakColumn(_ m: HeroModel) -> some View {
        VStack(spacing: 10) {
            StickerAchievementBadge()
                .frame(width: 122, height: 156)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(m.hasLoaded ? "\(m.currentStreak)" : "–")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundColor(theme.resolvedPrimaryText)
                        .contentTransition(.numericText())
                    Text("Day Streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.resolvedPrimaryText)
                }
                Text(m.hasLoaded ? "Longest \(m.longestStreak) days" : "Longest — days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Dashboard Hero") {
    DashboardHeroSection(stats: .sample, insightsData: .sample)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 860)
}
#endif
