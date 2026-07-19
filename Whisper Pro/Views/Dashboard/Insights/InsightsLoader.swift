import Foundation
import SwiftData

/// Caches the last successfully loaded `InsightsData` for the lifetime of the app
/// process. Dashboard/Stats views get torn down and rebuilt every time you switch
/// tabs (their `@State` resets to nil), which used to make the hero card flash an
/// empty state on every visit while `InsightsLoader.load` re-ran its full scan.
/// Seeding fresh view state from this cache means the last known numbers stay on
/// screen until the new load actually completes.
enum InsightsDataCache {
    static let shared = LatestValueCache<InsightsData>()
}

/// Aggregates stored `SessionMetric` rows into the `InsightsData` the panel renders.
/// Runs off the main actor over a background context, iterating rows once.
enum InsightsLoader {
    /// Whisper Pro itself — never counts as an app you "dictate into".
    /// The app ships under the original VoiceInk bundle id, so filter that.
    private static let selfBundleIds: Set<String> = [
        "com.prakashjoshipax.voiceink",
        "com.prakashjoshipax.whisperpro"
    ]
    private static let dayGridLength = 17 * 7
    private static let weeklyTrendCount = 12

    static func load(from container: ModelContainer, now: Date = Date()) async throws -> InsightsData? {
        let task = Task.detached(priority: .utility) { () throws -> InsightsData? in
            try Task.checkCancellation()
            let context = ModelContext(container)
            let total = try context.fetchCount(FetchDescriptor<SessionMetric>())
            guard total > 0 else { return nil }

            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US")
            let today = calendar.startOfDay(for: now)

            // Accumulators
            var wordsPerDay: [Date: Int] = [:]
            var durationPerDay: [Date: Double] = [:]
            var hourWords = Array(repeating: 0, count: 24)
            var appCounts: [String: (count: Int, bundle: String?)] = [:]
            var modeCounts: [String: Int] = [:]
            var weeklyWords = Array(repeating: 0, count: weeklyTrendCount)
            var weeklyDuration = Array(repeating: 0.0, count: weeklyTrendCount)
            var weeklyEnhanced = Array(repeating: 0, count: weeklyTrendCount)
            var hourWordsToday = Array(repeating: 0, count: 24)
            var durationHourToday = Array(repeating: 0.0, count: 24)
            var wordsPerMonth: [Date: Int] = [:]
            var durationPerMonth: [Date: Double] = [:]
            var thisMonthWords = 0
            var lastMonthWords = 0
            var enhancedSessions = 0

            let thisMonth = calendar.dateComponents([.year, .month], from: today)
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            let lastMonth = calendar.dateComponents([.year, .month], from: lastMonthDate)

            // Stream all metrics in batches.
            let batchSize = 500
            var offset = 0
            while offset < total {
                try Task.checkCancellation()
                var descriptor = FetchDescriptor<SessionMetric>(sortBy: [SortDescriptor(\.timestamp)])
                descriptor.fetchLimit = batchSize
                descriptor.fetchOffset = offset
                let rows = try context.fetch(descriptor)
                if rows.isEmpty { break }

                for metric in rows {
                    let day = calendar.startOfDay(for: metric.timestamp)
                    wordsPerDay[day, default: 0] += metric.wordCount
                    durationPerDay[day, default: 0] += metric.audioDuration

                    let hour = calendar.component(.hour, from: metric.timestamp)
                    if hour >= 0, hour < 24 { hourWords[hour] += metric.wordCount }

                    if calendar.isDate(metric.timestamp, inSameDayAs: today), hour >= 0, hour < 24 {
                        hourWordsToday[hour] += metric.wordCount
                        durationHourToday[hour] += metric.audioDuration
                    }

                    let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: metric.timestamp)) ?? day
                    wordsPerMonth[monthKey, default: 0] += metric.wordCount
                    durationPerMonth[monthKey, default: 0] += metric.audioDuration

                    if let name = metric.appName,
                       !name.isEmpty,
                       !selfBundleIds.contains((metric.appBundleId ?? "").lowercased()) {
                        let existing = appCounts[name]
                        appCounts[name] = ((existing?.count ?? 0) + 1, metric.appBundleId)
                    }
                    if let mode = metric.modeName, !mode.isEmpty {
                        modeCounts[mode, default: 0] += 1
                    }
                    if metric.aiEnhancementModelName?.isEmpty == false {
                        enhancedSessions += 1
                    }

                    // Weekly trend: how many whole weeks back from today.
                    let weeksAgo = (calendar.dateComponents([.day], from: calendar.startOfDay(for: metric.timestamp), to: today).day ?? 0) / 7
                    if weeksAgo >= 0, weeksAgo < weeklyTrendCount {
                        let bucket = weeklyTrendCount - 1 - weeksAgo
                        weeklyWords[bucket] += metric.wordCount
                        weeklyDuration[bucket] += metric.audioDuration
                        if metric.aiEnhancementModelName?.isEmpty == false {
                            weeklyEnhanced[bucket] += 1
                        }
                    }

                    let mc = calendar.dateComponents([.year, .month], from: metric.timestamp)
                    if mc.year == thisMonth.year, mc.month == thisMonth.month {
                        thisMonthWords += metric.wordCount
                    } else if mc.year == lastMonth.year, mc.month == lastMonth.month {
                        lastMonthWords += metric.wordCount
                    }
                }
                offset += rows.count
            }

