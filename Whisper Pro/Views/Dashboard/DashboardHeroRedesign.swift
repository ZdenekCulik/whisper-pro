import SwiftUI
import Charts

// MARK: - Dashboard hero (redesign 2026-07, Zdenek picked V1 "Calm")
// One wide card: time-saved hero number, cumulative dictated-words chart and
// the holographic streak sticker on the right. The gray "Napsáno" (typed)
// line was removed 2026-07: the app is about dictation, and the typed counts
// proved mostly machine text (see TypedLogIngestor — its ingest stays off).
// Replaces the old WordsOverTimeCard + OverviewStreakCard pair (kept in the
// tree, just no longer mounted).

/// Top section of the dashboard.
struct DashboardHeroSection: View {
    let stats: DashboardStats
    let insightsData: InsightsData?
    var animate: Bool = true

    var body: some View {
        HeroCalmCard(stats: stats, insightsData: insightsData)
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
        case .sixMonths, .year, .total: return .dateTime.month(.abbreviated)
        }
    }

    var xAxisValues: AxisMarkValues {
        switch range {
        case .today:     return .stride(by: .hour, count: 3)
        case .week:      return .stride(by: .day)
        case .month:     return .stride(by: .day, count: 5)
        case .sixMonths: return .stride(by: .month)
        case .year:      return .stride(by: .month, count: 2)
        case .total:     return .automatic(desiredCount: 6)
        }
    }

    func tooltipDateText(_ date: Date) -> String {
        switch range {
        case .today: return date.formatted(.dateTime.hour())
        case .week, .month: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .sixMonths: return "Week of " + date.formatted(.dateTime.month(.abbreviated).day())
        case .year, .total: return date.formatted(.dateTime.month(.wide).year())
        }
    }

    /// Cumulative running totals, so the calm curves climb instead of spiking.
    func cumulative(_ series: [WordsSeriesPoint]) -> [WordsSeriesPoint] {
        var total = 0.0
        return series.map { p in
            total += p.value
            return WordsSeriesPoint(date: p.date, value: total, duration: p.duration)
        }
    }
}

// MARK: - Range picker

private struct HeroRangePicker: View {
    @Binding var selectedRange: WordsRange
    @EnvironmentObject private var theme: ThemeManager

    private let inlineRanges: [WordsRange] = [.week, .month, .sixMonths, .total]
    private let moreRanges: [WordsRange] = [.today, .year]
    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(inlineRanges) { range in
                pill(range)
            }
            moreMenu
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

    private var moreMenu: some View {
        Menu {
            ForEach(moreRanges) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedRange = range }
                } label: {
                    if range == selectedRange {
                        Label(range.menuLabel, systemImage: "checkmark")
                    } else {
                        Text(range.menuLabel)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(moreRanges.contains(selectedRange) ? accent : theme.resolvedSecondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
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

    @AppStorage("dashboardWordsRange") private var selectedRange: WordsRange = .sixMonths
    @EnvironmentObject private var theme: ThemeManager
    @State private var hovered: WordsSeriesPoint?

    private var accent: Color { theme.resolvedAccent ?? .accentColor }
    private var model: HeroModel { HeroModel(stats: stats, insightsData: insightsData, range: selectedRange) }

    var body: some View {
        let m = model
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header(m)
                chart(m)
            }
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
                HeroRangePicker(selectedRange: $selectedRange)
            }

            Text(m.timeSavedText)
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.8)
                .foregroundColor(m.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.28), value: m.timeSavedText)

            HStack(spacing: 14) {
                legendItem(color: accent, label: "Nadiktováno", value: HeroModel.compact(m.spokenWords))
                // The range itself is visible on the picker above, so no
                // "· Last 30 days" caption here — just the unit.
                Text("words")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText.opacity(0.8))
            }
            .padding(.top, 2)
        }
    }

    private func legendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText.opacity(0.85))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func chart(_ m: HeroModel) -> some View {
        if m.points.count >= 2 {
            let spoken = m.cumulative(m.points)
            Chart {
                ForEach(spoken) { p in
                    AreaMark(x: .value("Time", p.date), y: .value("Words", p.value),
                             series: .value("Series", "dictated"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.01)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                ForEach(spoken) { p in
                    LineMark(x: .value("Time", p.date), y: .value("Words", p.value),
                             series: .value("Series", "dictated"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(accent)
                        .lineStyle(.init(lineWidth: 2, lineCap: .round))
                }
                if let hovered {
                    RuleMark(x: .value("Time", hovered.date))
                        .foregroundStyle(theme.resolvedSecondaryText.opacity(0.25))
                        .lineStyle(.init(lineWidth: 1))
                        .annotation(position: .top, spacing: 6,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            tooltip(m, at: hovered)
                        }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: m.xAxisValues) { _ in
                    AxisGridLine().foregroundStyle(theme.resolvedSecondaryText.opacity(0.07))
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
        } else {
            emptyChart
        }
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

    private func tooltip(_ m: HeroModel, at point: WordsSeriesPoint) -> some View {
        // The chart plots running totals, so the tooltip mirrors that.
        let spoken = Int(m.points.reduce(0) { $1.date <= point.date ? $0 + $1.value : $0 })
        return HeroTooltip(
            title: m.tooltipDateText(point.date) + "  ·  total so far",
            rows: [(accent, "Nadiktováno", spoken.formatted())],
            primaryText: theme.resolvedPrimaryText,
            secondaryText: theme.resolvedSecondaryText
        )
    }

    private func streakColumn(_ m: HeroModel) -> some View {
        VStack(spacing: 10) {
            StickerAchievementBadge()
                .frame(width: 108, height: 138)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(m.currentStreak)")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundColor(theme.resolvedPrimaryText)
                        .contentTransition(.numericText())
                    Text("Day Streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.resolvedPrimaryText)
                }
                Text("Longest \(m.longestStreak) days")
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
