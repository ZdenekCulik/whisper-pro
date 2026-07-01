import SwiftUI
import Charts

private enum WordsChartShape: String, CaseIterable, Identifiable {
    case sharp
    case smooth

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .sharp: return "Sharp line"
        case .smooth: return "Smooth line"
        }
    }

    var interpolation: InterpolationMethod {
        switch self {
        case .sharp: return .linear
        case .smooth: return .monotone
        }
    }

    var lineCap: CGLineCap {
        switch self {
        case .sharp: return .butt
        case .smooth: return .round
        }
    }
}

/// Four ways to show spoken-vs-written when "written" dwarfs "spoken". All linear
/// (log was rejected: it made 1k and 100k look the same). Switch live with V1/V2/V3/V4.
private enum WordsChartVariant: String, CaseIterable, Identifiable {
    case cumulative      // V1: running totals — two growing curves, gap = how much more you write
    case smallMultiples  // V2: two separate mini-charts, each auto-scaled to its own peak
    case dualAxis        // V3: both lines on one chart, each normalized to fill the height
    case bars            // V4: per-bucket clustered bars with honest linear magnitudes

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .cumulative: return "V1"
        case .smallMultiples: return "V2"
        case .dualAxis: return "V3"
        case .bars: return "V4"
        }
    }
}

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
    @AppStorage("dashboardWordsChartShape") private var chartShape: WordsChartShape = .sharp
    @AppStorage("dashboardWordsChartVariant") private var chartVariant: WordsChartVariant = .cumulative
    @EnvironmentObject private var theme: ThemeManager
    @State private var hoveredPoint: WordsSeriesPoint?

    private var accent: Color { theme.resolvedAccent ?? .accentColor }
    private var points: [WordsSeriesPoint] { insightsData?.wordsByRange[selectedRange] ?? [] }
    private var totalWords: Int { Int(points.reduce(0) { $0 + $1.value }) }
    /// Typed words for the selected range — counted only while the gray line shows.
    private var typedTotalWords: Int {
        showTyped ? Int(typedPoints.reduce(0) { $0 + $1.value }) : 0
    }
    /// Dictated + typed words for the range. Drives the header figure so it always
    /// exceeds any single hovered bucket (which shows the same combined total),
    /// keeping the headline and the hover numbers consistent.
    private var combinedTotalWords: Int { totalWords + typedTotalWords }
    private let countedTextAnimation: Animation = .easeOut(duration: 0.28)
    private var hasLoaded: Bool { insightsData != nil }

    /// Gray "Napsáno" (typed) series for the selected range, aligned 1:1 with `points`.
    private var typedPoints: [WordsSeriesPoint] { insightsData?.typedWordsByRange[selectedRange] ?? [] }
    /// Show the gray line + its legend only when typed data exists and this range
    /// carries at least two non-zero points (an all-zero range, e.g. Today, stays hidden).
    private var showTyped: Bool {
        (insightsData?.hasTypedData ?? false) && typedPoints.filter { $0.value > 0 }.count >= 2
    }
    private func typedPoint(at date: Date) -> WordsSeriesPoint? {
        guard showTyped else { return nil }
        return typedPoints.first { $0.date == date }
    }

    /// All-time words from the same series, used to scale time saved by the share
    /// of words that fall in the selected range.
    private var baselineWords: Int {
        Int((insightsData?.wordsByRange[.total] ?? []).reduce(0) { $0 + $1.value })
    }

    /// Time saved for the selected range, in seconds, or nil while loading.
    private var rangeTimeSavedSeconds: TimeInterval? {
        guard let timeSavedSeconds, hasLoaded else { return nil }
        let ratio = baselineWords > 0 ? min(1, max(0, Double(totalWords) / Double(baselineWords))) : 0
        return timeSavedSeconds * ratio
    }

    private var rangeTimeSavedText: String? {
        guard let rangeTimeSavedSeconds else { return nil }
        return Self.durationText(rangeTimeSavedSeconds)
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
                CountingDurationText(
                    seconds: rangeTimeSavedSeconds,
                    animation: countedTextAnimation,
                    formatter: Self.durationText
                )
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.7)
                    .foregroundColor(hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(countedTextAnimation, value: rangeTimeSavedText)

                wordsLine
            } else {
                wordsHeadline
            }

            legend
        }
    }

    /// Manual legend — Swift Charts shows no auto-legend here. The gray "Napsáno"
    /// entry only appears when there is typed data to show. The V1/V2/V3 switcher
    /// sits on the right of the same row.
    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: accent, label: "Nadiktováno")
            if showTyped {
                legendItem(color: theme.resolvedSecondaryText, label: "Napsáno")
            }
            Spacer(minLength: 12)
            variantSwitcher
        }
        .padding(.top, 2)
    }

    /// V1/V2/V3 segmented switcher — flip chart styles live to compare them.
    private var variantSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(WordsChartVariant.allCases) { variant in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { chartVariant = variant }
                } label: {
                    Text(variant.shortLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(variant == chartVariant ? accent : theme.resolvedSecondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(variant == chartVariant ? accent.opacity(0.16) : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.07)))
        .fixedSize()
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .tracking(0.2)
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }

    /// Big words figure — used when the card is standalone (no time-saved hero).
    private var wordsHeadline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            CountingNumberText(
                hasLoaded ? combinedTotalWords.formatted() : "–",
                animation: countedTextAnimation,
                tracking: -0.6
            )
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
            CountingNumberText(
                hasLoaded ? combinedTotalWords.formatted() : "–",
                animation: countedTextAnimation,
                tracking: -0.2
            )
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
            Section("Range") {
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
            }

            Section("Chart style") {
                ForEach(WordsChartShape.allCases) { shape in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) { chartShape = shape }
                    } label: {
                        if shape == chartShape {
                            Label(shape.menuLabel, systemImage: "checkmark")
                        } else {
                            Text(shape.menuLabel)
                        }
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
            Group {
                switch chartVariant {
                case .cumulative:     cumulativeChart
                case .smallMultiples: smallMultiplesChart
                case .dualAxis:       dualAxisChart
                case .bars:           barsChart
                }
            }
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.28), value: chartVariant)
        } else {
            emptyState
        }
    }

    // MARK: - Shared chart styling

    private func areaGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.26), color.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func barGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.95), color.opacity(0.68)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var seriesLineStyle: StrokeStyle {
        .init(lineWidth: 2.5, lineCap: chartShape.lineCap, lineJoin: .round)
    }

    private var barsMarkWidth: CGFloat {
        let visibleBars = points.count * (showTyped ? 2 : 1)
        switch visibleBars {
        case 0...16: return 10
        case 17...36: return 8
        case 37...64: return 5.5
        case 65...96: return 4
        default: return 3
        }
    }

    private var barsYMax: Double {
        let spokenMax = points.map(\.value).max() ?? 0
        let typedMax = showTyped ? (typedPoints.map(\.value).max() ?? 0) : 0
        return max(max(spokenMax, typedMax), 1) * 1.08
    }

    private func barOpacity(for date: Date) -> Double {
        guard let hoveredPoint else { return 1 }
        return hoveredPoint.date == date ? 1 : 0.36
    }

    /// One point on a cumulative curve. A named struct (not a tuple) so it's
    /// Identifiable for `ForEach` — Swift can't key-path into tuple members.
    private struct CumulativePoint: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    /// Running total of a series, so cumulative curves climb instead of spiking.
    private func cumulativeSeries(_ series: [WordsSeriesPoint]) -> [CumulativePoint] {
        var total = 0.0
        return series.map { point in
            total += point.value
            return CumulativePoint(date: point.date, value: total)
        }
    }

    /// Sum of a numeric field across every bucket up to and including `date` — the
    /// cumulative value at that point on the V1 curve.
    private func sumUpTo(_ date: Date, _ series: [WordsSeriesPoint], _ field: KeyPath<WordsSeriesPoint, Double>) -> Double {
        series.reduce(0) { $1.date <= date ? $0 + $1[keyPath: field] : $0 }
    }

    // MARK: - V1: Cumulative growth

    private var cumulativeChart: some View {
        let spoken = cumulativeSeries(points)
        let typed = showTyped ? cumulativeSeries(typedPoints) : []
        return Chart {
            // Clean lines only — no filled areas. The overlapping fills made the
            // smaller "spoken" total look like the biggest dark block. With lines, the
            // gray line ending ABOVE the blue line correctly reads as "wrote more".
            ForEach(typed) { p in
                LineMark(x: .value("Time", p.date), y: .value("Words", p.value),
                         series: .value("Series", "typed"))
                    .interpolationMethod(chartShape.interpolation)
                    .foregroundStyle(theme.resolvedSecondaryText)
                    .lineStyle(seriesLineStyle)
            }
            ForEach(spoken) { p in
                LineMark(x: .value("Time", p.date), y: .value("Words", p.value),
                         series: .value("Series", "dictated"))
                    .interpolationMethod(chartShape.interpolation)
                    .foregroundStyle(accent)
                    .lineStyle(seriesLineStyle)
            }
            hoverRule(withTooltip: true)
        }
        .chartYAxis(.hidden)
        .chartXAxis { defaultXAxis }
        .chartOverlay { proxy in hoverCapture(proxy) }
        .animation(.easeOut(duration: 0.12), value: hoveredPoint)
    }

    // MARK: - V2: Small multiples (each auto-scaled)

    private var smallMultiplesChart: some View {
        VStack(spacing: 10) {
            miniChart(points, color: accent, caption: "Nadiktováno", showTooltip: true)
            if showTyped {
                miniChart(typedPoints, color: theme.resolvedSecondaryText, caption: "Napsáno", showTooltip: false)
            }
        }
    }

    private func miniChart(_ series: [WordsSeriesPoint], color: Color, caption: String, showTooltip: Bool) -> some View {
        let maxValue = max(series.map(\.value).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 3) {
            Text(caption.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(theme.resolvedSecondaryText)
            Chart {
                ForEach(series) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Words", point.value))
                        .interpolationMethod(chartShape.interpolation)
                        .foregroundStyle(areaGradient(color))
                    LineMark(x: .value("Time", point.date), y: .value("Words", point.value))
                        .interpolationMethod(chartShape.interpolation)
                        .foregroundStyle(color)
                        .lineStyle(seriesLineStyle)
                }
                hoverRule(withTooltip: showTooltip)
            }
            .chartYScale(domain: 0...maxValue)
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .frame(maxHeight: .infinity)
            .chartOverlay { proxy in hoverCapture(proxy) }
            .animation(.easeOut(duration: 0.12), value: hoveredPoint)
        }
    }

    // MARK: - V3: Dual axis (each normalized to fill the height)

    private var dualAxisChart: some View {
        let spokenMax = max(points.map(\.value).max() ?? 1, 1)
        let typedMax = max(typedPoints.map(\.value).max() ?? 1, 1)
        // Scale written into spoken's range so BOTH lines use the full height.
        let scale = spokenMax / typedMax
        return Chart {
            if showTyped {
                ForEach(typedPoints) { point in
                    LineMark(x: .value("Time", point.date), y: .value("V", point.value * scale),
                             series: .value("Series", "typed"))
                        .interpolationMethod(chartShape.interpolation)
                        .foregroundStyle(theme.resolvedSecondaryText)
                        .lineStyle(seriesLineStyle)
                }
            }
            ForEach(points) { point in
                LineMark(x: .value("Time", point.date), y: .value("V", point.value),
                         series: .value("Series", "dictated"))
                    .interpolationMethod(chartShape.interpolation)
                    .foregroundStyle(accent)
                    .lineStyle(seriesLineStyle)
            }
            hoverRule(withTooltip: true)
        }
        .chartYAxis(.hidden)
        .chartXAxis { defaultXAxis }
        .chartOverlay { proxy in hoverCapture(proxy) }
        .animation(.easeOut(duration: 0.12), value: hoveredPoint)
    }

    // MARK: - V4: Clustered bars (honest per-bucket volume)

    private var barsChart: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Time", point.date),
                    y: .value("Words", point.value),
                    width: .fixed(barsMarkWidth)
                )
                .position(by: .value("Series", "dictated"))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .foregroundStyle(barGradient(accent))
                .opacity(barOpacity(for: point.date))
            }

            if showTyped {
                ForEach(typedPoints) { point in
                    BarMark(
                        x: .value("Time", point.date),
                        y: .value("Words", point.value),
                        width: .fixed(barsMarkWidth)
                    )
                    .position(by: .value("Series", "typed"))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .foregroundStyle(barGradient(theme.resolvedSecondaryText))
                    .opacity(barOpacity(for: point.date))
                }
            }

            hoverRule(withTooltip: true)
        }
        .chartYScale(domain: 0...barsYMax)
        .chartYAxis(.hidden)
        .chartXAxis { defaultXAxis }
        .chartOverlay { proxy in hoverCapture(proxy) }
        .animation(.easeOut(duration: 0.12), value: hoveredPoint)
    }

    @AxisContentBuilder
    private var defaultXAxis: some AxisContent {
        AxisMarks(values: xAxisValues) { _ in
            AxisGridLine()
                .foregroundStyle(theme.resolvedSecondaryText.opacity(0.08))
            AxisValueLabel(format: xAxisFormat)
                .font(.system(size: 10))
                .foregroundStyle(theme.resolvedSecondaryText)
        }
    }

    // MARK: - Shared hover (crosshair + tooltip)

    /// Dashed vertical crosshair at the hovered date. `withTooltip` draws the floating
    /// tooltip on top — used on the main/upper chart only so V2's two stacked charts
    /// share one rule but show a single tooltip.
    @ChartContentBuilder
    private func hoverRule(withTooltip: Bool) -> some ChartContent {
        if let hoveredPoint {
            RuleMark(x: .value("Time", hoveredPoint.date))
                .foregroundStyle(theme.resolvedSecondaryText.opacity(0.28))
                .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                .annotation(
                    position: .top,
                    spacing: 6,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    if withTooltip {
                        tooltip(for: hoveredPoint)
                    }
                }
        }
    }

    /// Transparent layer that tracks the cursor and resolves the nearest data point.
    private func hoverCapture(_ proxy: ChartProxy) -> some View {
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
        // V1 is a running total, so its tooltip must show cumulative figures (summed up
        // TO this date) so the numbers match where the lines actually sit. V2/V3/V4 show
        // the per-bucket values for that day/week.
        let cumulative = chartVariant == .cumulative
        let spokenWords = Int((cumulative ? sumUpTo(point.date, points, \.value) : point.value).rounded())
        let writtenWords: Int = {
            guard showTyped else { return 0 }
            let v = cumulative ? sumUpTo(point.date, typedPoints, \.value) : (typedPoint(at: point.date)?.value ?? 0)
            return Int(v.rounded())
        }()
        let displayDuration = cumulative ? sumUpTo(point.date, points, \.duration) : point.duration
        let totalWords = spokenWords + writtenWords

        return VStack(alignment: .leading, spacing: 4) {
            Text(tooltipDateText(point.date) + (cumulative ? "  ·  total so far" : ""))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(theme.resolvedSecondaryText)
            // Mirror the header's order: time (prominent) first, words below. The
            // time is always shown with no "spoken time" label, so the layout never
            // switches shapes — a bucket with no dictation simply reads "0m".
            Text(Self.durationText(displayDuration))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)
                .monospacedDigit()
            Text("\(totalWords.formatted()) words")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .monospacedDigit()

            tooltipMetricRow(color: accent, "Spoken", "\(spokenWords.formatted()) words")
                .padding(.top, 2)
            if showTyped {
                tooltipMetricRow(color: theme.resolvedSecondaryText, "Written", "\(writtenWords.formatted()) words")
            }
        }
        .frame(minWidth: 148, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
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

    private func tooltipMetricRow(color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText.opacity(0.92))
                .monospacedDigit()
        }
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
            return .dateTime.day()
        case .sixMonths, .year, .total:
            return .dateTime.month(.abbreviated)
        }
    }

    /// Axis tick density tuned per range: every day across a week, periodic days for
    /// a month, every month for the longer ranges — so the bottom labels read as the
    /// period the user picked instead of a sparse auto-count.
    private var xAxisValues: AxisMarkValues {
        switch selectedRange {
        case .today:     return .stride(by: .hour, count: 3)
        case .week:      return .stride(by: .day)
        case .month:     return .stride(by: .day, count: 5)
        case .sixMonths: return .stride(by: .month)
        case .year:      return .stride(by: .month, count: 2)
        case .total:     return .automatic(desiredCount: 6)
        }
    }
}

private struct CountingDurationText: View {
    let seconds: TimeInterval?
    let animation: Animation
    let formatter: (TimeInterval) -> String

    @State private var displayedSeconds: TimeInterval = 0

    var body: some View {
        if let seconds {
            CountingDurationDigits(seconds: displayedSeconds, formatter: formatter)
                .onAppear {
                    displayedSeconds = 0
                    withAnimation(animation) { displayedSeconds = seconds }
                }
                .onChange(of: seconds) { _, newValue in
                    withAnimation(animation) { displayedSeconds = newValue }
                }
        } else {
            Text("–")
        }
    }
}

private struct CountingDurationDigits: View, Animatable {
    var seconds: TimeInterval
    let formatter: (TimeInterval) -> String

    var animatableData: TimeInterval {
        get { seconds }
        set { seconds = newValue }
    }

    var body: some View {
        Text(formatter(max(0, seconds)))
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