            // Build day grid (oldest first, ending today).
            var days: [InsightsData.DayActivity] = []
            for back in stride(from: dayGridLength - 1, through: 0, by: -1) {
                guard let date = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
                days.append(InsightsData.DayActivity(date: date, count: wordsPerDay[date] ?? 0))
            }

            // Streaks (consecutive days with words, ending today or yesterday).
            let (current, longest) = streaks(days: days)

            // Trends
            let wordsTrend = weeklyWords.enumerated().map {
                InsightsData.TrendPoint(index: $0.offset, value: Double($0.element))
            }
            let wpmTrend = zip(weeklyWords, weeklyDuration).enumerated().map { idx, pair in
                let (words, duration) = pair
                let wpm = duration > 0 ? Double(words) / (duration / 60.0) : 0
                return InsightsData.TrendPoint(index: idx, value: wpm)
            }
            let enhancedTrend = weeklyEnhanced.enumerated().map {
                InsightsData.TrendPoint(index: $0.offset, value: Double($0.element))
            }
            let hourBuckets = hourWords.enumerated().map {
                InsightsData.TrendPoint(index: $0.offset, value: Double($0.element))
            }

            // Words time-series, pre-bucketed per selectable range.
            func dailySeries(daysBack: Int) -> [WordsSeriesPoint] {
                stride(from: daysBack - 1, through: 0, by: -1).compactMap { back in
                    guard let date = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
                    return WordsSeriesPoint(date: date, value: Double(wordsPerDay[date] ?? 0), duration: durationPerDay[date] ?? 0)
                }
            }

            let currentHour = calendar.component(.hour, from: now)
            let todaySeries: [WordsSeriesPoint] = (0...currentHour).compactMap { h in
                guard let date = calendar.date(byAdding: .hour, value: h, to: today) else { return nil }
                return WordsSeriesPoint(date: date, value: Double(hourWordsToday[h]), duration: durationHourToday[h])
            }

            // 26 weekly buckets ≈ 6 months, each summing the 7 days ending that week.
            let sixMonthsSeries: [WordsSeriesPoint] = stride(from: 25, through: 0, by: -1).compactMap { back in
                guard let weekEnd = calendar.date(byAdding: .day, value: -back * 7, to: today) else { return nil }
                let sum = (0..<7).reduce(0) { acc, d in
                    guard let day = calendar.date(byAdding: .day, value: -d, to: weekEnd) else { return acc }
                    return acc + (wordsPerDay[day] ?? 0)
                }
                let durSum = (0..<7).reduce(0.0) { acc, d in
                    guard let day = calendar.date(byAdding: .day, value: -d, to: weekEnd) else { return acc }
                    return acc + (durationPerDay[day] ?? 0)
                }
                let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
                return WordsSeriesPoint(date: weekStart, value: Double(sum), duration: durSum)
            }

            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            let yearSeries: [WordsSeriesPoint] = stride(from: 11, through: 0, by: -1).compactMap { back in
                guard let m = calendar.date(byAdding: .month, value: -back, to: currentMonthStart) else { return nil }
                return WordsSeriesPoint(date: m, value: Double(wordsPerMonth[m] ?? 0), duration: durationPerMonth[m] ?? 0)
            }

