import SwiftUI
import SwiftData
import AppKit

// v2 dashboard: a quiet personal-profile style overview (avatar, greeting, stats
// strip, a year activity heatmap, recent transcripts). Visual components are a 1:1
// port from the Tracking widget's ClaudeSpendBarApp.swift profile tab, re-wired to
// Whisper Pro's own Transcription data instead of Claude spend. Always renders in
// forced dark mode regardless of the app's own theme, matching that source.

private struct DashboardV2Stats: Equatable {
    var wordsToday = 0
    var wordsMonth = 0
    var totalTranscripts = 0
    var totalWords = 0
    var minutesDictated = 0
    var activeDays = 0
    var currentStreak = 0
}

private struct DashboardHeatDay {
    var words = 0
    var count = 0
    var duration: TimeInterval = 0
}

/// Chart style switcher for the activity section, all views over the same
/// underlying daily-words data.
private enum DashboardChartStyle: String, CaseIterable {
    case heatmap, bars, line

    var label: String {
        switch self {
        case .heatmap: return "Heatmap"
        case .bars: return "Bars"
        case .line: return "Line"
        }
    }
}

private enum DashboardChartMetrics {
    static let height: CGFloat = 107
    static let heatColor = Color(red: 0.03, green: 0.51, blue: 1.00)
}

/// One hover snapshot shared by all three chart styles, feeding the shared
/// rich-card tooltip from a single source instead of being duplicated per chart.
private struct DashboardChartHoverInfo: Equatable {
    let date: Date
    let words: Int
    let minutes: Int
    let transcripts: Int
}

/// Shared window used by both the aggregation pass and the heatmap drawing: the
/// 52 weeks (Mon-start) ending on the current week, so both agree on which days
/// are "in the grid".
private enum DashboardHeatmapWindow {
    static let weeks = 52

    static func gridStart(calendar: Calendar, today: Date) -> Date {
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7 // Mon = 0
        return calendar.date(byAdding: .day, value: -(51 * 7 + weekday), to: today)!
    }
}

struct DashboardV2View: View {
    @Environment(\.modelContext) private var modelContext

    @State private var stats = DashboardV2Stats()
    @State private var heatDays: [String: DashboardHeatDay] = [:]
    @State private var recentTranscriptions: [Transcription] = []
    @State private var hasLoaded = false
    @State private var chartSwitcherHovering = false
    @AppStorage("dashboardV2ChartStyle") private var chartStyle: DashboardChartStyle = .heatmap
    @AppStorage("dashboardUserName") private var dashboardUserName = ""
    @AppStorage("dashboardAvatarInitials") private var dashboardAvatarInitials = ""
    // Default to the warm orange-pink gradient (colorSets[1]); a stored user
    // pick still wins since AppStorage only applies this as the initial value.
    @AppStorage("dashboardAvatarColorIndex") private var avatarColorIndex = 1
    @AppStorage("dashboardLastSubtitle") private var lastSubtitle = ""
    @State private var subtitleText = ""

    @AppStorage("sonioxBalanceUSD") private var sonioxBalanceUSD = 0.0
    @AppStorage("sonioxBalanceSetDate") private var sonioxBalanceSetDate = 0.0
    @AppStorage("sonioxBalanceLabel") private var sonioxBalanceLabel = "Soniox"
    @State private var sonioxSpentSinceBalance = 0.0
    @State private var sonioxSpentThisMonth = 0.0

    // One-shot onload animation state: fades/slides the three main sections in
    // with a slight stagger, replayed every time the view appears. Purely
    // SwiftUI-animation driven (no Timer/TimelineView kept running).
    @State private var identityVisible = false
    @State private var statsVisible = false
    @State private var chartVisible = false

    // Matches the same card token every other screen renders on inside
    // ContentView's detailCanvas, so the dashboard reads as one continuous
    // surface with the sidebar/window frame instead of a different dark shade.
    private static let cardBackground = AppTheme.Surface.cardSolid
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                identitySection
                    .opacity(identityVisible ? 1 : 0)
                    .offset(y: identityVisible ? 0 : 8)
                DashboardStatsStripV2(stats: stats)
                .opacity(statsVisible ? 1 : 0)
                .offset(y: statsVisible ? 0 : 8)
                activitySection
                    .opacity(chartVisible ? 1 : 0)
                    .offset(y: chartVisible ? 0 : 8)
                recentSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fills the whole detailCanvas (ContentView renders it on a light card by
        // default) so v2 always reads as one dark screen, no light edge showing.
        .background(Self.cardBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .task {
            await loadData()
            subtitleText = pickSubtitle()
            await loadSonioxUsage()
        }
        .onAppear {
            identityVisible = false
            statsVisible = false
            chartVisible = false
            withAnimation(.easeOut(duration: 0.5)) { identityVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.08)) { statsVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.16)) { chartVisible = true }
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(spacing: 4) {
            DashboardAvatarView(initials: initials, colorIndex: $avatarColorIndex)
                .padding(.bottom, 8)
            Text(greeting)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)
            if !subtitleText.isEmpty {
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var fullName: String {
        let stored = dashboardUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }
        let full = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? "Zdeněk" : full
    }

    private var firstName: String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }

