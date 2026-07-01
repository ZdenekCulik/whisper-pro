import Foundation

/// Selectable time range for the "Words over time" dashboard chart.
enum WordsRange: String, CaseIterable, Identifiable {
    case today, week, month, sixMonths, year, total

    var id: String { rawValue }

    /// Short label shown on the segmented control.
    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .sixMonths: return "6M"
        case .year: return "Year"
        case .total: return "All"
        }
    }

    /// Longer label used in the "more ranges" dropdown menu.
    var menuLabel: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .sixMonths: return "6 Months"
        case .year: return "Year"
        case .total: return "All time"
        }
    }

    /// Human description shown under the headline number.
    var caption: String {
        switch self {
        case .today: return "Today, by hour"
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .sixMonths: return "Last 6 months, weekly"
        case .year: return "Last 12 months"
        case .total: return "All time, monthly"
        }
    }
}

/// One bucket of the words time-series, dated so the chart can lay out an axis.
struct WordsSeriesPoint: Equatable, Identifiable {
    let date: Date
    let value: Double
    /// Seconds of audio dictated in this bucket — surfaced in the hover tooltip.
    var duration: TimeInterval = 0
    var id: Date { date }
}

/// Richer analytics data for the Insights panel variants.
///
/// `DashboardStats` only carries pre-formatted headline strings; the charts need
/// the underlying series (per-day activity, per-mode breakdown, trends). For the
/// variant exploration this is fed by `.sample`; the chosen variant gets wired to
/// live `SessionMetric` aggregates afterwards.
struct InsightsData: Equatable {
    struct DayActivity: Equatable, Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    struct ModeSlice: Equatable, Identifiable {
        let name: String
        let symbol: String
        let fraction: Double // 0...1
        let count: Int
        /// App bundle id, used to look up the real macOS app icon (apps only).
        var bundleId: String? = nil
        var id: String { name }
    }

    struct TrendPoint: Equatable, Identifiable {
        let index: Int
        let value: Double
        var id: Int { index }
    }

    /// ~17 weeks of daily session counts, oldest first.
    let days: [DayActivity]
    let modes: [ModeSlice]
    let wpmTrend: [TrendPoint]
    let wordsTrend: [TrendPoint]
    /// Per-week count of AI-enhanced sessions, oldest first.
    let enhancedTrend: [TrendPoint]
    /// Words dictated per hour-of-day, index 0...23.
    let hourBuckets: [TrendPoint]
    /// Apps you dictate into most, largest first.
    let topApps: [ModeSlice]
    let currentStreak: Int
    let longestStreak: Int
    /// Month-over-month change for total words, e.g. -61 or +24.
    let wordsDeltaPercent: Int
    /// Dictionary: custom vocabulary words you taught it.
    let dictionaryWords: Int
    /// Dictionary: text replacement rules.
    let dictionaryReplacements: Int
    /// Sessions Whisper polished with AI enhancement.
    let enhancedSessions: Int
    /// Pre-bucketed words time-series, one series per selectable range.
    let wordsByRange: [WordsRange: [WordsSeriesPoint]]
    /// Typed-words ("Napsáno") time-series from Claude + Codex logs, bucketed to
    /// match `wordsByRange`. Default empty so existing call sites compile.
    var typedWordsByRange: [WordsRange: [WordsSeriesPoint]] = [:]
    /// Whether any typed-words data exists. Drives showing/hiding the gray line.
    var hasTypedData: Bool = false

    /// Largest daily count, used to normalise the contribution heatmap into levels.
    var maxDayCount: Int { days.map(\.count).max() ?? 0 }
}