            // All time stays daily: the first bar is the first day Whisper Pro
            // recorded a session, and every calendar day through today gets a bar.
            // Explicit zero days preserve honest spacing between active days.
            var totalSeries: [WordsSeriesPoint] = []
            if let earliest = wordsPerDay.keys.min() {
                var cursor = earliest
                while cursor <= today {
                    totalSeries.append(
                        WordsSeriesPoint(
                            date: cursor,
                            value: Double(wordsPerDay[cursor] ?? 0),
                            duration: durationPerDay[cursor] ?? 0
                        )
                    )
                    guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                }
            }

            let wordsByRange: [WordsRange: [WordsSeriesPoint]] = [
                .today: todaySeries,
                .week: dailySeries(daysBack: 7),
                .month: dailySeries(daysBack: 30),
                .sixMonths: sixMonthsSeries,
                .year: yearSeries,
                .total: totalSeries
            ]

            // MARK: Typed-words ("Napsáno") second pass.
            // Reads cached TypedDailyMetric aggregates (Claude + Codex) and buckets
            // them onto the SAME date grid as the blue series so the x-axis aligns.
            // Typed points carry duration 0 (no spoken audio) and we emit explicit
            // zero-value points for empty buckets so the gray line stays continuous.
            var typedWordsPerDay: [Date: Int] = [:]
            var typedWordsPerMonth: [Date: Int] = [:]
            var hasTypedData = false
            // TypedDailyMetric lives in its OWN dedicated store (see TypedStore), not
            // the main container, so read it from there.
            let typedRows: [TypedDailyMetric] = {
                guard let typedContainer = TypedStore.container else { return [] }
                let typedContext = ModelContext(typedContainer)
                return (try? typedContext.fetch(FetchDescriptor<TypedDailyMetric>())) ?? []
            }()
            if !typedRows.isEmpty { hasTypedData = true }
            for row in typedRows {
                let day = calendar.startOfDay(for: row.day)
                typedWordsPerDay[day, default: 0] += row.typedWords
                let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: row.day)) ?? day
                typedWordsPerMonth[monthKey, default: 0] += row.typedWords
            }

            func typedDailySeries(daysBack: Int) -> [WordsSeriesPoint] {
                stride(from: daysBack - 1, through: 0, by: -1).compactMap { back in
                    guard let date = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
                    return WordsSeriesPoint(date: date, value: Double(typedWordsPerDay[date] ?? 0), duration: 0)
                }
            }

            // No per-hour typed resolution exists (typed data is bucketed per day),
            // so the "today" typed series is all-zero on the same hour grid as blue.
            let typedTodaySeries: [WordsSeriesPoint] = (0...currentHour).compactMap { h in
                guard let date = calendar.date(byAdding: .hour, value: h, to: today) else { return nil }
                return WordsSeriesPoint(date: date, value: 0, duration: 0)
            }

            let typedSixMonthsSeries: [WordsSeriesPoint] = stride(from: 25, through: 0, by: -1).compactMap { back in
                guard let weekEnd = calendar.date(byAdding: .day, value: -back * 7, to: today) else { return nil }
                let sum = (0..<7).reduce(0) { acc, d in
                    guard let day = calendar.date(byAdding: .day, value: -d, to: weekEnd) else { return acc }
                    return acc + (typedWordsPerDay[day] ?? 0)
                }
                let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
                return WordsSeriesPoint(date: weekStart, value: Double(sum), duration: 0)
            }

            let typedYearSeries: [WordsSeriesPoint] = stride(from: 11, through: 0, by: -1).compactMap { back in
                guard let m = calendar.date(byAdding: .month, value: -back, to: currentMonthStart) else { return nil }
                return WordsSeriesPoint(date: m, value: Double(typedWordsPerMonth[m] ?? 0), duration: 0)
            }

            // Align typed totals to the exact daily grid of the dictation series.
            let typedTotalSeries = totalSeries.map {
                WordsSeriesPoint(date: $0.date, value: Double(typedWordsPerDay[$0.date] ?? 0), duration: 0)
            }

            let typedWordsByRange: [WordsRange: [WordsSeriesPoint]] = [
                .today: typedTodaySeries,
                .week: typedDailySeries(daysBack: 7),
                .month: typedDailySeries(daysBack: 30),
                .sixMonths: typedSixMonthsSeries,
                .year: typedYearSeries,
                .total: typedTotalSeries
            ]

            // Top apps
            let appTotal = max(appCounts.values.reduce(0) { $0 + $1.count }, 1)
            let topApps = appCounts
                .sorted { $0.value.count > $1.value.count }
                .prefix(5)
                .map { name, value in
                    InsightsData.ModeSlice(
                        name: name,
                        symbol: appSymbol(forBundle: value.bundle),
                        fraction: Double(value.count) / Double(appTotal),
                        count: value.count,
                        bundleId: value.bundle
                    )
                }

            // Modes
            let modeTotal = max(modeCounts.values.reduce(0, +), 1)
            let modes = modeCounts
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { name, count in
                    InsightsData.ModeSlice(
                        name: name,
                        symbol: "mic.fill",
                        fraction: Double(count) / Double(modeTotal),
                        count: count
                    )
                }

            let delta: Int = lastMonthWords > 0
                ? Int((Double(thisMonthWords - lastMonthWords) / Double(lastMonthWords) * 100).rounded())
                : 0

            let dictionaryWords = (try? context.fetchCount(FetchDescriptor<VocabularyWord>())) ?? 0
            let dictionaryReplacements = (try? context.fetchCount(FetchDescriptor<WordReplacement>())) ?? 0

            return InsightsData(
                days: days,
                modes: Array(modes),
                wpmTrend: wpmTrend,
                wordsTrend: wordsTrend,
                enhancedTrend: enhancedTrend,
                hourBuckets: hourBuckets,
                topApps: Array(topApps),
                currentStreak: current,
                longestStreak: longest,
                wordsDeltaPercent: delta,
                dictionaryWords: dictionaryWords,
                dictionaryReplacements: dictionaryReplacements,
                enhancedSessions: enhancedSessions,
                wordsByRange: wordsByRange,
                typedWordsByRange: typedWordsByRange,
                hasTypedData: hasTypedData
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func streaks(days: [InsightsData.DayActivity]) -> (current: Int, longest: Int) {
        var longest = 0
        var run = 0
        for day in days {
            if day.count > 0 { run += 1; longest = max(longest, run) }
            else { run = 0 }
        }
        // Current streak = trailing run of active days. Skip today when it has no
        // activity yet, so a streak ending yesterday still counts (you haven't
        // necessarily dictated today).
        var current = 0
        let trailing = (days.last?.count == 0) ? days.dropLast() : days[...]
        for day in trailing.reversed() {
            if day.count > 0 { current += 1 } else { break }
        }
        return (current, longest)
    }

    private static func appSymbol(forBundle bundle: String?) -> String {
        guard let bundle = bundle?.lowercased() else { return "app.fill" }
        if bundle.contains("cursor") || bundle.contains("code") || bundle.contains("xcode") {
            return "chevron.left.forwardslash.chevron.right"
        }
        if bundle.contains("safari") || bundle.contains("chrome") || bundle.contains("arc") || bundle.contains("firefox") {
            return "safari.fill"
        }
        if bundle.contains("slack") || bundle.contains("discord") || bundle.contains("message") {
            return "bubble.left.fill"
        }
        if bundle.contains("mail") || bundle.contains("spark") || bundle.contains("outlook") {
            return "envelope.fill"
        }
        if bundle.contains("note") || bundle.contains("obsidian") || bundle.contains("bear") {
            return "note.text"
        }
        return "app.fill"
    }
}