    private var initials: String {
        let stored = dashboardAvatarInitials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }
        let chars = fullName.split(separator: " ").prefix(2).compactMap(\.first)
        let value = String(chars).uppercased()
        return value.isEmpty ? "Z" : value
    }

    // Hour-of-day greeting phrases, ported 1:1 from the Tracking widget's
    // hourlyGreeting (ClaudeSpendBarApp.swift).
    private var greeting: String {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let variants: [[String]] = [
            ["Rest strong", "Sleep easy", "Recharge now"],
            ["Dream bigger", "Rest deeper", "Quiet power"],
            ["Stay steady", "Trust quiet", "Hold calm"],
            ["Keep going", "Soft focus", "Steady mind"],
            ["Dawn soon", "Light returns", "Begin gently"],
            ["Start light", "Wake softly", "Fresh energy"],
            ["Rise sharp", "Own morning", "Start clean"],
            ["Own today", "Move early", "Set pace"],
            ["Build momentum", "Open strong", "Start bright"],
            ["Find flow", "Shape today", "Think fresh"],
            ["Think clearly", "Focus forward", "Make progress"],
            ["Push forward", "Keep pace", "Stay sharp"],
            ["Reset well", "Breathe first", "Midday clarity"],
            ["Move calmly", "Hold focus", "Steady progress"],
            ["Ship progress", "Build clean", "Make it"],
            ["Stay focused", "Protect flow", "Keep shipping"],
            ["Finish strong", "Close well", "Push through"],
            ["Use momentum", "Keep rhythm", "Drive forward"],
            ["Reflect forward", "Evening clarity", "Review gently"],
            ["Keep building", "Evening focus", "Stay with"],
            ["Night focus", "Quiet build", "Deep work"],
            ["Close loops", "Wrap clean", "Finish calmly"],
            ["Rest soon", "Slow down", "Close softly"],
            ["Power down", "End well", "Sleep ready"],
        ]
        let daySeed = Self.dayKeyFormatter.string(from: now).unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let hourVariants = variants[hour % variants.count]
        let action = hourVariants[(daySeed + hour) % hourVariants.count]
        return "\(action), \(firstName)"
    }

    // MARK: - Subtitle

    /// A rotating fun-fact/motivational line under the greeting, picked fresh on
    /// every dashboard open. Avoids repeating the line shown last time.
    private func pickSubtitle() -> String {
        let pool = subtitlePool()
        guard !pool.isEmpty else { return "" }
        let candidates = pool.count > 1 ? pool.filter { $0 != lastSubtitle } : pool
        let choice = candidates.randomElement() ?? pool[0]
        lastSubtitle = choice
        return choice
    }

    private func subtitlePool() -> [String] {
        var pool: [String] = []

        let books: [(title: String, words: Int)] = [
            ("The Hobbit", 95_000),
            ("Harry Potter and the Philosopher's Stone", 77_000),
            ("The Lord of the Rings", 480_000),
            ("War and Peace", 587_000)
        ]
        for book in books {
            let ratio = Double(stats.totalWords) / Double(book.words)
            if ratio >= 0.5 {
                pool.append("You've dictated \(formatRatio(ratio))x the length of \(book.title)")
            }
        }

        if stats.minutesDictated > 0 {
            let movieRatio = Double(stats.minutesDictated) / 120.0
            if movieRatio >= 0.5 {
                pool.append("That's \(formatRatio(movieRatio))x the runtime of a movie, spoken instead of typed")
            }
            let albumRatio = Double(stats.minutesDictated) / 45.0
            if albumRatio >= 0.5 {
                pool.append("Enough talking to fill \(formatRatio(albumRatio)) albums")
            }
        }

        if stats.currentStreak >= 2 {
            pool.append("\(stats.currentStreak)-day streak, keep it alive")
        }
        if stats.activeDays >= 5 {
            pool.append("\(stats.activeDays) active days and counting")
        }
        if stats.totalWords >= 1000 {
            pool.append("\(formattedNumber(stats.totalWords)) words typed by voice, not by hand")
        }

        pool.append(contentsOf: [
            "Every dictated word is one you didn't have to type",
            "Your voice, your words, no keyboard required",
            "Small sessions add up to big totals",
            "Consistency beats intensity",
            "Dictate now, edit never",
            "Speaking is faster than typing, every time",
            "Keep the streak going, one thought at a time"
        ])
        return pool
    }

    private func formatRatio(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Soniox budget pill

    private var showSonioxBudgetPill: Bool {
        sonioxBalanceSetDate > 0 && APIKeyManager.shared.hasAPIKey(forProvider: "Soniox")
    }

    private var sonioxRemaining: Double {
        sonioxBalanceUSD - sonioxSpentSinceBalance
    }

    private var isSonioxBalanceLow: Bool {
        sonioxRemaining < 1.0
    }

    private var sonioxBalanceLabelOrDefault: String {
        let trimmed = sonioxBalanceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Soniox" : trimmed
    }

    private var sonioxBudgetPill: some View {
        Text("\(sonioxBalanceLabelOrDefault) \(formatMoney(sonioxRemaining))")
            .font(.system(size: 12))
            .foregroundStyle(isSonioxBalanceLow ? Color.orange : Color.secondary)
            .help("Estimated remaining Soniox transcription credit, based on usage since you last set your balance. Click to update balance.")
            .contentShape(Rectangle())
            .onTapGesture(perform: openSonioxSettings)
    }

    private var showSonioxSetBalanceAffordance: Bool {
        sonioxBalanceSetDate == 0 && APIKeyManager.shared.hasAPIKey(forProvider: "Soniox")
    }

    private var setSonioxBalanceAffordance: some View {
        Text("Set \(sonioxBalanceLabelOrDefault) balance")
            .font(.system(size: 12))
            .foregroundStyle(Color.accentColor)
            .help("Set your current Soniox transcription credit so the dashboard can estimate the remaining balance from usage.")
            .contentShape(Rectangle())
            .onTapGesture(perform: openSonioxSettings)
    }

    private func openSonioxSettings() {
        NotificationCenter.default.post(name: .navigateToDestination, object: nil, userInfo: ["destination": "Settings"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: .scrollToSonioxBalance, object: nil)
        }
    }

    private func formatMoney(_ value: Double) -> String {
        "$" + String(format: "%.2f", value)
    }

    private func loadSonioxUsage() async {
        guard sonioxBalanceSetDate > 0,
              let apiKey = APIKeyManager.shared.getAPIKey(forProvider: "Soniox"), !apiKey.isEmpty else { return }
        let balanceDate = Date(timeIntervalSince1970: sonioxBalanceSetDate)
        if let result = await SonioxUsageService.fetchUsage(apiKey: apiKey, balanceSetDate: balanceDate) {
            sonioxSpentSinceBalance = result.spentSinceBalanceDate
            sonioxSpentThisMonth = result.spentThisMonth
        }
    }

    // MARK: - Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                dashboardControlPills
            }
            activityChart
            if showSonioxBudgetPill {
                HStack {
                    Spacer()
                    sonioxBudgetPill
                }
                .padding(.top, -4)
            } else if showSonioxSetBalanceAffordance {
                HStack {
                    Spacer()
                    setSonioxBalanceAffordance
                }
                .padding(.top, -4)
            }
        }
    }

    @ViewBuilder
    private var activityChart: some View {
        switch chartStyle {
        case .heatmap:
            DashboardYearHeatmapView(days: heatDays)
        case .bars:
            DashboardBarsChartView(days: heatDays)
        case .line:
            DashboardLineChartView(days: heatDays)
        }
    }

    private var dashboardControlPills: some View {
        HStack(spacing: 14) {
            chartStyleSwitcher
        }
    }

    // Quiet switcher for the three daily-usage chart styles over the same
    // underlying data: just the current style's name, no chrome.
    private var chartStyleSwitcher: some View {
        Menu {
            ForEach(DashboardChartStyle.allCases, id: \.self) { style in
                Button {
                    chartStyle = style
                } label: {
                    if chartStyle == style {
                        Label(style.label, systemImage: "checkmark")
                    } else {
                        Text(style.label)
                    }
                }
            }
        } label: {
            Text(chartStyle.label)
                .font(.system(size: 11))
                .foregroundStyle(chartSwitcherHovering ? .white : .secondary)
        }
        .menuStyle(.borderlessButton)
        .tint(.secondary)
        .fixedSize()
        .onHover { hovering in
            chartSwitcherHovering = hovering
        }
    }

    // MARK: - Recent transcripts

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent transcripts")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            if recentTranscriptions.isEmpty {
                if hasLoaded {
                    Text("No recent dictations yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTranscriptions) { transcription in
                        DashboardV2RecentRow(transcription: transcription)
                    }
                }
            }
        }
    }

    // MARK: - Data loading

    private func loadData() async {
        let container = modelContext.container
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let gridStart = DashboardHeatmapWindow.gridStart(calendar: calendar, today: today)

        let aggregated = try? await Task.detached(priority: .utility) { () -> (DashboardV2Stats, [String: DashboardHeatDay]) in
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<Transcription>()
            descriptor.propertiesToFetch = [\.timestamp, \.duration, \.text, \.enhancedText]
            let items = try context.fetch(descriptor)

            let now = Date()
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"

            var wordsToday = 0
            var wordsMonth = 0
            var totalWords = 0
            var totalDuration: TimeInterval = 0
            var totalTranscripts = 0
            var activeDaySet: Set<Date> = []
            var heatDays: [String: DashboardHeatDay] = [:]

            for item in items {
                let source = item.text.isEmpty ? (item.enhancedText ?? "") : item.text
                let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
                totalTranscripts += 1
                totalWords += wordCount
                totalDuration += item.duration

                let day = calendar.startOfDay(for: item.timestamp)
                activeDaySet.insert(day)

                if calendar.isDateInToday(item.timestamp) {
                    wordsToday += wordCount
                }
                if calendar.isDate(item.timestamp, equalTo: now, toGranularity: .month) {
                    wordsMonth += wordCount
                }

                if day >= gridStart && day <= today {
                    let key = dayFormatter.string(from: item.timestamp)
                    var entry = heatDays[key] ?? DashboardHeatDay()
                    entry.words += wordCount
                    entry.count += 1
                    entry.duration += item.duration
                    heatDays[key] = entry
                }
            }

            // Current streak: consecutive active days ending today, or ending
            // yesterday if nothing has been dictated yet today (today isn't over).
            var streak = 0
            var cursor: Date? = today
            if !activeDaySet.contains(today) {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
                cursor = (yesterday.map { activeDaySet.contains($0) } ?? false) ? yesterday : nil
            }
            while let day = cursor, activeDaySet.contains(day) {
                streak += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: day)
            }

            let stats = DashboardV2Stats(
                wordsToday: wordsToday,
                wordsMonth: wordsMonth,
                totalTranscripts: totalTranscripts,
                totalWords: totalWords,
                minutesDictated: Int((totalDuration / 60).rounded()),
                activeDays: activeDaySet.count,
                currentStreak: streak
            )
            return (stats, heatDays)
        }.value

        var recentDescriptor = FetchDescriptor<Transcription>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        recentDescriptor.fetchLimit = 15
        let recent = (try? modelContext.fetch(recentDescriptor)) ?? []

        if let aggregated {
            stats = aggregated.0
            heatDays = aggregated.1
        }
        recentTranscriptions = recent
        hasLoaded = true
    }
}