extension InsightsData {
    /// Deterministic sample data (no randomness) so variant screenshots are stable.
    static let sample: InsightsData = {
        let calendar = Calendar(identifier: .gregorian)
        // Fixed anchor so the grid is identical across runs.
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 6, day: 13))!
        let totalDays = 17 * 7

        var days: [DayActivity] = []
        for offset in stride(from: totalDays - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: anchor) else { continue }
            // Deterministic pseudo-pattern: mostly light, occasional bursts, some empty days.
            let h = (offset &* 2_654_435_761) % 97
            let count: Int
            switch h % 10 {
            case 0, 1, 2: count = 0
            case 3, 4: count = 2 + (h % 4)
            case 5, 6: count = 6 + (h % 6)
            case 7, 8: count = 12 + (h % 9)
            default: count = 22 + (h % 14)
            }
            days.append(DayActivity(date: date, count: count))
        }

        let modes: [ModeSlice] = [
            ModeSlice(name: "General", symbol: "mic.fill", fraction: 0.72, count: 1_588),
            ModeSlice(name: "Coding", symbol: "chevron.left.forwardslash.chevron.right", fraction: 0.16, count: 352),
            ModeSlice(name: "Email", symbol: "envelope.fill", fraction: 0.08, count: 176),
            ModeSlice(name: "Messages", symbol: "bubble.left.fill", fraction: 0.04, count: 88)
        ]

        let wpm: [Double] = [88, 92, 96, 91, 103, 110, 99, 118, 124, 116, 130, 126]
        let words: [Double] = [4200, 5100, 4800, 6300, 5900, 7400, 6800, 8100, 7600, 9200, 8800, 9900]

        // Day-shifted bell around late morning + an after-lunch second wind.
        let hours: [Double] = [
            0, 0, 0, 0, 0, 2, 8, 24, 62, 140, 210, 188,
            96, 120, 230, 260, 198, 150, 110, 70, 44, 22, 8, 2
        ]

        let apps: [ModeSlice] = [
            ModeSlice(name: "Safari", symbol: "safari.fill", fraction: 0.42, count: 1_284, bundleId: "com.apple.Safari"),
            ModeSlice(name: "Chrome", symbol: "globe", fraction: 0.27, count: 421, bundleId: "com.google.Chrome"),
            ModeSlice(name: "Notes", symbol: "note.text", fraction: 0.16, count: 266, bundleId: "com.apple.Notes"),
            ModeSlice(name: "Slack", symbol: "bubble.left.fill", fraction: 0.09, count: 155, bundleId: "com.tinyspeck.slackmacgap"),
            ModeSlice(name: "Mail", symbol: "envelope.fill", fraction: 0.06, count: 88, bundleId: "com.apple.mail")
        ]

        // Deterministic sample series per range so previews are stable.
        func series(count: Int, step: Calendar.Component, pattern: [Double]) -> [WordsSeriesPoint] {
            (0..<count).compactMap { i in
                guard let date = calendar.date(byAdding: step, value: -(count - 1 - i), to: anchor) else { return nil }
                let words = pattern[i % pattern.count]
                return WordsSeriesPoint(date: date, value: words, duration: words / 130.0 * 60.0)
            }
        }
        let hourPattern: [Double] = [0, 0, 0, 60, 180, 240, 140, 320, 220, 410]
        let dayPattern: [Double] = [320, 540, 410, 720, 480, 860, 610]
        let weekPattern: [Double] = [2_400, 3_100, 2_700, 3_800, 3_300, 4_200, 3_600, 4_900]
        let monthPattern: [Double] = [9_800, 12_400, 11_100, 14_600, 13_200, 16_800]
        let wordsByRange: [WordsRange: [WordsSeriesPoint]] = [
            .today: series(count: 10, step: .hour, pattern: hourPattern),
            .week: series(count: 7, step: .day, pattern: dayPattern),
            .month: series(count: 30, step: .day, pattern: dayPattern),
            .sixMonths: series(count: 26, step: .weekOfYear, pattern: weekPattern),
            .year: series(count: 12, step: .month, pattern: monthPattern),
            .total: series(count: 18, step: .month, pattern: monthPattern)
        ]

        // Typed series — lower, distinct pattern so the gray line reads as a
        // separate trend in previews. Typed points carry no spoken duration.
        func typedSeries(count: Int, step: Calendar.Component, pattern: [Double]) -> [WordsSeriesPoint] {
            (0..<count).compactMap { i in
                guard let date = calendar.date(byAdding: step, value: -(count - 1 - i), to: anchor) else { return nil }
                return WordsSeriesPoint(date: date, value: pattern[i % pattern.count], duration: 0)
            }
        }
        let typedHourPattern: [Double] = [0, 0, 40, 110, 90, 160, 70, 200, 130, 250]
        let typedDayPattern: [Double] = [180, 320, 240, 420, 280, 510, 360]
        let typedWeekPattern: [Double] = [1_400, 1_900, 1_600, 2_300, 2_000, 2_500, 2_100, 2_900]
        let typedMonthPattern: [Double] = [5_800, 7_400, 6_500, 8_600, 7_800, 9_900]
        let typedWordsByRange: [WordsRange: [WordsSeriesPoint]] = [
            .today: typedSeries(count: 10, step: .hour, pattern: typedHourPattern),
            .week: typedSeries(count: 7, step: .day, pattern: typedDayPattern),
            .month: typedSeries(count: 30, step: .day, pattern: typedDayPattern),
            .sixMonths: typedSeries(count: 26, step: .weekOfYear, pattern: typedWeekPattern),
            .year: typedSeries(count: 12, step: .month, pattern: typedMonthPattern),
            .total: typedSeries(count: 18, step: .month, pattern: typedMonthPattern)
        ]

        return InsightsData(
            days: days,
            modes: modes,
            wpmTrend: wpm.enumerated().map { TrendPoint(index: $0.offset, value: $0.element) },
            wordsTrend: words.enumerated().map { TrendPoint(index: $0.offset, value: $0.element) },
            enhancedTrend: words.enumerated().map { TrendPoint(index: $0.offset, value: $0.element / 7) },
            hourBuckets: hours.enumerated().map { TrendPoint(index: $0.offset, value: $0.element) },
            topApps: apps,
            currentStreak: 2,
            longestStreak: 10,
            wordsDeltaPercent: 24,
            dictionaryWords: 13,
            dictionaryReplacements: 16,
            enhancedSessions: 1843,
            wordsByRange: wordsByRange,
            typedWordsByRange: typedWordsByRange,
            hasTypedData: true
        )
    }()
}
