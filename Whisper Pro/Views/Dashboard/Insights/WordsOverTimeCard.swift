import SwiftUI
import Charts

/// Dedicated "Words over time" chart card with a selectable time range.
/// Replaces the old decorative sparkline: a clean monotone line + area that
/// reads accurately at any range, with the chosen range persisted.
struct WordsOverTimeCard: View {
    let insightsData: InsightsData?
    /// All-time time saved (seconds). When set, the card leads with a "time saved"
    /// headline — scaled to the selected range — and demotes the words figure to a
    /// secondary line, merging both into one hero.
    var timeSavedSeconds: TimeInterval? = nil

    @AppStorage("dashboardWordsRange") private var selectedRange: WordsRange = .sixMonths
    @EnvironmentObject private var theme: ThemeManager
    @State private var hoveredPoint: WordsSeriesPoint?

    private var accent: Color { theme.resolvedAccent ?? .accentColor }
    private var points: [WordsSeriesPoint] { insightsData?.wordsByRange[selectedRange] ?? [] }
    private var totalWords: Int { Int(points.reduce(0) { $0 + $1.value }) }
    private var hasLoaded: Bool { insightsData != nil }

    /// All-time words from the same series, used to scale time saved by the share
    /// of words that fall in the selected range.
    private var baselineWords: Int {
        Int((insightsData?.wordsByRange[.total] ?? []).reduce(0) { $0 + $1.value })
    }

    /// Time saved for the selected range, formatted (e.g. "29h 11m"), or nil while loading.
    private var rangeTimeSavedText: String? {
        guard let timeSavedSeconds, hasLoaded else { return nil }
        let ratio = baselineWords > 0 ? min(1, max(0, Double(totalWords) / Double(baselineWords))) : 0
        return Self.durationText(timeSavedSeconds * ratio)
    }

    private static func durationText(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0m" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        return formatter.string(from: interval) ?? "0m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            chart
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 18))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Eyebrow + range switcher share the top row, so the big value below
            // gets the full card width and the switcher never has to wrap.
            HStack(alignment: .center, spacing: 12) {
                Text((timeSavedSeconds != nil ? "Time saved" : "Words over time").uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(theme.resolvedSecondaryText)

                Spacer(minLength: 12)

                rangePicker
            }

            if timeSavedSeconds != nil {
                Text(rangeTimeSavedText ?? "–")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.7)
                    .foregroundColor(hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())

                wordsLine
            } else {
                wordsHeadline
            }
        }
    }

    /// Big words figure — used when the card is standalone (no time-saved hero).
    private var wordsHeadline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            CountingNumberText(hasLoaded ? totalWords.formatted() : "–", tracking: -0.6)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("words · \(selectedRange.caption)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }

    /// Compact words line — used beneath the time-saved hero in the merged card.
    private var wordsLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            CountingNumberText(hasLoaded ? totalWords.formatted() : "–", tracking: -0.2)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.resolvedSecondaryText)

            Text("words over time · \(selectedRange.caption)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .padding(.top, 2)
    }

    // The common ranges sit inline; the rest live in a "More" dropdown so the
    // switcher stays compact next to the streak card.
    private let inlineRanges: [WordsRange] = [.week, .month, .sixMonths, .total]
    private let moreRanges: [WordsRange] = [.today, .year]
    private var isMoreSelected: Bool { moreRanges.contains(selectedRange) }

    private var rangePicker: some View {
        HStack(spacing: 2) {
            ForEach(inlineRanges) { range in
                rangePill(range)
            }
            moreMenu
        }
        .padding(3)
        .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.07)))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func rangePill(_ range: WordsRange) -> some View {
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
                .foregroundColor(isMoreSelected ? accent : theme.resolvedSecondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var chart: some View {
        if points.count >= 2 {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Words", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.28), accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Words", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(accent)
                    .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
                }

                if let hoveredPoint {
                    RuleMark(x: .value("Time", hoveredPoint.date))
                        .foregroundStyle(theme.resolvedSecondaryText.opacity(0.28))
                        .lineStyle(.init(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Time", hoveredPoint.date),
                        y: .value("Words", hoveredPoint.value)
                    )
                    .foregroundStyle(accent)
                    .symbolSize(70)
                    .annotation(
                        position: .top,
                        spacing: 10,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        tooltip(for: hoveredPoint)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(theme.resolvedSecondaryText.opacity(0.08))
                    AxisValueLabel(format: xAxisFormat)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.resolvedSecondaryText)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoveredPoint = nearestPoint(to: location, proxy: proxy, geo: geo)
                            case .ended:
                                hoveredPoint = nil
                            }
                        }
                }
            }
            .animation(.easeOut(duration: 0.12), value: hoveredPoint)
            .frame(height: 150)
        } else {
            emptyState
        }
    }

    /// Map a cursor position to the nearest data point along the x-axis.
    private func nearestPoint(to location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> WordsSeriesPoint? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let plotRect = geo[plotFrame]
        guard plotRect.contains(location) else { return nil }
        guard let date: Date = proxy.value(atX: location.x - plotRect.origin.x) else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private func tooltip(for point: WordsSeriesPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tooltipDateText(point.date))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(theme.resolvedSecondaryText)
            Text("\(Int(point.value.rounded()).formatted()) words")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)
            Text("\(Self.durationText(point.duration)) spoken")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.resolvedSecondaryText.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    /// Date label in the tooltip, matched to the granularity of the selected range.
    private func tooltipDateText(_ date: Date) -> String {
        switch selectedRange {
        case .today:
            return date.formatted(.dateTime.hour())
        case .week, .month:
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .sixMonths:
            return "Week of " + date.formatted(.dateTime.month(.abbreviated).day())
        case .year, .total:
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(theme.resolvedSecondaryText.opacity(0.5))
            Text("Not enough data for this range yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .today:
            return .dateTime.hour()
        case .week, .month:
            return .dateTime.month(.abbreviated).day()
        case .sixMonths, .year, .total:
            return .dateTime.month(.abbreviated)
        }
    }
}

#if DEBUG
#Preview("Words Over Time Card") {
    WordsOverTimeCard(insightsData: .sample)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 760)
}
#endif