private func formattedNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

// MARK: - Avatar (ported from ClaudeSpendBarApp.swift AvatarGradientSurface / avatar)

// 7 pleasant gradient triples for the avatar.
private let avatarColorSets: [[Color]] = [
    [Color(red: 0.33, green: 0.63, blue: 0.98),
     Color(red: 0.29, green: 0.85, blue: 0.60),
     Color(red: 0.45, green: 0.42, blue: 0.95)],
    [Color(red: 0.98, green: 0.45, blue: 0.35),
     Color(red: 0.98, green: 0.72, blue: 0.30),
     Color(red: 0.93, green: 0.35, blue: 0.55)],
    [Color(red: 0.35, green: 0.80, blue: 0.85),
     Color(red: 0.30, green: 0.55, blue: 0.95),
     Color(red: 0.55, green: 0.85, blue: 0.60)],
    [Color(red: 0.95, green: 0.55, blue: 0.85),
     Color(red: 0.65, green: 0.45, blue: 0.95),
     Color(red: 0.40, green: 0.55, blue: 0.98)],
    [Color(red: 0.98, green: 0.60, blue: 0.25),
     Color(red: 0.95, green: 0.35, blue: 0.35),
     Color(red: 0.90, green: 0.75, blue: 0.30)],
    [Color(red: 0.30, green: 0.90, blue: 0.70),
     Color(red: 0.20, green: 0.65, blue: 0.90),
     Color(red: 0.45, green: 0.95, blue: 0.45)],
    [Color(red: 0.55, green: 0.50, blue: 0.98),
     Color(red: 0.85, green: 0.40, blue: 0.90),
     Color(red: 0.35, green: 0.60, blue: 0.98)]
]

