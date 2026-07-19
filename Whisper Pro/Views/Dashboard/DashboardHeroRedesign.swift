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

// MARK: - The hero card

private struct HeroCalmCard: View {
    let stats: DashboardStats
    let insightsData: InsightsData?
    let animate: Bool

    @AppStorage("dashboardWordsRange") private var selectedRange: WordsRange = .total
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
        // Only the growth-curve (cumulative line) chart is offered anymore — the
        // Settings' Overview Chart picker that used to switch between an activity
        // heatmap, daily bars, and this growth curve was removed, so this is the
        // only branch left besides the loading/empty states below.
        if m.points.count >= 2 {
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
