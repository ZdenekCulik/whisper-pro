import SwiftUI

/// GitHub-style activity heatmap: columns are weeks, rows are weekdays.
/// Cell intensity is bucketed into 5 levels from the day's session count.
struct ContributionGraphView: View {
    let days: [InsightsData.DayActivity]
    var accent: Color
    /// When false (screenshots/tests) cells render at their final state immediately.
    var animate: Bool = true
    /// GitHub-style month labels along the top edge.
    var showMonths: Bool = false

    @EnvironmentObject var theme: ThemeManager
    @State private var appeared = false

    private let cell: CGFloat = 13
    private let spacing: CGFloat = 3
    private let weekdayColumnWidth: CGFloat = 28
    private let weekdayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    /// Split the flat day list into week columns aligned to weekday rows (0 = Sun).
    private var weeks: [[InsightsData.DayActivity?]] {
        let calendar = Calendar(identifier: .gregorian)
        guard let first = days.first else { return [] }
        let leadingPad = calendar.component(.weekday, from: first.date) - 1 // 0...6

        var slots: [InsightsData.DayActivity?] = Array(repeating: nil, count: leadingPad)
        slots.append(contentsOf: days.map { Optional($0) })
        while slots.count % 7 != 0 { slots.append(nil) }

        return stride(from: 0, to: slots.count, by: 7).map { Array(slots[$0..<$0 + 7]) }
    }

    private func level(for count: Int) -> Int {
        guard count > 0 else { return 0 }
        let maxCount = max(days.map(\.count).max() ?? 1, 1)
        let ratio = Double(count) / Double(maxCount)
        switch ratio {
        case ..<0.15: return 1
        case ..<0.4: return 2
        case ..<0.7: return 3
        default: return 4
        }
    }

    private func color(forLevel level: Int) -> Color {
        switch level {
        case 0: return theme.resolvedSecondaryText.opacity(0.12)
        case 1: return accent.opacity(0.28)
        case 2: return accent.opacity(0.5)
        case 3: return accent.opacity(0.72)
        default: return accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if showMonths {
                monthsRow
                    .padding(.leading, weekdayColumnWidth + 6)
            }
            HStack(alignment: .top, spacing: 6) {
                weekdayColumn
                grid
            }
        }
        .onAppear {
            guard animate else { appeared = true; return }
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    private var monthsRow: some View {
        HStack(spacing: spacing) {
            ForEach(weeks.indices, id: \.self) { i in
                Text(monthLabel(at: i))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .fixedSize()
                    .frame(width: cell, alignment: .leading)
            }
        }
    }

    /// Short month name on the first week of each month, empty otherwise.
    private func monthLabel(at index: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        func month(of week: [InsightsData.DayActivity?]) -> Int? {
            week.compactMap { $0 }.first.map { calendar.component(.month, from: $0.date) }
        }
        guard let current = month(of: weeks[index]) else { return "" }
        if index == 0 { return shortMonth(current) }
        if let prev = month(of: weeks[index - 1]), prev == current { return "" }
        return shortMonth(current)
    }

    private func shortMonth(_ month: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        let symbols = calendar.shortMonthSymbols
        guard month >= 1, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }

    private var weekdayColumn: some View {
        VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { row in
                Text(weekdayLabels[row])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .frame(width: weekdayColumnWidth, height: cell, alignment: .trailing)
            }
        }
    }

    private var grid: some View {
        HStack(spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { row in
                        let day = week[row]
                        let lvl = day.map { level(for: $0.count) } ?? 0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(forLevel: lvl))
                            .frame(width: cell, height: cell)
                            .scaleEffect(appeared ? 1 : 0.6)
                            .opacity(appeared ? 1 : 0)
                    }
                }
            }
        }
    }
}

/// "Less ▢▢▢▢ More" legend used beneath the heatmap.
struct ContributionLegend: View {
    var accent: Color
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: 6) {
            Text("Less")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
            ForEach(0..<5, id: \.self) { lvl in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(fill(for: lvl))
                    .frame(width: 11, height: 11)
            }
            Text("More")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
    }

    private func fill(for level: Int) -> Color {
        switch level {
        case 0: return theme.resolvedSecondaryText.opacity(0.12)
        case 1: return accent.opacity(0.28)
        case 2: return accent.opacity(0.5)
        case 3: return accent.opacity(0.72)
        default: return accent
        }
    }
}