private struct DashboardAvatarView: View {
    let initials: String
    @Binding var colorIndex: Int
    @State private var isHovered = false

    private var colors: [Color] {
        let sets = avatarColorSets
        return sets[((colorIndex % sets.count) + sets.count) % sets.count]
    }

    // Static frame shown when the avatar is idle, so the ~20fps clock only
    // runs while hovered instead of burning CPU forever.
    private static let idleTime: Double = 0

    @ViewBuilder
    private func spinSurface(at t: Double) -> some View {
        let endRadius: CGFloat = 30
        let hotspot = UnitPoint(x: 0.5 + 0.30 * cos(t * 0.9), y: 0.5 + 0.30 * sin(t * 1.35))
        ZStack {
            AngularGradient(colors: colors + colors + colors + colors + [colors[0]],
                            center: .center, angle: .degrees(t * 18))
            RadialGradient(colors: [colors[1].opacity(0.8), .clear],
                           center: hotspot,
                           startRadius: 1, endRadius: endRadius)
        }
        .scaleEffect(1.25)
        .blur(radius: 1)
    }

    var body: some View {
        ZStack {
            if isHovered {
                TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                    spinSurface(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                spinSurface(at: Self.idleTime)
            }
            Text(initials)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                colorIndex = (colorIndex + 1) % avatarColorSets.count
            }
        }
    }
}

// MARK: - Stats strip (ported from ClaudeSpendBarApp.swift profileStatsStrip)

private struct DashboardStatsStripV2: View {
    let stats: DashboardV2Stats

    // Drives the count-up: starts at zero on every appearance, then animates
    // to the real `stats` once loaded (or immediately if already loaded).
    @State private var displayStats = DashboardV2Stats()

    var body: some View {
        statCells
    }

    @ViewBuilder
    private var statCells: some View {
        Group {
            HStack(spacing: 0) {
                cellV2("Today", \.wordsToday, icon: "sun.max")
                divider
                cellV2("Month", \.wordsMonth, icon: "calendar")
                divider
                cellV2("Words", \.totalWords, icon: "textformat")
                divider
                cellV2("Minutes", \.minutesDictated, icon: "clock")
                divider
                cellV2("Active days", \.activeDays, icon: "calendar.badge.checkmark")
                divider
                cellV2("Streak", \.currentStreak, icon: "flame") { "\($0)d" }
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            displayStats = DashboardV2Stats()
            withAnimation(.easeOut(duration: 0.7)) {
                displayStats = stats
            }
        }
        .onChange(of: stats) { _, newStats in
            withAnimation(.easeOut(duration: 0.7)) {
                displayStats = newStats
            }
        }
    }

    private func cellV2(_ label: String,
                         _ keyPath: KeyPath<DashboardV2Stats, Int>,
                         icon: String,
                         format: @escaping (Int) -> String = { formattedNumber($0) }) -> some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 9)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.bottom, 2)
            DashboardCountUpNumber(value: Double(displayStats[keyPath: keyPath]), format: format)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 30)
    }
}

/// Number text whose displayed integer is driven by SwiftUI's animation
/// system (via `animatableData`) so it visibly counts up/down between values
/// with a single `withAnimation` call, no Timer or TimelineView involved.
private struct DashboardCountUpNumber: View, Animatable {
    var value: Double
    let format: (Int) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(Int(value.rounded())))
    }
}

// MARK: - Activity heatmap (ported from ClaudeSpendBarApp.swift YearHeatmapView, daily mode)

private struct DashboardYearHeatmapView: View {
    let days: [String: DashboardHeatDay]

    @State private var hoverDate: Date?
    @State private var hoverPoint: CGPoint = .zero

    private let gap: CGFloat = 2
    private let fallbackCell: CGFloat = 10
    private static let heatColor = Color(red: 0.03, green: 0.51, blue: 1.00)
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let gridStart = DashboardHeatmapWindow.gridStart(calendar: calendar, today: today)
        let weeks = DashboardHeatmapWindow.weeks
        let maxDay = days.values.map(\.words).max() ?? 0
        let df = Self.dayFormatter
        let blockHeight = 7 * (fallbackCell + gap) + 5 + 12 + 6

        GeometryReader { geo in
            let rawCell = (geo.size.width - CGFloat(weeks - 1) * gap) / CGFloat(weeks)
            let cell = (rawCell.isFinite && rawCell > 1) ? rawCell : fallbackCell
            let labelY = 7 * (cell + gap) + 5

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    var lastMonth = -1
                    for w in 0..<weeks {
                        if let colDate = calendar.date(byAdding: .day, value: w * 7, to: gridStart) {
                            let month = calendar.component(.month, from: colDate)
                            if month != lastMonth {
                                if w > 0 {
                                    let label = Text(monthAbbrev(month))
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.45))
                                    let nearEdge = w >= weeks - 3
                                    ctx.draw(ctx.resolve(label),
                                             at: CGPoint(x: CGFloat(w) * (cell + gap) + (nearEdge ? cell : 0),
                                                         y: labelY),
                                             anchor: nearEdge ? .topTrailing : .topLeading)
                                }
                                lastMonth = month
                            }
                        }
                        for r in 0..<7 {
                            guard let date = calendar.date(byAdding: .day, value: w * 7 + r, to: gridStart),
                                  date <= today else { continue }
                            let rect = CGRect(x: CGFloat(w) * (cell + gap),
                                              y: CGFloat(r) * (cell + gap),
                                              width: cell, height: cell)
                            let day = days[df.string(from: date)]
                            let hasWords = (day?.words ?? 0) > 0 && maxDay > 0
                            let baseAlpha = hasWords ? 0.18 + 0.82 * sqrt(Double(day!.words) / Double(maxDay)) : 0.07
                            let isHovered = hoverDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false

                            let alpha = isHovered ? (hasWords ? 1.0 : 0.16) : baseAlpha
                            let color: Color = hasWords ? Self.heatColor.opacity(alpha) : Color.white.opacity(alpha)
                            let drawRect = isHovered ? rect.insetBy(dx: -0.5, dy: -0.5) : rect
                            let path = Path(roundedRect: drawRect, cornerRadius: cell * 0.24)
                            ctx.fill(path, with: .color(color))
                            if isHovered {
                                ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: hoverDate)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pt):
                        let w = Int(pt.x / (cell + gap)), r = Int(pt.y / (cell + gap))
                        guard w >= 0, w < weeks, r >= 0, r < 7,
                              let date = calendar.date(byAdding: .day, value: w * 7 + r, to: gridStart),
                              date <= today else {
                            hoverDate = nil
                            return
                        }
                        hoverPoint = pt
                        hoverDate = date
                    case .ended:
                        hoverDate = nil
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let hoverDate {
                        DashboardTooltipRichCard(info: info(for: hoverDate))
                            .offset(x: dashboardTooltipX(hoverPoint.x, containerWidth: geo.size.width),
                                    y: dashboardTooltipY(hoverPoint.y))
                            .zIndex(10)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: blockHeight, maxHeight: blockHeight, alignment: .topLeading)
    }

    private func info(for date: Date) -> DashboardChartHoverInfo {
        let day = days[Self.dayFormatter.string(from: date)]
        return DashboardChartHoverInfo(date: date,
                                        words: day?.words ?? 0,
                                        minutes: Int(((day?.duration ?? 0) / 60).rounded()),
                                        transcripts: day?.count ?? 0)
    }

    private func monthAbbrev(_ m: Int) -> String {
        ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m]
    }
}

// MARK: - Chart helpers shared by the bars and line chart styles

private let dashboardDayKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private func dashboardShortDate(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.month, .day], from: d)
    return "\(dashboardMonthAbbrev(c.month ?? 0)) \(c.day ?? 0)"
}

private func dashboardMonthAbbrev(_ m: Int) -> String {
    ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m]
}

/// Rich-card tooltip position: horizontally centered on the cursor (clamped to
/// stay inside the chart's width), and always above the cursor with a small
/// gap, free to overflow past the top of the chart (no clamp on the low side).
private func dashboardTooltipX(_ cursorX: CGFloat, containerWidth: CGFloat) -> CGFloat {
    let halfWidth = DashboardTooltipRichCard.estimatedWidth / 2
    return min(max(cursorX - halfWidth, 0), max(0, containerWidth - DashboardTooltipRichCard.estimatedWidth))
}

private func dashboardTooltipY(_ cursorY: CGFloat) -> CGFloat {
    cursorY - DashboardTooltipRichCard.estimatedHeight - 18
}

/// Polyline through `points` with each interior corner rounded off by a tiny
/// quad curve, so the line chart's joints read as smooth rather than jagged
/// teeth, without softening the data into a full spline.
private func dashboardRoundedLinePath(points: [CGPoint], cornerRadius: CGFloat) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    guard points.count > 1 else { return path }

    for i in 1..<points.count {
        let prev = points[i - 1]
        let curr = points[i]
        guard i < points.count - 1 else {
            path.addLine(to: curr)
            break
        }
        let next = points[i + 1]

        let inVector = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
        let inLength = max(hypot(inVector.dx, inVector.dy), 0.0001)
        let cornerStart = CGPoint(x: curr.x - inVector.dx / inLength * cornerRadius,
                                   y: curr.y - inVector.dy / inLength * cornerRadius)

        let outVector = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
        let outLength = max(hypot(outVector.dx, outVector.dy), 0.0001)
        let cornerEnd = CGPoint(x: curr.x + outVector.dx / outLength * cornerRadius,
                                 y: curr.y + outVector.dy / outLength * cornerRadius)

        path.addLine(to: cornerStart)
        path.addQuadCurve(to: cornerEnd, control: curr)
    }
    return path
}

/// Rich-card tooltip: compact date header plus label/value rows, shared by
/// heatmap, bars, and line so it isn't copied three times.
private struct DashboardTooltipRichCard: View {
    let info: DashboardChartHoverInfo

    // Rough fixed footprint used by the position helpers above (the card is
    // fixedSize, so this only needs to be a close estimate, not exact).
    static let estimatedWidth: CGFloat = 118
    static let estimatedHeight: CGFloat = 74

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(dashboardShortDate(info.date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
            row(label: "Words", value: formattedNumber(info.words))
            row(label: "Minutes", value: "\(info.minutes)")
            row(label: "Transcripts", value: "\(info.transcripts)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.Surface.cardSolid)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .fixedSize()
        // The card's position (offset, set by callers) is allowed to animate
        // with the cursor, but the text content inside must snap instantly to
        // the new date/values on every hover update - otherwise it inherits
        // the ancestor chart's `.animation(value: hoverDate/hoverIndex)` and
        // cross-fades/slides between old and new numbers while resizing to
        // fit, visibly overflowing the card during fast hovers.
        .animation(nil, value: info)
    }

    private func row(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 9))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(minWidth: 96)
    }
}

// MARK: - Bars (last ~60 days)

private struct DashboardBarsChartView: View {
    let days: [String: DashboardHeatDay]

    private let dayCount = 60

    @State private var hoverIndex: Int?
    @State private var hoverPoint: CGPoint = .zero

    private var series: [(date: Date, day: DashboardHeatDay?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<dayCount).map { i in
            let date = calendar.date(byAdding: .day, value: -(dayCount - 1 - i), to: today)!
            return (date, days[dashboardDayKeyFormatter.string(from: date)])
        }
    }

    private func info(for item: (date: Date, day: DashboardHeatDay?)) -> DashboardChartHoverInfo {
        DashboardChartHoverInfo(date: item.date,
                                 words: item.day?.words ?? 0,
                                 minutes: Int(((item.day?.duration ?? 0) / 60).rounded()),
                                 transcripts: item.day?.count ?? 0)
    }

    var body: some View {
        let items = series
        let maxWords = items.compactMap { $0.day?.words }.max() ?? 0
        let gap: CGFloat = 3

        GeometryReader { geo in
            let slotWidth = max((geo.size.width - CGFloat(dayCount - 1) * gap) / CGFloat(dayCount), 1)
            let barWidth = slotWidth
            let xOffset = (slotWidth - barWidth) / 2
            let chartBottom = geo.size.height - 4
            let chartHeight = chartBottom - 4

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for (i, item) in items.enumerated() {
                        let words = item.day?.words ?? 0
                        let ratio = maxWords > 0 ? Double(words) / Double(maxWords) : 0
                        let barHeight = max(CGFloat(ratio) * chartHeight, words > 0 ? 3 : 1)
                        let x = CGFloat(i) * (slotWidth + gap) + xOffset
                        let rect = CGRect(x: x, y: chartBottom - barHeight, width: barWidth, height: barHeight)

                        let baseAlpha = words > 0 ? 0.18 + 0.82 * sqrt(ratio) : 0.07
                        let isHovered = hoverIndex == i
                        let alpha = isHovered ? (words > 0 ? 1.0 : 0.16) : baseAlpha
                        let color = words > 0 ? DashboardChartMetrics.heatColor.opacity(alpha) : Color.white.opacity(alpha)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: min(barWidth * 0.3, 3)), with: .color(color))
                    }
                }
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: hoverIndex)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pt):
                        let i = Int(pt.x / (slotWidth + gap))
                        guard items.indices.contains(i) else {
                            hoverIndex = nil
                            return
                        }
                        hoverPoint = pt
                        hoverIndex = i
                    case .ended:
                        hoverIndex = nil
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let hoverIndex, items.indices.contains(hoverIndex) {
                        let item = items[hoverIndex]
                        DashboardTooltipRichCard(info: info(for: item))
                            .offset(x: dashboardTooltipX(hoverPoint.x, containerWidth: geo.size.width),
                                    y: dashboardTooltipY(hoverPoint.y))
                            .zIndex(10)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: DashboardChartMetrics.height, maxHeight: DashboardChartMetrics.height)
    }
}

// MARK: - Line/area (last ~90 days)

private struct DashboardLineChartView: View {
    let days: [String: DashboardHeatDay]

    private let dayCount = 90

    @State private var hoverIndex: Int?
    @State private var hoverPoint: CGPoint = .zero

    private var series: [(date: Date, day: DashboardHeatDay?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<dayCount).map { i in
            let date = calendar.date(byAdding: .day, value: -(dayCount - 1 - i), to: today)!
            return (date, days[dashboardDayKeyFormatter.string(from: date)])
        }
    }

    private func info(for item: (date: Date, day: DashboardHeatDay?)) -> DashboardChartHoverInfo {
        DashboardChartHoverInfo(date: item.date,
                                 words: item.day?.words ?? 0,
                                 minutes: Int(((item.day?.duration ?? 0) / 60).rounded()),
                                 transcripts: item.day?.count ?? 0)
    }

    var body: some View {
        let items = series
        let maxWords = max(items.compactMap { $0.day?.words }.max() ?? 0, 1)

        GeometryReader { geo in
            let chartTop: CGFloat = 6
            let chartBottom = geo.size.height - 4
            let chartHeight = chartBottom - chartTop
            let stepX = items.count > 1 ? geo.size.width / CGFloat(items.count - 1) : 0
            let points: [CGPoint] = items.indices.map { i in
                let words = items[i].day?.words ?? 0
                let ratio = Double(words) / Double(maxWords)
                return CGPoint(x: CGFloat(i) * stepX, y: chartBottom - CGFloat(ratio) * chartHeight)
            }

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    let heatColor = DashboardChartMetrics.heatColor

                    // Minimal stepped line over a dotted baseline.
                    var stepPath = Path()
                    if let first = points.first {
                        stepPath.move(to: first)
                        for i in 1..<points.count {
                            let prev = points[i - 1]
                            let curr = points[i]
                            stepPath.addLine(to: CGPoint(x: curr.x, y: prev.y))
                            stepPath.addLine(to: curr)
                        }
                    }
                    var baseline = Path()
                    baseline.move(to: CGPoint(x: 0, y: chartBottom))
                    baseline.addLine(to: CGPoint(x: geo.size.width, y: chartBottom))
                    ctx.stroke(baseline, with: .color(.white.opacity(0.15)),
                                style: StrokeStyle(lineWidth: 1, dash: [1, 4], dashPhase: 0))

                    if let hoverPoint = hoverIndex.flatMap({ items.indices.contains($0) ? points[$0] : nil }) {
                        var guideLine = Path()
                        guideLine.move(to: CGPoint(x: hoverPoint.x, y: chartTop))
                        guideLine.addLine(to: CGPoint(x: hoverPoint.x, y: chartBottom))
                        ctx.stroke(guideLine, with: .color(.white.opacity(0.15)),
                                    style: StrokeStyle(lineWidth: 1, dash: [1, 4], dashPhase: 0))
                    }

                    ctx.stroke(stepPath, with: .color(heatColor.opacity(0.85)),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: hoverIndex)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pt):
                        guard stepX > 0 else {
                            hoverIndex = nil
                            return
                        }
                        let i = Int((pt.x / stepX).rounded())
                        guard items.indices.contains(i) else {
                            hoverIndex = nil
                            return
                        }
                        hoverPoint = points[i]
                        hoverIndex = i
                    case .ended:
                        hoverIndex = nil
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let hoverIndex, items.indices.contains(hoverIndex) {
                        let item = items[hoverIndex]
                        ZStack(alignment: .topLeading) {
                            Circle()
                                .fill(DashboardChartMetrics.heatColor)
                                .overlay(Circle().stroke(AppTheme.Surface.cardSolid, lineWidth: 1.5))
                                .frame(width: 8, height: 8)
                                .offset(x: hoverPoint.x - 4, y: hoverPoint.y - 4)
                            DashboardTooltipRichCard(info: info(for: item))
                                .offset(x: dashboardTooltipX(hoverPoint.x, containerWidth: geo.size.width),
                                        y: dashboardTooltipY(hoverPoint.y))
                                .zIndex(10)
                        }
                        .allowsHitTesting(false)
                        .animation(.easeOut(duration: 0.12), value: hoverIndex)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: DashboardChartMetrics.height, maxHeight: DashboardChartMetrics.height)
    }
}

// MARK: - Recent transcripts row

private struct DashboardV2RecentRow: View {
    let transcription: Transcription

    private static let weekdayAbbrevs = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var displayText: String {
        transcription.enhancedText ?? transcription.text
    }

    // Today -> just the time. This week -> weekday + time. Older -> "12 Jul".
    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let date = transcription.timestamp
        let time = Self.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) {
            return time
        }
        let startOfDate = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: Date())
        let daysAgo = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0
        if daysAgo < 7 {
            let weekday = calendar.component(.weekday, from: date)
            return "\(Self.weekdayAbbrevs[weekday]) \(time)"
        }
        let components = calendar.dateComponents([.day, .month], from: date)
        return "\(components.day ?? 0) \(dashboardMonthAbbrev(components.month ?? 0))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(formattedTimestamp)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
                .padding(.top, 6)

            Text(displayText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            CopyIconButton(textToCopy: displayText)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            _ = ClipboardManager.copyToClipboard(displayText)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}
